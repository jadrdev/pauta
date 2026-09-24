import BackgroundTasks
import UserNotifications
import WidgetKit
import PautaCore

/// Cruzar con el Mac de vez en cuando aunque no abras la app.
///
/// **No es tiempo real y no hay que venderlo como tal.** Quien decide cuándo
/// despertar es iOS, según lo que uses la app, la batería y la red: puede ser en
/// minutos o en horas, y con el ahorro de batería puesto puede no ocurrir. Lo
/// que arregla no es la app —esa se cruza al abrirla— sino lo que se ve **sin**
/// abrirla: el widget, el globo del icono y lo que el reloj tenga guardado.
///
/// Para tiempo real de verdad haría falta CloudKit, que es cambiarle los
/// cimientos a la app y perder que tus tareas sean archivos tuyos en tu carpeta.
@MainActor
enum RefrescoEnSegundoPlano {
    static let identificador = "dev.jadrdev.pauta.refresco"

    /// Se registra **antes** de que termine el lanzamiento, o el sistema avisa
    /// con una excepción. Por eso vive en el `init` de la app y no en una vista.
    static func registrar(_ trabajo: @escaping @Sendable () async -> Void) {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: identificador, using: nil
        ) { tarea in
            // Lo primero, pedir el siguiente: si se pide solo al final y el
            // sistema corta la tarea por tiempo, no queda ninguno pedido y no
            // vuelve a despertar nunca.
            programar()
            let faena = Task {
                await trabajo()
                tarea.setTaskCompleted(success: true)
            }
            tarea.expirationHandler = {
                faena.cancel()
                tarea.setTaskCompleted(success: false)
            }
        }
    }

    /// Lo que se hace al despertar: cruzar con el Mac y refrescar lo que se ve
    /// **sin** abrir la app — el widget, el globo y lo que tenga el reloj.
    ///
    /// Almacén propio y no el de la interfaz: cuando el sistema despierta la app
    /// no hay ninguna interfaz montada de la que sacarlo.
    static func cruzarYAvisar() async {
        let almacen = Store()
        await Sincronizar.conElMac(almacen)
        almacen.reload()
        let vistazo = Vistazo.de(almacen.items, proyectos: almacen.projects,
                                 limite: Vistazo.limitePublicado)
        WidgetCenter.shared.reloadAllTimelines()
        EnlaceConElReloj.shared.publicar(vistazo)
        try? await UNUserNotificationCenter.current()
            .setBadgeCount(vistazo.atrasadas)
    }

    /// Pide el siguiente despertar. Pedirlo de más no cuesta: el sistema se
    /// queda con uno solo por identificador.
    static func programar(dentroDe minutos: Double = 30) {
        let peticion = BGAppRefreshTaskRequest(identifier: identificador)
        peticion.earliestBeginDate = Date(timeIntervalSinceNow: minutos * 60)
        try? BGTaskScheduler.shared.submit(peticion)
    }
}
