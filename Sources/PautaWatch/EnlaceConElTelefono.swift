import Foundation
import Observation
import WatchConnectivity
import WidgetKit
import PautaCore

/// Lo que llega del teléfono.
///
/// Se usa el **contexto de aplicación** y no mensajes: el contexto es «lo último
/// que se sabe», lo guarda el sistema y está ahí al abrir el reloj aunque el
/// teléfono no esté cerca. Un mensaje exige a los dos despiertos a la vez, que
/// es justo lo que no pasa cuando levantas la muñeca.
@MainActor
@Observable
final class EnlaceConElTelefono: NSObject, WCSessionDelegate {
    /// Una sola, porque el atajo de Siri también manda órdenes y no vive dentro
    /// de la vista. Dos enlaces serían dos sesiones peleándose por el mismo
    /// delegado.
    static let shared = EnlaceConElTelefono()

    /// El último vistazo recibido, si hay alguno.
    private(set) var vistazo: Vistazo?

    /// Lo recibido, **solo si habla de hoy**.
    ///
    /// El contexto de aplicación lo guarda el sistema: sobrevive a cerrar la
    /// app, a apagar el reloj y a no acercarse al teléfono en días. Sin esta
    /// comprobación, «lo último que llegó» se enseñaba como si fuera lo de hoy,
    /// y una muñeca se mira de reojo — nadie comprueba una lista que ya está
    /// delante. La complicación lo hacía desde el principio; esto no.
    var alDia: Vistazo? { Vistazo.deHoy(vistazo) }
    /// Lo que se ha mandado tachar y todavía no ha vuelto confirmado.
    ///
    /// El reloj **no tiene los datos**: quien tacha de verdad es el teléfono, y
    /// la confirmación llega con el vistazo siguiente. Sin esto, la tarea se
    /// quedaría en pantalla sin marcar el segundo o dos que tarda el viaje, y
    /// se pulsaría otra vez pensando que no se enteró.
    private(set) var enCamino: Set<UUID> = []

    /// Lo que hay que mandar y todavía no se ha podido.
    ///
    /// Activar la sesión tarda, y una orden dictada a Siri puede salir antes de
    /// que haya por dónde: sin esta cola se pediría mandarla y se perdería en
    /// silencio. Es el mismo problema que el teléfono resolvió guardando el
    /// último vistazo, y por el mismo motivo.
    private var porMandar: [Orden] = []

    func activar() {
        guard WCSession.isSupported() else { return }
        let sesion = WCSession.default
        sesion.delegate = self
        sesion.activate()
        // Lo que ya hubiera guardado el sistema, sin esperar a que el teléfono
        // mande nada.
        leer(sesion.receivedApplicationContext)
    }

    /// `nonisolated` porque la llaman los métodos del delegado, y a esos el
    /// sistema los llama desde donde le parece. Lo que toca la interfaz salta al
    /// actor principal aquí dentro, en un solo sitio.
    nonisolated private func leer(_ contexto: [String: Any]) {
        guard let datos = contexto[Vistazo.clave] as? Data,
              let recibido = Vistazo.desde(datos) else { return }
        // Escrito en la carpeta del grupo antes de enseñarlo: la complicación
        // es otro proceso y no ve esta memoria. Es su única fuente, así que
        // hasta que esto se guarda, la esfera sigue contando lo de antes.
        Vistazo.publicar(recibido)
        WidgetCenter.shared.reloadAllTimelines()
        Task { @MainActor in
            self.vistazo = recibido
            // Lo que ya no viene en el vistazo es que el teléfono lo tachó: la
            // marca local sobra. Y lo que sigue viniendo se queda marcado, que
            // es una orden aún en camino y no una que se perdió.
            let vivas = Set(recibido.filas.map(\.id))
            self.enCamino.formIntersection(vivas)
        }
    }

    /// Pide al teléfono el vistazo de ahora.
    ///
    /// Al abrir la app, y solo si el teléfono está al alcance. Antes el reloj
    /// esperaba sentado a que el teléfono decidiera hablar —y el teléfono habla
    /// cuando abres su app—, así que levantar la muñeca un martes podía enseñar
    /// el lunes. Pedirlo despierta la app del iPhone en segundo plano y la
    /// respuesta llega sola por el camino de siempre.
    ///
    /// Sin cola a propósito: una petición de «dime lo de ahora» guardada para
    /// entregarla más tarde ya no pregunta por ahora. Si no hay teléfono a mano
    /// no se pide y se dice que no se sabe, que es la verdad.
    func pedirVistazo() {
        guard WCSession.isSupported() else { return }
        let sesion = WCSession.default
        guard sesion.activationState == .activated, sesion.isReachable else { return }
        sesion.sendMessage(Orden.refrescar.carga(),
                           replyHandler: nil, errorHandler: { _ in })
    }

    /// Manda tachar una tarea.
    func tachar(_ id: UUID) {
        enCamino.insert(id)
        mandar(.completar(id))
    }

    /// Manda apuntar lo que se ha dictado.
    func apuntar(_ texto: String) {
        activar()
        mandar(.apuntar(texto))
    }

    /// Una orden que **no se puede perder**.
    ///
    /// Dos caminos, y los dos hacen falta. Si el teléfono está al alcance va por
    /// mensaje, que llega en el acto y se ve antes de bajar el brazo. Si no lo
    /// está —y esa es justo la vez que el reloj sirve para algo— va en cola: se
    /// guarda, sobrevive a que se cierre la app y se entrega cuando vuelvan a
    /// verse.
    ///
    /// El mensaje puede fallar aunque el teléfono pareciera alcanzable, porque
    /// entre mirar y mandar pasa un instante. Por eso el fallo no se cuenta a
    /// nadie: se mete en la cola y se acabó. Lo que no puede pasar es que se
    /// pierda en silencio.
    ///
    /// Y si la sesión aún no está activada, espera aquí dentro: la orden dictada
    /// a Siri sale antes de que haya por dónde más veces de las que parece.
    private func mandar(_ orden: Orden) {
        guard WCSession.isSupported() else { return }
        guard WCSession.default.activationState == .activated else {
            porMandar.append(orden)
            return
        }
        let sesion = WCSession.default
        let carga = orden.carga()
        if sesion.isReachable {
            sesion.sendMessage(carga, replyHandler: nil) { _ in
                sesion.transferUserInfo(carga)
            }
        } else {
            sesion.transferUserInfo(carga)
        }
    }

    /// Lo que estuviera esperando a que hubiera sesión.
    private func vaciarCola() {
        let cola = porMandar
        porMandar = []
        for orden in cola { mandar(orden) }
    }

    // MARK: - WCSessionDelegate

    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith state: WCSessionActivationState,
                             error: Error?) {
        leer(session.receivedApplicationContext)
        Task { @MainActor in
            self.vaciarCola()
            self.pedirVistazo()
        }
    }

    nonisolated func session(_ session: WCSession,
                             didReceiveApplicationContext contexto: [String: Any]) {
        leer(contexto)
    }

    /// El vistazo que llega por mensaje, cuando lo hemos pedido nosotros. Mismo
    /// sobre y misma llave: lo que cambia es por dónde entra, y eso no puede
    /// cambiar lo que se hace con él.
    nonisolated func session(_ session: WCSession,
                             didReceiveMessage mensaje: [String: Any]) {
        leer(mensaje)
    }

    /// Cuando el teléfono vuelve a estar cerca. Es el momento en que se puede
    /// preguntar y, si lo que hay guardado es viejo, el momento en que hace más
    /// falta.
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.vaciarCola()
            self.pedirVistazo()
        }
    }
}
