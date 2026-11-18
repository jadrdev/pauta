import UIKit
import CloudKit
import WidgetKit
import UserNotifications
import PautaCore

/// La sincronía con CloudKit en el teléfono y el iPad (docs/plan-cloudkit.md,
/// fase 3).
///
/// El almacén ya es local —la carpeta que comparte con el widget—, así que no
/// hay mudanza: cambia con qué se cruza. `Sincronia` con `MotorCloudKit`, como
/// en el Mac, pero aquí **los avisos silenciosos sí llegan**: el servidor
/// despierta la app cuando otro aparato cambia algo, aunque esté en segundo
/// plano, y baja solo eso.
///
/// Arranca en el `init` de la app y no en una vista: cuando iOS la despierta
/// por un aviso no monta ninguna interfaz, y el motor tiene que estar ya.
@MainActor
@Observable
final class SincroniaDelTelefono {
    static let shared = SincroniaDelTelefono()

    /// En qué está, para los ajustes.
    private(set) var estado: Sincronia.Estado = .esperando
    /// La última vez que se habló con el servidor sin fallo.
    private(set) var ultima: Date?
    /// El último fallo, si lo hubo después de la última vez buena.
    private(set) var fallo: String?

    @ObservationIgnored private var sincronia: Sincronia?
    @ObservationIgnored private var motor: MotorCloudKit?

    var activa: Bool { sincronia != nil }

    func arrancar() {
        // La maqueta de las capturas no toca iCloud: llevaría sus tareas de
        // muestra a las de verdad.
        guard !Maqueta.activa, sincronia == nil else { return }
        let raiz = Store.defaultRoot
        let carpeta = MudanzaACloudKit.carpetaDelEstado(en: raiz)
        let s = Sincronia(raiz: raiz, estado: carpeta.appendingPathComponent("sincronia.json"))
        let m = MotorCloudKit(sincronia: s, carpeta: carpeta.appendingPathComponent("motor", isDirectory: true))
        s.alTraer = { [weak self] in self?.llegoAlgo() }
        sincronia = s
        motor = m
        Task {
            await m.comprobarCuenta()
            estado = s.estado
            await sincronizar(traer: true)
        }
    }

    /// El almacén de la interfaz avisa de lo que escribe. Los demás —el del
    /// widget, el de Siri, el de los avisos— lo dejan en los apuntes.
    func enganchar(_ store: Store) {
        guard let sincronia, store.storageURL == sincronia.raiz else { return }
        store.alEscribir = { sincronia.escrito($0) }
        store.alPurgar = { sincronia.purgadas($0) }
    }

    /// Lo que trajo el cruce con el contenedor de iCloud, también a CloudKit:
    /// lo escribió un aparato que todavía no lo usa.
    func traidasDelContenedor(_ claves: [Ficha.Clave]) {
        for clave in claves { sincronia?.escrito(clave) }
    }

    /// Sube lo pendiente y, si se pide, trae lo de los demás.
    ///
    /// Subir siempre y no dejarlo solo al motor: quien llama suele ser algo que
    /// va a dormir enseguida —un botón del aviso, la app que se va al fondo—,
    /// y lo apuntado tiene que salir antes.
    func sincronizar(traer: Bool) async {
        guard let sincronia, let motor else { return }
        sincronia.recogerApuntes()
        estado = sincronia.estado
        guard sincronia.puedeSubir else { return }
        do {
            try await motor.enviar()
            if traer { try await motor.traer() }
            ultima = .now
            fallo = nil
        } catch {
            fallo = error.localizedDescription
        }
        estado = sincronia.estado
    }

    /// Las tareas eran de otra cuenta de iCloud: subirlas a esta, o dejarlas
    /// sin sincronizar. No se borra nada en ningún caso.
    func decidirOtraCuenta(subir: Bool) {
        sincronia?.decidirOtraCuenta(subir: subir)
        estado = sincronia?.estado ?? .esperando
        if subir { Task { await sincronizar(traer: true) } }
    }

    /// Un aviso silencioso del servidor: hay cambios. Devuelve si trajo algo.
    func alRecibirAviso(contenedor: String?) async -> Bool {
        guard contenedor == MotorCloudKit.contenedor else { return false }
        let antes = ultima
        await sincronizar(traer: true)
        return ultima != antes
    }

    /// Lo que llegó cambió archivos de la carpeta. Si la interfaz está montada,
    /// relee; y lo que se ve sin abrir la app —el widget, el reloj, el globo,
    /// los avisos— se pone al día aquí, porque despertada por un aviso no hay
    /// interfaz que lo haga.
    private func llegoAlgo() {
        NotificationCenter.default.post(name: .pautaApuntadoDesdeFuera, object: nil)
        guard UIApplication.shared.applicationState != .active else { return }
        Task { await RefrescoEnSegundoPlano.avisar() }
    }
}

/// Lo justo de un delegado de la app: registrarse para los avisos silenciosos
/// y atenderlos. Registrarse no pregunta nada: los avisos silenciosos no
/// necesitan permiso.
final class DelegadoDeLaApp: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions opciones: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        application.registerForRemoteNotifications()
        return true
    }

    /// Del aviso se saca aquí lo único que hace falta, de qué contenedor es,
    /// antes de pasar al hilo principal: el diccionario no se puede llevar.
    nonisolated func application(_ application: UIApplication,
                                 didReceiveRemoteNotification info: [AnyHashable: Any]) async
        -> UIBackgroundFetchResult {
        let contenedor = CKNotification(fromRemoteNotificationDictionary: info)?.containerIdentifier
        return await SincroniaDelTelefono.shared.alRecibirAviso(contenedor: contenedor) ? .newData : .noData
    }
}
