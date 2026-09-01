import SwiftUI
import PautaCore

struct SidebarView: View {
    @Environment(Store.self) private var store
    @Environment(Navigation.self) private var nav

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Sin cabecera de marca: el icono del Dock ya identifica la app, y un
            // logo dentro de su propia barra lateral solo come espacio vertical.
            VStack(alignment: .leading, spacing: 1) {
                ForEach(Perspective.allCases, id: \.self) { perspective in
                    SidebarRow(perspective: perspective, label: perspective.title)
                }
            }

            // El grupo «sin área» se muestra en cuanto hay algo que agrupar,
            // aunque esté vacío: es el sitio donde se sueltan los proyectos para
            // sacarlos de un área, y sin él no habría forma de sacarlos
            // arrastrando.
            if !store.projects.isEmpty || !store.areas.isEmpty {
                CabeceraProyectos()

                VStack(alignment: .leading, spacing: 1) {
                    ForEach(store.projects(in: nil)) { project in
                        fila(project)
                    }
                }
            }

            ForEach(store.areas) { area in
                AreaRow(area: area)
                VStack(alignment: .leading, spacing: 1) {
                    // Sangrados: lo que cuelga de un área se lee de un vistazo.
                    ForEach(store.projects(in: area.id)) { project in
                        fila(project, sangria: 14)
                    }
                }
            }

            Spacer(minLength: 20)

            botonNuevo("Nuevo proyecto") {
                let project = store.addProject(name: "")
                nav.go(to: .project(project.id))
            }
            botonNuevo("Nueva área") {
                let area = store.addArea(name: "")
                nav.go(to: .area(area.id))
            }
            .padding(.bottom, 4)
        }
        // Hueco para los botones de la ventana, que flotan sobre la barra lateral.
        // NavigationSplitView ya reserva el margen de la zona del titular, así
        // que aquí solo hace falta un respiro por debajo de los botones.
        .padding(.top, 14)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Paper.bgSide)
        .overlay(alignment: .trailing) {
            Rectangle().fill(Paper.hairline).frame(width: 1)
        }
    }

    private func fila(_ project: Project, sangria: CGFloat = 0) -> some View {
        SidebarRow(perspective: .project(project.id),
                   label: project.name.isEmpty ? "Sin título" : project.name,
                   project: project,
                   sangria: sangria)
    }

    private func botonNuevo(_ titulo: String, accion: @escaping () -> Void) -> some View {
        Button(action: accion) {
            HStack(spacing: 9) {
                // El «+» ocupa la columna del icono, el texto la de la etiqueta.
                Text("\u{FF0B}")
                    .font(.system(size: 11, weight: .bold))
                    .frame(width: 17, alignment: .center)
                Text(titulo).font(.system(size: 12.5, weight: .medium))
            }
            .foregroundStyle(Paper.inkFaint)
            .padding(.leading, 15)
            .padding(.trailing, 18)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// El rótulo «PROYECTOS» y, al pasar por encima, el atajo para ordenarlos.
///
/// El botón solo aparece con el cursor encima: ordenar es algo que se hace de
/// año en año, y un control permanente ahí arriba pesaría más de lo que sirve.
private struct CabeceraProyectos: View {
    @Environment(Store.self) private var store
    @State private var encima = false
    @State private var recibiendo = false

    var body: some View {
        HStack(spacing: 8) {
            Text("PROYECTOS").rubricStyle(recibiendo ? Paper.accentInk : Paper.inkFaint)
            Spacer(minLength: 8)
            if encima {
                Button { store.sortAlphabetically() } label: {
                    Text("A–Z").rubricStyle(Paper.accentInk)
                }
                .buttonStyle(.plain)
                .help("Ordenar áreas y proyectos alfabéticamente")
            }
        }
        // Alineado con la columna de texto de las filas: 15 + 17 + 9.
        .padding(.leading, 41)
        .padding(.trailing, 18)
        .padding(.top, 26)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(recibiendo ? Paper.accent.opacity(0.30) : .clear)
        .contentShape(Rectangle())
        // Soltar aquí un proyecto lo saca del área en la que estuviera.
        .dropDestination(for: String.self) { payload, _ in
            let sueltos = payload.compactMap(Arrastre.proyecto).compactMap(store.project)
            for project in sueltos { store.move(project, toArea: nil) }
            return !sueltos.isEmpty
        } isTargeted: { recibiendo = $0 }
        .onHover { encima = $0 }
    }
}

/// Un área en la barra lateral: rótulo de grupo, pero además se puede pinchar
/// para ver todo lo pendiente de sus proyectos.
private struct AreaRow: View {
    @Environment(Store.self) private var store
    @Environment(Navigation.self) private var nav
    let area: Area

    @State private var encima = false
    @State private var recibiendo = false

    private var seleccionada: Bool { nav.perspective == .area(area.id) }
    /// Se está arrastrando otra área: entonces esto es reordenar, no meter.
    private var reordenando: Bool { nav.arrastrando == .area }

    var body: some View {
        let cuenta = store.count(for: .area(area.id))
        HStack(spacing: 8) {
            if !area.icon.isEmpty {
                Text(area.icon).font(.system(size: 11))
            }
            Text((area.name.isEmpty ? "Sin título" : area.name).uppercased())
                .rubricStyle(seleccionada ? Paper.accentInk : Paper.inkSoft)
                .lineLimit(1)
            Spacer(minLength: 8)
            if cuenta > 0 {
                Text("\(cuenta)")
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                    .foregroundStyle(seleccionada ? Paper.accentInk : Paper.inkFaint)
            }
        }
        .padding(.leading, 15)
        .padding(.trailing, 18)
        .padding(.top, 22)
        .padding(.bottom, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(fondo)
        .overlay(alignment: .leading) {
            Rectangle().fill(seleccionada ? Paper.accent : .clear).frame(width: 3)
        }
        .overlay(alignment: .top) {
            if recibiendo, reordenando {
                Rectangle().fill(Paper.accent).frame(height: 2).padding(.top, 10)
            }
        }
        .contentShape(Rectangle())
        .draggable(cargaDeArrastre())
        .dropDestination(for: String.self) { payload, _ in recibir(payload) }
            isTargeted: { recibiendo = $0 }
        .onHover { encima = $0 }
        .onTapGesture { nav.go(to: .area(area.id)) }
        .contextMenu {
            Button("Ordenar áreas y proyectos alfabéticamente") {
                store.sortAlphabetically()
            }
            Divider()
            Button("Eliminar área", role: .destructive) {
                if nav.perspective == .area(area.id) { nav.go(to: .inbox) }
                store.delete(area)
            }
        }
    }

    @ViewBuilder private var fondo: some View {
        if recibiendo, !reordenando {
            Paper.accent.opacity(0.30)
        } else if seleccionada {
            Paper.accent.opacity(0.16)
        } else if encima {
            Paper.ink.opacity(0.045)
        }
    }

    private func cargaDeArrastre() -> String {
        nav.arrastrando = .area
        return Arrastre.prefijoArea + area.id.uuidString
    }

    /// Un área recibe dos cosas: otra área, que se coloca antes; y un proyecto,
    /// que pasa a formar parte de ella. Tareas no: no tendría a qué colgarlas.
    private func recibir(_ payload: [String]) -> Bool {
        if let otra = payload.compactMap(Arrastre.area).compactMap(store.area).first {
            guard otra.id != area.id else { return false }
            store.place(otra, before: area)
            return true
        }
        let proyectos = payload.compactMap(Arrastre.proyecto).compactMap(store.project)
        for project in proyectos { store.move(project, toArea: area.id) }
        return !proyectos.isEmpty
    }
}

/// Cómo viaja lo arrastrado.
///
/// Tareas, proyectos y áreas son todos un UUID y caen sobre las mismas filas,
/// así que el texto lleva delante de qué se trata. Sin eso, soltar un proyecto
/// sobre otro se leería como una tarea que no existe.
enum Arrastre {
    static let prefijoProyecto = "proyecto:"
    static let prefijoArea = "area:"

    static func proyecto(_ payload: String) -> UUID? { id(payload, prefijoProyecto) }
    static func area(_ payload: String) -> UUID? { id(payload, prefijoArea) }
    /// Las tareas viajan como su UUID pelado.
    static func tarea(_ payload: String) -> UUID? { UUID(uuidString: payload) }

    private static func id(_ payload: String, _ prefijo: String) -> UUID? {
        guard payload.hasPrefix(prefijo) else { return nil }
        return UUID(uuidString: String(payload.dropFirst(prefijo.count)))
    }
}

private struct SidebarRow: View {
    @Environment(Store.self) private var store
    @Environment(Navigation.self) private var nav
    let perspective: Perspective
    let label: String
    var project: Project?
    var sangria: CGFloat = 0

    @State private var hovering = false
    @State private var isDropTarget = false

    private var isSelected: Bool { nav.perspective == perspective }

    var body: some View {
        let count = store.count(for: perspective)
        HStack(spacing: 9) {
            // Monocromo y un paso más tenue que la etiqueta: el icono ayuda a
            // apuntar, pero el texto sigue siendo lo primero que se lee. El
            // emoji del proyecto, si lo tiene, ocupa el sitio del símbolo.
            if let project, !project.icon.isEmpty {
                Text(project.icon)
                    .font(.system(size: 12))
                    .frame(width: 17, alignment: .center)
            } else {
                Image(systemName: perspective.symbol)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(isSelected ? Paper.accentInk : Paper.inkFaint)
                    .frame(width: 17, alignment: .center)
            }
            Text(label)
                .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                .lineLimit(1)
            Spacer(minLength: 8)
            if count > 0, perspective.showsCount {
                Text("\(count)")
                    .font(.system(size: 11.5, weight: .semibold).monospacedDigit())
                    .foregroundStyle(isSelected ? Paper.accentInk : Paper.inkFaint)
            }
        }
        .padding(.leading, 15 + sangria)
        .padding(.trailing, 18)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(isSelected ? Paper.ink : Paper.inkSoft)
        .background(background)
        // Marca de selección: filete en el margen, sin pastillas de color.
        // En overlay para que el alto lo fije el contenido, no el rectángulo.
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(isSelected ? Paper.accent : .clear)
                .frame(width: 3)
        }
        .contentShape(Rectangle())
        // Los proyectos se arrastran para ordenarlos entre ellos.
        .modifier(ArrastrableSiEsProyecto(project: project, carga: cargaDeArrastre))
        .dropDestination(for: String.self) { payload, _ in recibir(payload) }
            isTargeted: { isDropTarget = $0 }
        // Reordenando, una línea de inserción; recibiendo una tarea, la fila
        // entera encendida. Son dos gestos distintos y no deben parecer el mismo.
        .overlay(alignment: .top) {
            if isDropTarget, reordenando {
                Rectangle().fill(Paper.accent).frame(height: 2)
            }
        }
        .onHover { hovering = $0 }
        .onTapGesture { nav.go(to: perspective) }
        .contextMenu {
            if let project {
                if !store.areas.isEmpty {
                    Menu("Área") {
                        Button("Sin área") { store.move(project, toArea: nil) }
                        Divider()
                        ForEach(store.areas) { area in
                            Button(area.name.isEmpty ? "Sin título" : area.name) {
                                store.move(project, toArea: area.id)
                            }
                        }
                    }
                }
                Button("Ordenar áreas y proyectos alfabéticamente") {
                    store.sortAlphabetically()
                }
                Divider()
                Button("Eliminar proyecto", role: .destructive) {
                    if nav.perspective == .project(project.id) { nav.go(to: .inbox) }
                    store.delete(project)
                }
            }
        }
    }

    /// Se está arrastrando un proyecto sobre otro: es reordenar, no mover.
    private var reordenando: Bool { project != nil && nav.arrastrando == .proyecto }

    private func cargaDeArrastre(_ project: Project) -> String {
        nav.arrastrando = .proyecto
        return Arrastre.prefijoProyecto + project.id.uuidString
    }

    /// Qué hacer con lo que se suelta encima.
    ///
    /// El texto arrastrado dice qué es: las tareas viajan como su UUID pelado y
    /// los proyectos con un prefijo delante. Hace falta porque los dos son un
    /// UUID y caen sobre la misma fila, y sin distinguirlos un proyecto soltado
    /// sobre otro se interpretaría como una tarea que no existe.
    private func recibir(_ payload: [String]) -> Bool {
        if let project, let arrastrado = payload.compactMap(Arrastre.proyecto)
                                                .compactMap(store.project).first {
            guard arrastrado.id != project.id else { return false }
            // Cae en el sitio del de destino, área incluida: si no, saltaría al
            // hueco pero se quedaría colgando de otro grupo.
            store.move(arrastrado, toArea: project.areaID)
            store.place(arrastrado, before: project)
            return true
        }
        let tareas = payload
            .compactMap(Arrastre.tarea)
            .compactMap { id in store.items.first { $0.id == id } }
        for item in tareas { store.move(item, to: perspective) }
        return !tareas.isEmpty
    }

    @ViewBuilder private var background: some View {
        if isDropTarget, !reordenando {
            // Más marcado que la selección: hay que ver dónde va a caer.
            Paper.accent.opacity(0.30)
        } else if isSelected {
            Paper.accent.opacity(0.16)
        } else if hovering {
            Paper.ink.opacity(0.045)
        }
    }
}


/// `draggable` solo para las filas de proyecto: las listas fijas no se mueven.
private struct ArrastrableSiEsProyecto: ViewModifier {
    let project: Project?
    let carga: (Project) -> String

    func body(content: Content) -> some View {
        if let project {
            content.draggable(carga(project))
        } else {
            content
        }
    }
}
