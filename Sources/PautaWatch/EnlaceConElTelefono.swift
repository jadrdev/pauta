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
    /// El último vistazo recibido, si hay alguno.
    private(set) var vistazo: Vistazo?
    /// Si todavía no ha llegado nada: hay que poder distinguir «no hay tareas»
    /// de «no sé nada del teléfono», que en un reloj son mensajes muy
    /// distintos.
    private(set) var esperando = true
    /// Lo que se ha mandado tachar y todavía no ha vuelto confirmado.
    ///
    /// El reloj **no tiene los datos**: quien tacha de verdad es el teléfono, y
    /// la confirmación llega con el vistazo siguiente. Sin esto, la tarea se
    /// quedaría en pantalla sin marcar el segundo o dos que tarda el viaje, y
    /// se pulsaría otra vez pensando que no se enteró.
    private(set) var enCamino: Set<UUID> = []

    func activar() {
        guard WCSession.isSupported() else { esperando = false; return }
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
            self.esperando = false
            // Lo que ya no viene en el vistazo es que el teléfono lo tachó: la
            // marca local sobra. Y lo que sigue viniendo se queda marcado, que
            // es una orden aún en camino y no una que se perdió.
            let vivas = Set(recibido.filas.map(\.id))
            self.enCamino.formIntersection(vivas)
        }
    }

    /// Manda tachar una tarea.
    ///
    /// Dos caminos, y los dos hacen falta. Si el teléfono está al alcance va por
    /// mensaje, que llega en el acto y se ve tachado antes de bajar el brazo. Si
    /// no lo está —y esa es justo la vez que el reloj sirve para algo— va en
    /// cola: se guarda, sobrevive a que se cierre la app y se entrega cuando
    /// vuelvan a verse.
    ///
    /// El mensaje puede fallar aunque el teléfono pareciera alcanzable, porque
    /// entre mirar y mandar pasa un instante. Por eso el fallo no se cuenta a
    /// nadie: se mete en la cola y se acabó. Lo que no puede pasar es que una
    /// orden se pierda en silencio.
    func tachar(_ id: UUID) {
        guard WCSession.isSupported() else { return }
        enCamino.insert(id)
        let sesion = WCSession.default
        let carga = Orden(que: .completar, tarea: id).carga()
        guard sesion.activationState == .activated else {
            sesion.transferUserInfo(carga)
            return
        }
        if sesion.isReachable {
            sesion.sendMessage(carga, replyHandler: nil) { _ in
                sesion.transferUserInfo(carga)
            }
        } else {
            sesion.transferUserInfo(carga)
        }
    }

    // MARK: - WCSessionDelegate

    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith state: WCSessionActivationState,
                             error: Error?) {
        let contexto = session.receivedApplicationContext
        Task { @MainActor in
            // Sin nada recibido y sin error, seguimos esperando al teléfono; con
            // error, ya no hay nada que esperar y se dice lo que hay.
            if self.vistazo == nil { self.esperando = error == nil }
        }
        leer(contexto)
    }

    nonisolated func session(_ session: WCSession,
                             didReceiveApplicationContext contexto: [String: Any]) {
        leer(contexto)
    }
}
