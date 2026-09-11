import WidgetKit
import SwiftUI
import PautaCore

/// El widget de Pauta en el Mac.
///
/// Vive en el centro de notificaciones y en el escritorio, y hace lo mismo que
/// el del teléfono: enseñar el día sin abrir la app. Lo que cambia es de dónde
/// lo saca.
///
/// En el teléfono el widget lee **el almacén**, porque los datos viven en la
/// carpeta del grupo que la app y la extensión comparten. Aquí no puede: los
/// datos están en iCloud Drive, y una extensión de widget en macOS va en
/// sandbox —no se carga de otra manera—, así que por ruta no entra. Lo que lee
/// es la **instantánea** que la app le deja escrita en la carpeta del grupo.
///
/// El precio de esa copia es que envejece: con la app cerrada, lo que hay
/// escrito habla del día en que se escribió. Por eso el vistazo lleva su día
/// dentro y aquí se comprueba antes de dibujar. Un widget que enseñe la lista
/// de ayer como si fuera la de hoy hace más daño que uno que diga que no sabe.
@main
struct PautaWidgetsMac: WidgetBundle {
    var body: some Widget { HoyWidgetMac() }
}

struct MomentoMac: TimelineEntry {
    let date: Date
    /// El vistazo, solo si sirve para **hoy**.
    let vistazo: Vistazo?
}

struct ProveedorMac: TimelineProvider {
    static func caben(_ familia: WidgetFamily) -> Int {
        switch familia {
        case .systemSmall: 3
        case .systemMedium: 4
        case .systemLarge: 9
        default: 1
        }
    }

    func placeholder(in context: Context) -> MomentoMac {
        MomentoMac(date: .now,
                   vistazo: Vistazo.de([], limite: ProveedorMac.caben(context.family)))
    }

    func getSnapshot(in context: Context, completion: @escaping (MomentoMac) -> Void) {
        completion(leer(context))
    }

    /// Una entrada y la siguiente al filo de la medianoche, como en el teléfono:
    /// lo que se enseña no cambia con las horas, cambia cuando cambian las
    /// tareas —y de eso avisa la app— o cuando cambia el día.
    func getTimeline(in context: Context, completion: @escaping (Timeline<MomentoMac>) -> Void) {
        let ahora = Date.now
        let manana = Calendar.current.nextDate(
            after: ahora, matching: DateComponents(hour: 0, minute: 0),
            matchingPolicy: .nextTime) ?? ahora.addingTimeInterval(3600)
        completion(Timeline(entries: [leer(context)], policy: .after(manana)))
    }

    /// Lee la instantánea y **la descarta si no es de hoy**. La regla vive en el
    /// núcleo porque la esfera del reloj hace exactamente lo mismo.
    private func leer(_ context: Context) -> MomentoMac {
        guard let guardado = Vistazo.deHoy(Vistazo.instantanea())
        else { return MomentoMac(date: .now, vistazo: nil) }
        return MomentoMac(date: .now,
                          vistazo: guardado.recortado(a: ProveedorMac.caben(context.family)))
    }
}

struct HoyWidgetMac: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "hoy", provider: ProveedorMac()) { momento in
            HoyViewMac(vistazo: momento.vistazo)
        }
        .configurationDisplayName("Hoy")
        .description("Lo que toca hoy y lo que se arrastra de días pasados.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
