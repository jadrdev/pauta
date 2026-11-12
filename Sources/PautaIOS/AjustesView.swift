import SwiftUI
import UIKit
import EventKit
import UserNotifications
import PautaCore

/// Los ajustes del teléfono.
///
/// Los del Mac son cinco y aquí solo caben tres: arrancar al iniciar sesión y la
/// cuenta atrás de la barra de menús no existen en un teléfono, y el atajo
/// global tampoco. Lo que queda —el repaso, el margen y cuánto aplaza— son
/// preferencias de **este aparato**, así que se guardan en él y no viajan: la
/// hora a la que te levantas mirando el móvil no tiene por qué ser la del Mac.
///
/// Y lleva dos cosas que en el Mac viven en otro sitio: los permisos —que ahí
/// están en la ayuda— y el «Acerca de». En un teléfono no hay menú de la app
/// donde ponerlos, y son justo lo que se viene a buscar aquí.
struct AjustesView: View {
    @Environment(Store.self) private var store
    @Bindable private var ajustes = Ajustes.shared

    @State private var carpeta = CarpetaElegida.shared
    /// Si este aparato tiene iCloud para la app. `nil` mientras se pregunta:
    /// la primera vez el sistema prepara el contenedor y tarda.
    @State private var hayICloud: Bool?
    /// Lo que movió el último cruce, para poder decirlo en vez de dejar al
    /// usuario adivinando si sirvió de algo.
    @State private var balance: Puente.Balance?
    /// Mientras cruza, se dice. El primer cruce con una carpeta de verdad tarda
    /// —hay archivos que iCloud todavía tiene que bajar—, y un botón que no
    /// responde y no explica nada es una app colgada a ojos de cualquiera.
    @State private var cruzando = false
    @State private var avisos: UNAuthorizationStatus = .notDetermined
    @State private var calendario = Agenda.authorization
    @State private var globo = true
    @State private var preguntarFabrica = false

    private static let horasDeRepaso = [7 * 60, 7 * 60 + 30, 8 * 60, 8 * 60 + 30,
                                        9 * 60, 9 * 60 + 30, 10 * 60]

    private func cruzar() {
        guard !cruzando else { return }
        cruzando = true
        Task {
            balance = await Sincronizar.conICloud(store)
            cruzando = false
        }
    }

    private static func resumen(_ b: Puente.Balance) -> String {
        if b.traidas == 0 && b.llevadas == 0 {
            return b.pendientesDeBajar > 0
                ? "Nada que cruzar · \(b.pendientesDeBajar) sin bajar de iCloud"
                : "Nada que cruzar: ya estaban iguales"
        }
        var partes: [String] = []
        if b.traidas > 0 { partes.append("\(b.traidas) de iCloud") }
        if b.llevadas > 0 { partes.append("\(b.llevadas) a iCloud") }
        if b.pendientesDeBajar > 0 {
            partes.append("\(b.pendientesDeBajar) sin bajar de iCloud")
        }
        return partes.joined(separator: " · ")
    }

    var body: some View {
        Form {
            Section {
                Picker(selection: $ajustes.repasoHora) {
                    Text("Desactivado").tag(Int?.none)
                    ForEach(Self.horasDeRepaso, id: \.self) { m in
                        Text(DetalleView.hora(m)).tag(Int?.some(m))
                    }
                } label: {
                    Text("Avisar a las")
                }
            } header: {
                Text("REPASO DEL DÍA")
            } footer: {
                Text("Cuenta qué quedó sin hacer. Si no hay nada que decir, no suena.")
            }

            Section {
                Picker(selection: $ajustes.margenPorDefecto) {
                    Text("A la hora").tag(0)
                    ForEach([5, 10, 15, 30, 60], id: \.self) { m in
                        Text(Duracion.etiqueta(m) + " antes").tag(m)
                    }
                } label: {
                    Text("Avisar por defecto")
                }
                Picker(selection: $ajustes.minutosAplazados) {
                    ForEach([5, 10, 15, 30], id: \.self) { m in
                        Text(Duracion.etiqueta(m)).tag(m)
                    }
                } label: {
                    Text("Aplazar")
                }
            } header: {
                Text("AVISOS")
            } footer: {
                Text("El margen se le pone a cada hora nueva; las tareas que ya "
                     + "tengan el suyo no se tocan.")
            }

            Section {
                FilaDePermiso(nombre: "Avisos",
                              concedido: avisos == .authorized,
                              decidido: avisos != .notDetermined) {
                    await Avisos.request()
                    avisos = await Avisos.authorization()
                    globo = await Avisos.puedeGlobo()
                }
                // El globo es un permiso aparte y puede estar apagado con los
                // avisos concedidos: quien los concedió antes de la 0.3.8 nunca
                // llegó a decir que sí a esto, y el sistema no vuelve a
                // preguntar. Así que no se supone, se lee — y se dice **solo
                // cuando está apagado**, que es cuando hay algo que hacer.
                if avisos == .authorized, !globo {
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("Encender los globos del icono", systemImage: "app.badge")
                    }
                    .listRowBackground(Papel.bg)
                }
                FilaDePermiso(nombre: "Calendario",
                              concedido: calendario == .fullAccess,
                              decidido: calendario != .notDetermined) {
                    _ = await Agenda().requestAccess()
                    calendario = Agenda.authorization
                }
            } header: {
                Text("PERMISOS")
            } footer: {
                Text("Los avisos hacen falta para las horas y el repaso; el "
                     + "calendario, para ver los eventos en Hoy. Si están "
                     + "denegados, se cambian en los ajustes del sistema: el "
                     + "diálogo no vuelve a salir.")
            }

            Section {
                HStack {
                    Text("iCloud")
                    Spacer()
                    Text(hayICloud == nil ? "Mirando…" : hayICloud == true ? "Sincroniza" : "No disponible")
                        .foregroundStyle(hayICloud == false ? Papel.warning : Papel.inkSoft)
                }
                if hayICloud == true {
                    Button {
                        cruzar()
                    } label: {
                        HStack {
                            Label("Cruzar ahora", systemImage: "arrow.triangle.2.circlepath")
                            if cruzando {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(cruzando)
                    if let balance {
                        Text(Self.resumen(balance))
                            .font(.system(size: 12.5))
                            .foregroundStyle(Papel.inkFaint)
                    }
                }
                // La carpeta del Mac que se elegía antes de la mudanza. Se
                // sigue cruzando mientras dure, por si hay un Mac sin
                // actualizar; ya no se ofrece elegir una nueva.
                if let elegida = carpeta.url {
                    HStack {
                        Text("Carpeta de antes")
                        Spacer()
                        Text(elegida.lastPathComponent)
                            .foregroundStyle(Papel.inkSoft)
                    }
                    Button("Olvidar la carpeta de antes", role: .destructive) {
                        carpeta.olvidar()
                        balance = nil
                    }
                }
            } header: {
                Text("ICLOUD")
            } footer: {
                if hayICloud == false {
                    Text("Sin iCloud, las tareas se quedan en este aparato. Se "
                         + "activa en Ajustes del sistema ▸ tu nombre ▸ iCloud ▸ iCloud Drive.")
                } else {
                    Text("Tus tareas se cruzan con las de iCloud, que son las mismas del "
                         + "Mac y del iPad, sin elegir nada. Cada aparato guarda las "
                         + "suyas, así que funciona también sin red; y de cada tarea "
                         + "gana la versión más reciente.")
                }
            }

            Section {
                NavigationLink {
                    CopiasView()
                } label: {
                    Label("Copias de seguridad", systemImage: "clock.arrow.circlepath")
                }
            } header: {
                Text("COPIAS DE SEGURIDAD")
            } footer: {
                Text("Una al día. Para volver a como estaba todo otro día.")
            }

            Section {
                Text(SobreLaApp.rutaDeDatos(store))
                    .font(.system(size: 13).monospaced())
                    .foregroundStyle(Papel.inkSoft)
                    .textSelection(.enabled)
            } header: {
                Text("TUS DATOS")
            } footer: {
                Text("En este teléfono, en la carpeta que comparte con el widget. "
                     + "Con iCloud se cruzan arriba.")
            }

            Section {
                enlace("Código", "chevron.left.forwardslash.chevron.right",
                       Enlaces.repositorio)
                enlace("Novedades", "sparkles", Enlaces.novedades)
                enlace("Escribir al desarrollador", "envelope", Enlaces.problemas)
                // Con todo ya de fábrica no hay nada que hacer, y un botón que se
                // pulsa sin que cambie nada parece roto: se dice.
                if ajustes.estaDeFabrica {
                    Text("Tienes los valores de fábrica")
                        .foregroundStyle(Papel.inkFaint)
                } else {
                    Button("Restaurar los valores de fábrica") { preguntarFabrica = true }
                }
            } header: {
                Text("PAUTA \(SobreLaApp.version)")
            } footer: {
                Text("Hecho por @jadrdev · © 2026 Joshua A. Díaz Robayna · Todos "
                     + "los derechos reservados")
            }
        }
        .scrollContentBackground(.hidden)
        // En la lista y no en la fila del botón: una fila que sale de la
        // pantalla deja de existir, y el diálogo con ella.
        .confirmationDialog("¿Volver a los valores de fábrica?",
                            isPresented: $preguntarFabrica,
                            titleVisibility: .visible) {
            Button("Restaurar") { ajustes.restaurar() }
        } message: {
            Text("El repaso del día y los avisos vuelven a como venían. "
                 + "Tus tareas no se tocan.")
        }
        .background(Papel.bg)
        .navigationTitle("Ajustes")
        .task {
            hayICloud = await Task.detached(priority: .utility) {
                Contenedor.documentos() != nil
            }.value
            avisos = await Avisos.authorization()
            calendario = Agenda.authorization
            globo = await Avisos.puedeGlobo()
        }
        // La hora del repaso cambia lo que hay programado: esperar al siguiente
        // cambio en las tareas dejaría la hora nueva sin efecto hasta mañana.
        .onChange(of: ajustes.repasoHora) { Task { await Avisos.reschedule(store.items) } }
        // Y los minutos de aplazar están escritos en el botón del aviso, que se
        // congela al registrar la categoría.
        .onChange(of: ajustes.minutosAplazados) { Avisos.actualizarCategorias() }
    }

    private func enlace(_ titulo: String, _ icono: String, _ url: URL) -> some View {
        Button {
            UIApplication.shared.open(url)
        } label: {
            HStack {
                Label(titulo, systemImage: icono)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Papel.inkFaint)
            }
        }
    }
}

/// Un permiso, con lo que se puede hacer al respecto.
private struct FilaDePermiso: View {
    let nombre: String
    let concedido: Bool
    let decidido: Bool
    let pedir: () async -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: concedido ? "checkmark.circle.fill"
                                        : (decidido ? "xmark.circle.fill" : "circle.dotted"))
                .foregroundStyle(concedido ? Papel.accentInk
                                           : (decidido ? Papel.warning : Papel.inkFaint))
            Text(nombre)
            Spacer()
            // Sin preguntar, se pregunta. Denegado, no: eso solo se cambia en
            // los ajustes del sistema, porque el diálogo no vuelve a salir.
            if !decidido {
                Button("Pedir acceso") { Task { await pedir() } }
                    .font(.system(size: 14, weight: .medium))
            } else if !concedido {
                Button("Ajustes") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.system(size: 14, weight: .medium))
            } else {
                Text("Concedido")
                    .font(.system(size: 14))
                    .foregroundStyle(Papel.inkFaint)
            }
        }
    }
}

/// Lo que la app sabe de sí misma.
@MainActor
enum SobreLaApp {
    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    /// La carpeta, sin el contenedor: la ruta entera de una app de iOS empieza
    /// por un UUID que no dice nada a nadie y que además cambia al reinstalar.
    /// Lo que informa es la cola.
    ///
    /// Del almacén y no de `Store.localRoot`: desde que el widget existe, los
    /// datos viven en la carpeta del grupo, y enseñar la privada sería enseñar
    /// una carpeta vacía.
    @MainActor
    static func rutaDeDatos(_ store: Store) -> String {
        store.storageURL.pathComponents.suffix(3).joined(separator: "/")
    }
}
