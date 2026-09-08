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

    @State private var avisos: UNAuthorizationStatus = .notDetermined
    @State private var calendario = Agenda.authorization

    private static let horasDeRepaso = [7 * 60, 7 * 60 + 30, 8 * 60, 8 * 60 + 30,
                                        9 * 60, 9 * 60 + 30, 10 * 60]

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
            } header: {
                Text("PERMISOS")
            } footer: {
                Text("Los avisos hacen falta para las horas y el repaso; el "
                     + "calendario, para ver los eventos en Hoy. Si están "
                     + "denegados, se cambian en los ajustes del sistema: el "
                     + "diálogo no vuelve a salir.")
            }

            Section {
                Text(SobreLaApp.rutaDeDatos)
                    .font(.system(size: 13).monospaced())
                    .foregroundStyle(Papel.inkSoft)
                    .textSelection(.enabled)
            } header: {
                Text("TUS DATOS")
            } footer: {
                // Es la pregunta que se hace cualquiera que tenga las dos apps,
                // y callarla haría parecer que la app está rota.
                Text("En este teléfono. Todavía **no se sincroniza con el Mac**: "
                     + "entrar en la carpeta de iCloud necesita permisos que solo "
                     + "da la cuenta de desarrollador de pago. Mientras tanto, lo "
                     + "que dictes a Siri en Recordatorios sí llega al Mac.")
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
        .scrollContentBackground(.hidden)
        .background(Papel.bg)
        .navigationTitle("Ajustes")
        .task {
            avisos = await Avisos.authorization()
            calendario = Agenda.authorization
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
    static var rutaDeDatos: String {
        Store.localRoot.pathComponents.suffix(3).joined(separator: "/")
    }
}
