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
    @State private var eligiendo = false
    /// Lo que movió el último cruce, para poder decirlo en vez de dejar al
    /// usuario adivinando si sirvió de algo.
    @State private var balance: Puente.Balance?
    @State private var avisos: UNAuthorizationStatus = .notDetermined
    @State private var calendario = Agenda.authorization
    @State private var recordatorios = RemindersInbox.authorization

    private static let horasDeRepaso = [7 * 60, 7 * 60 + 30, 8 * 60, 8 * 60 + 30,
                                        9 * 60, 9 * 60 + 30, 10 * 60]

    private static func resumen(_ b: Puente.Balance) -> String {
        if b.traidas == 0 && b.llevadas == 0 {
            return b.pendientesDeBajar > 0
                ? "Nada que cruzar · \(b.pendientesDeBajar) sin bajar de iCloud"
                : "Nada que cruzar: ya estaban iguales"
        }
        var partes: [String] = []
        if b.traidas > 0 { partes.append("\(b.traidas) del Mac") }
        if b.llevadas > 0 { partes.append("\(b.llevadas) al Mac") }
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
                }
                FilaDePermiso(nombre: "Calendario",
                              concedido: calendario == .fullAccess,
                              decidido: calendario != .notDetermined) {
                    _ = await Agenda().requestAccess()
                    calendario = Agenda.authorization
                }
                FilaDePermiso(nombre: "Recordatorios",
                              concedido: recordatorios == .fullAccess,
                              decidido: recordatorios != .notDetermined) {
                    _ = try? await RemindersInbox().requestAccess()
                    recordatorios = RemindersInbox.authorization
                }
            } header: {
                Text("PERMISOS")
            } footer: {
                Text("Los avisos hacen falta para las horas y el repaso; el "
                     + "calendario, para ver los eventos en Hoy; Recordatorios, "
                     + "para traer lo que dictas a Siri. Si están denegados, se "
                     + "cambian en los ajustes del sistema: el diálogo no vuelve "
                     + "a salir.")
            }

            Section {
                if carpeta.caducada {
                    // El fallo del que se avisa al ofrecer esto, dicho en su
                    // sitio: sin esta línea la sincronización se pararía en
                    // silencio, que es la peor forma de fallar.
                    Label("La carpeta que elegiste ya no está", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(Papel.warning)
                }
                if let elegida = carpeta.url {
                    HStack {
                        Text("Carpeta")
                        Spacer()
                        Text(elegida.lastPathComponent)
                            .foregroundStyle(Papel.inkSoft)
                    }
                    Button {
                        balance = Sincronizar.conElMac(store)
                    } label: {
                        Label("Cruzar ahora", systemImage: "arrow.triangle.2.circlepath")
                    }
                    if let balance {
                        Text(Self.resumen(balance))
                            .font(.system(size: 12.5))
                            .foregroundStyle(Papel.inkFaint)
                    }
                    Button("Olvidar la carpeta", role: .destructive) {
                        carpeta.olvidar()
                        balance = nil
                    }
                } else {
                    Button {
                        eligiendo = true
                    } label: {
                        Label(carpeta.caducada ? "Volver a elegirla" : "Elegir la carpeta de Pauta…",
                              systemImage: "folder.badge.plus")
                    }
                }
            } header: {
                Text("LA CARPETA DEL MAC")
            } footer: {
                // Un literal de varias líneas y no trozos sumados: `Text` solo
                // interpreta el **negrita** cuando lo que recibe es un literal.
                // Con `+` llega un `String` ya hecho y los asteriscos se
                // dibujan tal cual — visto en pantalla.
                Text("""
                     Elige la carpeta **Pauta** de tu iCloud Drive y el teléfono \
                     cruzará sus tareas con las del Mac al volver a la app. Cada \
                     lado guarda las suyas, así que esto funciona aunque la \
                     carpeta no esté; y de cada tarea gana la versión más reciente.

                     Si mueves o renombras esa carpeta, el permiso deja de valer y \
                     habrá que elegirla otra vez — se avisa aquí.
                     """)
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
                     + "Con el Mac se cruzan arriba, y lo que dictes a Siri en "
                     + "Recordatorios llega igual por su cuenta.")
            }

            Section {
                enlace("Código", "chevron.left.forwardslash.chevron.right",
                       Enlaces.repositorio)
                enlace("Novedades", "sparkles", Enlaces.novedades)
                enlace("Escribir al desarrollador", "envelope", Enlaces.problemas)
                Button("Restaurar los valores de fábrica") { ajustes.restaurar() }
            } header: {
                Text("PAUTA \(SobreLaApp.version)")
            } footer: {
                Text("Hecho por @jadrdev · © 2026 Joshua A. Díaz Robayna · Todos "
                     + "los derechos reservados")
            }
        }
        // Solo carpetas: lo que hace falta es el permiso sobre el directorio
        // entero, no sobre un archivo.
        .fileImporter(isPresented: $eligiendo, allowedContentTypes: [.folder]) { resultado in
            guard case .success(let elegida) = resultado else { return }
            guard carpeta.elegir(elegida) else { return }
            // Se cruza en el momento: elegir la carpeta y no ver pasar nada
            // dejaría la duda de si sirvió.
            balance = Sincronizar.conElMac(store)
        }
        .scrollContentBackground(.hidden)
        .background(Papel.bg)
        .navigationTitle("Ajustes")
        .task {
            avisos = await Avisos.authorization()
            calendario = Agenda.authorization
            recordatorios = RemindersInbox.authorization
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
