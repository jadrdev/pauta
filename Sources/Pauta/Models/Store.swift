import Foundation
import Observation

/// Estado de la app + persistencia en JSON.
@Observable
@MainActor
final class Store {
    var items: [Item] = []
    var projects: [Project] = []

    private let fileURL: URL
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private struct Snapshot: Codable {
        var items: [Item]
        var projects: [Project]
    }

    /// En modo memoria no se lee ni se escribe en disco: sirve para maquetar.
    private let inMemory: Bool

    init(inMemory: Bool = false) {
        self.inMemory = inMemory
        let fm = FileManager.default
        let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = support.appendingPathComponent("Pauta", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("data.json")
        if !inMemory {
            migrateFromOldName(fm: fm, support: support)
            load()
        }
    }

    /// La app se llamó «Cosas» antes de llamarse «Pauta». Si quedan datos en la
    /// carpeta antigua y todavía no hay nada en la nueva, se copian. El archivo
    /// original se deja intacto a modo de respaldo.
    private func migrateFromOldName(fm: FileManager, support: URL) {
        guard !fm.fileExists(atPath: fileURL.path) else { return }
        let old = support.appendingPathComponent("Cosas/data.json")
        guard fm.fileExists(atPath: old.path) else { return }
        try? fm.copyItem(at: old, to: fileURL)
    }

    // MARK: - Persistencia

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let snap = try? decoder.decode(Snapshot.self, from: data) else { return }
        items = snap.items
        projects = snap.projects
    }

    private func save() {
        guard !inMemory else { return }
        let snap = Snapshot(items: items, projects: projects)
        guard let data = try? encoder.encode(snap) else { return }
        // Escritura atómica: si el proceso muere a mitad, el archivo previo sigue intacto.
        try? data.write(to: fileURL, options: .atomic)
    }

    var storageLocation: String { fileURL.path }

    // MARK: - Consultas

    func items(for perspective: Perspective) -> [Item] {
        switch perspective {
        case .inbox:
            items.filter { !$0.isCompleted && $0.projectID == nil
                           && $0.when == nil && !$0.isSomeday }
                .sorted { $0.createdAt < $1.createdAt }
        case .today:
            items.filter(\.isToday)
                .sorted {
                    let a = $0.when ?? .distantPast, b = $1.when ?? .distantPast
                    // Desempate por creación: lo nuevo va al final, como en Things.
                    return a == b ? $0.createdAt < $1.createdAt : a < b
                }
        case .upcoming:
            items.filter(\.isUpcoming)
                .sorted {
                    let a = $0.when ?? .distantFuture, b = $1.when ?? .distantFuture
                    return a == b ? $0.createdAt < $1.createdAt : a < b
                }
        case .anytime:
            items.filter(\.isAnytime)
                .sorted {
                    // Primero lo fechado (Hoy incluido), luego lo sin fecha.
                    let a = $0.when ?? .distantFuture, b = $1.when ?? .distantFuture
                    return a == b ? $0.createdAt < $1.createdAt : a < b
                }
        case .someday:
            items.filter { !$0.isCompleted && $0.isSomeday }
                .sorted { $0.createdAt < $1.createdAt }
        case .logbook:
            items.filter(\.isCompleted)
                .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
        case .project(let id):
            items.filter { !$0.isCompleted && $0.projectID == id }
                .sorted { $0.createdAt < $1.createdAt }
        }
    }

    func count(for perspective: Perspective) -> Int { items(for: perspective).count }

    /// Las tareas de «Próximamente» agrupadas por día, en orden. Sin agrupar,
    /// una lista de fechas mezcladas no dice de un vistazo qué cae cada día.
    func upcomingByDay() -> [(day: Date, items: [Item])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: items(for: .upcoming)) { item in
            calendar.startOfDay(for: item.when ?? .distantFuture)
        }
        return grouped.keys.sorted().map { ($0, grouped[$0] ?? []) }
    }

    func project(_ id: UUID) -> Project? { projects.first { $0.id == id } }

    func title(for perspective: Perspective) -> String {
        if case .project(let id) = perspective { return project(id)?.name ?? "Proyecto" }
        return perspective.title
    }

    // MARK: - Mutaciones de tareas

    /// Crea una tarea ya encajada en la perspectiva activa.
    @discardableResult
    func addItem(title: String, in perspective: Perspective) -> Item {
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
        case .inbox, .logbook:
            break
        }
        items.append(item)
        save()
        return item
    }

    func update(_ item: Item) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[idx] = item
        save()
    }

    func toggleComplete(_ item: Item) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[idx].isCompleted.toggle()
        items[idx].completedAt = items[idx].isCompleted ? .now : nil
        save()
    }

    func delete(_ item: Item) {
        items.removeAll { $0.id == item.id }
        save()
    }

    /// Poner o quitar fecha. Ambas cosas sacan la tarea de «Algún día»: una
    /// tarea aparcada y con fecha a la vez sería un estado contradictorio.
    func schedule(_ item: Item, to date: Date?) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[idx].when = date.map { Calendar.current.startOfDay(for: $0) }
        items[idx].isSomeday = false
        save()
    }

    /// Aparca la tarea en «Algún día», quitándole cualquier fecha.
    func park(_ item: Item) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[idx].isSomeday = true
        items[idx].when = nil
        save()
    }

    // MARK: - Mutaciones de proyectos

    @discardableResult
    func addProject(name: String) -> Project {
        let project = Project(name: name.isEmpty ? "Nuevo proyecto" : name)
        projects.append(project)
        save()
        return project
    }

    func rename(_ project: Project, to name: String) {
        guard let idx = projects.firstIndex(where: { $0.id == project.id }) else { return }
        projects[idx].name = name
        save()
    }

    /// Cambia el emoji del proyecto. Cadena vacía = quitarlo.
    func setIcon(_ project: Project, to icon: String) {
        guard let idx = projects.firstIndex(where: { $0.id == project.id }) else { return }
        projects[idx].icon = icon
        save()
    }

    /// Borra el proyecto y devuelve sus tareas a la bandeja de entrada.
    func delete(_ project: Project) {
        for idx in items.indices where items[idx].projectID == project.id {
            items[idx].projectID = nil
        }
        projects.removeAll { $0.id == project.id }
        save()
    }
}


// MARK: - Maqueta

extension Store {
    /// Datos de muestra en memoria para revisar el diseño (`--demo`).
    static func demo() -> Store {
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
