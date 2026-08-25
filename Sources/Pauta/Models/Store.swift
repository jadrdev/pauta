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
            items.filter { !$0.isCompleted && $0.projectID == nil && $0.when == nil }
                .sorted { $0.createdAt < $1.createdAt }
        case .today:
            items.filter(\.isToday)
                .sorted {
                    let a = $0.when ?? .distantPast, b = $1.when ?? .distantPast
                    // Desempate por creación: lo nuevo va al final, como en Things.
                    return a == b ? $0.createdAt < $1.createdAt : a < b
                }
        case .logbook:
            items.filter(\.isCompleted)
                .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
        case .project(let id):
            items.filter { !$0.isCompleted && $0.projectID == id }
                .sorted { $0.createdAt < $1.createdAt }
        }
    }

    func count(for perspective: Perspective) -> Int { items(for: perspective).count }

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
        case .today:
            item.when = Calendar.current.startOfDay(for: .now)
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

    func schedule(_ item: Item, to date: Date?) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[idx].when = date.map { Calendar.current.startOfDay(for: $0) }
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
        store.addItem(title: "Llamar al fontanero", in: .today)
        var budget = store.addItem(title: "Revisar el presupuesto del trimestre", in: .today)
        budget.notes = "Comparar con las cifras de junio antes de enviarlo."
        store.update(budget)
        store.addItem(title: "Definir la paleta de color", in: .project(project.id))
        store.schedule(store.items.last!, to: .now)
        store.addItem(title: "Comprar entradas del concierto", in: .inbox)
        let done = store.addItem(title: "Reservar mesa para el viernes", in: .inbox)
        store.toggleComplete(done)
        return store
    }
}
