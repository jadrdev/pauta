import AppIntents
import WidgetKit
import PautaCore

/// Tachar una tarea desde el widget, sin abrir la app.
///
/// Es lo único que el widget puede hacer que merezca romper su regla de solo
/// leer: mirar la lista y no poder tachar lo que acabas de hacer es la mitad del
/// gesto. Todo lo demás —cambiar el día, la hora, el proyecto— pide una pantalla
/// y para eso está la app a un toque.
///
/// **No reimplementa completar.** Abre el almacén de verdad y llama a
/// `toggleComplete`, que es lo que sabe que una repetitiva pare la siguiente,
/// que descompletar retire a la sucesora si nadie la tocó, y que el aplazamiento
/// se borre. Tocar `isCompleted` a mano desde aquí cortaría una serie diaria
/// desde la pantalla de inicio sin que nadie se enterara hasta echar de menos la
/// tarea de mañana.
///
/// Y no borra. Eliminar es de las que no se vuelve, y este es un sitio donde se
/// pulsa sin mirar.
struct CompletarTarea: AppIntent {
    static var title: LocalizedStringResource = "Completar tarea"

    /// No abre la app: el sentido de esto es no salir de donde estás.
    static var openAppWhenRun = false
    /// Y no sale en Atajos: es un botón de este widget, no una acción con la que
    /// nadie querría montar un atajo —lleva un identificador crudo dentro—.
    static var isDiscoverable = false

    @Parameter(title: "Tarea")
    var tarea: String

    init() {}

    init(_ id: UUID) {
        self.tarea = id.uuidString
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: tarea) else { return .result() }
        let store = Store()
        guard let item = store.items.first(where: { $0.id == id }) else { return .result() }
        store.toggleComplete(item)
        // El sistema recarga el widget al terminar un intent, pero la app puede
        // tener otro widget puesto —pequeño y mediano a la vez— y ese también
        // tiene que enterarse.
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
