import WidgetKit
import SwiftUI
import PautaCore

/// Lo que se ve.
///
/// Comparte con la app el tema —`Theme.swift` es de la app y del widget— porque
/// un widget que no se parece a su app parece de otra app. Lo que no comparte
/// es la vista del teléfono: allí el tema se resuelve con UIKit y aquí con
/// AppKit, y las dos interfaces no comparten ni una vista a propósito.
struct HoyViewMac: View {
    /// `nil` cuando no hay instantánea o cuando la que hay no es de hoy.
    let vistazo: Vistazo?
    @Environment(\.widgetFamily) private var familia

    private var pequeno: Bool { familia == .systemSmall }

    var body: some View {
        Group {
            if let vistazo {
                tarjeta(vistazo)
            } else {
                sinSaber
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(Paper.bg, for: .widget)
        .widgetURL(Enlaces.url(vistazo?.vacio == false ? .hoy : .apuntar))
    }

    private func tarjeta(_ v: Vistazo) -> some View {
        VStack(alignment: .leading, spacing: pequeno ? 7 : 8) {
            encabezado(v)
            if v.vacio {
                Spacer(minLength: 0)
                invitacion
                Spacer(minLength: 0)
            } else {
                VStack(alignment: .leading, spacing: pequeno ? 5 : 6) {
                    ForEach(v.filas) { fila in
                        FilaDelVistazoMac(fila: fila, pequeno: pequeno)
                    }
                }
                Spacer(minLength: 0)
                pie(v)
            }
        }
    }

    /// En el mediano y el grande caben en una línea; en el pequeño no —puestas
    /// en fila, «1 para hoy» partía en dos y se comía la primera tarea—.
    @ViewBuilder private func encabezado(_ v: Vistazo) -> some View {
        let titular = Text(v.titular)
            .font(.system(size: pequeno ? 15 : 16, weight: .semibold))
            .foregroundStyle(Paper.ink)
            .lineLimit(1)
        let apunte = v.apunte.map {
            Text($0)
                .font(.system(size: pequeno ? 10.5 : 11.5, weight: .semibold))
                .foregroundStyle(Paper.warning)
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

    private var invitacion: some View {
        HStack(spacing: 7) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: pequeno ? 16 : 18))
                .foregroundStyle(Paper.accentInk)
            Text("Apuntar algo")
                .font(.system(size: pequeno ? 13 : 14, weight: .medium))
                .foregroundStyle(Paper.inkSoft)
        }
    }

    @ViewBuilder private func pie(_ v: Vistazo) -> some View {
        let sobran = v.restantes > 0 ? "+\(v.restantes) más" : nil
        let bandeja = v.bandeja > 0
            ? (v.bandeja == 1 ? "1 en la bandeja" : "\(v.bandeja) en la bandeja")
            : nil
        if sobran != nil || bandeja != nil {
            HStack(spacing: 6) {
                if let sobran { Text(sobran).rubricStyle() }
                if sobran != nil && bandeja != nil { Text("·").rubricStyle(Paper.hairline) }
                if let bandeja { Text(bandeja).rubricStyle().lineLimit(1) }
            }
        }
    }

    /// Sin instantánea, o con una de otro día.
    ///
    /// No dice «no hay tareas», que sería mentira, ni enseña las de ayer, que
    /// sería peor: dice que hace falta abrir la app, que es exactamente lo que
    /// pasa. Un toque en el widget la abre.
    private var sinSaber: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Pauta")
                .font(.system(size: pequeno ? 15 : 16, weight: .semibold))
                .foregroundStyle(Paper.ink)
            Text("Abre Pauta para ver el día")
                .font(.system(size: pequeno ? 12 : 13))
                .foregroundStyle(Paper.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Una tarea, del ancho del widget.
private struct FilaDelVistazoMac: View {
    let fila: Vistazo.Fila
    let pequeno: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            // El círculo de la app sin ser un botón: desde aquí no se completa
            // nada —el widget no escribe en tus datos—, y uno que pareciera
            // pulsable sin serlo sería peor que no ponerlo. Se queda porque es
            // lo que hace que una lista se lea como una lista de tareas.
            Circle()
                .strokeBorder(fila.atrasada ? Paper.warning : Paper.inkFaint, lineWidth: 1.6)
                // La proporción de la fila de la app: círculo 1,27× el título.
                .frame(width: pequeno ? 16 : 17, height: pequeno ? 16 : 17)
                .offset(y: pequeno ? 2 : 2.5)
            Text(fila.titulo.isEmpty ? "Sin título" : fila.titulo)
                .font(.system(size: pequeno ? 12.5 : 13.5))
                .foregroundStyle(Paper.ink)
                .lineLimit(1)
            Spacer(minLength: 4)
            if let hora = fila.hora {
                Text(hora)
                    .font(.system(size: pequeno ? 11 : 12, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Paper.inkSoft)
            }
        }
    }
}
