import Foundation

/// Cada cuánto se repite una tarea.
public enum Recurrence: String, Codable, CaseIterable, Sendable {
    case diaria, semanal, mensual, anual

    public var title: String {
        switch self {
        case .diaria: "Cada día"
        case .semanal: "Cada semana"
        case .mensual: "Cada mes"
        case .anual: "Cada año"
        }
    }

    /// La siguiente fecha a partir de una dada.
    public func next(after date: Date, calendar: Calendar = .current) -> Date {
        let componente: Calendar.Component
        switch self {
        case .diaria: componente = .day
        case .semanal: componente = .weekOfYear
        case .mensual: componente = .month
        case .anual: componente = .year
        }
        return calendar.startOfDay(
            for: calendar.date(byAdding: componente, value: 1, to: date) ?? date)
    }
}

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
    /// Prioridad manual. Una sola posición para toda la app, no una por lista:
    /// las listas son consultas sobre la misma tarea, así que su prioridad es
    /// intrínseca y todas la respetan.
    ///
    /// Es `Double` para poder insertar entre dos vecinas sacando el punto medio,
    /// y así reordenar toca **un solo archivo** en vez de reescribirlos todos —
    /// que con la carpeta sincronizada importa mucho.
    public var position: Double = 0
    /// Fecha de entrega, distinta de `when`.
    ///
    /// `when` es cuándo pienso ponerme; `deadline` es cuándo tiene que estar. Son
    /// cosas distintas y mezclarlas obliga a elegir entre planificar y avisar.
    public var deadline: Date?
    /// Cada cuánto se repite, si se repite.
    ///
    /// El **inicio** no es un campo aparte: es `when`, la fecha de la tarea. Una
    /// semanal puesta para el 1 de septiembre empieza ahí. Guardarlo dos veces
    /// solo daría ocasión de que discreparan.
    public var recurrence: Recurrence?
    /// Último día en que puede caer una repetición. `nil` = no acaba nunca.
    public var recurrenceEnd: Date?
    /// Si esta tarea nació al completarse otra repetitiva, cuál era.
    ///
    /// Sirve para deshacer: si descompletas la original, la sucesora que generó
    /// se retira, en vez de quedarse ahí duplicando el trabajo.
    public var spawnedFrom: UUID?
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
        position    = try c.decodeIfPresent(Double.self, forKey: .position) ?? 0
        deadline    = try c.decodeIfPresent(Date.self,   forKey: .deadline)
        recurrence  = try c.decodeIfPresent(Recurrence.self, forKey: .recurrence)
        recurrenceEnd = try c.decodeIfPresent(Date.self, forKey: .recurrenceEnd)
        spawnedFrom = try c.decodeIfPresent(UUID.self,   forKey: .spawnedFrom)
    }

    /// Su fecha límite es hoy o ya pasó.
    public var deadlineIsDue: Bool {
        guard let deadline, !isCompleted else { return false }
        return Calendar.current.startOfDay(for: deadline)
            <= Calendar.current.startOfDay(for: .now)
    }

    /// La fecha límite ya pasó: no es «para hoy», es tarde.
    public var isOverdue: Bool {
        guard let deadline, !isCompleted else { return false }
        return Calendar.current.startOfDay(for: deadline)
            < Calendar.current.startOfDay(for: .now)
    }

    /// Planificada para hoy o antes, o con la fecha límite encima.
    ///
    /// Una fecha límite que vence arrastra la tarea a Hoy aunque no estuviera
    /// planificada: si no saliera a la superficie el día que toca, no serviría de
    /// nada. Lo aparcado en «Algún día» sí se respeta, porque aparcarlo fue una
    /// decisión explícita.
    public var isToday: Bool {
        guard !isCompleted, !isSomeday else { return false }
        if deadlineIsDue { return true }
        guard let when else { return false }
        return Calendar.current.startOfDay(for: when) <= Calendar.current.startOfDay(for: .now)
    }

    /// El día para el que está planificada, sin hora.
    public var day: Date? { when.map { Calendar.current.startOfDay(for: $0) } }

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
extension Area: Timestamped {}

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

    /// Orden manual, con la creación como desempate para que siga siendo total.
    public static func byPosition(_ a: Item, _ b: Item) -> Bool {
        a.position == b.position ? byCreation(a, b) : a.position < b.position
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
    /// Orden manual en la barra lateral. Como en las tareas, es un hueco entre
    /// vecinos y no un índice, para que mover uno escriba un solo archivo.
    public var position: Double = 0
    /// El área a la que pertenece, si está en alguna.
    public var areaID: UUID?

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
        position    = try c.decodeIfPresent(Double.self, forKey: .position) ?? 0
        areaID      = try c.decodeIfPresent(UUID.self,   forKey: .areaID)
    }
}

/// Un cajón de proyectos: «Trabajo», «Casa», «Estudios».
///
/// No guarda tareas propias. Lo que un área agrupa son proyectos, así que sus
/// tareas son las de sus proyectos: sin proyecto no hay a qué colgarlas, y una
/// tarea suelta dentro de un área sería un segundo padre con sus propias reglas.
public struct Area: Identifiable, Codable, Hashable {
    public var id = UUID()
    public var name: String
    /// Emoji que la identifica en la barra lateral. Vacío = sin emoji.
    public var icon: String = ""
    public var createdAt = Date()
    public var updatedAt = Date()
    public var deletedAt: Date?
    public var position: Double = 0

    public init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id        = try c.decodeIfPresent(UUID.self,   forKey: .id) ?? UUID()
        name      = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        icon      = try c.decodeIfPresent(String.self, forKey: .icon) ?? ""
        createdAt = try c.decodeIfPresent(Date.self,   forKey: .createdAt) ?? Date()
        updatedAt = try c.decodeIfPresent(Date.self,   forKey: .updatedAt) ?? createdAt
        deletedAt = try c.decodeIfPresent(Date.self,   forKey: .deletedAt)
        position  = try c.decodeIfPresent(Double.self, forKey: .position) ?? 0
    }
}

extension Project {
    /// Orden total, por el mismo motivo que en `Item`.
    public static func byCreation(_ a: Project, _ b: Project) -> Bool {
        a.createdAt == b.createdAt
            ? a.id.uuidString < b.id.uuidString
            : a.createdAt < b.createdAt
    }

    /// El orden de la barra lateral: manual, y por creación al empatar.
    public static func byPosition(_ a: Project, _ b: Project) -> Bool {
        a.position == b.position ? byCreation(a, b) : a.position < b.position
    }

    /// Orden alfabético del idioma del usuario: respeta acentos y la ñ, que un
    /// `<` entre cadenas compara por su valor Unicode y coloca al final.
    public static func byName(_ a: Project, _ b: Project) -> Bool {
        let comparacion = a.name.localizedStandardCompare(b.name)
        return comparacion == .orderedSame ? byCreation(a, b) : comparacion == .orderedAscending
    }
}

extension Area {
    /// Orden total, por el mismo motivo que en `Item`.
    public static func byCreation(_ a: Area, _ b: Area) -> Bool {
        a.createdAt == b.createdAt
            ? a.id.uuidString < b.id.uuidString
            : a.createdAt < b.createdAt
    }

    public static func byPosition(_ a: Area, _ b: Area) -> Bool {
        a.position == b.position ? byCreation(a, b) : a.position < b.position
    }

    public static func byName(_ a: Area, _ b: Area) -> Bool {
        let comparacion = a.name.localizedStandardCompare(b.name)
        return comparacion == .orderedSame ? byCreation(a, b) : comparacion == .orderedAscending
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
    case area(UUID)

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
        case .area: "Área"
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
        case .area: "square.stack"
        }
    }

    /// Dónde tiene sentido crear una tarea. En «Completadas» nacería ya hecha;
    /// en un área no habría a qué proyecto colgarla, porque lo que un área
    /// agrupa son proyectos.
    public var acceptsNewItems: Bool {
        switch self {
        case .completed, .area: false
        default: true
        }
    }

    /// La lista de completadas no lleva contador: crece sin parar y no es una
    /// pendiente que haya que vigilar.
    public var showsCount: Bool {
        if case .completed = self { return false }
        return true
    }
}
