import SwiftUI
import PautaCore

/// Panel que flota sobre la página: Liquid Glass en macOS 26+, papel con
/// filete en versiones anteriores.
struct FloatingPanel: ViewModifier {
    var radius: CGFloat = 13

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.glassEffect(.regular, in: .rect(cornerRadius: radius))
        } else {
            content
                .background(Paper.bgSide, in: RoundedRectangle(cornerRadius: radius))
                .overlay(
                    RoundedRectangle(cornerRadius: radius)
                        .strokeBorder(Paper.hairline, lineWidth: 1)
                )
        }
    }
}

extension View {
    func floatingPanel(radius: CGFloat = 13) -> some View {
        modifier(FloatingPanel(radius: radius))
    }
}

/// Casilla circular de trazo fino. Al completarse se rellena de terracota.
struct Checkbox: View {
    let isCompleted: Bool
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isCompleted ? Paper.accent : .clear)
                Circle()
                    .strokeBorder(isCompleted ? Paper.accent
                                  : (hovering ? Paper.accent.opacity(0.7) : Paper.inkFaint.opacity(0.65)),
                                  lineWidth: 1.6)
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(Paper.onAccent)
                }
            }
            .frame(width: 16, height: 16)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

struct ItemRowView: View {
    @Environment(Store.self) private var store
    @Environment(Navigation.self) private var nav
    let item: Item

    @State private var title = ""
    @State private var notes = ""
    @State private var hovering = false
    @State private var isDropTarget = false
    @State private var eligiendoFecha = false
    @FocusState private var titleFocused: Bool

    private var isSelected: Bool { nav.selectedItemID == item.id }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 13) {
                Checkbox(isCompleted: item.isCompleted) {
                    store.toggleComplete(item)
                    if isSelected { nav.selectedItemID = nil }
                }
                .offset(y: 2)

                if isSelected {
                    TextField("Título", text: $title)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundStyle(Paper.ink)
                        .focused($titleFocused)
                        .onSubmit { nav.selectedItemID = nil }
                } else {
                    Text(item.title.isEmpty ? "Sin título" : item.title)
                        .font(.system(size: 13.5, weight: .medium))
                        .strikethrough(item.isCompleted, color: Paper.inkFaint)
                        .foregroundStyle(item.isCompleted ? Paper.inkFaint : Paper.ink)
                    Spacer(minLength: 12)
                    badges
                }
            }

            if isSelected { editor }
        }
        .padding(.vertical, 9)
        .padding(.horizontal, isSelected ? 14 : 0)
        .padding(.vertical, isSelected ? 5 : 0)
        .modifier(SelectedPanel(isSelected: isSelected))
        .padding(.horizontal, isSelected ? -14 : 0)
        .contentShape(Rectangle())
        // Se arrastra el identificador, no la tarea entera: quien recibe la
        // busca en el almacén, que es la única fuente de verdad.
        .draggable(item.id.uuidString)
        // Soltar sobre una fila coloca lo arrastrado justo antes de ella.
        .dropDestination(for: String.self) { payload, _ in
            let arrastradas = payload
                .compactMap(UUID.init(uuidString:))
                .compactMap { id in store.items.first { $0.id == id } }
                .filter { $0.id != item.id }
            for dragged in arrastradas {
                store.place(dragged, before: item, in: nav.perspective)
            }
            return !arrastradas.isEmpty
        } isTargeted: { isDropTarget = $0 }
        // Línea de inserción: hace falta ver dónde va a caer, no solo que cae.
        .overlay(alignment: .top) {
            if isDropTarget {
                Rectangle().fill(Paper.accent).frame(height: 2)
            }
        }
        .onHover { hovering = $0 }
        .onTapGesture { select() }
        // El estado de edición se rellena desde el item en cuanto la fila se
        // abre, venga la selección de un clic o de cualquier otro sitio.
        .onAppear { if isSelected { hydrate() } }
        .onChange(of: isSelected) { _, nowSelected in if nowSelected { hydrate() } }
        .onChange(of: title) { guard isSelected else { return }; commitText() }
        .onChange(of: notes) { guard isSelected else { return }; commitText() }
        .contextMenu {
            Button("Programar para hoy") { store.schedule(item, to: .now) }
            Button("Aparcar en Algún día") { store.park(item) }
            Button("Quitar fecha") { store.schedule(item, to: nil) }
            Divider()
            Button("Eliminar", role: .destructive) { store.delete(item) }
        }
    }

    /// Indicadores a la derecha: notas, proyecto y fecha, en texto tenue.
    @ViewBuilder private var badges: some View {
        HStack(spacing: 12) {
            if item.recurrence != nil {
                Image(systemName: "repeat")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Paper.inkFaint)
            }
            if !item.notes.isEmpty {
                Image(systemName: "text.alignleft")
                    .font(.system(size: 9))
                    .foregroundStyle(Paper.inkFaint)
            }
            // Distintivo de proyecto: con el emoji del proyecto, si lo tiene, y
            // sobre una pastilla tenue. Sin ella, en una ventana ancha el nombre
            // queda tan lejos del título que cuesta asociarlos — y con dos tareas
            // que se llaman igual es lo único que las distingue.
            if let projectID = item.projectID,
               let project = store.project(projectID),
               !isProjectPerspective(projectID) {
                HStack(spacing: 4) {
                    if !project.icon.isEmpty {
                        Text(project.icon).font(.system(size: 10))
                    }
                    Text(project.name.isEmpty ? "Sin título" : project.name)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                }
                .foregroundStyle(Paper.inkSoft)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(
                    Capsule().fill(Paper.ink.opacity(0.07))
                )
                .overlay(Capsule().strokeBorder(Paper.hairline, lineWidth: 1))
            }
            // En Próximamente la lista ya va agrupada por día, así que repetir la
            // fecha en cada fila solo añade ruido.
            if let when = item.when, !item.isToday, !item.isCompleted, !isGroupedByDay {
                Text(when.formatted(.dateTime.day().month(.abbreviated)))
                    .font(.system(size: 11.5))
                    .foregroundStyle(Paper.inkFaint)
            }
        }
    }

    private var isGroupedByDay: Bool {
        if case .upcoming = nav.perspective { return true }
        return false
    }

    private func isProjectPerspective(_ id: UUID) -> Bool {
        if case .project(let current) = nav.perspective { return current == id }
        return false
    }

    // MARK: - Editor desplegado

    @ViewBuilder private var editor: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Notas", text: $notes, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5))
                .foregroundStyle(Paper.inkSoft)
                .lineLimit(1...6)

            HStack(spacing: 18) {
                Menu {
                    Button("Hoy") { store.schedule(item, to: .now) }
                    Button("Mañana") {
                        store.schedule(item, to: Calendar.current.date(byAdding: .day, value: 1, to: .now))
                    }
                    Button("Próxima semana") {
                        store.schedule(item, to: Calendar.current.date(byAdding: .day, value: 7, to: .now))
                    }
                    Button("Otra fecha…") { eligiendoFecha = true }
                    Divider()
                    Button("Algún día") { store.park(item) }
                    Button("Sin fecha") { store.schedule(item, to: nil) }
                } label: {
                    Text(whenLabel.uppercased()).rubricStyle(Paper.accentInk)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                // Sin esto no había forma de programar nada más allá de la
                // semana que viene: los atajos cubren lo frecuente, no todo.
                .popover(isPresented: $eligiendoFecha, arrowEdge: .bottom) {
                    SelectorDeFecha(inicial: item.when ?? Date()) { fecha in
                        store.schedule(item, to: fecha)
                        eligiendoFecha = false
                    }
                }

                Menu {
                    Button("No se repite") { store.setRecurrence(item, to: nil) }
                    Divider()
                    ForEach(Recurrence.allCases, id: \.self) { cada in
                        Button(cada.title) { store.setRecurrence(item, to: cada) }
                    }
                } label: {
                    Text((item.recurrence?.title ?? "No se repite").uppercased())
                        .rubricStyle()
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                // Con `tint` y no con `foregroundStyle`: los Menu sin borde
                // colorean su etiqueta con el tint e ignoran el estilo de primer
                // plano. Sin repetición va apagado; con ella, en verde.
                .tint(item.recurrence == nil ? Paper.inkSoft : Paper.accentInk)

                Menu {
                    Button("Bandeja") { move(to: nil) }
                    if !store.projects.isEmpty { Divider() }
                    ForEach(store.projects) { project in
                        Button(project.name.isEmpty ? "Sin título" : project.name) { move(to: project.id) }
                    }
                } label: {
                    Text(projectLabel.uppercased()).rubricStyle()
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                // El proyecto es contexto, no acción: apagado.
                .tint(Paper.inkSoft)

                Spacer()

                Button {
                    nav.selectedItemID = nil
                    store.delete(item)
                } label: {
                    Text("ELIMINAR")
                        .font(.rubric)
                        .tracking(1.1)
                        .foregroundStyle(Paper.accentInk)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.leading, 29)
        .padding(.top, 11)
    }

    private var whenLabel: String {
        if item.isSomeday { return "Algún día" }
        guard let when = item.when else { return "Sin fecha" }
        if Calendar.current.isDateInToday(when) { return "Hoy" }
        if Calendar.current.isDateInTomorrow(when) { return "Mañana" }
        return when.formatted(.dateTime.day().month(.abbreviated))
    }

    private var projectLabel: String {
        guard let id = item.projectID, let project = store.project(id) else { return "Bandeja" }
        return project.name.isEmpty ? "Sin título" : project.name
    }

    // MARK: - Acciones

    private func select() {
        guard !isSelected else { return }
        hydrate()
        nav.selectedItemID = item.id
        nav.isAddingItem = false
    }

    /// Copia el contenido del item en los campos editables. Sin poner el foco
    /// a propósito: al enfocarse, el campo selecciona todo el texto y el primer
    /// carácter que escribieras borraría el título entero.
    private func hydrate() {
        title = item.title
        notes = item.notes
    }

    private func move(to projectID: UUID?) {
        var updated = item
        updated.projectID = projectID
        store.update(updated)
    }

    /// Guarda título y notas mientras se escribe: no hay botón de guardar.
    private func commitText() {
        var updated = item
        updated.title = title
        updated.notes = notes
        guard updated != item else { return }
        store.update(updated)
    }
}

/// Solo la fila abierta se levanta de la página.
private struct SelectedPanel: ViewModifier {
    let isSelected: Bool

    func body(content: Content) -> some View {
        if isSelected {
            content.floatingPanel()
        } else {
            content
        }
    }
}

/// Calendario para elegir una fecha cualquiera.
struct SelectorDeFecha: View {
    let inicial: Date
    let alElegir: (Date) -> Void

    @State private var fecha: Date

    init(inicial: Date, alElegir: @escaping (Date) -> Void) {
        self.inicial = inicial
        self.alElegir = alElegir
        _fecha = State(initialValue: inicial)
    }

    var body: some View {
        VStack(spacing: 10) {
            DatePicker("", selection: $fecha, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .labelsHidden()
            Button("Programar") { alElegir(fecha) }
                .buttonStyle(.borderedProminent)
                .tint(Paper.accentInk)
        }
        .padding(14)
        .frame(width: 280)
    }
}
