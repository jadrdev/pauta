import Foundation

// MARK: - Tarea

public struct Item: Identifiable, Codable, Hashable {
    public var id = UUID()
    public var title: String
    public var notes: String = ""
    public var isCompleted = false
    public var completedAt: Date?
    /// Fecha para la que está planificada. `nil` = sin planificar.
    public var when: Date?
    /// Aparcada sin fecha, a propósito. Distinto de `when == nil`, que solo
    /// significa «todavía sin planificar» y deja la tarea en la bandeja.
    public var isSomeday = false
    public var projectID: UUID?
    public var createdAt = Date()
    /// Última modificación. Con un archivo por tarea, es lo que permite resolver
    /// un conflicto entre dos dispositivos que tocaron la misma: gana la más
    /// reciente.
    public var updatedAt = Date()
    /// Lápida. Borrar no elimina el archivo: lo marca. Si se eliminara, un
    /// dispositivo que no vio el borrado resucitaría la tarea al sincronizar.
    public var deletedAt: Date?
    /// Identificador en la fuente externa de la que se capturó, si vino de una.
    /// Evita reimportarla si el marcado en el origen falló.
    public var sourceID: String?

    public init(id: UUID = UUID(), title: String) {
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
    public init(from decoder: Decoder) throws {
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
        sourceID    = try c.decodeIfPresent(String.self, forKey: .sourceID)
        updatedAt   = try c.decodeIfPresent(Date.self,   forKey: .updatedAt) ?? createdAt
        deletedAt   = try c.decodeIfPresent(Date.self,   forKey: .deletedAt)
    }

    /// Planificada para hoy o antes (una tarea vencida sigue estando en Hoy).
    public var isToday: Bool {
        guard let when, !isCompleted, !isSomeday else { return false }
        return Calendar.current.startOfDay(for: when) <= Calendar.current.startOfDay(for: .now)
    }

    /// Planificada para un día posterior a hoy.
    public var isUpcoming: Bool {
        guard let when, !isCompleted, !isSomeday else { return false }
        return Calendar.current.startOfDay(for: when) > Calendar.current.startOfDay(for: .now)
    }

    /// Se puede hacer ya: ni aparcada ni planificada para el futuro. La bandeja
    /// queda fuera a propósito: lo que hay allí todavía está sin decidir.
    public var isAnytime: Bool {
        guard !isCompleted, !isSomeday, !isUpcoming else { return false }
        return projectID != nil || when != nil
    }
}

/// Lo que basta para resolver un conflicto de sincronización: quedarse con la
/// versión modificada más recientemente.
public protocol Timestamped: Codable {
    var updatedAt: Date { get }
}

extension Item: Timestamped {}
extension Project: Timestamped {}

extension Item {
    /// Orden total: por creación y, cuando coincide, por identificador.
    ///
    /// El desempate no es cosmético. Las fechas se guardan con fracción de
    /// segundo, pero los archivos escritos por versiones anteriores solo tienen
    /// segundos, así que los empates existen; y `sorted` no garantiza
    /// estabilidad. Sin un orden total, la lista se reordenaría sola entre
    /// arranques.
    public static func byCreation(_ a: Item, _ b: Item) -> Bool {
        a.createdAt == b.createdAt
            ? a.id.uuidString < b.id.uuidString
            : a.createdAt < b.createdAt
    }
}

// MARK: - Proyecto

public struct Project: Identifiable, Codable, Hashable {
    public var id = UUID()
    public var name: String
    public var notes: String = ""
    /// Emoji que identifica al proyecto en la barra lateral. Vacío = sin emoji.
    public var icon: String = ""
    public var isCompleted = false
    public var createdAt = Date()
    public var updatedAt = Date()
    public var deletedAt: Date?

    public init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decodeIfPresent(UUID.self,   forKey: .id) ?? UUID()
        name        = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        notes       = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        icon        = try c.decodeIfPresent(String.self, forKey: .icon) ?? ""
        isCompleted = try c.decodeIfPresent(Bool.self,   forKey: .isCompleted) ?? false
        createdAt   = try c.decodeIfPresent(Date.self,   forKey: .createdAt) ?? Date()
        updatedAt   = try c.decodeIfPresent(Date.self,   forKey: .updatedAt) ?? createdAt
        deletedAt   = try c.decodeIfPresent(Date.self,   forKey: .deletedAt)
    }
}

extension Project {
    /// Orden total, por el mismo motivo que en `Item`.
    public static func byCreation(_ a: Project, _ b: Project) -> Bool {
        a.createdAt == b.createdAt
            ? a.id.uuidString < b.id.uuidString
            : a.createdAt < b.createdAt
    }
}

// MARK: - Perspectivas de la barra lateral

public enum Perspective: Hashable, CaseIterable {
    case inbox
    case today
    case upcoming
    case anytime
    case someday
    case completed
    case project(UUID)

    /// Las fijas, en el orden en que se muestran. Los proyectos van aparte.
    public static var allCases: [Perspective] { [.inbox, .today, .upcoming, .anytime, .someday, .completed] }

    public var title: String {
        switch self {
        case .inbox: "Bandeja"
        case .today: "Hoy"
        case .upcoming: "Próximamente"
        case .anytime: "Cualquier momento"
        case .someday: "Algún día"
        case .completed: "Completadas"
        case .project: "Proyecto"
        }
    }

    /// Símbolos monocromos, elegidos para no chocar con otros significados de
    /// la interfaz: un check para «Completadas» competiría con la casilla de
    /// completar, y una estrella se lee como «favorito», no como «hoy».
    public var symbol: String {
        switch self {
        case .inbox: "tray"
        case .today: "sun.max"
        case .upcoming: "calendar"
        case .anytime: "list.bullet"
        case .someday: "shippingbox"
        case .completed: "archivebox"
        case .project: "circle.dotted"
        }
    }

    /// La lista de completadas no lleva contador: crece sin parar y no es una
    /// pendiente que haya que vigilar.
    public var showsCount: Bool {
        if case .completed = self { return false }
        return true
    }
}
