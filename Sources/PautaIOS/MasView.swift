import SwiftUI
import PautaCore

/// Todo lo que no cabe en tres pestañas.
///
/// Las listas de fondo, los proyectos, las áreas y las etiquetas. Aquí sí se
/// entra y se vuelve: son cosas que se visitan, no sitios donde se está.
struct MasView: View {
    @Environment(Store.self) private var store
    /// Qué nombre se está pidiendo, si se está pidiendo alguno.
    @State private var rotulo: Rotulo?
    @State private var nombre = ""

    /// Los cuatro momentos en que esta pantalla pide un nombre. Uno solo diálogo
    /// para los cuatro: son la misma pregunta —«¿cómo se llama?»— y cuatro
    /// diálogos distintos serían cuatro sitios donde arreglar la misma errata.
    private enum Rotulo: Identifiable {
        case proyectoNuevo
        case areaNueva
        case renombrarProyecto(Project)
        case renombrarArea(Area)

        var id: String {
            switch self {
            case .proyectoNuevo: "proyecto"
            case .areaNueva: "area"
            case .renombrarProyecto(let p): "p:\(p.id)"
            case .renombrarArea(let a): "a:\(a.id)"
            }
        }
        var titulo: String {
            switch self {
            case .proyectoNuevo: "Proyecto nuevo"
            case .areaNueva: "Área nueva"
            case .renombrarProyecto: "Renombrar proyecto"
            case .renombrarArea: "Renombrar área"
            }
        }
        var boton: String {
            switch self {
            case .proyectoNuevo, .areaNueva: "Crear"
            case .renombrarProyecto, .renombrarArea: "Renombrar"
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("LISTAS") {
                    fila(.anytime, "list.bullet")
                    fila(.someday, "shippingbox")
                    fila(.completed, "checkmark.circle")
                }
                if !store.areas.isEmpty || !store.projects.isEmpty {
                    Section("PROYECTOS") {
                        // Sueltos primero y luego por área: el orden de la barra
                        // lateral del Mac, que es el que el usuario decidió.
                        ForEach(store.projects.filter { $0.areaID == nil }) { proyecto in
                            filaProyecto(proyecto)
                        }
                        ForEach(store.areas) { area in
                            NavigationLink {
                                ListaView(perspectiva: .area(area.id))
                            } label: {
                                Label {
                                    Text(area.name).foregroundStyle(Papel.ink)
                                } icon: {
                                    Text(area.icon.isEmpty ? "🗂" : area.icon).font(.system(size: 15))
                                }
                            }
                            // Eliminar un área tampoco se lleva sus proyectos:
                            // los suelta, y pasan a la lista de arriba.
                            .swipeActions(edge: .trailing) {
                                Button("Eliminar", role: .destructive) { store.delete(area) }
                                Button("Renombrar") { pedirNombre(.renombrarArea(area)) }
                                    .tint(Papel.accentInk)
                            }
                            ForEach(store.projects(in: area.id)) { proyecto in
                                filaProyecto(proyecto, sangrado: true)
                            }
                        }
                    }
                }
                if !store.allTags.isEmpty {
                    Section("ETIQUETAS") {
                        ForEach(store.allTags, id: \.self) { tag in
                            NavigationLink {
                                ListaView(perspectiva: .tag(tag))
                            } label: {
                                Label(tag, systemImage: "tag")
                            }
                        }
                    }
                }
                // Al final, siempre: los ajustes son lo que menos se abre, y
                // ponerlos entre las listas los cruza con lo que sí se usa.
                Section {
                    NavigationLink {
                        AjustesView()
                    } label: {
                        Label("Ajustes", systemImage: "gearshape")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Papel.bg)
            .navigationTitle("Más")
            // Hasta ahora los proyectos aquí eran de **solo lectura**: se veían
            // los del Mac y no se podía crear ninguno, que en un teléfono sin
            // sincronizar deja la sección vacía para siempre.
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { pedirNombre(.proyectoNuevo) } label: {
                            Label("Proyecto nuevo", systemImage: "folder.badge.plus")
                        }
                        Button { pedirNombre(.areaNueva) } label: {
                            Label("Área nueva", systemImage: "square.grid.2x2")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert(rotulo?.titulo ?? "", isPresented: Binding(
                get: { rotulo != nil },
                set: { if !$0 { rotulo = nil } }
            ), presenting: rotulo) { cual in
                TextField("Nombre", text: $nombre)
                Button("Cancelar", role: .cancel) {}
                Button(cual.boton) { aplicar(cual) }
            }
        }
    }

    private func pedirNombre(_ cual: Rotulo) {
        switch cual {
        case .proyectoNuevo, .areaNueva: nombre = ""
        case .renombrarProyecto(let p): nombre = p.name
        case .renombrarArea(let a): nombre = a.name
        }
        rotulo = cual
    }

    private func aplicar(_ cual: Rotulo) {
        let limpio = nombre.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !limpio.isEmpty else { return }
        switch cual {
        case .proyectoNuevo: _ = store.addProject(name: limpio)
        case .areaNueva: _ = store.addArea(name: limpio)
        case .renombrarProyecto(let p): store.rename(p, to: limpio)
        case .renombrarArea(let a): store.rename(a, to: limpio)
        }
    }

    private func fila(_ perspectiva: Perspective, _ icono: String) -> some View {
        NavigationLink {
            ListaView(perspectiva: perspectiva)
        } label: {
            HStack {
                Label(store.title(for: perspectiva), systemImage: icono)
                Spacer()
                let n = store.count(for: perspectiva)
                if n > 0 {
                    Text("\(n)")
                        .font(.system(size: 14, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Papel.inkFaint)
                }
            }
        }
    }

    /// Deslizar da renombrar y eliminar.
    ///
    /// Eliminar un proyecto **no se lleva sus tareas**: las suelta, y las que no
    /// tengan fecha caen a la bandeja. Por eso el botón no pide confirmación:
    /// no hay nada que perder, y un diálogo por cada borrado sin consecuencias
    /// es un diálogo que se aprende a pulsar sin leer.
    private func filaProyecto(_ proyecto: Project, sangrado: Bool = false) -> some View {
        NavigationLink {
            ListaView(perspectiva: .project(proyecto.id))
        } label: {
            HStack {
                if sangrado { Spacer().frame(width: 14) }
                Label {
                    Text(proyecto.name).foregroundStyle(Papel.ink)
                } icon: {
                    Text(proyecto.icon.isEmpty ? "📁" : proyecto.icon).font(.system(size: 15))
                }
                Spacer()
                let n = store.count(for: .project(proyecto.id))
                if n > 0 {
                    Text("\(n)")
                        .font(.system(size: 14, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Papel.inkFaint)
                }
            }
        }
        .swipeActions(edge: .trailing) {
            Button("Eliminar", role: .destructive) { store.delete(proyecto) }
            Button("Renombrar") { pedirNombre(.renombrarProyecto(proyecto)) }
                .tint(Papel.accentInk)
        }
    }
}
