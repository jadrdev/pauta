import SwiftUI
import AppKit
import Observation
import PautaCore

/// Estado de navegación: qué lista se ve, qué tarea está seleccionada
/// y si hay una tarea nueva a medio escribir.
@Observable
@MainActor
final class Navigation {
    var perspective: Perspective = .today
    var selectedItemID: UUID?
    var isAddingItem = false

    func startNewItem() {
        if case .logbook = perspective { perspective = .inbox }
        selectedItemID = nil
        isAddingItem = true
    }

    func go(to perspective: Perspective) {
        self.perspective = perspective
        selectedItemID = nil
        isAddingItem = false
    }
}

/// Opciones de arranque para maquetar: datos falsos y apariencia forzada.
@MainActor
enum Launch {
    static var demo = false
    static var appearance: NSAppearance.Name?
    /// Vista inicial en maqueta, 1…5 según el orden de la barra lateral.
    static var view: Perspective?
}

/// Ejecuta trabajo asíncrono desde un punto de entrada síncrono sin bloquear el
/// hilo principal: hacerlo con un semáforo daría interbloqueo, porque el trabajo
/// necesita ese mismo hilo. Se hace girando el bucle de eventos, que además es
/// por donde vuelven las respuestas de permisos del sistema.
@MainActor
func runOnMainLoop(_ work: @escaping () async throws -> Void) {
    // Sin NSApplication inicializada el proceso no tiene conexión con el
    // servidor de ventanas, y TCC no puede presentar el diálogo de permisos:
    // devuelve «denegado» sin registrar decisión ni preguntar nada. Como
    // accesoria no aparece en el Dock, que es lo que se quiere en una
    // herramienta de línea de comandos.
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)

    var done = false
    Task { @MainActor in
        do { try await work() } catch { print("error: \(error.localizedDescription)") }
        done = true
    }
    while !done {
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
    }
}

@main
@MainActor
struct Entry {
    /// `--dump` imprime el estado y sale: comprueba persistencia y filtros sin
    /// abrir la interfaz. Con `--demo` inspecciona la maqueta en memoria en vez
    /// de los datos reales.
    static func main() {
        Launch.demo = CommandLine.arguments.contains("--demo")
        if CommandLine.arguments.contains("--light") { Launch.appearance = .aqua }
        if CommandLine.arguments.contains("--dark")  { Launch.appearance = .darkAqua }
        if let i = CommandLine.arguments.firstIndex(of: "--view"),
           let n = CommandLine.arguments.dropFirst(i + 1).first.flatMap(Int.init),
           (1...Perspective.allCases.count).contains(n) {
            Launch.view = Perspective.allCases[n - 1]
        }
        // Importación y siembra desde la línea de comandos: permiten probar la
        // integración con Recordatorios sin abrir la interfaz. El bucle de
        // eventos tiene que seguir vivo, porque la concesión de permisos de TCC
        // vuelve por él.
        if CommandLine.arguments.contains("--reminders-status") {
            let estado: String
            switch RemindersInbox.authorization {
            case .notDetermined: estado = "notDetermined (aún no se ha preguntado)"
            case .restricted:    estado = "restricted (bloqueado por perfil o control parental)"
            case .denied:        estado = "denied (hay que activarlo a mano en Ajustes)"
            case .fullAccess:    estado = "fullAccess (listo)"
            case .writeOnly:     estado = "writeOnly (insuficiente: hace falta leer)"
            @unknown default:    estado = "desconocido"
            }
            print("Recordatorios: \(estado)")
            print("lista dedicada: «\(RemindersInbox.listName)»")
            return
        }
        if CommandLine.arguments.contains("--import-reminders") {
            runOnMainLoop {
                let inbox = RemindersInbox()
                guard try await inbox.requestAccess() else {
                    print("permiso de Recordatorios denegado"); return
                }
                let captured = try await inbox.drain()
                let store = Store()
                let added = store.addCaptured(captured)
                print("recordatorios pendientes: \(captured.count)  importados: \(added)")
            }
            return
        }
        if let i = CommandLine.arguments.firstIndex(of: "--seed-reminder"),
           let title = CommandLine.arguments.dropFirst(i + 1).first {
            runOnMainLoop {
                let inbox = RemindersInbox()
                guard try await inbox.requestAccess() else {
                    print("permiso de Recordatorios denegado"); return
                }
                try inbox.seedForTesting(title: title)
                print("recordatorio creado en la lista «\(RemindersInbox.listName)»: \(title)")
            }
            return
        }
        if CommandLine.arguments.contains("--dump") {
            let store = Launch.demo ? Store.demo() : Store()
            print(Launch.demo ? "maqueta en memoria" : "archivo: \(store.storageLocation)")
            print("tareas: \(store.items.count)  proyectos: \(store.projects.count)")
            for perspective in Perspective.allCases {
                let titles = store.items(for: perspective).map(\.title)
                print("\n[\(perspective.title)] \(titles.count)")
                titles.forEach { print("  · \($0)") }
            }
            for project in store.projects {
                let titles = store.items(for: .project(project.id)).map(\.title)
                print("\n[Proyecto: \(project.name)] \(titles.count)")
                titles.forEach { print("  · \($0)") }
            }
            return
        }
        PautaApp.main()
    }
}

@MainActor
struct PautaApp: App {
    @State private var store = Launch.demo ? Store.demo() : Store()
    @State private var nav = Navigation()

    var body: some Scene {
        // Con id: el panel de la barra de menús la reabre si se cerró.
        WindowGroup(id: "main") {
            RootView()
                .environment(store)
                .environment(nav)
                .frame(minWidth: 720, minHeight: 420)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1000, height: 680)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Nueva tarea") { nav.startNewItem() }
                    .keyboardShortcut("n", modifiers: .command)
                Button("Nuevo proyecto") {
                    let project = store.addProject(name: "")
                    nav.go(to: .project(project.id))
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }
            CommandGroup(after: .newItem) {
                Button("Importar de Recordatorios") {
                    Task { await importFromReminders(into: store, nav: nav) }
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
            }
            CommandGroup(after: .toolbar) {
                // ⌘1…⌘6 en el mismo orden en que aparecen en la barra lateral.
                ForEach(Array(Perspective.allCases.enumerated()), id: \.element) { index, perspective in
                    Button(perspective.title) { nav.go(to: perspective) }
                        .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")),
                                          modifiers: .command)
                }
            }
        }

        MenuBarExtra {
            MenuBarView()
                .environment(store)
        } label: {
            if let icon = Brand.menuBar {
                Image(nsImage: icon)
            } else {
                // Sin bundle (binario suelto) no hay monograma: un símbolo vale.
                Image(systemName: "checklist")
            }
        }
        .menuBarExtraStyle(.window)
    }
}

struct RootView: View {
    @Environment(Store.self) private var store
    @Environment(Navigation.self) private var nav

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 190, ideal: 218, max: 300)
        } detail: {
            ItemListView()
        }
        .navigationSplitViewStyle(.balanced)
        // El tint colorea las etiquetas de los Menu sin borde, así que tiene que ser
        // la variante legible: el verde puro no contrasta sobre fondo claro.
        .tint(Paper.accentInk)
        .background(Paper.bg)
        .task {
            // Al arrancar, para que lo apuntado en el iPhone esté ya aquí.
            if !Launch.demo { await importFromReminders(into: store, nav: nav) }
            if let name = Launch.appearance {
                NSApp?.appearance = NSAppearance(named: name)
            }
            // En maqueta, abre una tarea para ver el editor desplegado.
            if Launch.demo {
                nav.perspective = Launch.view ?? .today
                // Abre una tarea para que se vea el editor desplegado.
                nav.selectedItemID = store.items(for: nav.perspective).dropFirst().first?.id
            }
        }
    }
}

/// Trae lo pendiente de la lista de Recordatorios a la bandeja.
///
/// Silencioso a propósito: si no hay permiso todavía, o la lista está vacía, no
/// interrumpe. El permiso se pide la primera vez que se ejecuta, y si se deniega
/// la app sigue funcionando igual sin la captura remota.
@MainActor
func importFromReminders(into store: Store, nav: Navigation) async {
    do {
        let inbox = RemindersInbox()
        guard try await inbox.requestAccess() else { return }
        let captured = try await inbox.drain()
        guard !captured.isEmpty else { return }
        let added = store.addCaptured(captured)
        // Llevar a la bandeja solo si algo entró y no estabas en otra lista.
        if added > 0, case .today = nav.perspective { nav.go(to: .inbox) }
    } catch {
        // La captura remota es un extra: si falla, la app sigue siendo usable.
    }
}
