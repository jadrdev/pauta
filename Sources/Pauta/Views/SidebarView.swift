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

            if !store.projects.isEmpty {
                CabeceraProyectos()

                VStack(alignment: .leading, spacing: 1) {
                    ForEach(store.projects) { project in
                        SidebarRow(perspective: .project(project.id),
                                   label: project.name.isEmpty ? "Sin título" : project.name,
                                   project: project)
                    }
                }
            }

            Spacer(minLength: 20)

            Button {
                let project = store.addProject(name: "")
                nav.go(to: .project(project.id))
            } label: {
                HStack(spacing: 9) {
                    // El «+» ocupa la columna del icono, el texto la de la etiqueta.
                    Text("\u{FF0B}")
                        .font(.system(size: 11, weight: .bold))
                        .frame(width: 17, alignment: .center)
                    Text("Nuevo proyecto").font(.system(size: 12.5, weight: .medium))
                }
                .foregroundStyle(Paper.inkFaint)
                .padding(.leading, 15)
                .padding(.trailing, 18)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
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
}

/// El rótulo «PROYECTOS» y, al pasar por encima, el atajo para ordenarlos.
///
/// El botón solo aparece con el cursor encima: ordenar es algo que se hace de
/// año en año, y un control permanente ahí arriba pesaría más de lo que sirve.
private struct CabeceraProyectos: View {
    @Environment(Store.self) private var store
    @State private var encima = false

    var body: some View {
        HStack(spacing: 8) {
            Text("PROYECTOS").rubricStyle()
            Spacer(minLength: 8)
            if encima {
                Button { store.sortProjectsAlphabetically() } label: {
                    Text("A–Z").rubricStyle(Paper.accentInk)
                }
                .buttonStyle(.plain)
                .help("Ordenar los proyectos alfabéticamente")
            }
        }
        // Alineado con la columna de texto de las filas: 15 + 17 + 9.
        .padding(.leading, 41)
        .padding(.trailing, 18)
        .padding(.top, 26)
        .padding(.bottom, 8)
        .contentShape(Rectangle())
        .onHover { encima = $0 }
    }
}

private struct SidebarRow: View {
    @Environment(Store.self) private var store
    @Environment(Navigation.self) private var nav
    let perspective: Perspective
    let label: String
    var project: Project?

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
        .padding(.leading, 15)
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
                Button("Ordenar proyectos alfabéticamente") {
                    store.sortProjectsAlphabetically()
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
    private var reordenando: Bool { project != nil && nav.arrastrandoProyecto }

    private static let prefijo = "proyecto:"

    private func cargaDeArrastre(_ project: Project) -> String {
        nav.arrastrandoProyecto = true
        return Self.prefijo + project.id.uuidString
    }

    /// Qué hacer con lo que se suelta encima.
    ///
    /// El texto arrastrado dice qué es: las tareas viajan como su UUID pelado y
    /// los proyectos con un prefijo delante. Hace falta porque los dos son un
    /// UUID y caen sobre la misma fila, y sin distinguirlos un proyecto soltado
    /// sobre otro se interpretaría como una tarea que no existe.
    private func recibir(_ payload: [String]) -> Bool {
        if let project, let arrastrado = payload.compactMap(proyecto).first {
            guard arrastrado.id != project.id else { return false }
            store.place(arrastrado, before: project)
            return true
        }
        let tareas = payload
            .compactMap(UUID.init(uuidString:))
            .compactMap { id in store.items.first { $0.id == id } }
        for item in tareas { store.move(item, to: perspective) }
        return !tareas.isEmpty
    }

    private func proyecto(_ payload: String) -> Project? {
        guard payload.hasPrefix(Self.prefijo),
              let id = UUID(uuidString: String(payload.dropFirst(Self.prefijo.count)))
        else { return nil }
        return store.project(id)
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
