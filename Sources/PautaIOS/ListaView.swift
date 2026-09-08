import SwiftUI
import PautaCore

/// Una lista de tareas.
///
/// La misma vista para las cinco listas, los proyectos, las áreas y las
/// etiquetas: son consultas sobre las mismas tareas, así que enseñarlas con
/// vistas distintas sería mantener la misma pantalla varias veces.
struct ListaView: View {
    let perspectiva: Perspective

    @Environment(Store.self) private var store
    @State private var abierta: Item?
    @State private var apuntando = false

    private var items: [Item] { store.items(for: perspectiva) }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                contenido
                if !apuntando { BotonDeApuntar { apuntando = true } }
            }
            .background(Papel.bg)
            .navigationTitle(store.title(for: perspectiva))
            .navigationBarTitleDisplayMode(.large)
            // Como franja del área segura y no como superposición: una
            // superposición se queda **debajo** de la barra de pestañas, y el
            // teclado la tapa. Así el sistema la coloca sobre el teclado él.
            .safeAreaInset(edge: .bottom) {
                if apuntando {
                    CapturaView(perspectiva: perspectiva) { apuntando = false }
                }
            }
            // Mientras se apunta, las pestañas se van: no se cambia de sección
            // con el teclado abierto, y su barra flotante robaba el sitio justo
            // donde hay que escribir.
            .toolbar(apuntando ? .hidden : .visible, for: .tabBar)
        }
        .sheet(item: $abierta) { DetalleView(item: $0) }
    }

    @ViewBuilder private var contenido: some View {
        if items.isEmpty {
            VacioView(perspectiva: perspectiva)
        } else {
            List {
                // La cuenta va aquí y no en la barra: en la barra, un texto
                // suelto se dibuja dentro de una cápsula y parece un botón que
                // no hace nada.
                Text(cuenta)
                    .rubrica()
                    .listRowBackground(Papel.bg)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 6, trailing: 16))
                ForEach(items) { item in
                    FilaView(item: item) { abierta = item }
                        .listRowBackground(Papel.bg)
                        .listRowInsets(EdgeInsets(top: 9, leading: 16,
                                                  bottom: 9, trailing: 16))
                        .listRowSeparatorTint(Papel.hairline)
                        .swipeActions(edge: .trailing) {
                            Button("Eliminar", role: .destructive) { store.delete(item) }
                        }
                        .swipeActions(edge: .leading) {
                            // Aplazar a mano es lo que evita que una tarea se
                            // quede mirándote todo el día sin poder tocarla.
                            Button("Hoy") { store.schedule(item, to: .now) }
                                .tint(Papel.accentInk)
                        }
                }
                // Aire al final: sin esto, el botón de apuntar tapa la última
                // fila y no hay forma de completarla.
                Color.clear.frame(height: 64)
                    .listRowBackground(Papel.bg)
                    .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private var cuenta: String {
        let n = items.count
        if case .completed = perspectiva { return n == 1 ? "1 TAREA" : "\(n) TAREAS" }
        return n == 1 ? "1 ABIERTA" : "\(n) ABIERTAS"
    }
}

/// Lo que se dice cuando no hay nada, que no es lo mismo en cada lista.
struct VacioView: View {
    let perspectiva: Perspective

    var body: some View {
        VStack(spacing: 7) {
            Image(systemName: icono)
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(Papel.hairline)
            Text(texto)
                .font(.system(size: 15))
                .foregroundStyle(Papel.inkFaint)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
    }

    private var icono: String {
        switch perspectiva {
        case .today: "sun.max"
        case .upcoming: "calendar"
        case .inbox: "tray"
        case .completed: "checkmark.circle"
        default: "list.bullet"
        }
    }

    private var texto: String {
        switch perspectiva {
        case .today: "Nada para hoy. Buen día para no hacer nada."
        case .inbox: "La bandeja está vacía."
        case .upcoming: "Nada planificado más adelante."
        case .someday: "Nada aparcado."
        case .completed: "Todavía no has completado nada."
        default: "Nada por aquí."
        }
    }
}
