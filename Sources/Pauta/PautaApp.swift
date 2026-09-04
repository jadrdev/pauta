import SwiftUI
import EventKit
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
    /// Abre el panel de alta rápida al arrancar.
    ///
    /// Existe para poder mirarlo —y comprobar que el foco cae en el campo— sin
    /// inyectar el atajo por debajo: un ⌃Espacio sintético obliga a que el foco
    /// salte entre apps, y eso ni prueba lo que hay que probar ni sale gratis.
    static var altaRapida = false
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
        Launch.altaRapida = CommandLine.arguments.contains("--alta-rapida")
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
        if CommandLine.arguments.contains("--eventos") {
            runOnMainLoop {
                let estados: [EKAuthorizationStatus: String] = [
                    .notDetermined: "notDetermined (aún no se ha preguntado)",
                    .restricted: "restricted", .denied: "denied (hay que activarlo en Ajustes)",
                    .fullAccess: "fullAccess (listo)", .writeOnly: "writeOnly (insuficiente)",
                ]
                print("Calendario: \(estados[Agenda.authorization] ?? "desconocido")")
                let agenda = Agenda()
                await agenda.load()
                print("eventos de hoy: \(agenda.eventos.count)")
                for e in agenda.eventos {
                    print("  · \(e.timeLabel)  \(e.title)   [\(e.calendarName)]")
                }
            }
            return
        }
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
                if let hora = Repaso.hora() {
                    let puesto = pendientes.contains(Repaso.identificador)
                    print("repaso del día: a las \(hora / 60):"
                          + String(format: "%02d", hora % 60)
                          + (puesto ? " (programado)" : " (nada que repasar)"))
                } else {
                    print("repaso del día: desactivado")
                }
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
    @State private var agenda = Agenda()
    @State private var reloj = Reloj()
    /// La hora del repaso vive en las preferencias; aquí se guarda una copia
    /// para que el menú pueda decir cuál está puesta y cambiar al elegir otra.
    @State private var horaRepaso: Int? = Repaso.hora()
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
                .environment(agenda)
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
                    // El atajo global se registra aquí y no se suelta al cerrar
                    // la ventana: apuntar tiene que funcionar con la app en la
                    // barra de menús y nada abierto.
                    AltaRapida.shared.instalar(store: store)
                    if Launch.altaRapida { AltaRapida.shared.alternar() }

                    AvisoAcciones.alAbrir = { id in
                        openWindow(id: "main")
                        mostrar(id, in: store, nav: nav)
                    }
                    // Los dos reprograman a mano en vez de esperar a que el
                    // cambio de las tareas lo dispare: ese disparador vive en
                    // esta ventana, y un aviso se atiende con la ventana
                    // cerrada. Sin esto, completar desde el aviso dejaría la
                    // insistencia sonando y aplazar no volvería nunca.
                    AvisoAcciones.alCompletar = { id in
                        guard let item = store.items.first(where: { $0.id == id }) else { return }
                        store.toggleComplete(item)
                        Task { await Avisos.reschedule(store.items) }
                    }
                    // El repaso no lleva tarea: abre Hoy, que es donde se
                    // decide el día.
                    AvisoAcciones.alRepasar = {
                        openWindow(id: "main")
                        nav.go(to: .today)
                    }
                    AvisoAcciones.alAplazar = { id, minutos in
                        guard let item = store.items.first(where: { $0.id == id }) else { return }
                        store.snooze(item, minutes: minutos)
                        Task { await Avisos.reschedule(store.items) }
                    }
                }
                // Al cambiar el día, lo que era «de hoy» pasa a ser atrasado y
                // su aviso tiene que empezar a insistir. Nada en las tareas
                // cambia a medianoche, así que sin esto no se enteraría nadie.
                .onReceive(NotificationCenter.default.publisher(
                    for: .NSCalendarDayChanged).receive(on: RunLoop.main)) { _ in
                    guard !Launch.demo else { return }
                    Task {
                        await Avisos.reschedule(store.items)
                        await agenda.load(force: true)
                    }
                }
                // Los eventos se releen al entrar en Hoy y al cambiar el día:
                // son de fuera y no cambian cuando cambian las tareas.
                .task(id: nav.perspective) {
                    // En maqueta, eventos inventados: mirar el diseño no debe
                    // pedir permiso ni leer el calendario de nadie.
                    if Launch.demo { agenda.seedForDemo(); return }
                    guard case .today = nav.perspective else { return }
                    await agenda.load()
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
                // El atajo no se declara aquí porque no lo lleva el menú: lo
                // registra Carbon para que funcione con otra app delante. El
                // botón existe para que se pueda descubrir y para decir cuál es.
                Button(AltaRapida.shared.combinacion.map { "Alta rápida  \($0)" }
                        ?? "Alta rápida") {
                    AltaRapida.shared.alternar()
                }
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
                Button("Eventos del calendario…") {
                    Task {
                        // Si ya se dijo que no, pedirlo otra vez no abre nada:
                        // esa decisión solo se cambia en los ajustes.
                        if Agenda.authorization == .notDetermined {
                            await agenda.requestAccess()
                            await agenda.load(force: true)
                        } else if !Agenda.isAuthorized {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }
                }
                Menu(horaRepaso.map { "Repaso del día  ·  \(ItemRowView.hora($0))" }
                        ?? "Repaso del día  ·  desactivado") {
                    ForEach([7 * 60, 7 * 60 + 30, 8 * 60, 8 * 60 + 30,
                             9 * 60, 10 * 60], id: \.self) { m in
                        Button(ItemRowView.hora(m)) { ponerRepaso(m) }
                    }
                    Divider()
                    Button("Desactivado") { ponerRepaso(nil) }
                }
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
            EtiquetaDeBarra(store: store, reloj: reloj)
        }
        .menuBarExtraStyle(.window)
    }

    /// Cambia la hora del repaso y lo reprograma en el momento: si esperara al
    /// siguiente cambio en las tareas, la hora nueva no valdría hasta mañana.
    private func ponerRepaso(_ minutos: Int?) {
        horaRepaso = minutos
        Repaso.setHora(minutos)
        Task { await Avisos.reschedule(store.items) }
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
