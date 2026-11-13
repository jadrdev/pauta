import Foundation

/// La mudanza de los datos al contenedor de iCloud de la app.
///
/// El plan entero está en docs/plan-contenedor-icloud.md. Aquí va, de momento,
/// la fase 1: la red de seguridad. Nada se muda sin una copia completa de cómo
/// estaba todo, y la mudanza no empieza si esa copia no sale.
public enum Mudanza {
    /// La copia de antes de la mudanza, ya hecha y comprobada.
    public struct Resguardo: Equatable, Sendable {
        public let carpeta: URL
        public let archivos: Int
        public let bytes: Int64
    }

    public enum Fallo: Error, Equatable, CustomStringConvertible {
        /// Archivos que iCloud no terminó de bajar en el tiempo de espera.
        case sinBajar([String])
        /// Un archivo copiado no es igual que el original.
        case copiaDistinta(String)
        /// La copia no se pudo hacer: sin sitio, sin permiso…
        case noSePudo(String)

        public var description: String {
            switch self {
            case .sinBajar(let faltan):
                let muestra = faltan.prefix(5).joined(separator: ", ")
                return "\(faltan.count) archivos sin bajar de iCloud: \(muestra)"
                    + (faltan.count > 5 ? "…" : "")
            case .copiaDistinta(let ruta): return "la copia de \(ruta) no es igual que el original"
            case .noSePudo(let motivo): return "no se pudo copiar: \(motivo)"
            }
        }
    }

    // MARK: - Fase 2: la mudanza

    /// Cómo fue un intento de mudanza.
    public struct Resultado: Equatable, Sendable {
        /// Lo que el cruce movió, en cada sentido.
        public var balance = Puente.Balance()
        /// Copias diarias llevadas al contenedor.
        public var copias = 0
        /// Lo que no cuadra entre las dos carpetas, dicho por ruta. Vacío es
        /// que se puede cambiar de carpeta.
        public var discrepancias: [String] = []
        public var cuadra: Bool { discrepancias.isEmpty }
    }

    /// Lleva los datos de la carpeta vieja al contenedor y comprueba que no se
    /// ha quedado nada atrás.
    ///
    /// **La mudanza es un cruce**: `Puente.cruzar`, el de siempre, con su «gana
    /// la versión más reciente» y sin borrar nunca. Eso es lo que la hace
    /// repetible: si se corta a medias, el siguiente intento cruza lo que
    /// faltaba y no duplica nada; si dos Mac se mudan a la vez, cruzan los
    /// mismos archivos y llegan a lo mismo. Y como cruza en los dos sentidos,
    /// lo que otro aparato ya hubiera llevado al contenedor tampoco se pierde.
    ///
    /// Las copias diarias van aparte y en un solo sentido: no son datos que se
    /// editen, y el Puente no las mira.
    public static func mudar(desde vieja: URL, a contenedor: URL,
                             enLocal: (URL) -> Bool = Puente.enLocal) -> Resultado {
        var resultado = Resultado()
        resultado.balance = Puente.cruzar(vieja, contenedor, enLocal: enLocal)
        resultado.copias = llevarCopias(desde: vieja, a: contenedor, enLocal: enLocal)
        resultado.discrepancias = discrepancias(entre: vieja, y: contenedor, enLocal: enLocal)
        return resultado
    }

    /// Qué hay en la carpeta vieja que el contenedor no tenga igual o más nuevo.
    ///
    /// Es la comprobación que decide si se cambia de carpeta, así que mira lo
    /// que importa y nada más: cada tarea, proyecto y área de la vieja tiene
    /// que estar en el contenedor con la misma fecha o una posterior, y cada
    /// adjunto vigente, presente. Lo que no se pueda leer porque iCloud no lo
    /// ha bajado **no cuadra**: no se sabe qué hay dentro.
    public static func discrepancias(entre vieja: URL, y contenedor: URL,
                                     enLocal: (URL) -> Bool = Puente.enLocal) -> [String] {
        let fm = FileManager.default
        let decoder = ISODate.decodificador()
        struct Version: Decodable { let updatedAt: Date }
        func fecha(_ url: URL) -> Date? {
            guard let datos = try? Data(contentsOf: url) else { return nil }
            return (try? decoder.decode(Version.self, from: datos))?.updatedAt
        }

        var faltan: [String] = []
        var vigentes: [Adjunto] = []
        for sub in ["items", "projects", "areas"] {
            let dir = vieja.appendingPathComponent(sub, isDirectory: true)
            let nombres = (try? fm.contentsOfDirectory(atPath: dir.path)) ?? []
            for nombre in nombres.sorted() where nombre.hasSuffix(".json") && !nombre.hasPrefix(".") {
                let ruta = "\(sub)/\(nombre)"
                let suya = dir.appendingPathComponent(nombre)
                let nueva = contenedor.appendingPathComponent(ruta)
                guard enLocal(suya) else { faltan.append("\(ruta) (sin bajar)"); continue }
                guard fm.fileExists(atPath: nueva.path) else { faltan.append(ruta); continue }
                guard enLocal(nueva) else { faltan.append("\(ruta) (sin bajar en el contenedor)"); continue }
                // Uno que no se entiende en la vieja no se puede comparar, y no
                // es motivo para quedarse: el cruce tampoco lo habría llevado.
                guard let antes = fecha(suya) else { continue }
                guard let ahora = fecha(nueva), ahora >= antes else {
                    faltan.append("\(ruta) (más viejo en el contenedor)"); continue
                }
                if sub == "items", let datos = try? Data(contentsOf: suya),
                   let item = try? decoder.decode(Item.self, from: datos) {
                    vigentes.append(contentsOf: item.adjuntosVigentes())
                }
            }
        }
        for adjunto in vigentes {
            let ruta = "adjuntos/\(adjunto.id.uuidString)/\(adjunto.nombre)"
            // Solo los que la vieja tiene de verdad: uno que faltaba ya allí no
            // es culpa de la mudanza.
            guard fm.fileExists(atPath: vieja.appendingPathComponent(ruta).path) else { continue }
            if !fm.fileExists(atPath: contenedor.appendingPathComponent(ruta).path) {
                faltan.append(ruta)
            }
        }
        return faltan
    }

    /// Las copias diarias que el contenedor no tiene, sin pisar ninguna.
    static func llevarCopias(desde vieja: URL, a contenedor: URL,
                             enLocal: (URL) -> Bool) -> Int {
        let fm = FileManager.default
        let origen = vieja.appendingPathComponent("copias", isDirectory: true)
        let destino = contenedor.appendingPathComponent("copias", isDirectory: true)
        let nombres = (try? fm.contentsOfDirectory(atPath: origen.path)) ?? []
        var llevadas = 0
        for nombre in nombres where nombre.hasSuffix(".json.gz") && !nombre.hasPrefix(".") {
            let de = origen.appendingPathComponent(nombre)
            let a = destino.appendingPathComponent(nombre)
            guard !fm.fileExists(atPath: a.path), enLocal(de) else { continue }
            try? fm.createDirectory(at: destino, withIntermediateDirectories: true)
            if (try? fm.copyItem(at: de, to: a)) != nil { llevadas += 1 }
        }
        return llevadas
    }

    // MARK: - Dónde vive el almacén

    /// Desde cuándo este Mac usa el contenedor, o `nil` si todavía no se ha
    /// mudado. Es **de cada Mac** —en sus preferencias, no en iCloud—: que el
    /// otro se haya mudado no quiere decir que este haya comprobado nada.
    public static func mudadoDesde(_ defaults: UserDefaults = .standard) -> Date? {
        defaults.object(forKey: claveMudado) as? Date
    }

    public static func marcarMudado(_ cuando: Date = .now, _ defaults: UserDefaults = .standard) {
        defaults.set(cuando, forKey: claveMudado)
    }

    /// La carpeta del almacén, según si este Mac se ha mudado.
    ///
    /// Al contenedor solo cuando la mudanza se comprobó **y** la carpeta
    /// existe. Si no, la de siempre: equivocarse hacia la vieja deja los datos
    /// como estaban; equivocarse hacia un contenedor vacío enseñaría una app
    /// sin nada.
    public static func raiz(mudado: Bool, contenedor: URL?, vieja: URL?) -> URL? {
        if mudado, let contenedor,
           FileManager.default.fileExists(atPath: contenedor.path) { return contenedor }
        return vieja
    }

    static let claveMudado = "mudanza.contenedorDesde"

    /// Si una carpeta tiene alguna tarea, proyecto o área. Una que no tiene
    /// nada no necesita copia de antes: no hay nada que proteger.
    public static func tieneDatos(_ carpeta: URL) -> Bool {
        ["items", "projects", "areas"].contains { sub in
            let nombres = (try? FileManager.default.contentsOfDirectory(
                atPath: carpeta.appendingPathComponent(sub).path)) ?? []
            return nombres.contains { $0.hasSuffix(".json") }
        }
    }

    /// Dónde va la copia de antes de la mudanza: la carpeta de usuario, que no
    /// se sincroniza.
    ///
    /// No en Documentos: con «Escritorio y Documentos» en iCloud —como en el Mac
    /// donde se escribió esto—, Documentos **es** iCloud, y una copia de
    /// seguridad en el mismo sitio que lo que protege no protege nada.
    #if os(macOS)
    public static func carpetaDelResguardo(ahora: Date = .now) -> URL {
        let dia = ahora.formatted(.iso8601.year().month().day())
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Pauta antes de la mudanza \(dia)", isDirectory: true)
    }
    #endif

    /// Copia **todo** `origen` en `destino`, esperando antes a que iCloud baje
    /// lo que tenga desalojado, y comprobando cada archivo.
    ///
    /// Tres cosas que la hacen de fiar:
    ///
    /// - **Espera a que baje todo.** Un archivo desalojado está en el listado
    ///   pero no en el disco: copiarlo así copia la nada. Se pide la descarga
    ///   y se espera; si en `espera` no ha llegado todo, se para y dice cuáles.
    /// - **Comprueba byte a byte.** Cada archivo copiado se compara con el
    ///   original. Una copia que no se ha comprobado es una esperanza.
    /// - **O entera o nada.** Se copia a una carpeta provisional y solo al
    ///   final, si todo cuadra, toma su nombre. Una copia a medias con el
    ///   nombre bueno se tomaría por buena.
    ///
    /// Si `destino` ya existe no se toca: se usa el mismo nombre con un número.
    /// `enLocal` y `pedirBajada` solo los cambian las pruebas, que no tienen
    /// iCloud con el que desalojar nada.
    public static func resguardar(
        _ origen: URL, en destino: URL,
        espera: Duration = .seconds(180),
        enLocal: @Sendable (URL) -> Bool = Puente.enLocal,
        pedirBajada: @Sendable (URL) -> Void = { try? FileManager.default.startDownloadingUbiquitousItem(at: $0) }
    ) async throws -> Resguardo {
        let fm = FileManager.default
        let archivos = listar(origen)

        // 1. Que baje todo lo que falte.
        var faltan = archivos.filter { !enLocal($0) }
        faltan.forEach(pedirBajada)
        let limite = ContinuousClock.now + espera
        while !faltan.isEmpty && ContinuousClock.now < limite {
            try await Task.sleep(for: .milliseconds(500))
            // Con una URL nueva cada vez: Foundation guarda el estado de iCloud
            // en la propia URL, y preguntar a la misma devolvía «sin bajar»
            // para siempre aunque el archivo ya estuviera en el disco. Así se
            // estuvo tres minutos esperando a treinta copias ya bajadas.
            faltan = faltan.filter { !enLocal(URL(fileURLWithPath: $0.path)) }
        }
        guard faltan.isEmpty else {
            throw Fallo.sinBajar(faltan.map { relativa($0, a: origen) }.sorted())
        }

        // 2. Copiar a una carpeta provisional, junto a la definitiva.
        let final = libre(destino)
        let provisional = final.deletingLastPathComponent()
            .appendingPathComponent(".\(final.lastPathComponent).a-medias", isDirectory: true)
        try? fm.removeItem(at: provisional)
        var bytes: Int64 = 0
        do {
            for archivo in archivos {
                let ruta = relativa(archivo, a: origen)
                let copia = provisional.appendingPathComponent(ruta)
                try fm.createDirectory(at: copia.deletingLastPathComponent(),
                                       withIntermediateDirectories: true)
                try fm.copyItem(at: archivo, to: copia)
                // 3. Y comprobarlo, leyendo los dos.
                let original = try Data(contentsOf: archivo)
                guard (try? Data(contentsOf: copia)) == original else {
                    throw Fallo.copiaDistinta(ruta)
                }
                bytes += Int64(original.count)
            }
            try manifiesto(archivos.count, bytes, de: origen)
                .write(to: provisional.appendingPathComponent("LEEME.txt"),
                       atomically: true, encoding: .utf8)
            try fm.moveItem(at: provisional, to: final)
        } catch let fallo as Fallo {
            try? fm.removeItem(at: provisional)
            throw fallo
        } catch {
            try? fm.removeItem(at: provisional)
            throw Fallo.noSePudo(error.localizedDescription)
        }
        return Resguardo(carpeta: final, archivos: archivos.count, bytes: bytes)
    }

    /// Todos los archivos de verdad de una carpeta, a cualquier profundidad.
    ///
    /// Sin los ocultos (`.DS_Store`, los marcadores que deja iCloud), pero con
    /// los desalojados: en macOS siguen en el listado con su nombre de
    /// siempre, que es lo que permite pedir que bajen.
    static func listar(_ carpeta: URL) -> [URL] {
        guard let recorrido = FileManager.default.enumerator(
            at: carpeta, includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]) else { return [] }
        return recorrido.compactMap { $0 as? URL }
            .filter { (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true }
            .sorted { $0.path < $1.path }
    }

    private static func relativa(_ url: URL, a raiz: URL) -> String {
        let base = raiz.standardizedFileURL.resolvingSymlinksInPath().path
        let ruta = url.standardizedFileURL.resolvingSymlinksInPath().path
        guard ruta.hasPrefix(base) else { return url.lastPathComponent }
        return String(ruta.dropFirst(base.count)).trimmingCharacters(in: ["/"])
    }

    /// `destino`, o el mismo nombre con « 2», « 3»… si ya existe.
    private static func libre(_ destino: URL) -> URL {
        let fm = FileManager.default
        guard fm.fileExists(atPath: destino.path) else { return destino }
        let padre = destino.deletingLastPathComponent()
        var n = 2
        while fm.fileExists(atPath: padre.appendingPathComponent(
            "\(destino.lastPathComponent) \(n)").path) { n += 1 }
        return padre.appendingPathComponent("\(destino.lastPathComponent) \(n)", isDirectory: true)
    }

    private static func manifiesto(_ archivos: Int, _ bytes: Int64, de origen: URL,
                                   ahora: Date = .now) -> String {
        let cuando = ahora.formatted(date: .long, time: .standard)
        let ruta = origen.path
        let tamano = ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
        return String(localized: """
            Copia de los datos de Pauta de antes de mudarlos al contenedor de iCloud.

            Hecha el \(cuando), desde:
              \(ruta)
            \(archivos) archivos, \(tamano), comprobados uno a uno.

            Pauta no la lee ni la borra: es tuya. Si algo saliera mal, esta carpeta
            tiene todo como estaba.
            """, comment: "Texto del LEEME.txt que va en la copia de antes de mudar los datos (Mac); huecos: fecha y hora, ruta de la carpeta, número de archivos, tamaño")
    }
}
