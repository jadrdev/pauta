import WidgetKit
import SwiftUI
import PautaCore

/// Lo que se dibuja en cada sitio de la esfera.
///
/// Cuatro formas del mismo dato y no cuatro complicaciones: lo que cambia es
/// cuánto espacio hay, no qué se cuenta. En el círculo cabe un número; al lado
/// de la hora, un renglón; en el rectángulo, el renglón y lo primero que toca.
///
/// Sin color propio: en una esfera manda el color que haya elegido quien la
/// lleva, y una complicación que se pinta a su gusto se ve como un parche. Lo
/// único que se permite es marcar lo atrasado, que es el dato que cambia lo que
/// haces con el día.
///
/// Cada forma es una vista aparte y no una rama dentro de esta: así se pueden
/// mirar de una en una sin montar una esfera entera, que es la única manera de
/// comprobar una complicación sin un reloj delante.
struct EsferaView: View {
    let vistazo: Vistazo?
    @Environment(\.widgetFamily) private var familia

    var body: some View {
        switch familia {
        case .accessoryInline:
            // Una sola línea y sin fondo: es texto al lado de la hora.
            Text(vistazo?.renglon ?? "Pauta · sin datos")
        case .accessoryCorner:
            Text(EsferaTextos.cifra(vistazo))
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .widgetLabel(vistazo?.renglon ?? "Sin datos")
        case .accessoryRectangular:
            RectanguloDeEsfera(vistazo: vistazo)
        default:
            CirculoDeEsfera(vistazo: vistazo)
        }
    }
}

enum EsferaTextos {
    /// «—» cuando no se sabe. Un hueco en blanco en una esfera no se lee como
    /// «no hay nada», se lee como que algo se rompió.
    static func cifra(_ vistazo: Vistazo?) -> String { vistazo?.cifra ?? "—" }
}

struct CirculoDeEsfera: View {
    let vistazo: Vistazo?

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: -2) {
                Text(EsferaTextos.cifra(vistazo))
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .minimumScaleFactor(0.6)
                Text("hoy")
                    .font(.system(size: 9, weight: .medium))
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
            }
        }
        // El borde solo aparece cuando hay algo arrastrándose: si se viera
        // siempre, dejaría de decir nada.
        .overlay {
            if let vistazo, vistazo.atrasadas > 0 {
                Circle().strokeBorder(.orange, lineWidth: 2)
            }
        }
    }
}

struct RectanguloDeEsfera: View {
    let vistazo: Vistazo?

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            if let vistazo {
                Text(vistazo.titular)
                    .font(.system(size: 15, weight: .semibold))
                if let apunte = vistazo.apunte {
                    Text(apunte)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.orange)
                }
                // Lo primero que toca, si queda sitio. Una sola: dos títulos
                // recortados a la mitad no se leen de reojo, que es la única
                // forma en que se mira esto.
                if let primera = vistazo.filas.first {
                    Text(primera.hora.map { "\($0)  \(primera.titulo)" } ?? primera.titulo)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            } else {
                Text("Pauta").font(.system(size: 15, weight: .semibold))
                Text("Abre Pauta en el reloj")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
