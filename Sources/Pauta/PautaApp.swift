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
    /// Qué se está arrastrando ahora mismo. Una misma fila recibe cosas
    /// distintas —una tarea que se mueve dentro, o un hermano que se coloca
    /// antes— y la señal que dibuja tiene que ser distinta. Lo anota quien
    /// empieza el arrastre, porque al soltar ya es tarde para dibujar nada.
    var arrastrando: Arrastrado = .tarea

    enum Arrastrado { case tarea, proyecto, area }

    func startNewItem() {
        // Hay listas donde una tarea nueva no tendría dónde caer: en las
        // completadas nacería ya hecha, y un área no sabría a qué proyecto
        // colgarla. Se crea en la bandeja, que es donde va lo aún sin decidir.
        if !perspective.acceptsNewItems { perspective = .inbox }
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
        // Antes de lanzar la interfaz: si se pusiera después, un aviso pulsado
        // con la app cerrada se entregaría sin nadie que lo atendiera.
        Avisos.hookUp()
        if CommandLine.arguments.contains("--avisos") {
            // Por el bucle principal, como los de Recordatorios: el centro de
            // notificaciones responde por él, y esperando con un semáforo en el
            // hilo principal la respuesta no llegaría nunca.
            runOnMainLoop {
                let nombres = ["notDetermined", "denied", "authorized", "provisional",
                               "ephemeral"]
                let i = await Avisos.authorization().rawValue
                print("permiso de avisos: \(i < nombres.count ? nombres[i] : "\(i)")")
                let pendientes = await Avisos.pending()
                print("avisos programados: \(pendientes.count)")
                for id in pendientes.prefix(5) { print("  · \(id)") }
            }
            return
        }
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
            if Launch.demo {
                print("maqueta en memoria")
            } else {
                print("carpeta: \(store.storageLocation)")
                print("sincronizada por iCloud: \(store.isSynced ? "sí" : "no")")
                if store.pendingDownloads > 0 {
                    print("archivos pendientes de bajar de iCloud: \(store.pendingDownloads)")
                }
            }
            print("tareas: \(store.items.count)  proyectos: \(store.projects.count)"
                  + "  áreas: \(store.areas.count)")
            for perspective in Perspective.allCases {
                let titles = store.items(for: perspective).map(\.title)
                print("\n[\(perspective.title)] \(titles.count)")
                titles.forEach { print("  · \($0)") }
            }
            for area in store.areas {
                let dentro = store.projects(in: area.id).map(\.name).joined(separator: ", ")
                print("\n[Área: \(area.name)] \(store.count(for: .area(area.id)))"
                      + (dentro.isEmpty ? "  (sin proyectos)" : "  → \(dentro)"))
            }
            for project in store.projects {
                let titles = store.items(for: .project(project.id)).map(\.title)
                let area = project.areaID.flatMap(store.area)
                print("\n[Proyecto: \(project.name)"
                      + (area.map { " · \($0.name)" } ?? "") + "] \(titles.count)")
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
    /// Vigila la carpeta de datos para recoger lo que llegue de otro
    /// dispositivo mientras la app está abierta.
    @State private var watcher: FolderWatcher?
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        // `Window` y no `WindowGroup`: esta app es de una sola ventana, y con
        // WindowGroup cada `openWindow(id:)` abría una nueva en vez de traer la
        // que ya había. El id permite reabrirla desde el menú y desde el panel
        // de la barra de menús cuando se ha cerrado.
        Window("Pauta", id: "main") {
            RootView()
                .environment(store)
                .environment(nav)
                .frame(minWidth: 720, minHeight: 420)
                .task {
                    // Recoge lo que llegue de otro dispositivo mientras la app
                    // está abierta: sin esto solo se leería al arrancar.
                    guard !Launch.demo, watcher == nil else { return }
                    watcher = FolderWatcher(url: store.storageURL) {
                        store.reload()
                    }
                }
                // Los avisos se rehacen enteros con cada cambio de las tareas.
                // Da igual qué cambió —hora, día, completada, borrada, llegada
                // de otro dispositivo—: reconstruir es más barato que razonar
                // sobre qué aviso quedó suelto.
                .task {
                    AvisoAcciones.alAbrir = { id in
                        openWindow(id: "main")
                        mostrar(id, in: store, nav: nav)
                    }
                    AvisoAcciones.alCompletar = { id in
                        guard let item = store.items.first(where: { $0.id == id }) else { return }
                        store.toggleComplete(item)
                    }
                }
                // Al cambiar el día, lo que era «de hoy» pasa a ser atrasado y
                // su aviso tiene que empezar a insistir. Nada en las tareas
                // cambia a medianoche, así que sin esto no se enteraría nadie.
                .onReceive(NotificationCenter.default.publisher(
                    for: .NSCalendarDayChanged).receive(on: RunLoop.main)) { _ in
                    guard !Launch.demo else { return }
                    Task { await Avisos.reschedule(store.items) }
                }
                .task(id: store.items) {
                    guard !Launch.demo else { return }
                    // Un segundo de espera: escribir un título cambia las tareas
                    // en cada tecla, y `task(id:)` cancela la anterior, así que
                    // solo se reprograma cuando la mano para.
                    try? await Task.sleep(for: .seconds(1))
                    guard !Task.isCancelled else { return }
                    await Avisos.reschedule(store.items)
                }
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
                Button("Nueva área") {
                    let area = store.addArea(name: "")
                    nav.go(to: .area(area.id))
                }
                .keyboardShortcut("n", modifiers: [.command, .option])
            }
            // Sin esto, cerrar la ventana deja la app sin forma de volver salvo el
            // panel de la barra de menús: quien no lo conozca se queda fuera.
            CommandGroup(after: .windowList) {
                Button("Ventana principal") { openWindow(id: "main") }
                    .keyboardShortcut("0", modifiers: .command)
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
                // Prefiere una repetitiva: es la fila con más que enseñar.
                let visibles = store.items(for: nav.perspective)
                nav.selectedItemID = visibles.first { $0.recurrence != nil }?.id
                    ?? visibles.dropFirst().first?.id
            }
        }
    }
}

/// Trae lo pendiente de la lista de Recordatorios a la bandeja.
///
/// Silencioso a propósito: si no hay permiso todavía, o la lista está vacía, no
/// interrumpe. El permiso se pide la primera vez que se ejecuta, y si se deniega
/// la app sigue funcionando igual sin la captura remota.
/// Lleva la vista hasta una tarea y la deja abierta.
///
/// La lista se elige por la tarea y no se deja la que hubiera: si el aviso te
/// manda a una tarea que no se ve desde donde estabas, el salto no serviría de
/// nada. Toda tarea con aviso tiene día, así que o es de hoy o es futura.
@MainActor
func mostrar(_ id: UUID, in store: Store, nav: Navigation) {
    guard let item = store.items.first(where: { $0.id == id }) else { return }
    if item.isCompleted { nav.go(to: .completed) }
    else if item.isToday { nav.go(to: .today) }
    else if item.isUpcoming { nav.go(to: .upcoming) }
    else if let projectID = item.projectID { nav.go(to: .project(projectID)) }
    else { nav.go(to: .inbox) }
    nav.selectedItemID = id
}

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
