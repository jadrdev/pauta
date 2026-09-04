import SwiftUI
import Observation
import PautaCore

/// Un reloj que se mueve solo.
///
/// Hace falta porque nada en los datos cambia cuando pasa el tiempo: una tarea a
/// las nueve es la misma tarea a las ocho y a las ocho y media, y sin algo que
/// marque el minuto la cuenta atrás se quedaría escrita en el momento en que se
/// dibujó.
@Observable
@MainActor
final class Reloj {
    private(set) var ahora = Date()
    @ObservationIgnored private var timer: Timer?

    /// Medio minuto: la cuenta se dice en minutos, así que afinar más solo
    /// gastaría batería para escribir el mismo número.
    init(cada segundos: TimeInterval = 30) {
        timer = Timer.scheduledTimer(withTimeInterval: segundos, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.ahora = Date() }
        }
        // Con tolerancia, para que el sistema pueda agrupar el despertar con
        // otros en vez de encender el procesador solo para esto.
        timer?.tolerance = 10
    }

    deinit { timer?.invalidate() }
}

/// Lo que se ve en la barra de menús: el monograma y, cuando falta poco, cuánto
/// falta y para qué.
///
/// El rótulo aparece solo dentro de la ventana de `Cuenta`. Un texto puesto todo
/// el día se deja de leer, y entonces tampoco dice nada cuando falta un cuarto
/// de hora —que es el único momento en que hacía falta—.
struct EtiquetaDeBarra: View {
    let store: Store
    let reloj: Reloj
    let ajustes: Ajustes

    var body: some View {
        HStack(spacing: 5) {
            if let icon = Brand.menuBar {
                Image(nsImage: icon)
            } else {
                // Sin bundle (binario suelto) no hay monograma: un símbolo vale.
                Image(systemName: "checklist")
            }
            if ajustes.barraConCuenta,
               let inminente = Cuenta.inminente(store.items, now: reloj.ahora) {
                Text("\(Cuenta.restante(inminente.cuando, now: reloj.ahora))"
                     + " · \(Self.recortado(inminente.item.title))")
            }
        }
    }

    /// La barra de menús es de todos: un título largo empujaría a los demás
    /// iconos fuera de la pantalla.
    static func recortado(_ titulo: String, a maximo: Int = 22) -> String {
        titulo.count <= maximo ? titulo
            : titulo.prefix(maximo - 1).trimmingCharacters(in: .whitespaces) + "…"
    }
}

/// Panel de la barra de menús: ver Hoy, completar y añadir sin abrir la
/// ventana. Cubre casi todo lo que daría un widget, sin extensión ni firma.
struct MenuBarView: View {
    @Environment(Store.self) private var store
    @Environment(\.openWindow) private var openWindow

    @State private var draftTitle = ""

    private var items: [Item] { store.items(for: .today) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("HOY").rubricStyle(Paper.inkSoft)
                Spacer()
                if !items.isEmpty {
                    Text("\(items.count)")
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Paper.inkFaint)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 9)

            Rectangle().fill(Paper.hairline).frame(height: 1)

            if items.isEmpty {
                Text("Nada para hoy.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Paper.inkFaint)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 13)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(items) { item in
                            MenuBarItemRow(item: item)
                        }
                    }
                    .padding(.vertical, 5)
                }
                .frame(maxHeight: 280)
            }

            Rectangle().fill(Paper.hairline).frame(height: 1)

            // Alta rápida: siempre a Hoy, que es lo que enseña este panel.
            HStack(spacing: 10) {
                Circle()
                    .strokeBorder(Paper.accent.opacity(0.8),
                                  style: StrokeStyle(lineWidth: 1.4, dash: [2.5, 2.5]))
                    .frame(width: 14, height: 14)
                TextField("Nueva tarea para hoy", text: $draftTitle)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Paper.ink)
                    .onSubmit(commitDraft)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Rectangle().fill(Paper.hairline).frame(height: 1)

            Button {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Text("ABRIR PAUTA")
                    .font(.rubric)
                    .tracking(1.1)
                    .foregroundStyle(Paper.accentInk)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .frame(width: 300)
        .background(Paper.bg)
    }

    private func commitDraft() {
        // Un texto pegado con varias líneas crea una tarea por línea.
        store.addItems(from: draftTitle, in: .today)
        draftTitle = ""
    }
}

/// Fila compacta: casilla y título, sin editor. Para lo demás está la ventana.
private struct MenuBarItemRow: View {
    @Environment(Store.self) private var store
    let item: Item
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 10) {
            Checkbox(isCompleted: item.isCompleted) { store.toggleComplete(item) }
            Text(item.title.isEmpty ? "Sin título" : item.title)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(Paper.ink)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(hovering ? Paper.ink.opacity(0.045) : .clear)
        .onHover { hovering = $0 }
    }
}
