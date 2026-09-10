import SwiftUI
import PautaCore

/// El día, en una muñeca.
///
/// Ni listas largas ni gestos: un titular que se lee de reojo y las tareas que
/// caben. Lo que hace falta a la altura del brazo es el número, no el detalle.
struct HoyWatchView: View {
    let vistazo: Vistazo?
    let esperando: Bool

    var body: some View {
        NavigationStack {
            contenido
                .navigationTitle("Hoy")
        }
    }

    @ViewBuilder private var contenido: some View {
        if let vistazo {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(vistazo.titular)
                            .font(.system(size: 17, weight: .semibold))
                        if let apunte = vistazo.apunte {
                            Text(apunte)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.orange)
                        }
                    }
                }
                if !vistazo.filas.isEmpty {
                    Section {
                        ForEach(vistazo.filas) { fila in
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Circle()
                                    .strokeBorder(fila.atrasada ? .orange : .secondary,
                                                  lineWidth: 1.5)
                                    .frame(width: 8, height: 8)
                                Text(fila.titulo)
                                    .font(.system(size: 14))
                                    .lineLimit(2)
                                Spacer(minLength: 2)
                                if let hora = fila.hora {
                                    Text(hora)
                                        .font(.system(size: 12, weight: .semibold)
                                            .monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                if vistazo.restantes > 0 {
                    Text("+\(vistazo.restantes) más")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            // «No sé nada» y «no hay nada» no se dicen igual: el primero se
            // arregla abriendo la app del teléfono, y el segundo se celebra.
            VStack(spacing: 6) {
                Image(systemName: esperando ? "iphone.badge.exclamationmark" : "sun.max")
                    .font(.system(size: 22))
                    .foregroundStyle(.secondary)
                Text(esperando ? "Abre Pauta en el iPhone" : "Nada para hoy")
                    .font(.system(size: 14))
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
    }
}
