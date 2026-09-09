import WidgetKit
import SwiftUI
import PautaCore

/// El widget de Pauta.
///
/// Un widget es la única parte de la app que se ve **sin abrirla**, y por eso
/// existe: apuntar algo sirve de poco si para acordarte de lo apuntado hay que
/// acordarse de abrir la app. Aquí lo del día está delante sin pedirlo.
///
/// Es otro proceso: no comparte memoria con la app, no puede preguntarle nada y
/// no escribe en sus datos. Solo lee la carpeta del grupo y dibuja.
@main
struct PautaWidgets: WidgetBundle {
    var body: some Widget { HoyWidget() }
}

/// Un momento del día, ya resuelto: el widget se dibuja cuando el sistema
/// quiere, no cuando pasa algo, así que cada entrada lleva dentro todo lo que
/// hay que enseñar.
struct Momento: TimelineEntry {
    let date: Date
    let vistazo: Vistazo
}

struct Proveedor: TimelineProvider {
    /// Cuántas tareas caben, por tamaño. Se recorta a lo que **cabe** y no a lo
    /// que hay: una fila cortada por la mitad no se lee, y el resto se dice con
    /// un «+3 más».
    static func caben(_ familia: WidgetFamily) -> Int {
        switch familia {
        case .systemSmall: 3
        case .systemMedium: 4
        case .systemLarge: 9
        default: 1
        }
    }

    /// El hueco mientras el sistema prepara el widget. Sin leer disco: esto se
    /// dibuja en la galería y al colocarlo, y ahí no hay nada que contar.
    func placeholder(in context: Context) -> Momento {
        Momento(date: .now, vistazo: Vistazo.de([], limite: Proveedor.caben(context.family)))
    }

    func getSnapshot(in context: Context, completion: @escaping (Momento) -> Void) {
        completion(Momento(date: .now, vistazo: leer(context)))
    }

    /// Una sola entrada, y la siguiente al filo de la medianoche.
    ///
    /// No hay más entradas que calcular: lo que se enseña no cambia con el
    /// paso de las horas, cambia cuando **cambian las tareas** —y de eso avisa
    /// la app en cuanto toca algo—. Lo que sí cambia solo es el día: a las doce
    /// lo de hoy pasa a ser atrasado. Un widget que se recargara cada hora
    /// gastaría el presupuesto de recargas del sistema para dibujar lo mismo.
    func getTimeline(in context: Context, completion: @escaping (Timeline<Momento>) -> Void) {
        let ahora = Date.now
        let manana = Calendar.current.nextDate(
            after: ahora, matching: DateComponents(hour: 0, minute: 0),
            matchingPolicy: .nextTime) ?? ahora.addingTimeInterval(3600)
        completion(Timeline(entries: [Momento(date: ahora, vistazo: leer(context))],
                            policy: .after(manana)))
    }

    private func leer(_ context: Context) -> Vistazo {
        Vistazo.leer(en: Store.defaultRoot, limite: Proveedor.caben(context.family))
    }
}

struct HoyWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "hoy", provider: Proveedor()) { momento in
            HoyView(vistazo: momento.vistazo)
        }
        .configurationDisplayName("Hoy")
        .description("Lo que toca hoy y lo que se arrastra de días pasados.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular])
    }
}
