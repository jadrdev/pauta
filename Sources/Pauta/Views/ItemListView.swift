import SwiftUI
import PautaCore

struct ItemListView: View {
    @Environment(Store.self) private var store
    @Environment(Navigation.self) private var nav

    @State private var draftTitle = ""
    @FocusState private var draftFocused: Bool

    private var items: [Item] { store.items(for: nav.perspective) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header

                Rectangle().fill(Paper.hairline).frame(height: 1)
                    .padding(.top, 16)
                    .padding(.bottom, 10)

                if items.isEmpty && !nav.isAddingItem {
                    emptyState.padding(.top, 26).padding(.bottom, 10)
                }

                LazyVStack(alignment: .leading, spacing: 0) {
                    if case .upcoming = nav.perspective {
                        ForEach(store.upcomingByDay(), id: \.day) { group in
                            Text(dayLabel(group.day).uppercased())
                                .rubricStyle()
                                .padding(.top, 18)
                                .padding(.bottom, 6)
                            ForEach(group.items) { ItemRowView(item: $0) }
                        }
                    } else {
                        ForEach(items) { item in
                            ItemRowView(item: item)
                        }
                    }
                }

                if nav.isAddingItem {
                    draftRow
                } else if nav.perspective != .logbook {
                    addButton
                }
            }
            .padding(.horizontal, 46)
            .padding(.top, 46)
            .padding(.bottom, 60)
            .frame(maxWidth: 700, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(Paper.bg)
        .onTapGesture {
            nav.selectedItemID = nil
            commitDraft()
        }
    }

    // MARK: - Cabecera

    @ViewBuilder private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            if case .project(let id) = nav.perspective, let project = store.project(id) {
                ProjectIconButton(project: project)
                ProjectTitleField(project: project)
            } else {
                Text(store.title(for: nav.perspective))
                    .font(.display(30))
                    .tracking(-0.6)
                    .foregroundStyle(Paper.ink)
            }
            Spacer(minLength: 0)
            if !items.isEmpty {
                Text(countLabel)
                    .rubricStyle()
            }
        }
    }

    private var countLabel: String {
        let n = items.count
        if case .logbook = nav.perspective {
            return n == 1 ? "1 COMPLETADA" : "\(n) COMPLETADAS"
        }
        return n == 1 ? "1 ABIERTA" : "\(n) ABIERTAS"
    }

    @ViewBuilder private var emptyState: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(emptyTitle)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Paper.inkSoft)
            Text("Pulsa ⌘N para añadir una tarea.")
                .font(.system(size: 12.5))
                .foregroundStyle(Paper.inkFaint)
        }
    }

    /// «Mañana», «Sábado» dentro de la semana, y fecha con mes más allá.
    private func dayLabel(_ day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInTomorrow(day) { return "Mañana" }
        let days = calendar.dateComponents([.day],
                                           from: calendar.startOfDay(for: .now),
                                           to: day).day ?? 0
        if days <= 6 { return day.formatted(.dateTime.weekday(.wide)) }
        return day.formatted(.dateTime.weekday(.abbreviated).day().month(.wide))
    }

    private var emptyTitle: String {
        switch nav.perspective {
        case .inbox: "La bandeja está vacía."
        case .today: "Nada para hoy."
        case .upcoming: "Nada planificado más adelante."
        case .anytime: "Nada que hacer ahora mismo."
        case .someday: "Nada aparcado para algún día."
        case .logbook: "Todavía no has completado nada."
        case .project: "Este proyecto no tiene tareas."
        }
    }

    // MARK: - Añadir tarea

    @ViewBuilder private var addButton: some View {
        Button { nav.startNewItem() } label: {
            HStack(spacing: 10) {
                Text("\u{FF0B}").font(.system(size: 12))
                Text("Añadir").font(.system(size: 13.5, weight: .medium))
            }
            .foregroundStyle(Paper.inkFaint)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }

    @ViewBuilder private var draftRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 13) {
            Circle()
                .strokeBorder(Paper.accent.opacity(0.8), style: StrokeStyle(lineWidth: 1.6, dash: [2.5, 2.5]))
                .frame(width: 16, height: 16)
                .offset(y: 2)
            TextField("Nueva tarea", text: $draftTitle)
                .textFieldStyle(.plain)
                .font(.system(size: 13.5, weight: .medium))
                .foregroundStyle(Paper.ink)
                .focused($draftFocused)
                .onSubmit { commitDraft(keepOpen: true) }
                .onExitCommand { draftTitle = ""; nav.isAddingItem = false }
        }
        .padding(.vertical, 9)
        .onAppear { draftFocused = true }
    }

    private func commitDraft(keepOpen: Bool = false) {
        // Un texto pegado con varias líneas crea una tarea por línea.
        let created = store.addItems(from: draftTitle, in: nav.perspective)
        draftTitle = ""
        if keepOpen && !created.isEmpty {
            draftFocused = true
        } else {
            nav.isAddingItem = false
        }
    }
}

/// Emoji del proyecto en la cabecera; al pulsarlo se abre un pequeño panel
/// para elegirlo. Paleta corta y curada a propósito: entre veinte se escoge
/// de un vistazo, en el teclado de emojis completo del sistema no.
private struct ProjectIconButton: View {
    @Environment(Store.self) private var store
    let project: Project
    @State private var showingPicker = false

    private static let palette = [
        "📌", "⭐️", "🔥", "🎯", "🏠", "💼", "📚", "🎨", "🎸", "🌱",
        "✈️", "🛒", "💪", "🧠", "🖥️", "📷", "🧾", "🛠️", "🐾", "🎁",
    ]

    var body: some View {
        Button { showingPicker.toggle() } label: {
            if project.icon.isEmpty {
                Image(systemName: "circle.dotted")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(Paper.inkFaint)
            } else {
                Text(project.icon).font(.system(size: 23))
            }
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showingPicker, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 10) {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(30)), count: 5),
                          spacing: 6) {
                    ForEach(Self.palette, id: \.self) { emoji in
                        Button {
                            store.setIcon(project, to: emoji)
                            showingPicker = false
                        } label: {
                            Text(emoji)
                                .font(.system(size: 17))
                                .frame(width: 30, height: 30)
                                .background(project.icon == emoji ? Paper.accent.opacity(0.16) : .clear,
                                            in: RoundedRectangle(cornerRadius: 6))
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                if !project.icon.isEmpty {
                    Button("Quitar emoji") {
                        store.setIcon(project, to: "")
                        showingPicker = false
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(Paper.inkSoft)
                }
            }
            .padding(12)
        }
    }
}

/// Título editable en la cabecera de un proyecto.
private struct ProjectTitleField: View {
    @Environment(Store.self) private var store
    let project: Project
    @State private var name = ""

    var body: some View {
        TextField("Sin título", text: $name)
            .textFieldStyle(.plain)
            .font(.display(30))
            .tracking(-0.6)
            .foregroundStyle(Paper.ink)
            .fixedSize(horizontal: false, vertical: true)
            .onAppear { name = project.name }
            .onChange(of: project.id) { name = project.name }
            .onChange(of: name) { store.rename(project, to: name) }
    }
}
