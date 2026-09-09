import SwiftUI
import PautaCore

/// Una tarea en la lista.
///
/// Recupera la densidad del Mac —hora, retraso, aplazamiento, duración, fecha
/// límite— pero en dos alturas: a la derecha lo que tiene que ver con el reloj,
/// que es lo que se consulta de un vistazo, y debajo del título el contexto
/// —proyecto, etiquetas, pasos—, que solo se lee cuando ya has parado en la
/// fila. Todo junto en una línea sería una fila que no se puede leer de reojo.
struct FilaView: View {
    let item: Item
    let alPulsar: () -> Void
    @Environment(Store.self) private var store

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            casilla
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title.isEmpty ? "Sin título" : item.title)
                    .font(.system(size: 16.5))
                    .foregroundStyle(item.isCompleted ? Papel.inkFaint : Papel.ink)
                    .strikethrough(item.isCompleted, color: Papel.inkFaint)
                    .fixedSize(horizontal: false, vertical: true)
                contexto
            }
            Spacer(minLength: 8)
            if !item.isCompleted { reloj }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: alPulsar)
    }

    /// El área de toque es de 44 puntos aunque el círculo mida 21: es el tamaño
    /// de un dedo, y fallar al completar una tarea es el peor fallo posible en
    /// una lista de tareas.
    private var casilla: some View {
        Button { store.toggleComplete(item) } label: {
            Circle()
                .strokeBorder(item.isCompleted ? Papel.accentInk : Papel.inkFaint,
                              lineWidth: 1.5)
                .background(item.isCompleted ? Papel.accent.opacity(0.9) : .clear,
                            in: Circle())
                .frame(width: 21, height: 21)
                .overlay {
                    if item.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundStyle(Papel.bg)
                    }
                }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, -11)
        .padding(.leading, -11)
    }

    /// Lo del reloj, en columna a la derecha.
    @ViewBuilder private var reloj: some View {
        VStack(alignment: .trailing, spacing: 3) {
            if let hora = item.timeLabel {
                HStack(spacing: 3) {
                    Text(hora)
                        .font(.system(size: 14, weight: .semibold).monospacedDigit())
                    if item.warnBefore != nil {
                        Image(systemName: "bell.badge").font(.system(size: 10))
                    }
                }
                .foregroundStyle(Papel.inkSoft)
            }
            if let hasta = item.snoozeLabel() {
                marca("moon.zzz.fill", hasta, Papel.inkFaint)
            }
            if item.daysLate > 0, let dia = item.day {
                marca("clock.arrow.circlepath",
                      dia.formatted(.dateTime.day().month(.abbreviated)), Papel.inkSoft)
            } else if let dia = item.day, !Calendar.current.isDateInToday(dia),
                      esFutura {
                marca("calendar", dia.formatted(.dateTime.day().month(.abbreviated)),
                      Papel.inkFaint)
            }
            // Sin icono: «45 min» ya se entiende solo, y a este tamaño el
            // cronómetro no se distinguía del reloj del retraso, que es lo
            // único que debe leerse como un reloj.
            if let minutos = item.estimate {
                Text(Duracion.etiqueta(minutos))
                    .font(.system(size: 12.5, weight: .medium).monospacedDigit())
                    .foregroundStyle(Papel.inkFaint)
            }
            if let limite = item.deadline {
                marca(item.isOverdue ? "exclamationmark.triangle.fill" : "flag.fill",
                      limite.formatted(.dateTime.day().month(.abbreviated)),
                      item.deadlineIsDue ? Papel.warning : Papel.inkFaint)
            }
            if let parada = item.staleLabel() {
                marca("hourglass.bottomhalf.filled", parada, Papel.inkFaint)
            }
        }
    }

    /// La fecha solo se repite cuando aporta: en `Próximamente` la fila ya está
    /// bajo su día en el Mac, y aquí no, así que se dice.
    private var esFutura: Bool { item.isUpcoming }

    private func marca(_ icono: String, _ texto: String, _ color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icono).font(.system(size: 9.5))
            Text(texto).font(.system(size: 12.5, weight: .medium).monospacedDigit())
        }
        .foregroundStyle(color)
    }

    /// Proyecto, etiquetas y pasos. Solo si hay algo que decir.
    @ViewBuilder private var contexto: some View {
        let proyecto = item.projectID.flatMap(store.project)
        if proyecto != nil || !item.tags.isEmpty || !item.checklist.isEmpty
            || item.recurrence != nil {
            HStack(spacing: 8) {
                // Solo el icono, como en el Mac: poner «Cada día» al lado del
                // título gasta la mitad de la fila en algo que ya se sabe en
                // cuanto se reconoce la flecha.
                if item.recurrence != nil {
                    Image(systemName: "repeat").font(.system(size: 10, weight: .semibold))
                }
                if let proyecto {
                    HStack(spacing: 4) {
                        if !proyecto.icon.isEmpty {
                            Text(proyecto.icon).font(.system(size: 11))
                        }
                        Text(proyecto.name)
                    }
                }
                if !item.checklist.isEmpty {
                    HStack(spacing: 3) {
                        Image(systemName: "checklist").font(.system(size: 9.5))
                        Text("\(item.checklistDone)/\(item.checklist.count)")
                            .monospacedDigit()
                    }
                    .foregroundStyle(item.checklistDone == item.checklist.count
                                     ? Papel.accentInk : Papel.inkFaint)
                }
                ForEach(item.tags, id: \.self) { tag in
                    Text(tag)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1.5)
                        .background(Papel.hairline.opacity(0.55), in: Capsule())
                }
            }
            .font(.system(size: 12.5))
            .foregroundStyle(Papel.inkFaint)
        }
    }
}
