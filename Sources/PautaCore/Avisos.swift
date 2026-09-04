import Foundation
import Observation
import UserNotifications

/// Si hay algo que avisar y el sistema no va a dejar.
///
/// Un aviso que no llega y no lo dice es peor que no tener avisos: la tarea
/// parece cubierta y no lo está. Esto es lo que permite que la interfaz lo
/// cuente en vez de callarse.
@Observable
@MainActor
public final class AvisoEstado {
    public static let shared = AvisoEstado()
    public private(set) var mudos = false
    private init() {}

    static func set(_ valor: Bool) { shared.mudos = valor }
}

/// Avisos del sistema para las tareas que tienen hora.
///
/// Una hora sin aviso no sería más que una etiqueta: la app tendría que estar
/// abierta y mirándose para que sirviera de algo. Con el aviso, la hora es lo
/// que dice ser.
///
/// Los avisos se **reconstruyen enteros** en cada cambio en vez de irse
/// añadiendo y quitando uno a uno. Es más trabajo por cambio y muchísimo menos
/// de lo que cuesta razonar sobre qué avisos quedaron pendientes de una tarea
/// que se completó, se movió de día, se borró o volvió de otro dispositivo.
/// Lo que la app quiere que pase cuando se toca un aviso. Lo rellena la app al
/// arrancar; vive aquí porque el delegado no tiene forma de alcanzarla.
@MainActor
public enum AvisoAcciones {
    public static var alAbrir: ((UUID) -> Void)?
    public static var alCompletar: ((UUID) -> Void)?
    public static var alAplazar: ((UUID, Int) -> Void)?
    /// El repaso no lleva tarea dentro: abre la app para decidir el día.
    public static var alRepasar: (() -> Void)?
}

/// Delegado del centro de notificaciones.
///
/// Sin él no pasan dos cosas. La primera: **el aviso no se ve si Pauta está
/// delante**, porque el sistema lo silencia por defecto dando por hecho que ya
/// estás mirando la app — y en una app de tareas ese es justo el momento en que
/// más falta hace. La segunda: pulsarlo no hace nada.
public final class AvisoDelegado: NSObject, UNUserNotificationCenterDelegate {
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let peticion = response.notification.request.identifier
        if peticion == Repaso.identificador {
            await MainActor.run { AvisoAcciones.alRepasar?() }
            return
        }
        guard let id = UUID(uuidString: peticion) else { return }
        let accion = response.actionIdentifier
        await MainActor.run {
            switch accion {
            case Avisos.accionCompletar: AvisoAcciones.alCompletar?(id)
            case Avisos.accionAplazar:   AvisoAcciones.alAplazar?(id, Avisos.minutosAplazados)
            default:                     AvisoAcciones.alAbrir?(id)
            }
        }
    }
}

public enum Avisos {
    /// Identificadores de las acciones y de su categoría.
    static let accionCompletar = "completar"
    static let accionAplazar = "aplazar"
    static let categoria = "tarea"

    /// Cuánto aplaza el botón de aplazar. Diez minutos de fábrica: lo bastante
    /// para terminar lo que tenías entre manos y lo bastante poco para que
    /// aplazar no sea otra forma de perderlo de vista. Se cambia en los ajustes.
    @MainActor
    public static var minutosAplazados: Int { Ajustes.shared.minutosAplazados }

    nonisolated(unsafe) private static let delegado = AvisoDelegado()

    /// Se llama al arrancar, antes de que la app termine de lanzarse: puesto
    /// más tarde, el sistema ya habría entregado sin delegado los avisos que
    /// esperaban.
    @MainActor
    public static func hookUp() {
        guard let centro else { return }
        centro.delegate = delegado
        actualizarCategorias()
    }

    /// Vuelve a registrar los botones.
    ///
    /// Hace falta al cambiar los minutos de aplazamiento: el título del botón se
    /// congela al registrar la categoría, así que sin esto seguiría diciendo
    /// «Aplazar 10 min» y aplazando quince.
    @MainActor
    public static func actualizarCategorias() {
        guard let centro else { return }
        // Poder completar desde el propio aviso es lo que hace que una rutina
        // diaria no obligue a abrir la app para nada.
        // Y aplazar es lo que evita el descarte: un aviso que llega en mal
        // momento se quita de en medio con el gesto de siempre, y ese gesto se
        // lo lleva hasta mañana. Con el botón, «ahora no» deja de significar
        // «nunca».
        centro.setNotificationCategories([
            UNNotificationCategory(
                identifier: categoria,
                actions: [UNNotificationAction(identifier: accionCompletar,
                                               title: "Completar",
                                               options: []),
                          UNNotificationAction(identifier: accionAplazar,
                                               title: "Aplazar \(minutosAplazados) min",
                                               options: [])],
                intentIdentifiers: [])
        ])
    }

    /// Cuántos avisos se programan como mucho.
    ///
    /// El sistema descarta los que pasen de 64 por app, y sin un tope propio se
    /// perderían los primeros sin avisar de nada. Con 60 queda margen y se
    /// programan siempre los más cercanos, que son los que importan.
    static let tope = 60

    private static var centro: UNUserNotificationCenter? {
        // Sin bundle no hay centro de notificaciones, y pedirlo revienta el
        // proceso. Pasa al ejecutar el binario suelto, fuera del .app.
        guard Bundle.main.bundleIdentifier != nil else { return nil }
        return UNUserNotificationCenter.current()
    }

    public static func authorization() async -> UNAuthorizationStatus {
        guard let centro else { return .denied }
        return await centro.notificationSettings().authorizationStatus
    }

    /// Pide permiso. Devuelve si quedó concedido.
    @discardableResult
    public static func request() async -> Bool {
        guard let centro else { return false }
        return (try? await centro.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    /// Lo que el sistema ya ha entregado y sigue en el centro de
    /// notificaciones. Es la única forma de comprobar que un aviso llegó de
    /// verdad: lo programado dice lo que va a pasar, no lo que pasó.
    public static func delivered() async -> [(id: String, titulo: String,
                                              subtitulo: String, cuando: Date)] {
        guard let centro else { return [] }
        return await centro.deliveredNotifications().map {
            (id: $0.request.identifier,
             titulo: $0.request.content.title,
             subtitulo: $0.request.content.subtitle,
             cuando: $0.date)
        }
    }

    /// Los botones que lleva cada categoría, tal como los tiene registrados el
    /// sistema. Que estén en el código no significa que estén puestos.
    public static func categories() async -> [(String, [String])] {
        guard let centro else { return [] }
        return await centro.notificationCategories()
            .map { ($0.identifier, $0.actions.map(\.title)) }
    }

    public static func pending() async -> [String] {
        guard let centro else { return [] }
        return await centro.pendingNotificationRequests().map(\.identifier)
    }

    /// Vuelve a programar todos los avisos a partir de las tareas.
    ///
    /// El permiso se pide aquí y solo cuando hay algo que avisar: preguntarlo al
    /// arrancar molestaría a quien no use horas, y no preguntarlo nunca dejaría
    /// los avisos mudos sin explicación.
    public static func reschedule(_ items: [Item], now: Date = .now) async {
        guard let centro else { return }

        // El repaso primero, porque decide cuántos huecos quedan para tareas.
        let repaso = await Avisos.repasoPendiente(items, now: now)
        let pendientes = items
            .filter { $0.deletedAt == nil && !$0.isCompleted }
            .compactMap { item -> (Item, Date)? in
                guard let cuando = item.nextAlarm(after: now) else { return nil }
                return (item, cuando)
            }
            .sorted { $0.1 < $1.1 }
            .prefix(repaso == nil ? tope : tope - 1)

        centro.removeAllPendingNotificationRequests()
        guard !pendientes.isEmpty || repaso != nil else {
            await AvisoEstado.set(false)
            return
        }

        if await authorization() == .notDetermined { await request() }
        let permitido = await authorization() == .authorized
        await AvisoEstado.set(!permitido)
        guard permitido else { return }

        for (item, cuando) in pendientes {
            let contenido = UNMutableNotificationContent()
            contenido.title = item.title.isEmpty ? "Sin título" : item.title
            var explicacion: [String] = []
            // Cuando suena antes de la hora hay que decir cuánto falta, o
            // parecerá que la hora está mal puesta.
            if !item.isSnoozed(now: now), item.warnBefore != nil,
               let momento = item.nextOccurrence(after: now) {
                explicacion.append(Cuenta.restante(momento, now: cuando))
            }
            // Con fecha absoluta y no «hace tres días»: el aviso se escribe hoy
            // y puede sonar mañana, y entonces la cuenta ya no cuadraría.
            if item.daysLate > 0, let dia = item.day {
                explicacion.append(
                    "Pendiente desde el \(dia.formatted(.dateTime.day().month(.wide)))")
            }
            contenido.subtitle = explicacion.joined(separator: " · ")
            if !item.notes.isEmpty { contenido.body = item.notes }
            contenido.sound = .default
            contenido.categoryIdentifier = categoria

            // Lo de hoy y lo atrasado insiste cada día a su hora hasta que se
            // haga; lo de más adelante avisa el día que le toca y punto.
            //
            // La repetición es de la insistencia, no de la tarea repetitiva: una
            // serie avanza creando la sucesora al completar, y esa trae su
            // propio aviso. Un disparador diario atado a la serie seguiría
            // sonando después de que la serie hubiera acabado.
            let insiste = item.alarmInsists(now: now)
            let campos: Set<Calendar.Component> =
                insiste ? [.hour, .minute] : [.year, .month, .day, .hour, .minute]
            // Lo aplazado va por intervalo y no por calendario: un disparador de
            // calendario se cuenta al minuto, y aplazar diez minutos a y media y
            // treinta segundos daría un momento ya pasado —que no suena nunca—.
            let disparador: UNNotificationTrigger
            if item.isSnoozed(now: now) {
                disparador = UNTimeIntervalNotificationTrigger(
                    timeInterval: max(1, cuando.timeIntervalSince(now)), repeats: false)
            } else {
                disparador = UNCalendarNotificationTrigger(
                    dateMatching: Calendar.current.dateComponents(campos, from: cuando),
                    repeats: insiste)
            }
            let peticion = UNNotificationRequest(
                identifier: item.id.uuidString,
                content: contenido,
                trigger: disparador)
            try? await centro.add(peticion)
        }

        if let (cuando, resumen) = repaso {
            let contenido = UNMutableNotificationContent()
            contenido.title = resumen.titulo
            contenido.body = resumen.cuerpo
            contenido.sound = .default
            // Sin categoría: no lleva una tarea dentro, así que «Completar» no
            // tendría a qué aplicarse y «Aplazar» solo serviría para aplazar la
            // decisión, que es lo contrario de para lo que existe.
            let peticion = UNNotificationRequest(
                identifier: Repaso.identificador,
                content: contenido,
                trigger: UNCalendarNotificationTrigger(
                    dateMatching: Calendar.current.dateComponents(
                        [.year, .month, .day, .hour, .minute], from: cuando),
                    repeats: false))
            try? await centro.add(peticion)
        }
    }

    /// El repaso que toca, si toca alguno.
    ///
    /// **Uno solo y sin repetición**, aunque el repaso sea diario: el texto lleva
    /// las cuentas dentro, y un disparador repetitivo seguiría cantando las de
    /// hoy dentro de un mes. El siguiente se programa en cuanto algo cambia o
    /// cambia el día, que es lo que mantiene el texto verdadero.
    @MainActor
    static func repasoPendiente(_ items: [Item],
                                now: Date) -> (Date, Repaso.Resumen)? {
        guard let cuando = Repaso.proximo(hora: Repaso.hora, after: now) else { return nil }
        let resumen = Repaso.resumen(items, para: cuando)
        // Un repaso que dice «nada» enseña a ignorar los repasos.
        guard !resumen.vacio else { return nil }
        return (cuando, resumen)
    }
}
