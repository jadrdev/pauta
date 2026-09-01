import SwiftUI
import PautaCore

struct ItemListView: View {
    @Environment(Store.self) private var store
    @Environment(Navigation.self) private var nav

    @State private var draftTitle = ""
    @State private var pegado: String?
    @State private var isEndDropTarget = false
    @FocusState private var draftFocused: Bool

    private var items: [Item] { store.items(for: nav.perspective) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header

                Rectangle().fill(Paper.hairline).frame(height: 1)
                    .padding(.top, 16)
                    .padding(.bottom, 10)

                if AvisoEstado.shared.mudos { avisosMudos }

                if items.isEmpty && !nav.isAddingItem {
                    emptyState.padding(.top, 26).padding(.bottom, 10)
                }

                LazyVStack(alignment: .leading, spacing: 0) {
                    if case .upcoming = nav.perspective {
                        ForEach(store.upcomingByDay(), id: \.day) { group in
                            DayHeader(label: dayLabel(group.day), items: group.items)
                            ForEach(group.items) { ItemRowView(item: $0) }
                        }
                    } else {
                        ForEach(items) { item in
                            ItemRowView(item: item)
                        }
                    }
                }

                if let pegado {
                    eleccionDePegado(pegado)
                } else if nav.isAddingItem {
                    draftRow
                } else if nav.perspective.acceptsNewItems {
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
                IconoEditable(icon: project.icon) { store.setIcon(project, to: $0) }
                TituloEditable(id: project.id, nombre: project.name) {
                    store.rename(project, to: $0)
                }
            } else if case .area(let id) = nav.perspective, let area = store.area(id) {
                IconoEditable(icon: area.icon) { store.setIcon(area, to: $0) }
                TituloEditable(id: area.id, nombre: area.name) { store.rename(area, to: $0) }
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

    /// Hay tareas con hora y el sistema no va a avisar de ninguna.
    ///
    /// Se dice una vez arriba y no en cada tarea: es una condición de la app
    /// entera, no de una tarea, y repetirla por fila sería ruido.
    @ViewBuilder private var avisosMudos: some View {
        HStack(spacing: 8) {
            Image(systemName: "bell.slash")
                .font(.system(size: 10.5, weight: .semibold))
            Text("LOS AVISOS ESTÁN DESACTIVADOS PARA PAUTA")
                .font(.rubric).tracking(1.3)
            Spacer(minLength: 8)
            Button {
                if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                Text("ACTIVAR").font(.rubric).tracking(1.3)
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(Paper.warning)
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(Paper.warning.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8)
            .strokeBorder(Paper.warning.opacity(0.35), lineWidth: 1))
        .padding(.bottom, 12)
    }

    private var countLabel: String {
        let n = items.count
        // El título de esa lista ya dice «Completadas»: repetirlo en el rótulo
        // sobraría, así que ahí solo se cuenta.
        if case .completed = nav.perspective {
            return n == 1 ? "1 TAREA" : "\(n) TAREAS"
        }
        return n == 1 ? "1 ABIERTA" : "\(n) ABIERTAS"
    }

    @ViewBuilder private var emptyState: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(emptyTitle)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Paper.inkSoft)
            if let emptyHint {
                Text(emptyHint)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Paper.inkFaint)
            }
        }
    }

    /// Qué se puede hacer desde aquí. En un área ⌘N no añade nada —lo que
    /// agrupa son proyectos—, así que ofrecerlo sería mandar a un sitio donde
    /// no pasa lo que se promete.
    private var emptyHint: String? {
        if case .area = nav.perspective {
            return "Arrastra proyectos a esta área en la barra lateral."
        }
        guard nav.perspective.acceptsNewItems else { return nil }
        return "Pulsa ⌘N para añadir una tarea."
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
        case .completed: "Todavía no has completado nada."
        case .project: "Este proyecto no tiene tareas."
        case .area: "Los proyectos de esta área no tienen nada pendiente."
        case .tag: "Nada lleva esta etiqueta."
        }
    }

    // MARK: - Añadir tarea

    @ViewBuilder private var addButton: some View {
        addButtonLabel
            // Soltar aquí manda la tarea al final de la lista.
            .dropDestination(for: String.self) { payload, _ in
                let arrastradas = payload
                    .compactMap(UUID.init(uuidString:))
                    .compactMap { id in store.items.first { $0.id == id } }
                for dragged in arrastradas {
                    store.place(dragged, before: nil, in: nav.perspective)
                }
                return !arrastradas.isEmpty
            } isTargeted: { isEndDropTarget = $0 }
            .overlay(alignment: .top) {
                if isEndDropTarget {
                    Rectangle().fill(Paper.accent).frame(height: 2)
                }
            }
    }

    @ViewBuilder private var addButtonLabel: some View {
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
        // Con varias líneas hay dos lecturas razonables —varias tareas, o una
        // con pasos— y ninguna es obviamente la buena, así que se pregunta en
        // vez de decidir por el usuario.
        if Store.titles(from: draftTitle).count > 1 {
            pegado = draftTitle
            draftTitle = ""
            return
        }
        let created = store.addItems(from: draftTitle, in: nav.perspective)
        draftTitle = ""
        if keepOpen && !created.isEmpty {
            draftFocused = true
        } else {
            nav.isAddingItem = false
        }
    }

    @ViewBuilder private func eleccionDePegado(_ texto: String) -> some View {
        let titulos = Store.titles(from: texto)
        VStack(alignment: .leading, spacing: 9) {
            Text("HAS PEGADO \(titulos.count) LÍNEAS").rubricStyle()
            Text(titulos.first ?? "")
                .font(.system(size: 13.5, weight: .medium))
                .foregroundStyle(Paper.ink)
                .lineLimit(1)
            HStack(spacing: 8) {
                botonDeEleccion("\(titulos.count) tareas", destacado: true) {
                    store.addItems(from: texto, in: nav.perspective)
                    cerrarEleccion()
                }
                botonDeEleccion("Una tarea con \(titulos.count - 1) pasos") {
                    store.addItemWithChecklist(from: texto, in: nav.perspective)
                    cerrarEleccion()
                }
                Button("Cancelar") { cerrarEleccion() }
                    .buttonStyle(.plain)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Paper.inkFaint)
            }
        }
        .padding(.vertical, 10)
    }

    private func botonDeEleccion(_ titulo: String,
                                 destacado: Bool = false,
                                 accion: @escaping () -> Void) -> some View {
        Button(action: accion) {
            Text(titulo)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(destacado ? Paper.onAccent : Paper.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(destacado ? AnyShapeStyle(Paper.accent)
                                      : AnyShapeStyle(Paper.ink.opacity(0.07)),
                            in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(destacado ? .clear : Paper.hairline))
        }
        .buttonStyle(.plain)
    }

    private func cerrarEleccion() {
        pegado = nil
        nav.isAddingItem = false
    }
}

/// Cabecera de un día en «Próximamente». Además de rotular, recibe: soltar
/// encima manda la tarea a ese día, la primera. Sin ella, cambiar de día
/// arrastrando obligaría a acertar sobre una fila concreta, y al primer día de
/// la lista no se llegaría nunca por arriba.
private struct DayHeader: View {
    @Environment(Store.self) private var store
    let label: String
    let items: [Item]
    @State private var isTargeted = false

    var body: some View {
        Text(label.uppercased())
            .rubricStyle()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 18)
            .padding(.bottom, 6)
            .contentShape(Rectangle())
            .dropDestination(for: String.self) { payload, _ in
                guard let primera = items.first else { return false }
                let arrastradas = payload
                    .compactMap(UUID.init(uuidString:))
                    .compactMap { id in store.items.first { $0.id == id } }
                    .filter { $0.id != primera.id }
                for dragged in arrastradas {
                    store.place(dragged, before: primera, in: .upcoming)
                }
                return !arrastradas.isEmpty
            } isTargeted: { isTargeted = $0 }
            // La línea va abajo: lo que se suelta cae entre el rótulo y la
            // primera tarea del día, no encima del rótulo.
            .overlay(alignment: .bottom) {
                if isTargeted {
                    Rectangle().fill(Paper.accent).frame(height: 2)
                }
            }
    }
}

/// Emoji del proyecto o del área en la cabecera; al pulsarlo se abre un panel
/// para elegirlo. Paleta corta y curada a propósito: entre veinte se escoge
/// de un vistazo, en el teclado de emojis completo del sistema no.
private struct IconoEditable: View {
    let icon: String
    let alElegir: (String) -> Void
    @State private var showingPicker = false

    private static let palette = [
        "📌", "⭐️", "🔥", "🎯", "🏠", "💼", "📚", "🎨", "🎸", "🌱",
        "✈️", "🛒", "💪", "🧠", "🖥️", "📷", "🧾", "🛠️", "🐾", "🎁",
    ]

    var body: some View {
        Button { showingPicker.toggle() } label: {
            if icon.isEmpty {
                Image(systemName: "circle.dotted")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(Paper.inkFaint)
            } else {
                Text(icon).font(.system(size: 23))
            }
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showingPicker, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 10) {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(30)), count: 5),
                          spacing: 6) {
                    ForEach(Self.palette, id: \.self) { emoji in
                        Button {
                            alElegir(emoji)
                            showingPicker = false
                        } label: {
                            Text(emoji)
                                .font(.system(size: 17))
                                .frame(width: 30, height: 30)
                                .background(icon == emoji ? Paper.accent.opacity(0.16) : .clear,
                                            in: RoundedRectangle(cornerRadius: 6))
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                if !icon.isEmpty {
                    Button("Quitar emoji") {
                        alElegir("")
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

/// Título editable en la cabecera de un proyecto o de un área.
private struct TituloEditable: View {
    let id: UUID
    let nombre: String
    let alCambiar: (String) -> Void
    @State private var texto = ""

    var body: some View {
        TextField("Sin título", text: $texto)
            .textFieldStyle(.plain)
            .font(.display(30))
            .tracking(-0.6)
            .foregroundStyle(Paper.ink)
            .fixedSize(horizontal: false, vertical: true)
            .onAppear { texto = nombre }
            // Al cambiar de proyecto o de área hay que recargar el campo: si no,
            // el texto del anterior se escribiría encima del nuevo.
            .onChange(of: id) { texto = nombre }
            .onChange(of: texto) { alCambiar(texto) }
    }
}
