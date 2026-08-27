import SwiftUI
import PautaCore

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
        let title = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        store.addItem(title: title, in: .today)
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
