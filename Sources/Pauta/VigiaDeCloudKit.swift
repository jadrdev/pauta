import AppKit
import PautaCore

// ANDAMIO-CLOUDKIT: todo este archivo es de la fase 0 del plan de CloudKit
// (docs/plan-cloudkit.md) y se borra al cerrarla.

/// `Pauta --cloudkit-prueba vigilar`: se queda escuchando los avisos
/// silenciosos de la zona de prueba y dice cuánto tarda cada uno desde que el
/// otro aparato escribió.
///
/// Necesita una `NSApplication` de verdad corriendo —los avisos remotos
/// llegan por su delegado—, así que no sirve `runOnMainLoop`. Como accesoria
/// no sale en el Dock.
final class VigiaDeCloudKit: NSObject, NSApplicationDelegate {
    private static var vigia: VigiaDeCloudKit?
    private let formato: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss.SSS"; return f
    }()

    @MainActor static func vigilar() {
        // Línea a línea: redirigido a un archivo, la salida se quedaba en el
        // búfer y el vigía parecía mudo.
        setvbuf(stdout, nil, _IOLBF, 0)
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let v = VigiaDeCloudKit()
        vigia = v
        app.delegate = v
        print("vigilando avisos de la zona «Prueba»… (ctrl-C para salir)")
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.registerForRemoteNotifications()
        // Y una llamada a CloudKit: puede que el sistema no apunte el proceso
        // a los avisos del contenedor hasta que lo usa.
        Task {
            print("cuenta de iCloud: \(await PruebaCloudKit.cuenta())")
            let subs = (try? await PruebaCloudKit.suscripciones()) ?? []
            print("suscripciones: \(subs.count)")
        }
    }

    func application(_ application: NSApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("registrado para avisos · token \(deviceToken.map { String(format: "%02x", $0) }.joined())")
    }

    func application(_ application: NSApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("✗ no se pudo registrar para avisos: \(error.localizedDescription)")
    }

    func application(_ application: NSApplication,
                     didReceiveRemoteNotification userInfo: [String: Any]) {
        let ahora = Date()
        print("aviso crudo: \(PruebaCloudKit.apuntarCrudo(userInfo, ahora))")
        guard PruebaCloudKit.esDeLaPrueba(userInfo) else { return }
        Task {
            let a = await PruebaCloudKit.alRecibirAviso(ahora)
            let retraso = a.retraso.map { String(format: "%.1f s", $0) } ?? "?"
            print("aviso a las \(formato.string(from: ahora)) · último de \(a.ultimoDe ?? "?") · tardó \(retraso)")
        }
    }
}
