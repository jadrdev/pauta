import Foundation
import UserNotifications

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
public enum Avisos {
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

        let pendientes = items
            .filter { $0.deletedAt == nil && !$0.isCompleted }
            .compactMap { item -> (Item, Date)? in
                guard let cuando = item.scheduledAt, cuando > now else { return nil }
                return (item, cuando)
            }
            .sorted { $0.1 < $1.1 }
            .prefix(tope)

        centro.removeAllPendingNotificationRequests()
        guard !pendientes.isEmpty else { return }

        if await authorization() == .notDetermined { await request() }
        guard await authorization() == .authorized else { return }

        for (item, cuando) in pendientes {
            let contenido = UNMutableNotificationContent()
            contenido.title = item.title.isEmpty ? "Sin título" : item.title
            if !item.notes.isEmpty { contenido.body = item.notes }
            contenido.sound = .default

            let partes = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute], from: cuando)
            let peticion = UNNotificationRequest(
                identifier: item.id.uuidString,
                content: contenido,
                // Sin repetición aunque la tarea se repita: la sucesora nace al
                // completar la anterior y trae su propio aviso. Un disparador
                // repetitivo seguiría sonando aunque la serie hubiera acabado.
                trigger: UNCalendarNotificationTrigger(dateMatching: partes, repeats: false))
            try? await centro.add(peticion)
        }
    }
}
