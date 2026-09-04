import AppKit
import Carbon.HIToolbox
import SwiftUI
import os
import PautaCore

/// Alta rápida: apuntar algo sin ir a buscar la app.
///
/// ⌘N solo sirve con Pauta delante, y la cosa que hay que apuntar aparece
/// **mientras estás en otra cosa**: leyendo un correo, al teléfono, a mitad de
/// otra tarea. Si apuntarla exige cambiar de app, buscar la ventana y volver, no
/// se apunta —y lo que no se apunta no lo arregla ninguna lista—.
///
/// Va a la bandeja a propósito. Capturar y decidir son dos gestos distintos, y
/// juntarlos es lo que hace que apuntar cueste: la bandeja permite escribirlo
/// mal, deprisa y sin pensar dónde va.
@MainActor
final class AltaRapida {
    static let shared = AltaRapida()

    private var atajo: AtajoGlobal?
    private var panel: PanelFlotante?
    private var store: Store?
    private var testigo: (any NSObjectProtocol)?
    /// Quién tenía el foco antes de abrir, para devolverlo al cerrar.
    private var anterior: NSRunningApplication?
    private var ultimoAtajo = Date.distantPast
    private let log = Logger(subsystem: "dev.jadrdev.pauta", category: "alta-rápida")

    private init() {}

    /// Registra el atajo. Se llama una vez, y sobrevive a que se cierre la
    /// ventana: el atajo tiene que seguir funcionando con la app en la barra de
    /// menús y nada abierto.
    func instalar(store: Store) {
        self.store = store
        guard atajo == nil else { return }
        atajo = AtajoGlobal(candidatos: AtajoGlobal.paraAltaRapida) { [weak self] in
            self?.alternar()
        }
        if let combinacion = atajo?.combinacion {
            log.notice("alta rápida en \(combinacion, privacy: .public)")
        } else {
            log.error("no se pudo registrar ningún atajo para el alta rápida")
        }
    }

    /// Cómo se escribe el atajo que quedó registrado, para poder decirlo en la
    /// interfaz en vez de que el usuario lo adivine.
    var combinacion: String? { atajo?.combinacion }

    /// El mismo atajo abre y cierra: si abriera solamente, pulsarlo dos veces
    /// dejaría un panel que hay que quitar de en medio a mano.
    func alternar() {
        // Abrir y cerrar mueve el foco entre dos apps. Una ráfaga de pulsaciones
        // —una tecla trabada, un atajo repetido sin querer— encadenaría esas
        // activaciones más rápido de lo que el sistema las resuelve, y eso
        // cuelga la pantalla. Se ignora lo que llegue pisando a lo anterior.
        let ahora = Date()
        guard ahora.timeIntervalSince(ultimoAtajo) > 0.35 else { return }
        ultimoAtajo = ahora
        if panel?.isVisible == true { cerrar() } else { abrir() }
    }

    private func abrir() {
        guard let store else { return }
        // Panel nuevo cada vez: garantiza campo vacío y foco puesto, y ahorra
        // tener que deshacer a mano el estado de la vez anterior.
        cerrar()

        let panel = PanelFlotante(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 92),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered, defer: false)
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        // Por encima de todo y en cualquier escritorio: si apareciera solo en el
        // espacio de Pauta, el atajo global no serviría para nada.
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .utilityWindow
        panel.contentView = NSHostingView(rootView: VistaAltaRapida(
            store: store,
            guardar: { [weak self] texto, aHoy in
                self?.guardar(texto, aHoy: aHoy, in: store)
            },
            cerrar: { [weak self] in self?.cerrar() }))

        panel.setFrameOrigin(Self.origen(para: panel))
        self.panel = panel

        // Hay que activar la app para poder escribir: el sistema entrega las
        // teclas a la app que está delante, así que un panel de una app de
        // fondo se ve, se puede pulsar, y no recibe una sola letra.
        //
        // El precio es que la ventana principal sube con la app. Se paga porque
        // la alternativa es un panel donde no se puede escribir, y se devuelve
        // al cerrar: el foco vuelve a donde estaba, que es lo que hace que esto
        // interrumpa un segundo y no un minuto.
        anterior = NSWorkspace.shared.frontmostApplication
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // El vigilante del clic fuera se pone con retraso: la activación llega
        // por el bucle de eventos y de camino la ventana principal se hace clave
        // un instante, lo que cerraría el panel al abrirlo.
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard let self, let panel = self.panel, panel.isVisible else { return }
            panel.makeKeyAndOrderFront(nil)
            // Clic fuera: se cierra. Un panel flotante que se queda puesto
            // tapando lo que estabas mirando es peor que no tener atajo.
            self.testigo = NotificationCenter.default.addObserver(
                forName: NSWindow.didResignKeyNotification, object: panel, queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in self?.cerrar() }
            }
        }
    }

    private func cerrar() {
        // Idempotente a propósito. Lo llaman el atajo, la tecla de escape, el
        // clic fuera y el propio guardado, y sin esta salida un cierre repetido
        // volvería a activar la app de antes: dos activaciones seguidas es como
        // empieza un baile de foco del que no se sale.
        guard let panel else { return }
        if let testigo { NotificationCenter.default.removeObserver(testigo) }
        testigo = nil
        panel.orderOut(nil)
        self.panel = nil
        // Devolver el foco a lo que estabas haciendo es parte del gesto: si
        // Pauta se quedara delante, apuntar algo costaría además volver.
        if let anterior, anterior.bundleIdentifier != Bundle.main.bundleIdentifier,
           !anterior.isTerminated {
            anterior.activate()
        }
        anterior = nil
    }

    private func guardar(_ texto: String, aHoy: Bool, in store: Store) {
        // Varias líneas, varias tareas: pegar una lista en el panel hace lo
        // mismo que pegarla en la lista, y no una tarea con saltos dentro.
        store.addItems(from: texto, in: aHoy ? .today : .inbox)
        cerrar()
    }

    /// Arriba y centrado en la pantalla donde está el ratón, como todo lo que
    /// aparece llamándolo con el teclado.
    private static func origen(para panel: NSWindow) -> NSPoint {
        let raton = NSEvent.mouseLocation
        let pantalla = NSScreen.screens.first { $0.frame.contains(raton) }
            ?? NSScreen.main ?? NSScreen.screens[0]
        let marco = pantalla.visibleFrame
        return NSPoint(x: marco.midX - panel.frame.width / 2,
                       y: marco.maxY - marco.height * 0.24 - panel.frame.height)
    }
}

/// Un panel que puede recibir teclas sin que la app pase a primer plano.
///
/// Sin `canBecomeKey` no se podría escribir en él, y sin `nonactivatingPanel`
/// escribir exigiría activar Pauta —que es justo la interrupción que el atajo
/// existe para evitar—.
final class PanelFlotante: NSPanel {
    override var canBecomeKey: Bool { true }

    /// Escape cierra. Va aquí y no en la vista porque el campo de texto se come
    /// la tecla antes de que ningún modificador de SwiftUI la vea.
    override func cancelOperation(_ sender: Any?) {
        NotificationCenter.default.post(name: PanelFlotante.cancelado, object: self)
    }

    static let cancelado = Notification.Name("dev.jadrdev.pauta.panel.cancelado")
}

/// El contenido del panel: una línea para escribir y nada más.
private struct VistaAltaRapida: View {
    let store: Store
    let guardar: (String, Bool) -> Void
    let cerrar: () -> Void

    @State private var texto = ""
    @FocusState private var enfocado: Bool

    var body: some View {
        HStack(spacing: 11) {
            Circle()
                .strokeBorder(Paper.accent.opacity(0.8),
                              style: StrokeStyle(lineWidth: 1.5, dash: [2.5, 2.5]))
                .frame(width: 17, height: 17)
            VStack(alignment: .leading, spacing: 3) {
                TextField("Apunta lo que sea", text: $texto, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Paper.ink)
                    .focused($enfocado)
                    .lineLimit(1...3)
                    .onSubmit(enviar)
                Text(pista)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(Paper.inkFaint)
            }
        }
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Paper.bg)
        // Sin esto el hueco de la barra de título —oculta, pero contada— deja
        // el contenido bailando por debajo del centro.
        .ignoresSafeArea()
        .onAppear {
            // En el mismo ciclo el campo aún no existe para el sistema de foco.
            DispatchQueue.main.async { enfocado = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: PanelFlotante.cancelado)) { _ in
            cerrar()
        }
    }

    private var pista: String {
        texto.contains("\n") ? "⏎ crea una tarea por línea · ⇧⏎ a Hoy"
                             : "⏎ a la bandeja · ⇧⏎ a Hoy"
    }

    /// El destino se lee del teclado en el momento de enviar.
    ///
    /// Con `keyboardShortcut` no bastaría: en un panel hospedado los atajos de
    /// SwiftUI dependen de la cadena de menús, que aquí no hay. `modifierFlags`
    /// dice qué está pulsado ahora mismo, que es exactamente la pregunta.
    private func enviar() {
        let limpio = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !limpio.isEmpty else { cerrar(); return }
        guardar(texto, NSEvent.modifierFlags.contains(.shift))
    }
}

/// Un atajo de teclado que funciona con la app de fondo.
///
/// Con Carbon y no con `NSEvent.addGlobalMonitorForEvents`: el monitor global
/// exige permiso de monitorización de entrada —el mismo que se le pide a un
/// registrador de teclas— y pedirlo para apuntar tareas es desproporcionado.
/// `RegisterEventHotKey` no pide nada porque no ve el resto de las teclas.
@MainActor
final class AtajoGlobal {
    /// Los candidatos, en orden de preferencia.
    ///
    /// ⌃Espacio es el atajo que usa Things y el que la gente ya tiene en los
    /// dedos. Si estuviera cogido —lo usa el conmutador de fuentes de entrada
    /// de macOS cuando hay más de un teclado configurado— se cae a ⌥Espacio.
    static let paraAltaRapida: [(nombre: String, tecla: Int, modificadores: Int)] = [
        ("⌃Espacio", kVK_Space, controlKey),
        ("⌥Espacio", kVK_Space, optionKey),
        ("⌃⌥Espacio", kVK_Space, controlKey | optionKey),
    ]

    private var referencia: EventHotKeyRef?
    private var manejador: EventHandlerRef?
    /// Cómo se escribe el que quedó puesto.
    private(set) var combinacion: String?

    init(candidatos: [(nombre: String, tecla: Int, modificadores: Int)],
         accion: @escaping () -> Void) {
        alPulsar = accion

        var tipo = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), atajoPulsado, 1, &tipo, nil, &manejador)

        for (i, candidato) in candidatos.enumerated() {
            let id = EventHotKeyID(signature: OSType(0x50415554), id: UInt32(i))
            let estado = RegisterEventHotKey(UInt32(candidato.tecla),
                                             UInt32(candidato.modificadores),
                                             id, GetApplicationEventTarget(), 0, &referencia)
            if estado == noErr, referencia != nil {
                combinacion = candidato.nombre
                return
            }
        }
    }

    deinit {
        if let referencia { UnregisterEventHotKey(referencia) }
        if let manejador { RemoveEventHandler(manejador) }
    }
}

/// La acción del atajo, fuera de la clase: el manejador de Carbon es un puntero
/// a función de C y no puede capturar nada.
private nonisolated(unsafe) var alPulsar: (() -> Void)?

private func atajoPulsado(_ llamada: EventHandlerCallRef?, _ evento: EventRef?,
                          _ contexto: UnsafeMutableRawPointer?) -> OSStatus {
    DispatchQueue.main.async { alPulsar?() }
    return noErr
}
