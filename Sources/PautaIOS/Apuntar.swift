import AppIntents
import WidgetKit
import PautaCore

/// Apuntar algo en la bandeja sin abrir la app.
///
/// Es lo que faltaba para que Pauta se pueda usar con la voz por su cuenta.
/// Hasta ahora lo que le dictabas a Siri entraba por la lista de Recordatorios:
/// funcionaba, pero obligaba a un permiso, a una lista intermedia y a marcar
/// como completado un recordatorio que nunca fue tuyo. Esto entra derecho.
///
/// Vive en la app y no en el widget a propósito. El intent del widget es un
/// botón de ese widget —lleva un identificador crudo dentro y no sale en
/// Atajos—; este es una acción de la app, y tiene que aparecer en Atajos, en la
/// pantalla bloqueada y en el botón de acción.
///
/// **No reimplementa apuntar.** Usa `addItems(from:)`, que es lo que ya sabe
/// partir varias líneas, quitar viñetas y descartar lo que queda en blanco. Un
/// dictado es una línea, pero un atajo puede traer un texto entero, y ahí hacer
/// una tarea con tres renglones dentro sería peor que hacer tres.
struct ApuntarEnPauta: AppIntent {
    static var title: LocalizedStringResource = "Apuntar en la bandeja"
    static var description = IntentDescription(
        "Mete lo que le digas en la bandeja de Pauta. No abre la app.")

    /// Sin abrir la app: apuntar algo es lo que haces **mientras** estás en otra
    /// cosa. Si te sacara de donde estás, no serviría para eso.
    static var openAppWhenRun = false

    @Parameter(title: "Qué", requestValueDialog: "¿Qué apunto?")
    var texto: String

    init() {}

    init(texto: String) { self.texto = texto }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = Store()
        let nuevas = store.addItems(from: texto, in: .inbox)
        // Un dictado que no dice nada no crea una tarea en blanco, y se dice en
        // voz alta: devolver «hecho» sin haber hecho nada es la forma más rápida
        // de que dejes de fiarte de esto.
        guard !nuevas.isEmpty else { throw FalloAlApuntar.nadaQueApuntar }
        WidgetCenter.shared.reloadAllTimelines()
        // Y si la app está delante, que se entere ya. Sin esto, dictar con Pauta
        // abierta no cambiaría nada en pantalla hasta salir y volver, que es
        // justo cuando parece que se perdió.
        NotificationCenter.default.post(name: .pautaApuntadoDesdeFuera, object: nil)
        return .result(dialog: nuevas.count == 1
                       ? "Apuntado: \(nuevas[0].title)"
                       : "Apuntadas \(nuevas.count) en la bandeja")
    }
}

extension Notification.Name {
    /// Algo entró en la bandeja desde fuera de la interfaz. La app la escucha
    /// para recargar; si no hay nadie escuchando —el intent corriendo con la app
    /// dormida— no pasa nada, porque al abrirla se lee todo de la carpeta.
    static let pautaApuntadoDesdeFuera = Notification.Name("pauta.apuntado.desde.fuera")
}

enum FalloAlApuntar: Error, CustomLocalizedStringResourceConvertible {
    case nadaQueApuntar

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .nadaQueApuntar: "No he entendido qué apuntar."
        }
    }
}

/// La frase con la que se le pide a Siri, y el sitio que ocupa en Atajos.
///
/// Varias formas de decir lo mismo porque nadie recuerda la exacta: si solo
/// valiera una, el atajo existiría para quien leyó la documentación.
struct AtajosDePauta: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ApuntarEnPauta(),
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
