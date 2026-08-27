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
                // ⌘1…⌘6 en el mismo orden en que aparecen en la barra lateral.
                ForEach(Array(Perspective.allCases.enumerated()), id: \.element) { index, perspective in
                    Button(perspective.title) { nav.go(to: perspective) }
                        .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")),
                                          modifiers: .command)
                }
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
                nav.perspective = Launch.view ?? .today
                // Abre una tarea para que se vea el editor desplegado.
                nav.selectedItemID = store.items(for: nav.perspective).dropFirst().first?.id
            }
        }
    }
}
