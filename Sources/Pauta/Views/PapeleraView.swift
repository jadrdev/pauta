import SwiftUI
import PautaCore

/// Lo borrado que todavía se puede recuperar.
///
/// Borrar nunca borró: pone una lápida y el almacén la guarda treinta días. Lo
/// que faltaba no era guardar, era **una puerta** — y sin ella borrar era la
/// única acción sin vuelta atrás de toda la app, alcanzable desde un
/// deslizamiento en el teléfono y propagada al Mac y al reloj por la carpeta
/// antes de que levantes el dedo.
///
/// No es una lista más y no se disfraza de una: aquí las tareas **no se tachan
/// ni se editan**, porque una tarea borrada no es una tarea pendiente. Solo se
/// puede devolver, que es lo único que se viene a hacer.
struct PapeleraView: View {
    @Environment(Store.self) private var store
    @Environment(Navigation.self) private var nav

    @State private var vaciando = false

    private var vacia: Bool { !store.papeleraLlena }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                cabecera
                Rectangle().fill(Paper.hairline).frame(height: 1)
                    .padding(.top, 16).padding(.bottom, 10)

                if vacia {
                    vacio.padding(.top, 26)
                } else {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(store.areasBorradas) { area in
                            FilaBorrada(icono: area.icon.isEmpty ? nil : area.icon,
                                        simbolo: "square.stack",
                                        titulo: area.name.isEmpty ? "Sin título" : area.name,
                                        detalle: detalleArea(area),
                                        cuando: area.deletedAt) {
                                store.restaurarArea(area.id)
                            }
                        }
                        ForEach(store.proyectosBorrados) { proyecto in
                            FilaBorrada(icono: proyecto.icon.isEmpty ? nil : proyecto.icon,
                                        simbolo: "circle.dotted",
                                        titulo: proyecto.name.isEmpty ? "Sin título" : proyecto.name,
                                        detalle: detalleProyecto(proyecto),
                                        cuando: proyecto.deletedAt) {
                                store.restaurarProyecto(proyecto.id)
                            }
                        }
                        ForEach(store.borradas) { tarea in
                            FilaBorrada(icono: nil,
                                        simbolo: nil,
                                        titulo: tarea.title.isEmpty ? "Sin título" : tarea.title,
                                        detalle: nil,
                                        cuando: tarea.deletedAt) {
                                store.restaurar(tarea.id)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 46).padding(.top, 46).padding(.bottom, 60)
            .frame(maxWidth: 700, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(Paper.bg)
        .confirmationDialog("¿Vaciar la papelera?", isPresented: $vaciando) {
            Button("Vaciar", role: .destructive) { store.vaciarPapelera() }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Esto sí borra de verdad, y no se puede deshacer. "
                 + "Lo que no toques se irá solo a los treinta días.")
        }
    }

    @ViewBuilder private var cabecera: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("Papelera")
                .font(.display(30)).tracking(-0.6).foregroundStyle(Paper.ink)
            Spacer(minLength: 0)
            if !vacia {
                Button { vaciando = true } label: {
                    Text("VACIAR").rubricStyle(Paper.accentInk)
                }
                .buttonStyle(.plain)
                .help("Borrar de verdad lo que hay aquí, sin esperar a los treinta días")
            }
        }
    }

    private var vacio: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("La papelera está vacía.")
                .font(.system(size: 14)).foregroundStyle(Paper.inkSoft)
            Text("Lo que borres aparece aquí y se puede devolver durante treinta días.")
                .font(.system(size: 12.5)).foregroundStyle(Paper.inkFaint)
        }
    }

    /// Lo que se va a devolver con él, que es lo que hace falta saber antes de
    /// pulsar: un proyecto vacío y una carpeta con quince tareas dentro se leen
    /// igual en una lista.
    private func detalleProyecto(_ p: Project) -> String? {
        let vuelven = p.sueltos.filter { id in
            store.items.contains { $0.id == id && $0.projectID == nil }
        }.count
        guard vuelven > 0 else { return "proyecto" }
        return vuelven == 1 ? "proyecto · vuelve con 1 tarea"
                            : "proyecto · vuelve con \(vuelven) tareas"
    }

    private func detalleArea(_ a: Area) -> String? {
        let vuelven = a.sueltos.filter { id in
            store.projects.contains { $0.id == id && $0.areaID == nil }
        }.count
        guard vuelven > 0 else { return "área" }
        return vuelven == 1 ? "área · vuelve con 1 proyecto"
                            : "área · vuelve con \(vuelven) proyectos"
    }
}

/// Una fila de la papelera. El botón de devolver solo aparece al pasar por
/// encima, como el «⋯» de la barra lateral: la lista se lee sin una columna de
/// botones repetidos, y la acción está donde miras.
private struct FilaBorrada: View {
    let icono: String?
    let simbolo: String?
    let titulo: String
    let detalle: String?
    let cuando: Date?
    let devolver: () -> Void

    @State private var encima = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            if let icono {
                Text(icono).font(.system(size: 12))
            } else if let simbolo {
                Image(systemName: simbolo)
                    .font(.system(size: 11)).foregroundStyle(Paper.inkFaint)
                    .frame(width: 14)
            } else {
                // Ni casilla ni círculo: lo borrado no se completa.
                Image(systemName: "minus")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Paper.inkFaint.opacity(0.5))
                    .frame(width: 14)
            }
            Text(titulo)
                .font(.system(size: 13.5))
                .foregroundStyle(Paper.inkSoft)
                .lineLimit(1)
            if let detalle {
                Text(detalle).rubricStyle()
            }
            Spacer(minLength: 12)
            if let cuando {
                Text(Retention.leQuedan(desde: cuando))
                    .font(.system(size: 11.5))
                    .foregroundStyle(Paper.inkFaint)
                    .help("Se borra solo cuando pase el plazo")
            }
            Button("Devolver", action: devolver)
                .buttonStyle(.plain)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(Paper.accentInk)
                .opacity(encima ? 1 : 0)
        }
        .padding(.vertical, 7)
        .contentShape(Rectangle())
        .onHover { encima = $0 }
        .overlay(alignment: .bottom) {
            Rectangle().fill(Paper.hairline).frame(height: 1)
        }
    }
}
