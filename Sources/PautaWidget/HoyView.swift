import WidgetKit
import SwiftUI
import PautaCore

/// Lo que se ve.
///
/// Comparte con la app la paleta y las versalitas —`Tema.swift` es del teléfono
/// y del widget— porque un widget que no se parece a su app parece de otra app.
/// Lo que no comparte son las filas: aquí no se puede tocar nada, no hay
/// gestos, y cada punto cuenta.
struct HoyView: View {
    let vistazo: Vistazo
    @Environment(\.widgetFamily) private var familia

    var body: some View {
        switch familia {
        case .accessoryRectangular:
            Accesorio(vistazo: vistazo)
        default:
            Tarjeta(vistazo: vistazo, familia: familia)
        }
    }
}

/// El widget de la pantalla de inicio.
private struct Tarjeta: View {
    let vistazo: Vistazo
    let familia: WidgetFamily

    private var pequeno: Bool { familia == .systemSmall }

    var body: some View {
        VStack(alignment: .leading, spacing: pequeno ? 7 : 8) {
            encabezado
            if vistazo.vacio {
                Spacer(minLength: 0)
                invitacion
                Spacer(minLength: 0)
            } else {
                VStack(alignment: .leading, spacing: pequeno ? 5 : 6) {
                    ForEach(vistazo.filas) { fila in
                        // En el tamaño pequeño el sistema ignora los enlaces de
                        // dentro y solo respeta el del widget entero, así que
                        // ahí no se envuelve: un enlace que no lleva a ninguna
                        // parte engaña al dedo.
                        if pequeno {
                            FilaDelVistazo(fila: fila, pequeno: true)
                        } else {
                            Link(destination: Enlaces.url(.tarea(fila.id))) {
                                FilaDelVistazo(fila: fila, pequeno: false)
                            }
                        }
                    }
                }
                Spacer(minLength: 0)
                pie
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(Papel.bg, for: .widget)
        // El widget entero abre Hoy. Es el destino honesto: es lo que estás
        // mirando.
        .widgetURL(Enlaces.url(vistazo.vacio ? .apuntar : .hoy))
    }

    /// En el tamaño mediano las dos cosas caben en una línea, el titular a la
    /// izquierda y el retraso a la derecha. En el pequeño **no caben**: puestas
    /// en fila, «1 para hoy» partía en dos líneas y se comía la primera tarea.
    @ViewBuilder private var encabezado: some View {
        let titular = Text(vistazo.titular)
            .font(.system(size: pequeno ? 15 : 16, weight: .semibold))
            .foregroundStyle(Papel.ink)
            .lineLimit(1)
        let apunte = vistazo.apunte.map {
            Text($0)
                .font(.system(size: pequeno ? 10.5 : 11.5, weight: .semibold))
                .foregroundStyle(Papel.warning)
                .lineLimit(1)
        }
        if pequeno {
            VStack(alignment: .leading, spacing: 1) {
                titular
                apunte
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                titular
                Spacer(minLength: 0)
                apunte
            }
        }
    }

    /// Con el día vacío, lo único útil que se puede hacer desde un widget es
    /// apuntar lo próximo. Así que el widget vacío **es** ese botón.
    private var invitacion: some View {
        HStack(spacing: 7) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: pequeno ? 16 : 18))
                .foregroundStyle(Papel.accentInk)
            Text("Apuntar algo")
                .font(.system(size: pequeno ? 13 : 14, weight: .medium))
                .foregroundStyle(Papel.inkSoft)
        }
    }

    @ViewBuilder private var pie: some View {
        let sobran = vistazo.restantes > 0 ? "+\(vistazo.restantes) más" : nil
        let bandeja = vistazo.bandeja > 0
            ? (vistazo.bandeja == 1 ? "1 en la bandeja" : "\(vistazo.bandeja) en la bandeja")
            : nil
        // Las dos cosas caben en una línea; si solo hay una, ocupa ella el pie.
        if sobran != nil || bandeja != nil {
            HStack(spacing: 6) {
                if let sobran {
                    Text(sobran).rubrica(Papel.inkFaint)
                }
                if sobran != nil && bandeja != nil {
                    Text("·").rubrica(Papel.hairline)
                }
                if let bandeja {
                    if pequeno {
                        Text(bandeja).rubrica(Papel.inkFaint).lineLimit(1)
                    } else {
                        Link(destination: Enlaces.url(.bandeja)) {
                            Text(bandeja).rubrica(Papel.inkFaint)
                        }
                    }
                }
            }
        }
    }
}

/// Una tarea, del ancho del widget.
private struct FilaDelVistazo: View {
    let fila: Vistazo.Fila
    let pequeno: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            // El círculo **es** un botón: tacha la tarea sin abrir la app. Era
            // lo único que faltaba para que mirar la lista y hacer algo con ella
            // fueran el mismo gesto.
            //
            // El área de toque, que es donde esto se hizo mal la primera vez:
            // el círculo mide nueve puntos y el botón se cerró a once, o sea dos
            // milímetros. Con un toque por coordenadas en el simulador acertaba
            // siempre; con un dedo, casi nunca — y desde fuera eso se ve como
            // «el widget no hace nada».
            //
            // Ahora el área es de 24×18 y el círculo va pegado a la izquierda
            // dentro de ella, así que lo que crece es el hueco **a la derecha**,
            // hacia el título. Los 18 de alto son los de la fila: más alto
            // solaparía con la fila de arriba, y completar la tarea equivocada
            // es peor que fallar el toque. El ancho vuelve a la fila con un
            // margen negativo —el mismo truco que la casilla de la app—, así que
            // el dibujo no se mueve y el toque sí crece.
            Button(intent: CompletarTarea(fila.id)) {
                Circle()
                    .strokeBorder(fila.atrasada ? Papel.warning : Papel.inkFaint,
                                  lineWidth: 1.6)
                    // La proporción de la fila de la app y no un número a ojo:
                    // allí el círculo mide 21 con un título de 16,5, o sea
                    // 1,27×. Con títulos de 12,5 y 13,5 salen 16 y 17.
                    .frame(width: pequeno ? 16 : 17, height: pequeno ? 16 : 17)
                    // El alto del área es el de la fila: 20 y no más, porque
                    // solapar con la fila de arriba significa tachar la tarea
                    // equivocada.
                    .frame(width: 30, height: 20, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, -15)
            // Bajado y medido en la captura: con la fila alineada por la primera
            // línea base, el círculo queda por encima del centro del texto.
            .offset(y: pequeno ? 2 : 2.5)
            Text(fila.titulo.isEmpty ? "Sin título" : fila.titulo)
                .font(.system(size: pequeno ? 12.5 : 13.5))
                .foregroundStyle(Papel.ink)
                .lineLimit(1)
            Spacer(minLength: 4)
            if let hora = fila.hora {
                Text(hora)
                    .font(.system(size: pequeno ? 11 : 12, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Papel.inkSoft)
            }
        }
    }
}

/// La pantalla de bloqueo: dos líneas, en un solo color y sin fondo. Ahí no se
/// pinta, se cuenta.
private struct Accesorio: View {
    let vistazo: Vistazo

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(vistazo.titular)
                .font(.headline)
                .widgetAccentable()
            if let apunte = vistazo.apunte {
                Text(apunte).font(.caption)
            } else if let primera = vistazo.filas.first {
                Text(primera.titulo).font(.caption).lineLimit(1)
            } else if vistazo.bandeja > 0 {
                Text("\(vistazo.bandeja) en la bandeja").font(.caption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(.clear, for: .widget)
        .widgetURL(Enlaces.url(.hoy))
    }
}
