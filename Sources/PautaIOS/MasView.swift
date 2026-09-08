import SwiftUI
import PautaCore

/// Todo lo que no cabe en tres pestañas.
///
/// Las listas de fondo, los proyectos, las áreas y las etiquetas. Aquí sí se
/// entra y se vuelve: son cosas que se visitan, no sitios donde se está.
struct MasView: View {
    @Environment(Store.self) private var store

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
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Papel.bg)
            .navigationTitle("Más")
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
    }
}
