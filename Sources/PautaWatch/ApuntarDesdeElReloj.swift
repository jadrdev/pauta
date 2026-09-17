import AppIntents
import PautaCore

/// Apuntar desde la muñeca, dictándoselo a Siri.
///
/// Es lo último que faltaba para que el reloj se valga solo, y lo que quita a
/// Recordatorios su última razón de existir: hasta ahora, dictar una tarea desde
/// aquí pasaba por la lista de Recordatorios, con su permiso y su lista
/// intermedia. Esto entra derecho.
///
/// El teléfono tiene un intent igual, pero **los App Intents no cruzan de un
/// aparato al otro**: los del iPhone no se ofrecen en la muñeca. Por eso hay
/// dos, y por eso este no puede simplemente llamar al del teléfono.
///
/// Lo que sí comparte es el camino: el reloj **no tiene los datos**, así que no
/// apunta — lo pide, por la misma tubería que usa para tachar. Si el teléfono
/// está cerca llega en el acto; si no, la orden se guarda y se entrega cuando
/// vuelvan a verse, que es justo cuando esto sirve: apuntar algo caminando, con
/// el teléfono en otra habitación.
struct ApuntarEnPautaDesdeElReloj: AppIntent {
    static var title: LocalizedStringResource = "Apuntar en la bandeja"
    static var description = IntentDescription(
        "Manda al iPhone lo que le digas, y entra en la bandeja de Pauta.")

    /// Sin abrir la app: apuntar algo en el reloj es lo que haces sin parar lo
    /// que estabas haciendo. Si además hubiera que mirar una pantalla, valdría
    /// más sacar el teléfono.
    static var openAppWhenRun = false

    @Parameter(title: "Qué", requestValueDialog: "¿Qué apunto?")
    var texto: String

    init() {}

    init(texto: String) { self.texto = texto }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Lo vacío no se manda. En un reloj el dictado falla más que en un
        // teléfono —ruido, viento, la muñeca lejos de la boca— y mandar una
        // cadena en blanco crearía una tarea sin título que luego hay que ir a
        // borrar desde otro sitio.
        guard !texto.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw FalloAlApuntarEnElReloj.nadaQueApuntar
        }
        EnlaceConElTelefono.shared.apuntar(texto)
        // «Mandado» y no «apuntado», que es la verdad: quien apunta es el
        // teléfono y esto solo lo ha pedido. Decir «hecho» cuando aún puede
        // estar en la cola es la clase de mentira pequeña que hace que dejes de
        // fiarte de dictar.
        return .result(dialog: "Mandado al iPhone")
    }
}

enum FalloAlApuntarEnElReloj: Error, CustomLocalizedStringResourceConvertible {
    case nadaQueApuntar

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .nadaQueApuntar: "No he entendido qué apuntar."
        }
    }
}

/// Las frases con las que se le pide a Siri desde la muñeca.
///
/// Las mismas que en el teléfono a propósito: la frase que te sabes es la que te
/// sabes, y que cambie según el aparato que lleves encima es garantía de que no
/// funcione justo cuando la necesitas.
struct AtajosDePautaEnElReloj: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ApuntarEnPautaDesdeElReloj(),
            phrases: [
                "Apuntar en \(.applicationName)",
                "Apunta en \(.applicationName)",
                "Añadir a \(.applicationName)",
                "Nueva tarea en \(.applicationName)",
            ],
            shortTitle: "Apuntar",
            systemImageName: "tray.and.arrow.down")
    }
}
