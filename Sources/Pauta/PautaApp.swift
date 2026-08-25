import SwiftUI
import AppKit
import Observation

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

/// Punto de entrada. `--dump` imprime el estado guardado y sale: sirve para
/// comprobar la persistencia y los filtros sin abrir la interfaz.
/// Opciones de arranque para maquetar: datos falsos y apariencia forzada.
@MainActor
enum Launch {
    static var demo = false
    static var appearance: NSAppearance.Name?
}

@main
@MainActor
struct Entry {
    static func main() {
        Launch.demo = CommandLine.arguments.contains("--demo")
        if CommandLine.arguments.contains("--light") { Launch.appearance = .aqua }
        if CommandLine.arguments.contains("--dark")  { Launch.appearance = .darkAqua }
        if CommandLine.arguments.contains("--dump") {
            let store = Store()
            print("archivo: \(store.storageLocation)")
            print("tareas: \(store.items.count)  proyectos: \(store.projects.count)")
            for perspective in [Perspective.inbox, .today, .logbook] {
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
        WindowGroup {
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
            CommandGroup(after: .toolbar) {
                Button("Bandeja de entrada") { nav.go(to: .inbox) }
                    .keyboardShortcut("1", modifiers: .command)
                Button("Hoy") { nav.go(to: .today) }
                    .keyboardShortcut("2", modifiers: .command)
                Button("Registro") { nav.go(to: .logbook) }
                    .keyboardShortcut("3", modifiers: .command)
            }
        }
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
            if let name = Launch.appearance {
                NSApp?.appearance = NSAppearance(named: name)
            }
            // En maqueta, abre una tarea para ver el editor desplegado.
            if Launch.demo {
                nav.perspective = .today
                nav.selectedItemID = store.items(for: .today).dropFirst().first?.id
            }
        }
    }
}
