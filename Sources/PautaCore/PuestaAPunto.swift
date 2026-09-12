import Foundation
import EventKit
import UserNotifications

/// Los permisos que Pauta necesita del sistema.
public enum Permiso: String, CaseIterable, Sendable {
    case avisos, calendario, recordatorios

    public var titulo: String {
        switch self {
        case .avisos: "Avisos"
        case .calendario: "Calendario"
        case .recordatorios: "Recordatorios"
        }
    }

    /// Una línea, y dice **qué se pierde sin él**, no qué se concede.
    ///
    /// «Pauta quiere acceder a tu calendario» no es una razón, es un trámite.
    /// La razón es que sin eso el día que enseña Hoy está incompleto.
    public var motivo: String {
        switch self {
        case .avisos: "Sin ellos, una hora es solo una etiqueta."
        case .calendario: "Para que Hoy sea el día entero y no solo tus tareas."
        case .recordatorios: "Lo que le dictas a Siri entra en la bandeja."
        }
    }

    public var icono: String {
        switch self {
        case .avisos: "bell.badge"
        case .calendario: "calendar"
        case .recordatorios: "checklist"
        }
    }
}

public enum EstadoDePermiso: Sendable, Equatable {
    case sinPreguntar, concedido, denegado
}

/// Qué hay que ofrecer al usuario nuevo, y qué no.
///
/// La bienvenida de Pauta es la lista vacía: no hay asistente de páginas. Pedir
/// tres permisos antes de que se haya visto una sola tarea es pedir permiso
/// antes de que exista el motivo —y aquí un «no» es **para siempre**, porque ni
/// macOS ni iOS vuelven a preguntar—. Así que la tarjeta va debajo del vacío,
/// se puede ignorar, y no bloquea nada.
///
/// Y solo lista **lo que no se ha contestado**. Un permiso denegado no vuelve
/// aquí a insistir: eso ya lo dicen las franjas de su sitio y la pantalla de
/// permisos. Una tarjeta que no se va nunca deja de ser una bienvenida y pasa a
/// ser una regañina.
public enum PuestaAPunto {
    /// La decisión, aislada de cómo se consultan los estados, para poder
    /// probarla sin depender de lo que el sistema tenga concedido hoy.
    public static func pendientes(_ estados: [Permiso: EstadoDePermiso]) -> [Permiso] {
        Permiso.allCases.filter { estados[$0] == .sinPreguntar }
    }

    @MainActor
    public static func estados() async -> [Permiso: EstadoDePermiso] {
        [.avisos: deAvisos(await Avisos.authorization()),
         .calendario: deEventKit(EKEventStore.authorizationStatus(for: .event)),
         .recordatorios: deEventKit(EKEventStore.authorizationStatus(for: .reminder))]
    }

    @MainActor
    public static func pendientes() async -> [Permiso] {
        pendientes(await estados())
    }

    /// Pide uno. Devuelve si quedó concedido.
    ///
    /// Por el mismo camino que la pantalla de ajustes, y no por uno propio:
    /// `Agenda` y `RemindersInbox` **guardan su `EKEventStore`**, y eso no es
    /// decoración. Un `EKEventStore()` creado al vuelo se suelta al terminar la
    /// expresión, mientras el diálogo del sistema sigue abierto esperando tu
    /// respuesta; cuando contestas ya no hay a quién avisar y la espera no vuelve
    /// nunca. Desde fuera parece que el permiso no se dio: el botón se queda en
    /// «…» y la tarjeta, igual que estaba.
    ///
    /// `withExtendedLifetime` y no confiar en que la variable local baste: lo que
    /// mantiene vivo un objeto es su último uso, y aquí el último uso es la
    /// llamada — justo la que hay que sobrevivir.
    @MainActor
    @discardableResult
    public static func pedir(_ permiso: Permiso) async -> Bool {
        switch permiso {
        case .avisos:
            return await Avisos.request()
        case .calendario:
            let agenda = Agenda()
            let concedido = await agenda.requestAccess()
            withExtendedLifetime(agenda) {}
            return concedido
        case .recordatorios:
            let bandeja = RemindersInbox()
            let concedido = (try? await bandeja.requestAccess()) ?? false
            withExtendedLifetime(bandeja) {}
            return concedido
        }
    }

    private static func deAvisos(_ estado: UNAuthorizationStatus) -> EstadoDePermiso {
        switch estado {
        case .notDetermined: .sinPreguntar
        case .authorized, .provisional, .ephemeral: .concedido
        default: .denegado
        }
    }

    /// «Solo añadir» cuenta como denegado: con eso Pauta no puede **leer** ni un
    /// evento ni un recordatorio, que es lo único que hace con ellos.
    private static func deEventKit(_ estado: EKAuthorizationStatus) -> EstadoDePermiso {
        switch estado {
        case .notDetermined: .sinPreguntar
        case .fullAccess: .concedido
        default: .denegado
        }
    }
}
