import SwiftUI
import PautaCore

/// Pauta en el teléfono.
///
/// Comparte con el Mac todo el núcleo —modelo, almacén, consultas, avisos— y no
/// comparte una sola vista, a propósito. Un teléfono no se maneja como un Mac:
/// no hay barra lateral que quepa, no hay clic derecho, y la mano tapa media
/// pantalla.
@main
@MainActor
struct PautaIOSApp: App {
    @State private var store = Store()

    init() {
        // Antes de la interfaz: un aviso pulsado con la app cerrada se entrega
        // sin nadie que lo atienda si el delegado llega tarde.
        Avisos.hookUp()
    }

    var body: some Scene {
        WindowGroup {
            RaizView()
                .environment(store)
                .tint(Papel.accentInk)
        }
    }
}

/// Las pestañas.
///
/// Abajo y no en una tira arriba: es donde llega el pulgar, es un toque para
/// cambiar, y es lo que iOS entiende por «cambiar de sección» —una fila de
/// fichas arriba es un patrón de web, y en un teléfono se lee como un
/// navegador—.
///
/// Cuatro y no siete. Las tres que se usan a diario tienen su sitio fijo; el
/// resto —las listas de fondo, los proyectos, las áreas, las etiquetas— vive en
/// «Más», porque una barra de siete iconos no se lee: se adivina.
struct RaizView: View {
    @Environment(Store.self) private var store
    @Environment(\.scenePhase) private var fase

    var body: some View {
        TabView {
            ListaView(perspectiva: .today)
                .tabItem { Label("Hoy", systemImage: "sun.max") }
            ListaView(perspectiva: .upcoming)
                .tabItem { Label("Próximamente", systemImage: "calendar") }
            ListaView(perspectiva: .inbox)
                .tabItem { Label("Bandeja", systemImage: "tray") }
            MasView()
                .tabItem { Label("Más", systemImage: "ellipsis") }
        }
        // Al volver del fondo: el día pudo cambiar mientras la app dormía, y lo
        // que era «de hoy» pasó a ser atrasado.
        .onChange(of: fase) { _, nueva in
            guard nueva == .active else { return }
            store.reload()
            Task { await Avisos.reschedule(store.items) }
        }
        .task(id: store.items) {
            // Un segundo de espera, como en el Mac: escribir un título cambia
            // las tareas en cada tecla.
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            await Avisos.reschedule(store.items)
        }
    }
}
