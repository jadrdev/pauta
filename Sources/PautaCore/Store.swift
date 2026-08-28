import Foundation
import Observation

/// Formateadores de fecha, a propósito fuera de `Store`: dentro quedarían
/// aislados al actor principal y el codificador los usa desde clausuras
/// `Sendable`. `ISO8601DateFormatter` es seguro para formatear en paralelo.
///
/// La fracción de segundo importa: sin ella, dos tareas creadas en el mismo
/// segundo quedan con la misma fecha y su orden relativo se pierde al guardar,
/// así que pegar varias líneas y reabrir la app las reordenaría.
private enum ISODate {
    nonisolated(unsafe) static let precise: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    nonisolated(unsafe) static let secondsOnly = ISO8601DateFormatter()
}

/// Cuánto se conservan las lápidas antes de borrar su archivo.
///
/// Fuera de `Store` a propósito: dentro quedaría aislada al actor principal y se
/// usa como valor por defecto de un parámetro, que no lo está.
///
/// Treinta días es un compromiso. Da margen de sobra para que un dispositivo
/// apagado o sin conexión sincronice y se entere del borrado, sin que los
/// archivos se acumulen para siempre. Un dispositivo que pase más de ese tiempo
/// desconectado podría resucitar lo que borraste: es el precio de no guardar
/// lápidas eternas.
public enum Retention {
    public static let tombstones: TimeInterval = 30 * 24 * 3600
}

/// Estado de la app + persistencia en JSON.
@Observable
@MainActor
public final class Store {
    public var items: [Item] = []
    public var projects: [Project] = []

    private let root: URL
    private let itemsDir: URL
    private let projectsDir: URL
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .custom { date, encoder in
            var c = encoder.singleValueContainer()
            try c.encode(ISODate.precise.string(from: date))
        }
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        // Se acepta también el formato sin fracción, que es el que escribieron
        // las versiones anteriores.
        d.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            if let date = ISODate.precise.date(from: text) { return date }
            if let date = ISODate.secondsOnly.date(from: text) { return date }
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: "fecha no reconocida: \(text)"))
        }
        return d
    }()

    /// En modo memoria no se lee ni se escribe en disco: sirve para maquetar.
    private let inMemory: Bool

    /// Identificadores de origen de tareas ya borradas, para que una captura
    /// repetida no las resucite.
    private var buriedSourceIDs: Set<String> = []

    /// Archivos que iCloud tenía desalojados en la última carga. Si es mayor que
    /// cero, faltan datos que aparecerán cuando terminen de bajar.
    public private(set) var pendingDownloads = 0

    /// Si los datos viven en iCloud Drive o solo en local.
    public var isSynced: Bool { root == Store.iCloudRoot }

    /// Carpeta de la app dentro de iCloud Drive, si iCloud Drive está activo.
    ///
    /// No se usa `url(forUbiquityContainerIdentifier:)`: esa vía exige
    /// entitlements y un perfil de aprovisionamiento embebido, que no encajan con
    /// un bundle montado a mano. iCloud Drive es una carpeta normal, y la app no
    /// está en sandbox, así que puede escribir en ella directamente.
    public static var iCloudRoot: URL? {
        let drive = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs",
                                    isDirectory: true)
        guard FileManager.default.fileExists(atPath: drive.path) else { return nil }
        return drive.appendingPathComponent("Pauta", isDirectory: true)
    }

    /// Carpeta local, que es también el respaldo si iCloud no está disponible.
    public static var localRoot: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Pauta", isDirectory: true)
    }

    /// iCloud si está, y si no la local. Nunca falla: sin iCloud la app sigue
    /// funcionando exactamente como antes.
    public static var defaultRoot: URL { iCloudRoot ?? localRoot }

    /// Copia los datos de una carpeta a otra si el destino aún no tiene ninguno.
    /// El origen se deja intacto: sirve de respaldo del paso anterior.
    ///
    /// Devuelve **cuántos archivos** copió, sumando tareas y proyectos.
    @discardableResult
    static func adoptData(from source: URL, to destination: URL) -> Int {
        let fm = FileManager.default
        guard source != destination else { return 0 }
        let already = (try? fm.contentsOfDirectory(
            at: destination.appendingPathComponent("items"),
            includingPropertiesForKeys: nil))?.filter { $0.pathExtension == "json" } ?? []
        guard already.isEmpty else { return 0 }

        var copied = 0
        try? fm.createDirectory(at: destination, withIntermediateDirectories: true)
        for sub in ["items", "projects"] {
            let from = source.appendingPathComponent(sub, isDirectory: true)
            let to = destination.appendingPathComponent(sub, isDirectory: true)
            guard let files = try? fm.contentsOfDirectory(at: from,
                                                          includingPropertiesForKeys: nil)
            else { continue }
            try? fm.createDirectory(at: to, withIntermediateDirectories: true)
            for file in files where file.pathExtension == "json" {
                let target = to.appendingPathComponent(file.lastPathComponent)
                if !fm.fileExists(atPath: target.path),
                   (try? fm.copyItem(at: file, to: target)) != nil { copied += 1 }
            }
        }
        // Y el blob antiguo, si todavía no se había troceado.
        let blob = source.appendingPathComponent("data.json")
        let blobTarget = destination.appendingPathComponent("data.json")
        if copied == 0, fm.fileExists(atPath: blob.path), !fm.fileExists(atPath: blobTarget.path) {
            try? fm.copyItem(at: blob, to: blobTarget)
        }
        return copied
    }

    /// `root` permite apuntar a otra carpeta en los tests.
    public init(inMemory: Bool = false, root: URL? = nil) {
        self.inMemory = inMemory
        let base = root ?? Store.defaultRoot
        self.root = base
        self.itemsDir = base.appendingPathComponent("items", isDirectory: true)
        self.projectsDir = base.appendingPathComponent("projects", isDirectory: true)
        if !inMemory {
            // Al estrenar la carpeta de iCloud, adopta lo que hubiera en local.
            if root == nil { Store.adoptData(from: Store.localRoot, to: base) }
            migrateFromSingleFile()
            let fm = FileManager.default
            try? fm.createDirectory(at: itemsDir, withIntermediateDirectories: true)
            try? fm.createDirectory(at: projectsDir, withIntermediateDirectories: true)
            load()
            normalizePositionsIfNeeded()
            purgeOldTombstones()
        }
    }

    public var storageLocation: String { root.path }
    /// La carpeta de datos, para quien necesite vigilarla.
    public var storageURL: URL { root }

    // MARK: - Persistencia
    //
    // Un archivo por objeto en vez de un único JSON con todo. Con un solo blob,
    // dos dispositivos que añaden tareas distintas escriben versiones
    // incompatibles del mismo archivo y una de las dos tareas se pierde en
    // silencio. Con un archivo por objeto, tocar tareas distintas no genera
    // ningún conflicto, y un archivo corrupto solo se lleva su propia tarea en
    // vez de todo el almacén.

    private func url(forItem id: UUID) -> URL {
        itemsDir.appendingPathComponent("\(id.uuidString).json")
    }

    private func url(forProject id: UUID) -> URL {
        projectsDir.appendingPathComponent("\(id.uuidString).json")
    }

    /// Pide a iCloud que baje lo que tenga desalojado.
    ///
    /// Para ahorrar espacio, iCloud puede dejar un archivo sin contenido local y
    /// sustituirlo por un marcador `.nombre.json.icloud`. Pedir la descarga es
    /// asíncrono: esta carga no lo verá, pero la siguiente sí. Devuelve cuántos
    /// quedaban pendientes, que es lo que hace falta para poder avisar.
    @discardableResult
    private func requestDownloads(in dir: URL) -> Int {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: dir,
                                                     includingPropertiesForKeys: nil)
        else { return 0 }
        var pending = 0
        for file in files where file.pathExtension == "icloud" {
            try? fm.startDownloadingUbiquitousItem(at: file)
            pending += 1
        }
        return pending
    }

    /// Resuelve un conflicto de sincronización quedándose con la versión
    /// modificada más recientemente.
    ///
    /// Cuando dos dispositivos tocan el mismo archivo, iCloud guarda las
    /// versiones en conflicto en vez de elegir. Con `updatedAt` en el propio
    /// contenido la elección es determinista, y sin resolverlas el conflicto se
    /// quedaría ahí para siempre.
    private func resolveConflict<T: Timestamped>(at url: URL, as type: T.Type) -> T? {
        guard let conflicts = NSFileVersion.unresolvedConflictVersionsOfItem(at: url),
              !conflicts.isEmpty else { return nil }

        func decode(_ from: URL) -> T? {
            guard let data = try? Data(contentsOf: from) else { return nil }
            return try? decoder.decode(T.self, from: data)
        }

        var best = decode(url)
        for version in conflicts {
            guard let candidate = decode(version.url) else { continue }
            if best == nil || candidate.updatedAt > best!.updatedAt { best = candidate }
        }
        if let best, let data = try? encoder.encode(best) {
            try? data.write(to: url, options: .atomic)
        }
        // Marcar resueltas: si no, iCloud las conserva y el conflicto persiste.
        for version in conflicts { version.isResolved = true }
        try? NSFileVersion.removeOtherVersionsOfItem(at: url)
        return best
    }

    /// Vuelve a leer la carpeta. Es lo que se llama cuando llegan cambios de
    /// otro dispositivo.
    ///
    /// Idempotente a propósito: si lo leído coincide con lo que ya hay, no toca
    /// nada. Sin eso, las escrituras de la propia app dispararían recargas que
    /// refrescarían la interfaz sin motivo, y podrían interrumpir una edición en
    /// curso.
    public func reload() {
        guard !inMemory else { return }
        load()
    }

    private func load() {
        let fm = FileManager.default
        pendingDownloads = requestDownloads(in: itemsDir) + requestDownloads(in: projectsDir)

        let itemFiles = (try? fm.contentsOfDirectory(at: itemsDir,
                                                    includingPropertiesForKeys: nil)) ?? []
        var live: [Item] = []
        for file in itemFiles where file.pathExtension == "json" {
            // Un archivo ilegible o corrupto se salta: no debe tumbar la carga.
            let resolved = resolveConflict(at: file, as: Item.self)
            guard let item = resolved ?? (try? Data(contentsOf: file))
                    .flatMap({ try? decoder.decode(Item.self, from: $0) })
            else { continue }
            if item.deletedAt == nil {
                live.append(item)
            } else if let source = item.sourceID {
                buriedSourceIDs.insert(source)
            }
        }
        let freshItems = live.sorted(by: Item.byCreation)
        if freshItems != items { items = freshItems }

        let projectFiles = (try? fm.contentsOfDirectory(at: projectsDir,
                                                       includingPropertiesForKeys: nil)) ?? []
        let freshProjects = projectFiles
            .filter { $0.pathExtension == "json" }
            .compactMap { file in
                let resolved = resolveConflict(at: file, as: Project.self)
                guard let project = resolved ?? (try? Data(contentsOf: file))
                        .flatMap({ try? decoder.decode(Project.self, from: $0) }),
                      project.deletedAt == nil else { return nil }
                return project
            }
            .sorted(by: Project.byCreation)
        if freshProjects != projects { projects = freshProjects }
    }

    /// Escritura atómica del objeto tocado, y solo de ese: reescribir todo en
    /// cada cambio agitaría las fechas de modificación de archivos intactos, que
    /// es justo lo que hace trabajar de más a la sincronización.
    private func persist(_ item: Item) {
        guard !inMemory, let data = try? encoder.encode(item) else { return }
        try? data.write(to: url(forItem: item.id), options: .atomic)
    }

    private func persist(_ project: Project) {
        guard !inMemory, let data = try? encoder.encode(project) else { return }
        try? data.write(to: url(forProject: project.id), options: .atomic)
    }

    /// Reparte el `data.json` de un solo blob en un archivo por objeto. El
    /// original se deja intacto como respaldo.
    private func migrateFromSingleFile() {
        let fm = FileManager.default
        let legacy = root.appendingPathComponent("data.json")
        guard fm.fileExists(atPath: legacy.path) else { return }
        let existing = (try? fm.contentsOfDirectory(at: itemsDir,
                                                   includingPropertiesForKeys: nil)) ?? []
        guard existing.filter({ $0.pathExtension == "json" }).isEmpty else { return }

        struct Snapshot: Decodable {
            var items: [Item]
            var projects: [Project]
        }
        guard let data = try? Data(contentsOf: legacy),
              let snap = try? decoder.decode(Snapshot.self, from: data) else { return }

        try? fm.createDirectory(at: itemsDir, withIntermediateDirectories: true)
        try? fm.createDirectory(at: projectsDir, withIntermediateDirectories: true)
        // El blob guardaba el orden en el propio array, y sus fechas solo tienen
        // segundos, así que muchas empatan. Al trocearlo, el orden vendría del
        // identificador —aleatorio— y la lista del usuario aparecería revuelta.
        // Se separan un milisegundo respetando el orden original.
        var last: Date?
        var orden = 1
        for var item in snap.items {
            item.createdAt = Store.stamped(item.createdAt)
            if let previous = last, item.createdAt < previous.addingTimeInterval(0.001) {
                item.createdAt = Store.stamped(previous.addingTimeInterval(0.001))
            }
            item.updatedAt = item.createdAt
            item.position = Double(orden)
            orden += 1
            last = item.createdAt
            persist(item)
        }
        var lastProject: Date?
        for var project in snap.projects {
            project.createdAt = Store.stamped(project.createdAt)
            if let previous = lastProject, project.createdAt < previous.addingTimeInterval(0.001) {
                project.createdAt = Store.stamped(previous.addingTimeInterval(0.001))
            }
            project.updatedAt = project.createdAt
            lastProject = project.createdAt
            persist(project)
        }
    }

    /// Redondea al milisegundo, que es la precisión con la que se guardan las
    /// fechas.
    ///
    /// Sin esto, el valor en memoria conserva la precisión completa de `Date` y
    /// el del archivo no, así que releer devuelve algo distinto de lo que hay
    /// cargado y **cada recarga parece un cambio**. Con el vigilante de carpeta
    /// encendido eso refrescaría la interfaz sin motivo e interrumpiría cualquier
    /// edición en curso.
    static func stamped(_ date: Date = .now) -> Date {
        Date(timeIntervalSince1970: (date.timeIntervalSince1970 * 1000).rounded() / 1000)
    }

    /// Fuerza que la fecha de creación sea estrictamente posterior a la de
    /// cualquier tarea existente.
    ///
    /// Las fechas se guardan con precisión de milisegundo (es lo máximo que da
    /// ISO8601), así que dos tareas creadas en el mismo milisegundo —pegar varias
    /// líneas, por ejemplo— empatarían, y el desempate por identificador es
    /// aleatorio: la lista se reordenaría entre arranques. Lo que hay que
    /// preservar es el orden, no el instante exacto, y desplazar un milisegundo
    /// no le importa a nadie.
    private func stampCreation(_ item: inout Item) {
        // La comparación es contra «último + 1 ms», no contra «último»: dos fechas
        // separadas por microsegundos son distintas en memoria pero colapsan al
        // mismo milisegundo al guardarse, y el empate reaparece al recargar.
        let minimo = 0.001
        var created = Store.stamped(item.createdAt)
        if let last = items.map(\.createdAt).max(),
           created < last.addingTimeInterval(minimo) {
            created = Store.stamped(last.addingTimeInterval(minimo))
        }
        item.createdAt = created
        item.updatedAt = created
        // Lo nuevo va al final de la prioridad.
        item.position = (items.map(\.position).max() ?? 0) + 1
    }

    /// Aplica un cambio a una tarea, le pone fecha de modificación y la guarda.
    /// Centralizado para que ninguna mutación se olvide de una de las tres.
    private func mutateItem(_ id: UUID, _ change: (inout Item) -> Void) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        change(&items[idx])
        items[idx].updatedAt = Store.stamped()
        persist(items[idx])
    }

    private func mutateProject(_ id: UUID, _ change: (inout Project) -> Void) {
        guard let idx = projects.firstIndex(where: { $0.id == id }) else { return }
        change(&projects[idx])
        projects[idx].updatedAt = Store.stamped()
        persist(projects[idx])
    }

    // MARK: - Consultas

    public func items(for perspective: Perspective) -> [Item] {
        switch perspective {
        case .inbox:
            items.filter { !$0.isCompleted && $0.projectID == nil
                           && $0.when == nil && !$0.isSomeday }
                .sorted(by: Item.byPosition)
        case .today:
            // Aquí manda el orden manual: es la lista que se prioriza a diario.
            items.filter(\.isToday).sorted(by: Item.byPosition)
        case .upcoming:
            // El día manda; dentro de cada día, el orden manual.
            items.filter(\.isUpcoming)
                .sorted {
                    let a = $0.when ?? .distantFuture, b = $1.when ?? .distantFuture
                    return a == b ? Item.byPosition($0, $1) : a < b
                }
        case .anytime:
            items.filter(\.isAnytime).sorted(by: Item.byPosition)
        case .someday:
            items.filter { !$0.isCompleted && $0.isSomeday }
                .sorted(by: Item.byPosition)
        case .completed:
            items.filter(\.isCompleted)
                .sorted {
                    let a = $0.completedAt ?? .distantPast, b = $1.completedAt ?? .distantPast
                    return a == b ? Item.byCreation($1, $0) : a > b
                }
        case .project(let id):
            items.filter { !$0.isCompleted && $0.projectID == id }
                .sorted(by: Item.byPosition)
        }
    }

    public func count(for perspective: Perspective) -> Int { items(for: perspective).count }

    /// Las tareas de «Próximamente» agrupadas por día, en orden. Sin agrupar,
    /// una lista de fechas mezcladas no dice de un vistazo qué cae cada día.
    public func upcomingByDay() -> [(day: Date, items: [Item])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: items(for: .upcoming)) { item in
            calendar.startOfDay(for: item.when ?? .distantFuture)
        }
        return grouped.keys.sorted().map { ($0, grouped[$0] ?? []) }
    }

    public func project(_ id: UUID) -> Project? { projects.first { $0.id == id } }

    public func title(for perspective: Perspective) -> String {
        if case .project(let id) = perspective { return project(id)?.name ?? "Proyecto" }
        return perspective.title
    }

    // MARK: - Mutaciones de tareas

    /// Divide un texto (normalmente pegado) en títulos de tarea: uno por
    /// línea, sin viñetas (`*`, `-`, `•`, `1.`, `1)`) ni espacios sobrantes.
    /// Un texto de una sola línea devuelve un único título.
    public static func titles(from text: String) -> [String] {
        text.split(whereSeparator: \.isNewline).compactMap { line in
            var s = line.trimmingCharacters(in: .whitespaces)
            if let bullet = s.range(of: #"^([*\-•·+]|\d+[.)])\s+"#, options: .regularExpression) {
                s.removeSubrange(bullet)
                s = s.trimmingCharacters(in: .whitespaces)
            }
            return s.isEmpty ? nil : s
        }
    }

    /// Crea una tarea por cada línea del texto, en orden.
    @discardableResult
    public func addItems(from text: String, in perspective: Perspective) -> [Item] {
        Store.titles(from: text).map { addItem(title: $0, in: perspective) }
    }

    /// Crea una tarea ya encajada en la perspectiva activa.
    @discardableResult
    public func addItem(title: String, in perspective: Perspective) -> Item {
        var item = Item(title: title)
        switch perspective {
        // En «Cualquier momento», una tarea sin fecha ni proyecto caería a la
        // bandeja y desaparecería de la vista; con fecha de hoy se queda donde
        // se creó.
        case .today, .anytime:
            item.when = Calendar.current.startOfDay(for: .now)
        case .upcoming:
            // Sin más contexto, «próximamente» más cercano es mañana.
            item.when = Calendar.current.startOfDay(
                for: Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now)
        case .someday:
            item.isSomeday = true
        case .project(let id):
            item.projectID = id
        case .inbox, .completed:
            break
        }
        stampCreation(&item)
        items.append(item)
        persist(item)
        return item
    }

    /// Da de alta lo capturado en una fuente externa, en la bandeja. Devuelve
    /// cuántas entraron: las que ya se habían importado antes se ignoran.
    @discardableResult
    public func addCaptured(_ incoming: [Captured]) -> Int {
        // Se descartan las ya importadas, incluidas las que se borraron después:
        // volver a capturarlas las resucitaría.
        let known = Set(items.compactMap(\.sourceID)).union(buriedSourceIDs)
        let fresh = incoming.filter { !known.contains($0.sourceID) }
        for capture in fresh {
            var item = Item(title: capture.title)
            item.notes = capture.notes
            item.sourceID = capture.sourceID
            stampCreation(&item)
            items.append(item)
            persist(item)
        }
        return fresh.count
    }

    public func update(_ item: Item) {
        mutateItem(item.id) { $0 = item }
    }

    public func toggleComplete(_ item: Item) {
        mutateItem(item.id) {
            $0.isCompleted.toggle()
            $0.completedAt = $0.isCompleted ? Store.stamped() : nil
        }
    }

    /// Borrar deja una lápida en lugar de eliminar el archivo: si se eliminara,
    /// un dispositivo que no vio el borrado resucitaría la tarea al sincronizar.
    public func delete(_ item: Item) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        var buried = items.remove(at: idx)
        buried.deletedAt = Store.stamped()
        buried.updatedAt = buried.deletedAt!
        if let source = buried.sourceID { buriedSourceIDs.insert(source) }
        persist(buried)
    }

    /// Poner o quitar fecha saca la tarea de «Algún día» en ambos casos: una
    /// tarea aparcada y con fecha a la vez sería un estado contradictorio.
    public func schedule(_ item: Item, to date: Date?) {
        mutateItem(item.id) {
            $0.when = date.map { Calendar.current.startOfDay(for: $0) }
            $0.isSomeday = false
        }
    }

    /// Borra los archivos de lo eliminado hace más de `retention`.
    ///
    /// La lápida existe solo para que un dispositivo que no vio el borrado no
    /// resucite la tarea al sincronizar. Cumplido ese plazo ya no protege de
    /// nada: es un archivo que se lee en cada carga y ocupa sitio en iCloud.
    ///
    /// Devuelve cuántos archivos borró.
    @discardableResult
    func purgeOldTombstones(olderThan retention: TimeInterval = Retention.tombstones,
                            now: Date = .now) -> Int {
        guard !inMemory else { return 0 }
        let fm = FileManager.default
        let limite = now.addingTimeInterval(-retention)
        var borrados = 0

        func purge<T: Decodable>(_ dir: URL, as type: T.Type,
                                 deletedAt: (T) -> Date?) {
            guard let files = try? fm.contentsOfDirectory(at: dir,
                                                          includingPropertiesForKeys: nil)
            else { return }
            for file in files where file.pathExtension == "json" {
                guard let data = try? Data(contentsOf: file),
                      let objeto = try? decoder.decode(T.self, from: data),
                      let fecha = deletedAt(objeto), fecha < limite else { continue }
                if (try? fm.removeItem(at: file)) != nil { borrados += 1 }
            }
        }
        purge(itemsDir, as: Item.self) { $0.deletedAt }
        purge(projectsDir, as: Project.self) { $0.deletedAt }
        return borrados
    }

    /// Da posiciones distintas a todas las tareas si hay empates.
    ///
    /// Las tareas guardadas antes de que existiera el campo valen todas 0, y
    /// entre dos ceros no hay punto medio: sin esto el primer arrastre no movería
    /// nada. Se numeran respetando el orden que ya tenían, y se hace una sola vez
    /// porque después las posiciones ya son distintas.
    func normalizePositionsIfNeeded() {
        guard Set(items.map(\.position)).count != items.count else { return }
        for (i, item) in items.sorted(by: Item.byPosition).enumerated() {
            mutateItem(item.id) { $0.position = Double(i + 1) }
        }
    }

    /// Coloca `item` justo antes de `other`, o al final si `other` es `nil`.
    ///
    /// La posición sale del punto medio entre las dos vecinas, así que reordenar
    /// **escribe un solo archivo**. Reasignar posiciones correlativas a toda la
    /// lista sería más simple de leer, pero reescribiría decenas de archivos por
    /// cada arrastre, y con la carpeta sincronizada eso es tráfico y ocasiones de
    /// conflicto por nada.
    public func place(_ item: Item, before other: Item?, in perspective: Perspective) {
        let lista = items(for: perspective).filter { $0.id != item.id }
        guard !lista.isEmpty else { return }

        let nueva: Double
        if let other, let idx = lista.firstIndex(where: { $0.id == other.id }) {
            let anterior = idx > 0 ? lista[idx - 1].position : lista[idx].position - 2
            nueva = (anterior + lista[idx].position) / 2
        } else {
            nueva = (lista.map(\.position).max() ?? 0) + 1
        }
        mutateItem(item.id) { $0.position = nueva }
    }

    /// Mueve la tarea a la lista indicada, aplicando lo que esa lista significa.
    ///
    /// Las listas son consultas, no carpetas: «mover» es cambiar los campos que
    /// hacen que la tarea caiga en esa consulta. Vive aquí y no en la vista para
    /// que la semántica sea una sola y se pueda probar.
    public func move(_ item: Item, to perspective: Perspective) {
        switch perspective {
        case .inbox:
            // La bandeja es lo que no tiene nada decidido: ni fecha, ni proyecto.
            mutateItem(item.id) {
                $0.when = nil
                $0.isSomeday = false
                $0.projectID = nil
                $0.isCompleted = false
                $0.completedAt = nil
            }
        case .today:
            mutateItem(item.id) {
                $0.when = Calendar.current.startOfDay(for: .now)
                $0.isSomeday = false
                $0.isCompleted = false
                $0.completedAt = nil
            }
        case .upcoming:
            // Si ya tenía fecha futura se respeta; si no, mañana.
            let manana = Calendar.current.startOfDay(
                for: Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now)
            mutateItem(item.id) {
                let actual = $0.when.map { Calendar.current.startOfDay(for: $0) }
                $0.when = (actual.map { $0 > Calendar.current.startOfDay(for: .now) } == true)
                    ? actual : manana
                $0.isSomeday = false
                $0.isCompleted = false
                $0.completedAt = nil
            }
        case .anytime:
            // Se puede hacer ya, pero sin día asignado. Conserva el proyecto.
            mutateItem(item.id) {
                $0.when = nil
                $0.isSomeday = false
                $0.isCompleted = false
                $0.completedAt = nil
            }
        case .someday:
            mutateItem(item.id) {
                $0.isSomeday = true
                $0.when = nil
                $0.isCompleted = false
                $0.completedAt = nil
            }
        case .completed:
            mutateItem(item.id) {
                guard !$0.isCompleted else { return }
                $0.isCompleted = true
                $0.completedAt = Store.stamped()
            }
        case .project(let id):
            mutateItem(item.id) { $0.projectID = id }
        }
    }

    /// Aparca la tarea en «Algún día», quitándole cualquier fecha.
    public func park(_ item: Item) {
        mutateItem(item.id) {
            $0.isSomeday = true
            $0.when = nil
        }
    }

    // MARK: - Mutaciones de proyectos

    @discardableResult
    public func addProject(name: String) -> Project {
        var project = Project(name: name.isEmpty ? "Nuevo proyecto" : name)
        var created = Store.stamped(project.createdAt)
        if let last = projects.map(\.createdAt).max(),
           created < last.addingTimeInterval(0.001) {
            created = Store.stamped(last.addingTimeInterval(0.001))
        }
        project.createdAt = created
        project.updatedAt = created
        projects.append(project)
        persist(project)
        return project
    }

    public func rename(_ project: Project, to name: String) {
        mutateProject(project.id) { $0.name = name }
    }

    /// Cambia el emoji del proyecto. Cadena vacía = quitarlo.
    public func setIcon(_ project: Project, to icon: String) {
        mutateProject(project.id) { $0.icon = icon }
    }

    /// Borra el proyecto y devuelve sus tareas a la bandeja de entrada.
    public func delete(_ project: Project) {
        for item in items where item.projectID == project.id {
            mutateItem(item.id) { $0.projectID = nil }
        }
        guard let idx = projects.firstIndex(where: { $0.id == project.id }) else { return }
        var buried = projects.remove(at: idx)
        buried.deletedAt = Store.stamped()
        buried.updatedAt = buried.deletedAt!
        persist(buried)
    }
}


// MARK: - Maqueta

extension Store {
    /// Datos de muestra en memoria para revisar el diseño (`--demo`).
    public static func demo() -> Store {
        let store = Store(inMemory: true)
        let project = store.addProject(name: "Rediseño de la web")
        store.setIcon(project, to: "🎨")
        store.addItem(title: "Llamar al fontanero", in: .today)
        var budget = store.addItem(title: "Revisar el presupuesto del trimestre", in: .today)
        budget.notes = "Comparar con las cifras de junio antes de enviarlo."
        store.update(budget)
        store.addItem(title: "Definir la paleta de color", in: .project(project.id))
        store.schedule(store.items.last!, to: .now)
        // Sin fecha: solo se ve en el proyecto y en Cualquier momento.
        store.addItem(title: "Escribir los textos de la portada", in: .project(project.id))
        store.addItem(title: "Comprar entradas del concierto", in: .inbox)
        // Dos días distintos, para que se vea el agrupado de Próximamente.
        let calendar = Calendar.current
        let dentist = store.addItem(title: "Cita con el dentista", in: .upcoming)
        store.schedule(dentist, to: calendar.date(byAdding: .day, value: 1, to: .now))
        let taxes = store.addItem(title: "Presentar el trimestre", in: .upcoming)
        store.schedule(taxes, to: calendar.date(byAdding: .day, value: 4, to: .now))
        let flights = store.addItem(title: "Buscar vuelos de septiembre", in: .upcoming)
        store.schedule(flights, to: calendar.date(byAdding: .day, value: 4, to: .now))
        store.addItem(title: "Aprender a tocar el bajo", in: .someday)
        store.addItem(title: "Rehacer la estantería del salón", in: .someday)
        let done = store.addItem(title: "Reservar mesa para el viernes", in: .inbox)
        store.toggleComplete(done)
        return store
    }
}
