import SwiftUI

struct SidebarView: View {
    @Environment(Store.self) private var store
    @Environment(Navigation.self) private var nav

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Sin cabecera de marca: el icono del Dock ya identifica la app, y un
            // logo dentro de su propia barra lateral solo come espacio vertical.
            VStack(alignment: .leading, spacing: 1) {
                SidebarRow(perspective: .inbox, label: "Bandeja")
                SidebarRow(perspective: .today, label: "Hoy")
                SidebarRow(perspective: .logbook, label: "Registro")
            }

            if !store.projects.isEmpty {
                Text("PROYECTOS")
                    .rubricStyle()
                    .padding(.horizontal, 20)
                    .padding(.top, 26)
                    .padding(.bottom, 8)

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
                HStack(spacing: 7) {
                    Text("\u{FF0B}").font(.system(size: 11, weight: .bold))
                    Text("Nuevo proyecto").font(.system(size: 12.5, weight: .medium))
                }
                .foregroundStyle(Paper.inkFaint)
                .padding(.horizontal, 20)
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

private struct SidebarRow: View {
    @Environment(Store.self) private var store
    @Environment(Navigation.self) private var nav
    let perspective: Perspective
    let label: String
    var project: Project?

    @State private var hovering = false

    private var isSelected: Bool { nav.perspective == perspective }

    var body: some View {
        let count = store.count(for: perspective)
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                .lineLimit(1)
            Spacer(minLength: 8)
            if count > 0, perspective != .logbook {
                Text("\(count)")
                    .font(.system(size: 11.5, weight: .semibold).monospacedDigit())
                    .foregroundStyle(isSelected ? Paper.accentInk : Paper.inkFaint)
            }
        }
        .padding(.leading, 18)
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
        .onHover { hovering = $0 }
        .onTapGesture { nav.go(to: perspective) }
        .contextMenu {
            if let project {
                Button("Eliminar proyecto", role: .destructive) {
                    if nav.perspective == .project(project.id) { nav.go(to: .inbox) }
                    store.delete(project)
                }
            }
        }
    }

    @ViewBuilder private var background: some View {
        if isSelected {
            Paper.accent.opacity(0.16)
        } else if hovering {
            Paper.ink.opacity(0.045)
        }
    }
}
