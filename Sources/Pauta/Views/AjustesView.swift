import SwiftUI
import AppKit
import ServiceManagement
import os
import UniformTypeIdentifiers
import PautaCore

/// Abrir Pauta al iniciar sesión.
///
/// No es comodidad: es la diferencia entre que la app funcione y que no. Con
/// Pauta cerrada, ⌃Espacio no existe, el repaso no se reprograma y la cuenta
/// atrás no está en ninguna parte. Una app que hay que acordarse de abrir para
/// que te acuerde de las cosas no sirve.
@MainActor
enum Arranque {
    private static let log = Logger(subsystem: "dev.jadrdev.pauta", category: "arranque")

    static var activo: Bool { SMAppService.mainApp.status == .enabled }

    /// Devuelve si quedó como se pedía.
    @discardableResult
    static func poner(_ encendido: Bool) -> Bool {
        do {
            if encendido { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            return activo == encendido
        } catch {
            log.error("no se pudo cambiar el arranque: \(error.localizedDescription)")
            return false
        }
    }
}

/// La pantalla de ajustes.
struct AjustesView: View {
    @Bindable var ajustes: Ajustes
    let store: Store

    @State private var alArrancar = Arranque.activo
    @State private var falloDeArranque = false
    @State private var grabandoAtajo = false
    @State private var novedad = Novedad.shared
    @State private var copias: [Copias.Guardada] = []
    @State private var aRestaurar: Copias.Guardada?
    @State private var restaurada: String?
    @State private var preguntarFabrica = false
    /// La copia importada, esperando a que se confirme.
    @State private var importada: Copia?

    init(ajustes: Ajustes, store: Store) {
        self.ajustes = ajustes
        self.store = store
    }

    /// Qué contar del último vistazo a las versiones. «No se pudo comprobar» no
    /// es lo mismo que «estás al día», y decir lo segundo cuando pasó lo primero
    /// es mentir en voz baja.
    private var estadoDeVersiones: String {
        if let hay = novedad.hay { return String(localized: "Hay una nueva: \(hay.version.description)") }
        if novedad.falloAlMirar { return String(localized: "No se pudo comprobar") }
        if Ajustes.shared.ultimaMiradaDeVersiones != nil { return String(localized: "Tienes la última (\(Acercade.version))") }
        return String(localized: "Se mira una vez al día. Solo pregunta; no envía nada")
    }

    private static let horasDeRepaso = [7 * 60, 7 * 60 + 30, 8 * 60, 8 * 60 + 30,
                                        9 * 60, 9 * 60 + 30, 10 * 60]

    /// Las preferencias, y el atajo **registrado de verdad**: guardar el de
    /// fábrica sin registrarlo dejaba funcionando el de antes, y el ajuste
    /// enseñando uno que no respondía. Si el sistema no acepta el de fábrica
    /// —otra app se lo queda—, se queda el tuyo, que sí funciona.
    private func restaurarDeFabrica() {
        let atajo = ajustes.atajo
        ajustes.restaurar()
        guard atajo != Atajo.porDefecto else { return }
        ajustes.atajo = atajo
        _ = AltaRapida.shared.cambiar(a: Atajo.porDefecto)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            grupo("AL ARRANCAR") {
                Toggle(isOn: Binding(get: { alArrancar },
                                     set: { nuevo in
                    alArrancar = nuevo
                    falloDeArranque = !Arranque.poner(nuevo)
                    if falloDeArranque { alArrancar = Arranque.activo }
                })) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Abrir Pauta al iniciar sesión").ajusteStyle()
                        Text("Con la app cerrada no hay atajo, ni avisos nuevos, ni cuenta atrás.")
                            .ajusteNota()
                    }
                }
                .toggleStyle(.switch)
                if falloDeArranque {
                    Text("El sistema no lo aceptó. Suele ser porque la app no está en Aplicaciones.")
                        .ajusteNota(Paper.warning)
                }
            }

            grupo("ALTA RÁPIDA") {
                GrabadorDeAtajo(grabando: $grabandoAtajo, actual: ajustes.atajo) { nuevo in
                    AltaRapida.shared.cambiar(a: nuevo)
                }
                Text("Abre la línea para apuntar algo sin ir a buscar la ventana. Si al pulsarlo no pasa nada, es que otra app o el propio sistema se queda esa combinación: el registro no falla, pero la tecla no llega. Elige otra.")
                    .ajusteNota()
            }

            grupo("REPASO DEL DÍA") {
                Picker(selection: $ajustes.repasoHora) {
                    Text("Desactivado").tag(Int?.none)
                    Divider()
                    ForEach(Self.horasDeRepaso, id: \.self) { m in
                        Text(ItemRowView.hora(m)).tag(Int?.some(m))
                    }
                } label: {
                    Text("Avisar a las").ajusteStyle()
                }
                .pickerStyle(.menu)
                .fixedSize()
                Text("Cuenta qué quedó sin hacer. Si no hay nada que decir, no suena.")
                    .ajusteNota()
            }

            grupo("AVISOS") {
                Picker(selection: $ajustes.margenPorDefecto) {
                    Text("A la hora").tag(0)
                    Divider()
                    ForEach([5, 10, 15, 30, 60], id: \.self) { m in
                        Text("\(Duracion.etiqueta(m)) antes").tag(m)
                    }
                } label: {
                    Text("Avisar por defecto").ajusteStyle()
                }
                .pickerStyle(.menu)
                .fixedSize()
                Text("Se le pone a cada hora nueva. Las tareas que ya tengan margen propio no se tocan.")
                    .ajusteNota()

                Picker(selection: $ajustes.minutosAplazados) {
                    ForEach([5, 10, 15, 30], id: \.self) { m in
                        Text(Duracion.etiqueta(m)).tag(m)
                    }
                } label: {
                    Text("Aplazar").ajusteStyle()
                }
                .pickerStyle(.menu)
                .fixedSize()
                .padding(.top, 10)
            }

            grupo("BARRA DE MENÚS") {
                Toggle(isOn: $ajustes.avisarDeVersiones) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Avisar de versiones nuevas")
                        // Lo que hace de verdad, dicho sin adornos: es la única
                        // vez que esta app habla con internet por su cuenta.
                        Text(estadoDeVersiones)
                            .font(.system(size: 11.5))
                            .foregroundStyle(novedad.hay != nil ? Paper.accentInk : Paper.inkFaint)
                    }
                }
                .toggleStyle(.switch)
                if ajustes.avisarDeVersiones {
                    HStack(spacing: 10) {
                        Button(novedad.mirando ? "Mirando…" : "Buscar ahora") {
                            Task { await novedad.mirarAhora() }
                        }
                        .disabled(novedad.mirando)
                        if let hay = novedad.hay {
                            EnlaceDeTexto("Ver la \(hay.version.description)") {
                                NSWorkspace.shared.open(hay.url)
                            }
                        }
                    }
                }

                Toggle(isOn: $ajustes.barraConCuenta) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enseñar la cuenta atrás").ajusteStyle()
                        Text("«En 20 min · Recoger a los niños» cuando falta menos de una hora. Si no, solo el icono.")
                            .ajusteNota()
                    }
                }
                .toggleStyle(.switch)
            }

            grupo("COPIAS DE SEGURIDAD") {
                Text(copias.first.map { String(localized: "La última: \($0.titulo.lowercased())") }
                     ?? String(localized: "Todavía ninguna: se hace la primera al abrir la app"))
                    .ajusteStyle()
                Text("Una al día, de los últimos \(Copias.cuantas) días, junto a tus datos en iCloud. Volver a una deja todo como estaba ese día; lo apuntado después va a la papelera, y antes se guarda una copia de ahora.")
                    .ajusteNota()
                HStack(spacing: 14) {
                    Menu("Volver a una copia…") {
                        ForEach(copias) { copia in
                            Button("\(copia.titulo) — \(copia.detalle)") { aRestaurar = copia }
                        }
                    }
                    .disabled(copias.isEmpty)
                    .fixedSize()
                    EnlaceDeTexto("Mostrar en el Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting(
                            [copias.first?.url ?? store.carpetaDeCopias])
                    }
                }
                .padding(.top, 4)
                // Fuera de la app: para quien no usa iCloud, y para pasar las
                // tareas a otro aparato. Los adjuntos no van dentro.
                HStack(spacing: 14) {
                    EnlaceDeTexto("Exportar una copia…") { exportar() }
                    EnlaceDeTexto("Importar una copia…") { importar() }
                }
                .padding(.top, 2)
                .confirmationDialog(
                    "¿Dejar todo como en la copia importada?",
                    isPresented: Binding(get: { importada != nil },
                                         set: { if !$0 { importada = nil } }),
                    titleVisibility: .visible
                ) {
                    Button("Importar", role: .destructive) {
                        guard let copia = importada else { return }
                        store.restaurar(copia)
                        restaurada = String(localized: "Hecho: \(copia.items.count) tareas importadas.")
                        Task { await leerCopias() }
                    }
                } message: {
                    Text("Lo que no esté en ella irá a la papelera. Antes se guarda una copia de cómo está ahora, por si quieres volver.")
                }
                if let restaurada {
                    Text(restaurada).ajusteNota(Paper.accentInk)
                }
            }
            .confirmationDialog(
                "¿Dejar todo como estaba el \(aRestaurar?.titulo.lowercased() ?? "")?",
                isPresented: Binding(get: { aRestaurar != nil },
                                     set: { if !$0 { aRestaurar = nil } }),
                titleVisibility: .visible
            ) {
                Button("Volver a esa copia", role: .destructive) {
                    guard let elegida = aRestaurar else { return }
                    // Sin bajar no se espera: se pide y se dice.
                    guard let copia = Copias.leer(elegida.url) else {
                        restaurada = String(localized: "Esa copia aún está bajando de iCloud. Prueba en un momento.")
                        return
                    }
                    store.restaurar(copia)
                    restaurada = String(localized: "Hecho: todo está como el \(elegida.titulo.lowercased()).")
                    Task { await leerCopias() }
                }
            } message: {
                Text("Lo que hayas apuntado después irá a la papelera. Antes se guarda una copia de cómo está ahora, por si quieres volver.")
            }

            Rectangle().fill(Paper.hairline).frame(height: 1).padding(.vertical, 14)
            HStack {
                // Con todo ya de fábrica no hay nada que restaurar, y un botón
                // que se pulsa sin que cambie nada parece roto: se dice.
                if ajustes.estaDeFabrica {
                    Text("Tienes los valores de fábrica")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Paper.inkFaint)
                } else {
                    EnlaceDeTexto("Restaurar los valores de fábrica") { preguntarFabrica = true }
                }
                Spacer(minLength: 0)
            }
            .confirmationDialog("¿Volver a los valores de fábrica?",
                                isPresented: $preguntarFabrica) {
                Button("Restaurar") { restaurarDeFabrica() }
            } message: {
                Text("El atajo, el repaso del día, los avisos y la barra de menús vuelven a como venían. Tus tareas no se tocan.")
            }
        }
        .padding(24)
        .frame(width: 460)
        .background(Paper.bg)
        .tint(Paper.accentInk)
        // La hora del repaso cambia lo que hay programado, así que se reprograma
        // al momento: esperar al siguiente cambio en las tareas dejaría la hora
        // nueva sin efecto hasta mañana.
        .onChange(of: ajustes.repasoHora) { Task { await Avisos.reschedule(store.items) } }
        // Y los minutos de aplazar están escritos en el botón del aviso, que se
        // congela al registrar la categoría.
        .onChange(of: ajustes.minutosAplazados) { Avisos.actualizarCategorias() }
        // Un permiso concedido o revocado en los ajustes del sistema mientras
        // esto estaba cerrado.
        .onAppear { alArrancar = Arranque.activo }
        // Las copias, fuera del hilo principal y solo al abrir los ajustes.
        // Esta vista se construye al arrancar la app —es la escena de
        // Ajustes—, y leerlas ahí colgó la app: iCloud las tenía sin bajar y
        // cada lectura esperaba a la descarga.
        .task { await leerCopias() }
    }

    /// Guarda una copia de todo donde se elija: tareas, proyectos y áreas,
    /// sin adjuntos, en el mismo formato que las copias diarias.
    private func exportar() {
        let datos: Data, nombre: String
        do { (datos, nombre) = try store.exportar() } catch {
            restaurada = String(localized: "Aún faltan tareas por bajar de iCloud. Prueba en un momento.")
            return
        }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = nombre
        panel.allowedContentTypes = [.gzip]
        panel.message = String(localized: "Tus tareas, proyectos y áreas. Los adjuntos no van dentro.")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try datos.write(to: url, options: .atomic)
            restaurada = String(localized: "Copia exportada: \(url.lastPathComponent).")
        } catch {
            restaurada = String(localized: "No se pudo guardar: \(error.localizedDescription)")
        }
    }

    /// Abre una copia exportada y pide confirmación antes de restaurarla.
    private func importar() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.gzip, .json]
        panel.allowsMultipleSelection = false
        panel.prompt = String(localized: "Importar")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let datos = try? Data(contentsOf: url), let copia = Copias.leer(datos: datos) else {
            restaurada = String(localized: "Ese archivo no es una copia de Pauta.")
            return
        }
        importada = copia
    }

    private func leerCopias() async {
        let raiz = store.storageURL
        copias = await Task.detached(priority: .utility) { Copias.resumenes(en: raiz) }.value
    }

    @ViewBuilder
    private func grupo(_ titulo: LocalizedStringKey,
                       @ViewBuilder _ contenido: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(titulo).rubricStyle()
            contenido()
        }
        .padding(.bottom, 20)
    }
}

private extension View {
    func ajusteStyle() -> some View {
        font(.system(size: 12.5, weight: .medium)).foregroundStyle(Paper.ink)
    }
    func ajusteNota(_ color: Color = Paper.inkFaint) -> some View {
        font(.system(size: 11))
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
    }
}
