import Foundation

/// Qué se puede decidir sobre una tarea de la bandeja.
///
/// La bandeja existe para poder apuntar sin decidir. El precio es que hay que
/// decidir **después**, y ese después no llega: se mira la lista de sesenta
/// cosas, se cierra, y la bandeja se convierte en el sitio donde las cosas van
/// a morir. Es lo que le pasa a cualquier app de tareas con bandeja, y no se
/// arregla con un recordatorio: se arregla no enseñando sesenta cosas.
///
/// De ahí el vaciado: una tarea delante, cinco decisiones, la siguiente. No hay
/// nada que priorizar ni que arrastrar; solo hay que contestar.
public enum Despacho: Hashable, Sendable {
    case hoy
    case manana
    case proximaSemana
    case algunDia
    case eliminar
    case proyecto(UUID)

    /// Las que caben en botones fijos. El proyecto va aparte porque depende de
    /// cuáles haya.
    public static let sueltas: [Despacho] = [.hoy, .manana, .proximaSemana,
                                             .algunDia, .eliminar]

    public var titulo: String {
        switch self {
        case .hoy: "Hoy"
        case .manana: "Mañana"
        case .proximaSemana: "Próxima semana"
        case .algunDia: "Algún día"
        case .eliminar: "Eliminar"
        case .proyecto: "A un proyecto"
        }
    }

    public var icono: String {
        switch self {
        case .hoy: "sun.max"
        case .manana: "sunrise"
        case .proximaSemana: "calendar"
        case .algunDia: "shippingbox"
        case .eliminar: "trash"
        case .proyecto: "folder"
        }
    }

    /// Si es una decisión de la que no se vuelve.
    public var esDestructiva: Bool { self == .eliminar }
}

extension Store {
    /// Aplica una decisión del vaciado.
    ///
    /// Todas sacan la tarea de la bandeja, que es el punto: una decisión que la
    /// dejara donde estaba no sería una decisión.
    public func despachar(_ item: Item, _ decision: Despacho) {
        let cal = Calendar.current
        switch decision {
        case .hoy:
            schedule(item, to: .now)
        case .manana:
            schedule(item, to: cal.date(byAdding: .day, value: 1, to: .now))
        case .proximaSemana:
            schedule(item, to: cal.date(byAdding: .day, value: 7, to: .now))
        case .algunDia:
            park(item)
        case .eliminar:
            delete(item)
        case .proyecto(let id):
            move(item, to: .project(id))
        }
    }
}
