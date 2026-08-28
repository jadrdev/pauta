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
    @State private var eligiendoLimite = false
    @State private var eligiendoFin = false
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
            if let deadline = item.deadline, !item.isCompleted {
                HStack(spacing: 3) {
                    Image(systemName: item.isOverdue ? "exclamationmark.triangle.fill" : "flag.fill")
                        .font(.system(size: 8.5))
                    Text(deadline.formatted(.dateTime.day().month(.abbreviated)))
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(item.deadlineIsDue ? Paper.warning : Paper.inkFaint)
            }
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
                    Button("Sin fecha límite") { store.setDeadline(item, to: nil) }
                    Divider()
                    Button("Hoy") { store.setDeadline(item, to: .now) }
                    Button("Mañana") {
                        store.setDeadline(item, to: Calendar.current.date(byAdding: .day, value: 1, to: .now))
                    }
                    Button("En una semana") {
                        store.setDeadline(item, to: Calendar.current.date(byAdding: .day, value: 7, to: .now))
                    }
                    Button("Otra fecha…") { eligiendoLimite = true }
                } label: {
                    Text(limiteLabel.uppercased()).rubricStyle()
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                // En rojo solo cuando ya aprieta: si todas las fechas límite
                // gritaran, ninguna diría nada.
                .tint(item.deadlineIsDue ? Paper.warning : Paper.inkSoft)
                .popover(isPresented: $eligiendoLimite, arrowEdge: .bottom) {
                    SelectorDeFecha(inicial: item.deadline ?? Date()) { fecha in
                        store.setDeadline(item, to: fecha)
                        eligiendoLimite = false
                    }
                }

                Menu {
                    Button("No se repite") { store.setRecurrence(item, to: nil) }
                    Divider()
                    ForEach(Recurrence.allCases, id: \.self) { cada in
                        Button(cada.title) { store.setRecurrence(item, to: cada) }
                    }
                    if item.recurrence != nil {
                        Divider()
                        Button("No acaba nunca") { store.setRecurrenceEnd(item, to: nil) }
                        Button("Acabar en una fecha…") { eligiendoFin = true }
                    }
                } label: {
                    Text(repeticionLabel.uppercased())
                        .rubricStyle()
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                // Con `tint` y no con `foregroundStyle`: los Menu sin borde
                // colorean su etiqueta con el tint e ignoran el estilo de primer
                // plano. Sin repetición va apagado; con ella, en verde.
                .tint(item.recurrence == nil ? Paper.inkSoft : Paper.accentInk)
                .popover(isPresented: $eligiendoFin, arrowEdge: .bottom) {
                    SelectorDeFecha(inicial: item.recurrenceEnd ?? item.when ?? Date(),
                                    accion: "Acabar aquí") { fecha in
                        store.setRecurrenceEnd(item, to: fecha)
                        eligiendoFin = false
                    }
                }

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
                    // Icono y no texto: con cinco controles en fila, «ELIMINAR»
                    // partía la línea en dos. Y una papelera dice «destructivo»
                    // mejor que una palabra del color del acento.
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Paper.inkSoft)
                }
                .buttonStyle(.plain)
                .help("Eliminar tarea")
            }
        }
        .padding(.leading, 29)
        .padding(.top, 11)
    }

    /// En una tarea repetitiva la fecha **es** el inicio de la serie, así que se
    /// dice con esas palabras en vez de inventar un campo aparte que diría lo
    /// mismo y podría discrepar.
    private var whenLabel: String {
        if item.isSomeday { return "Algún día" }
        guard let when = item.when else { return "Sin fecha" }
        if item.recurrence != nil {
            let cal = Calendar.current
            if cal.isDateInToday(when) { return "Desde hoy" }
            if cal.isDateInTomorrow(when) { return "Desde mañana" }
            return "Desde \(when.formatted(.dateTime.day().month(.abbreviated)))"
        }
        if Calendar.current.isDateInToday(when) { return "Hoy" }
        if Calendar.current.isDateInTomorrow(when) { return "Mañana" }
        return when.formatted(.dateTime.day().month(.abbreviated))
    }

    /// «Cada semana», o «Cada semana → 30 nov» cuando tiene fin.
    private var repeticionLabel: String {
        guard let recurrence = item.recurrence else { return "No repite" }
        guard let fin = item.recurrenceEnd else { return recurrence.title }
        return "\(recurrence.title) → \(fin.formatted(.dateTime.day().month(.abbreviated)))"
    }

    /// Corto a propósito: en el editor hay cuatro menús en fila y las etiquetas
    /// largas en mayúsculas lo convierten en un muro.
    private var limiteLabel: String {
        guard let deadline = item.deadline else { return "Sin límite" }
        let cal = Calendar.current
        if cal.isDateInToday(deadline) { return "Vence hoy" }
        if cal.isDateInTomorrow(deadline) { return "Vence mañana" }
        return "Vence \(deadline.formatted(.dateTime.day().month(.abbreviated)))"
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
    let accion: String
    let alElegir: (Date) -> Void

    @State private var fecha: Date
    @State private var mes: Date

    private let cal = Calendar.autoupdatingCurrent
    /// Ancho de celda y alto de fila. De aquí sale el ancho del panel.
    private static let celda: CGFloat = 36
    private static let fila: CGFloat = 32

    init(inicial: Date, accion: String = "Programar", alElegir: @escaping (Date) -> Void) {
        self.inicial = inicial
        self.accion = accion
        self.alElegir = alElegir
        _fecha = State(initialValue: inicial)
        _mes = State(initialValue: Calendar.autoupdatingCurrent.inicioDeMes(inicial))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            cabecera
            VStack(spacing: 1) {
                HStack(spacing: 0) {
                    ForEach(Array(simbolos.enumerated()), id: \.offset) { _, dia in
                        Text(dia).rubricStyle().frame(width: Self.celda)
                    }
                }
                .padding(.bottom, 4)
                // Siempre seis filas: si el mes ocupara cinco, el panel
                // encogería al cambiar de mes y los botones bailarían.
                ForEach(0..<6, id: \.self) { fila in
                    HStack(spacing: 0) {
                        ForEach(0..<7, id: \.self) { columna in
                            celda(dias[fila * 7 + columna])
                        }
                    }
                }
            }
            boton
        }
        .padding(16)
        .frame(width: Self.celda * 7 + 32)
    }

    // MARK: - Partes

    private var cabecera: some View {
        HStack(spacing: 2) {
            Text(tituloDelMes)
                .font(.display(15))
                .foregroundStyle(Paper.ink)
            Spacer(minLength: 8)
            // Volver a hoy solo se ofrece cuando sirve de algo.
            if !cal.isDate(mes, equalTo: .now, toGranularity: .month) {
                Button { mes = cal.inicioDeMes(.now) } label: {
                    Text("HOY").rubricStyle(Paper.accentInk)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 4)
            }
            flecha("chevron.left", -1)
            flecha("chevron.right", 1)
        }
    }

    private func flecha(_ icono: String, _ meses: Int) -> some View {
        Button {
            if let otro = cal.date(byAdding: .month, value: meses, to: mes) { mes = otro }
        } label: {
            Image(systemName: icono)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Paper.inkSoft)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func celda(_ dia: Date) -> some View {
        DiaCelda(dia: dia,
                 ancho: Self.celda,
                 alto: Self.fila,
                 delMes: cal.isDate(dia, equalTo: mes, toGranularity: .month),
                 elegido: cal.isDate(dia, inSameDayAs: fecha),
                 hoy: cal.isDateInToday(dia)) {
            fecha = dia
            // Pinchar un día de relleno lleva a su mes: si no, el día elegido
            // quedaría fuera de la rejilla y no se vería marcado.
            if !cal.isDate(dia, equalTo: mes, toGranularity: .month) {
                mes = cal.inicioDeMes(dia)
            }
        }
    }

    private var boton: some View {
        Button { alElegir(fecha) } label: {
            Text(accion)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(Paper.onAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Paper.accent, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .padding(.top, 2)
    }

    // MARK: - Cuentas

    /// Iniciales de los días, girados para empezar por el primer día de la
    /// semana del idioma: en español el lunes, en inglés el domingo.
    private var simbolos: [String] {
        let todos = cal.veryShortStandaloneWeekdaySymbols
        return (0..<7).map { todos[(cal.firstWeekday - 1 + $0) % 7].uppercased() }
    }

    /// Las 42 casillas de la rejilla, con los días de relleno de los meses
    /// vecinos a los lados.
    private var dias: [Date] {
        let primero = cal.inicioDeMes(mes)
        let hueco = (cal.component(.weekday, from: primero) - cal.firstWeekday + 7) % 7
        let arranque = cal.date(byAdding: .day, value: -hueco, to: primero) ?? primero
        return (0..<42).map {
            cal.date(byAdding: .day, value: $0, to: arranque) ?? arranque
        }
    }

    private var tituloDelMes: String {
        let nombre = mes.formatted(.dateTime.month(.wide))
        return nombre.prefix(1).uppercased() + nombre.dropFirst()
            + " " + mes.formatted(.dateTime.year())
    }
}

/// Un día de la rejilla. Vive aparte por el estado del cursor encima.
private struct DiaCelda: View {
    let dia: Date
    let ancho: CGFloat
    let alto: CGFloat
    let delMes: Bool
    let elegido: Bool
    let hoy: Bool
    let alPulsar: () -> Void

    @State private var encima = false

    var body: some View {
        Button(action: alPulsar) {
            Text("\(Calendar.autoupdatingCurrent.component(.day, from: dia))")
                .font(.system(size: 12.5, weight: elegido || hoy ? .semibold : .regular))
                .foregroundStyle(tinta)
                .frame(width: ancho - 6, height: alto - 4)
                .background { fondo }
                // El área sensible es la casilla entera, no solo el número: se
                // pincha sin apuntar.
                .frame(width: ancho, height: alto)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { encima = $0 }
    }

    @ViewBuilder private var fondo: some View {
        let forma = RoundedRectangle(cornerRadius: 7)
        if elegido {
            forma.fill(Paper.accent)
        } else if encima {
            forma.fill(Paper.hairline)
        } else if hoy {
            // Hoy va perfilado, no relleno: el relleno es de lo elegido, y dos
            // rellenos a la vez se confundirían.
            forma.strokeBorder(Paper.accent.opacity(0.55), lineWidth: 1.2)
        }
    }

    private var tinta: Color {
        if elegido { return Paper.onAccent }
        if hoy { return Paper.accentInk }
        return delMes ? Paper.ink : Paper.inkFaint.opacity(0.45)
    }
}

private extension Calendar {
    func inicioDeMes(_ fecha: Date) -> Date {
        date(from: dateComponents([.year, .month], from: fecha)) ?? startOfDay(for: fecha)
    }
}
