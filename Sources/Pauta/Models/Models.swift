import Foundation

// MARK: - Tarea

struct Item: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var notes: String = ""
    var isCompleted = false
    var completedAt: Date?
    /// Fecha para la que está planificada. `nil` = sin planificar.
    var when: Date?
    /// Aparcada sin fecha, a propósito. Distinto de `when == nil`, que solo
    /// significa «todavía sin planificar» y deja la tarea en la bandeja.
    var isSomeday = false
    var projectID: UUID?
    var createdAt = Date()

    init(id: UUID = UUID(), title: String) {
        self.id = id
        self.title = title
    }

    /// Decodificación tolerante a claves ausentes.
    ///
    /// El `Codable` sintetizado de Swift usa `decode` para las propiedades no
    /// opcionales e **ignora sus valores por defecto**, así que añadir un campo
    /// nuevo rompería la lectura de los archivos ya guardados. Leyendo todo con
    /// `decodeIfPresent` los datos antiguos siguen abriéndose, y los campos que
    /// se añadan en el futuro tampoco los romperán.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decodeIfPresent(UUID.self,   forKey: .id) ?? UUID()
        title       = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        notes       = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        isCompleted = try c.decodeIfPresent(Bool.self,   forKey: .isCompleted) ?? false
        completedAt = try c.decodeIfPresent(Date.self,   forKey: .completedAt)
        when        = try c.decodeIfPresent(Date.self,   forKey: .when)
        isSomeday   = try c.decodeIfPresent(Bool.self,   forKey: .isSomeday) ?? false
        projectID   = try c.decodeIfPresent(UUID.self,   forKey: .projectID)
        createdAt   = try c.decodeIfPresent(Date.self,   forKey: .createdAt) ?? Date()
    }

    /// Planificada para hoy o antes (una tarea vencida sigue estando en Hoy).
    var isToday: Bool {
        guard let when, !isCompleted, !isSomeday else { return false }
        return Calendar.current.startOfDay(for: when) <= Calendar.current.startOfDay(for: .now)
    }

    /// Planificada para un día posterior a hoy.
    var isUpcoming: Bool {
        guard let when, !isCompleted, !isSomeday else { return false }
        return Calendar.current.startOfDay(for: when) > Calendar.current.startOfDay(for: .now)
    }
}

// MARK: - Proyecto

struct Project: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var notes: String = ""
    var isCompleted = false
    var createdAt = Date()

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decodeIfPresent(UUID.self,   forKey: .id) ?? UUID()
        name        = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        notes       = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        isCompleted = try c.decodeIfPresent(Bool.self,   forKey: .isCompleted) ?? false
        createdAt   = try c.decodeIfPresent(Date.self,   forKey: .createdAt) ?? Date()
    }
}

// MARK: - Perspectivas de la barra lateral

enum Perspective: Hashable, CaseIterable {
    case inbox
    case today
    case upcoming
    case someday
    case logbook
    case project(UUID)

    /// Las fijas, en el orden en que se muestran. Los proyectos van aparte.
    static var allCases: [Perspective] { [.inbox, .today, .upcoming, .someday, .logbook] }

    var title: String {
        switch self {
        case .inbox: "Bandeja"
        case .today: "Hoy"
        case .upcoming: "Próximamente"
        case .someday: "Algún día"
        case .logbook: "Registro"
        case .project: "Proyecto"
        }
    }

    /// Símbolos monocromos. A propósito no se usan aquí la estrella para «Hoy»
    /// ni el check para «Registro»: son dos de las señas visuales de Things.
    var symbol: String {
        switch self {
        case .inbox: "tray"
        case .today: "sun.max"
        case .upcoming: "calendar"
        case .someday: "shippingbox"
        case .logbook: "archivebox"
        case .project: "circle.dotted"
        }
    }

    /// El Registro no lleva contador: crece sin parar y no es una pendiente.
    var showsCount: Bool {
        if case .logbook = self { return false }
        return true
    }
}
