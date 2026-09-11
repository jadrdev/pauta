import SwiftUI
import PautaCore

/// El día, en una muñeca.
///
/// Ni listas largas ni gestos: un titular que se lee de reojo y las tareas que
/// caben. Lo que hace falta a la altura del brazo es el número, no el detalle.
struct HoyWatchView: View {
    let vistazo: Vistazo?
    let esperando: Bool
    /// Las que se han mandado tachar y aún no han vuelto confirmadas.
    var enCamino: Set<UUID> = []
    /// Qué hacer al pulsar el círculo. Vacío en las vistas de solo mirar.
    var tachar: (UUID) -> Void = { _ in }

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
                            FilaDeReloj(fila: fila,
                                        yendo: enCamino.contains(fila.id),
                                        tachar: { tachar(fila.id) })
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

/// Una tarea en la muñeca, con su círculo para tacharla.
///
/// El círculo es un botón aparte y ocupa más de lo que se ve: en un reloj el
/// dedo tapa lo que va a pulsar, y un blanco de ocho puntos se falla. El resto
/// de la fila no hace nada al tocarlo — aquí no hay ficha que abrir, y una
/// pulsación que a veces tacha y a veces no es peor que una que nunca lo hace.
private struct FilaDeReloj: View {
    let fila: Vistazo.Fila
    /// La orden está en camino: el teléfono aún no ha confirmado.
    let yendo: Bool
    let tachar: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Button(action: tachar) {
                ZStack {
                    Circle()
                        .strokeBorder(color, lineWidth: 1.5)
                        .frame(width: 14, height: 14)
                    if yendo {
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .black))
                            .foregroundStyle(color)
                    }
                }
                // El blanco de verdad, más grande que el dibujo.
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(yendo)

            Text(fila.titulo)
                .font(.system(size: 14))
                .lineLimit(2)
                // Tachada en cuanto se pulsa, aunque la confirmación tarde: el
                // reloj no es quien tacha, pero quien lo mira necesita ver que
                // se enteró.
                .strikethrough(yendo)
                .foregroundStyle(yendo ? .secondary : .primary)
            Spacer(minLength: 2)
            if let hora = fila.hora {
                Text(hora)
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var color: Color {
        if yendo { return .secondary }
        return fila.atrasada ? .orange : .secondary
    }
}
