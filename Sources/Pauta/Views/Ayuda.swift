import SwiftUI
import AppKit
import EventKit
import UserNotifications
import PautaCore

/// La ayuda de la app.
///
/// Una ventana propia y **no un libro de ayuda de Apple**: un help book exige
/// empaquetar un bundle de HTML con su índice hecho con `hiutil` y confiar en el
/// visor del sistema, para un contenido que cabe en una pantalla. La guía larga
/// ya vive en el README, y desde aquí se abre.
///
/// Lo que sí tiene que estar aquí dentro son las dos cosas que no se pueden
/// leer en ningún sitio: **los atajos** —empezando por el global, que si no se
/// conoce no existe— y **los permisos**, porque tres funciones de la app las da
/// el sistema y cuando dice no, la app se queda muda sin explicar por qué.
struct AyudaView: View {
    @State private var avisos: UNAuthorizationStatus = .notDetermined
    /// Observable, para que cambiar el atajo en los ajustes se vea aquí.
    @State private var alta = AltaRapida.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Ayuda")
                .font(.display(26))
                .tracking(-0.5)
                .foregroundStyle(Paper.ink)

            Text("ATAJOS").rubricStyle().padding(.top, 18)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(atajos, id: \.0) { atajo, que in
                    FilaDeAtajo(atajo: atajo, que: que)
                }
            }
            .padding(.top, 8)

            Text("PERMISOS").rubricStyle().padding(.top, 22)
            Text("Tres cosas las hace el sistema y no la app. Si están en «no», "
                 + "esa parte se queda muda.")
                .font(.system(size: 11.5))
                .foregroundStyle(Paper.inkFaint)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
            VStack(alignment: .leading, spacing: 0) {
                FilaDePermiso(
                    nombre: "Avisos",
                    para: "avisar de lo que tiene hora",
                    concedido: avisos == .authorized,
                    decidido: avisos != .notDetermined,
                    ajustes: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")
                FilaDePermiso(
                    nombre: "Calendario",
                    para: "enseñar los eventos en Hoy",
                    concedido: Agenda.isAuthorized,
                    decidido: Agenda.authorization != .notDetermined,
                    ajustes: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")
                FilaDePermiso(
                    nombre: "Recordatorios",
                    para: "traer lo que dictas a Siri",
                    concedido: RemindersInbox.authorization == .fullAccess,
                    decidido: RemindersInbox.authorization != .notDetermined,
                    ajustes: "x-apple.systempreferences:com.apple.preference.security?Privacy_Reminders")
            }
            .padding(.top, 8)

            Rectangle().fill(Paper.hairline).frame(height: 1).padding(.vertical, 16)

            HStack(spacing: 14) {
                EnlaceDeTexto("Guía completa") { NSWorkspace.shared.open(Enlaces.guia) }
                EnlaceDeTexto("Informar de un problema") {
                    NSWorkspace.shared.open(Enlaces.problemas)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(26)
        .frame(width: 440)
        .background(Paper.bg)
        // Al abrirla y no una vez: el permiso se puede haber concedido o
        // revocado en los ajustes mientras la ventana estaba cerrada.
        .task { avisos = await Avisos.authorization() }
    }

    /// El atajo del alta rápida se lee del que quedó **registrado**, no del que
    /// se pidió: si ⌃Espacio estaba cogido, la app cayó a otro y decir el
    /// primero sería mentir.
    private var atajos: [(String, String)] {
        [(alta.combinacion ?? Ajustes.shared.atajo.descripcion,
          "Apuntar algo desde cualquier app"),
         ("⌘N", "Nueva tarea en la lista de delante"),
         ("⌘⇧N", "Nuevo proyecto"),
         ("⌘⌥N", "Nueva área"),
         ("↩", "Guardar y seguir con otra tarea"),
         ("esc", "Dejarlo estar"),
         ("⌘1 … ⌘6", "Saltar de lista, en el orden de la barra lateral"),
         ("⌘⇧R", "Traer lo apuntado en Recordatorios"),
         ("⌘0", "Volver a la ventana principal")]
    }
}

private struct FilaDeAtajo: View {
    let atajo: String
    let que: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(atajo)
                .font(.system(size: 11.5, weight: .semibold).monospaced())
                .foregroundStyle(Paper.ink)
                .frame(width: 82, alignment: .leading)
            Text(que)
                .font(.system(size: 12))
                .foregroundStyle(Paper.inkSoft)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
}

private struct FilaDePermiso: View {
    let nombre: String
    let para: String
    let concedido: Bool
    let decidido: Bool
    let ajustes: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: concedido ? "checkmark.circle.fill"
                                        : (decidido ? "xmark.circle.fill" : "circle.dotted"))
                .font(.system(size: 11))
                .foregroundStyle(concedido ? Paper.accentInk
                                          : (decidido ? Paper.warning : Paper.inkFaint))
            VStack(alignment: .leading, spacing: 1) {
                Text(nombre)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Paper.ink)
                Text(estado)
                    .font(.system(size: 11))
                    .foregroundStyle(Paper.inkFaint)
            }
            Spacer(minLength: 8)
            // Solo cuando ya se dijo que no: una decisión denegada no se cambia
            // volviendo a preguntar, solo en los ajustes. Y si aún no se ha
            // preguntado, la app lo hará ella cuando toque.
            if decidido && !concedido {
                EnlaceDeTexto("Ajustes") {
                    if let url = URL(string: ajustes) { NSWorkspace.shared.open(url) }
                }
            }
        }
        .padding(.vertical, 5)
    }

    private var estado: String {
        if concedido { return "Concedido, para \(para)" }
        if decidido { return "Denegado — hace falta para \(para)" }
        return "Sin preguntar todavía, para \(para)"
    }
}
