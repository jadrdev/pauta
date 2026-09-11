import WidgetKit
import SwiftUI
import PautaCore

/// Pauta en la esfera.
///
/// Lo que una muñeca hace mejor que un teléfono es decirte lo que hay **sin que
/// lo pidas**, y una complicación es el único sitio donde eso pasa de verdad:
/// se ve al levantar el brazo, sin abrir nada. La app del reloj ya enseñaba el
/// día, pero había que ir a buscarla.
///
/// De dónde salen los datos: igual que en el Mac, de una copia. El reloj no
/// tiene almacén —recibe del teléfono el mismo `Vistazo` que dibuja el widget—
/// y una extensión es otro proceso que no comparte memoria con la app, así que
/// la app del reloj deja el vistazo escrito en la carpeta del grupo y esto lo
/// lee.
///
/// El precio, dicho sin adornos: la copia envejece. Se actualiza cuando la app
/// del reloj recibe algo del teléfono, y eso pasa al abrirla y cuando el
/// sistema la despierta para entregarle el contexto. Si lo guardado no es de
/// hoy, aquí se dice que no se sabe en vez de enseñar la cuenta de ayer.
@main
struct PautaWatchWidgets: WidgetBundle {
    var body: some Widget { HoyEnLaEsfera() }
}

struct MomentoEnLaEsfera: TimelineEntry {
    let date: Date
    /// El vistazo, solo si sirve para **hoy**.
    let vistazo: Vistazo?
}

struct ProveedorDeEsfera: TimelineProvider {
    func placeholder(in context: Context) -> MomentoEnLaEsfera {
        MomentoEnLaEsfera(date: .now, vistazo: Vistazo.de([], limite: 2))
    }

    func getSnapshot(in context: Context,
                     completion: @escaping (MomentoEnLaEsfera) -> Void) {
        completion(leer())
    }

    /// Una entrada, y la siguiente al filo de la medianoche. Lo que se enseña
    /// no cambia con las horas: cambia cuando cambian las tareas —y de eso
    /// avisa la app del reloj al recibirlas— o cuando cambia el día.
    func getTimeline(in context: Context,
                     completion: @escaping (Timeline<MomentoEnLaEsfera>) -> Void) {
        let ahora = Date.now
        let manana = Calendar.current.nextDate(
            after: ahora, matching: DateComponents(hour: 0, minute: 0),
            matchingPolicy: .nextTime) ?? ahora.addingTimeInterval(3600)
        completion(Timeline(entries: [leer()], policy: .after(manana)))
    }

    private func leer() -> MomentoEnLaEsfera {
        MomentoEnLaEsfera(date: .now, vistazo: Vistazo.deHoy(Vistazo.instantanea()))
    }
}

struct HoyEnLaEsfera: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "hoy", provider: ProveedorDeEsfera()) { momento in
            EsferaView(vistazo: momento.vistazo)
        }
        .configurationDisplayName("Hoy")
        .description("Cuántas tareas quedan hoy, sin abrir nada.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner,
                            .accessoryInline, .accessoryRectangular])
    }
}
