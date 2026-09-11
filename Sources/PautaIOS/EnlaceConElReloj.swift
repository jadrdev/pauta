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

    /// Qué hacer con lo que pide el reloj.
    ///
    /// Lo instala la app, que es quien tiene el almacén: aquí no se guarda
    /// ninguno. Un segundo almacén en el mismo proceso escribiendo los mismos
    /// archivos es exactamente el problema que no se quiere tener.
    var obedecer: ((Orden) -> Void)? {
        didSet { desatascar() }
    }
    /// Las que llegaron antes de que hubiera quien las obedeciera.
    ///
    /// El sistema puede entregar una orden mientras la app aún está montándose
    /// —o despertarla en segundo plano solo para eso—, y ahí todavía no hay
    /// almacén. Sin esta cola, la orden se entregaría a nadie y el sistema no
    /// la repite: la tarea se quedaría sin tachar y nadie sabría por qué.
    private var pendientes: [Orden] = []

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

    /// Lo que pidió el reloj, cuando ya hay quien lo atienda.
    private func desatascar() {
        guard let obedecer else { return }
        let cola = pendientes
        pendientes = []
        for orden in cola { obedecer(orden) }
    }

    private func recibir(_ orden: Orden) {
        guard let obedecer else { pendientes.append(orden); return }
        obedecer(orden)
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

    /// Lo que manda el reloj: hoy, tachar.
    ///
    /// Llega por `transferUserInfo` y no por mensaje, así que puede aparecer
    /// con la app en segundo plano o recién despertada — y puede repetirse si
    /// el sistema reintentó. Por eso la orden dice qué hacer y no «alterna»:
    /// obedecerla dos veces no deshace la primera.
    /// Lo mismo, cuando llega por mensaje en vez de por cola. Dos puertas y una
    /// sola cocina: obedecer una orden no puede depender de por dónde entró.
    nonisolated func session(_ session: WCSession,
                             didReceiveMessage message: [String: Any]) {
        guard let orden = Orden.desde(message) else { return }
        Task { @MainActor in self.recibir(orden) }
    }

    nonisolated func session(_ session: WCSession,
                             didReceiveUserInfo userInfo: [String: Any]) {
        guard let orden = Orden.desde(userInfo) else { return }
        Task { @MainActor in self.recibir(orden) }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
}
