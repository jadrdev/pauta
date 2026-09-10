import Foundation
import Observation
import WatchConnectivity
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
        Task { @MainActor in
            self.vistazo = recibido
            self.esperando = false
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
