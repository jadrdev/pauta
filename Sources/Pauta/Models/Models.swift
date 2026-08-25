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
    var projectID: UUID?
    var createdAt = Date()

    var isToday: Bool {
        guard let when, !isCompleted else { return false }
        return Calendar.current.startOfDay(for: when) <= Calendar.current.startOfDay(for: .now)
    }
}

// MARK: - Proyecto

struct Project: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var notes: String = ""
    var isCompleted = false
    var createdAt = Date()
}

// MARK: - Perspectivas de la barra lateral

enum Perspective: Hashable {
    case inbox
    case today
    case logbook
    case project(UUID)

    var title: String {
        switch self {
        case .inbox: "Bandeja"
        case .today: "Hoy"
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
        case .logbook: "archivebox"
        case .project: "circle.dotted"
        }
    }
}
