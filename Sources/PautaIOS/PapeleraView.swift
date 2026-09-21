import SwiftUI
import PautaCore

/// Lo borrado que todavía se puede recuperar, en el teléfono.
///
/// Aquí es donde más falta hacía: en el Mac hay que abrir un menú para borrar,
/// y en el teléfono basta **deslizar** — el mismo gesto con el que se archiva un
/// correo, sobre una lista que también borra proyectos y áreas enteras. Y como
/// la carpeta va por iCloud, un deslizamiento mal dado llegaba al Mac y al reloj
/// antes de que levantaras el dedo.
///
/// Lo borrado no se tacha ni se abre: una tarea borrada no es una tarea
/// pendiente. Solo se devuelve.
struct PapeleraView: View {
    @Environment(Store.self) private var store
    @State private var vaciando = false

    var body: some View {
        List {
            if !store.papeleraLlena {
                Section {
                    Text("Aquí aparece lo que borres, y se puede devolver "
                         + "durante treinta días.")
                        .font(.system(size: 14))
                        .foregroundStyle(Papel.inkFaint)
                        .listRowBackground(Papel.bg)
                }
            }
            if !store.areasBorradas.isEmpty {
                Section("ÁREAS") {
                    ForEach(store.areasBorradas) { area in
                        Fila(titulo: area.name, icono: area.icon, simbolo: "square.grid.2x2",
                             detalle: cuentaDeArea(area), cuando: area.deletedAt) {
                            store.restaurarArea(area.id)
                        }
                    }
                }
            }
            if !store.proyectosBorrados.isEmpty {
                Section("PROYECTOS") {
                    ForEach(store.proyectosBorrados) { p in
                        Fila(titulo: p.name, icono: p.icon, simbolo: "folder",
                             detalle: cuentaDeProyecto(p), cuando: p.deletedAt) {
                            store.restaurarProyecto(p.id)
                        }
                    }
                }
            }
            if !store.borradas.isEmpty {
                Section("TAREAS") {
                    ForEach(store.borradas) { t in
                        Fila(titulo: t.title, icono: "", simbolo: nil,
                             detalle: nil, cuando: t.deletedAt) {
                            store.restaurar(t.id)
                        }
                    }
                }
            }
            if store.papeleraLlena {
                Section {
                    Button("Vaciar la papelera", role: .destructive) { vaciando = true }
                        .listRowBackground(Papel.bg)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Papel.bg)
        .navigationTitle("Papelera")
        .confirmationDialog("¿Vaciar la papelera?", isPresented: $vaciando,
                            titleVisibility: .visible) {
            Button("Vaciar", role: .destructive) { store.vaciarPapelera() }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Esto sí borra de verdad y no se puede deshacer. "
                 + "Lo que no toques se irá solo a los treinta días.")
        }
    }

    /// Con cuántas vuelve, que es lo que hace falta saber antes de pulsar: un
    /// proyecto vacío y uno con quince tareas dentro se leen igual en una lista.
    private func cuentaDeProyecto(_ p: Project) -> String? {
        let vuelven = p.sueltos.filter { id in
            store.items.contains { $0.id == id && $0.projectID == nil }
        }.count
        guard vuelven > 0 else { return nil }
        return vuelven == 1 ? "vuelve con 1 tarea" : "vuelve con \(vuelven) tareas"
    }

    private func cuentaDeArea(_ a: Area) -> String? {
        let vuelven = a.sueltos.filter { id in
            store.projects.contains { $0.id == id && $0.areaID == nil }
        }.count
        guard vuelven > 0 else { return nil }
        return vuelven == 1 ? "vuelve con 1 proyecto" : "vuelve con \(vuelven) proyectos"
    }
}

/// Una fila. El botón de devolver **se desliza**, como todo lo demás en estas
/// listas: aquí el deslizamiento es el que arregla, no el que rompe.
private struct Fila: View {
    let titulo: String
    let icono: String
    let simbolo: String?
    let detalle: String?
    let cuando: Date?
    let devolver: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if !icono.isEmpty {
                Text(icono).font(.system(size: 15))
            } else if let simbolo {
                Image(systemName: simbolo)
                    .font(.system(size: 13)).foregroundStyle(Papel.inkFaint)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(titulo.isEmpty ? "Sin título" : titulo)
                    .font(.system(size: 16)).foregroundStyle(Papel.inkSoft)
                HStack(spacing: 6) {
                    if let detalle { Text(detalle) }
                    if detalle != nil && cuando != nil { Text("·") }
                    if let cuando { Text(Retention.leQuedan(desde: cuando)) }
                }
                .font(.system(size: 12.5))
                .foregroundStyle(Papel.inkFaint)
            }
            Spacer(minLength: 8)
        }
        .listRowBackground(Papel.bg)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button("Devolver", action: devolver).tint(Papel.accentInk)
        }
        .swipeActions(edge: .trailing) {
            Button("Devolver", action: devolver).tint(Papel.accentInk)
        }
    }
}
