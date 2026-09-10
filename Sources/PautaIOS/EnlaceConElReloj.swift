import Foundation
import WatchConnectivity
import PautaCore

/// Lo que el teléfono le cuenta al reloj.
///
/// Se manda el **contexto de aplicación** y no mensajes: el contexto es «lo
/// último que se sabe», el sistema lo guarda y el reloj lo tiene al levantar la
/// muñeca aunque el teléfono esté en otra habitación. Un mensaje exige a los dos
/// despiertos a la vez, que es justo lo que no pasa entonces.
///
/// Y lo que se manda es el **vistazo**, no las tareas: lo que cabe en un golpe
/// de vista, ya calculado y ya ordenado por el núcleo. El reloj no tiene datos
/// que perder ni que reconciliar.
@MainActor
final class EnlaceConElReloj: NSObject, WCSessionDelegate {
    static let shared = EnlaceConElReloj()

    private var activada = false
    /// El último vistazo, guardado para poder **reintentarlo**.
    ///
    /// Activar la sesión tarda, y el primer vistazo sale un segundo después de
    /// abrir la app: sin esto, se pedía enviarlo antes de que hubiera por dónde
    /// y se perdía en silencio — el reloj se quedaba diciendo «abre Pauta en el
    /// iPhone» para siempre. Visto en el simulador.
    private var ultimo: Vistazo?

    func activar() {
        guard WCSession.isSupported(), !activada else { return }
        activada = true
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Deja escrito el último vistazo, o lo guarda para cuando haya sesión.
    func publicar(_ vistazo: Vistazo) {
        ultimo = vistazo
        enviar()
    }

    private func enviar() {
        guard WCSession.isSupported(), let vistazo = ultimo else { return }
        let sesion = WCSession.default
        // Todavía sin activar: se reintenta al activarse, que es cuando el
        // sistema avisa.
        guard sesion.activationState == .activated else { return }
        guard let datos = vistazo.datos() else { return }
        // El contexto reemplaza al anterior, así que no hay cola que se acumule
        // ni orden que respetar: siempre es lo último. Sin reloj emparejado
        // lanza, y eso aquí no es un problema: no había a quién contárselo.
        try? sesion.updateApplicationContext([Vistazo.clave: datos])
    }

    // MARK: - WCSessionDelegate
    //
    // Los tres son obligatorios en iOS aunque aquí no haya nada que hacer: al
    // cambiar de reloj el sistema desactiva la sesión y hay que volver a
    // activarla, o el siguiente vistazo no sale del teléfono.

    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith state: WCSessionActivationState,
                             error: Error?) {
        // Ya hay por dónde: se manda lo que estuviera esperando.
        Task { @MainActor in self.enviar() }
    }

    /// Y otra vez cuando el estado del reloj cambia.
    ///
    /// Esto es lo que faltaba y costó encontrar. La sesión se activa **antes**
    /// de saber que la app del reloj está instalada: el registro del sistema
    /// enseña `appInstalled: NO` al activarse y `appInstalled: YES` dos segundos
    /// después. El primer vistazo salía justo en medio y se perdía con
    /// `WCErrorCodeWatchAppNotInstalled`, y el reloj se quedaba diciendo «abre
    /// Pauta en el iPhone» para siempre.
    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in self.enviar() }
    }

    /// Cuando el reloj vuelve a estar cerca, también: puede haberse perdido un
    /// vistazo mientras no lo estaba.
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in self.enviar() }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
}
