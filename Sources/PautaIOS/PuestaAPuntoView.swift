import SwiftUI
import PautaCore

/// La tarjeta de bienvenida, debajo de la lista vacía.
///
/// Misma idea que en el Mac y por la misma razón: no hay asistente de páginas.
/// Pedir los permisos antes de que se haya visto una sola tarea es pedirlos
/// antes de que exista el motivo, y aquí un «no» es **para siempre** porque iOS
/// no vuelve a preguntar. Va donde ya hay hueco, se puede ignorar, y se va
/// cuando están todos contestados.
struct PuestaAPuntoView: View {
    let alConceder: (Permiso) -> Void

    @State private var pendientes: [Permiso] = []
    /// Los que están esperando respuesta. Un conjunto y no uno solo: si se
    /// pedían los dos seguidos, el primero en volver soltaba también el otro, y
    /// su botón volvía a «Activar» con el diálogo aún por salir.
    @State private var pidiendo: Set<Permiso> = []
    @Environment(\.scenePhase) private var fase

    var body: some View {
        // Un `Color.clear` de altura cero cuando no hay nada, en vez de dejar
        // que la vista sea vacía: un `.task` colgado de una vista que no existe
        // **no se ejecuta**, así que la consulta de los permisos no llegaba a
        // hacerse y la tarjeta no podía aparecer nunca. Hace falta algo real,
        // aunque no se vea, donde colgar la tarea.
        contenido
            // Y mientras quede algo pendiente, se vuelve a mirar cada dos
            // segundos. El diálogo del sistema puede tardar en salir —en un
            // aparato nuevo bajando de iCloud, mucho— o salir pedido desde otro
            // sitio, y la respuesta no siempre vuelve por el botón: sin esto la
            // tarjeta seguía ofreciendo lo que ya estaba concedido.
            .task {
                pendientes = await PuestaAPunto.pendientes()
                while !Task.isCancelled, !pendientes.isEmpty {
                    try? await Task.sleep(for: .seconds(2))
                    guard !Task.isCancelled else { return }
                    pendientes = await PuestaAPunto.pendientes()
                }
            }
            // Y al volver de fuera. Un permiso se puede conceder en los ajustes
            // del sistema, y también se puede haber concedido aquí sin que la
            // respuesta llegara de vuelta. En los dos casos la tarjeta se
            // corrige sola al volver, en vez de quedarse pidiendo algo que ya
            // tiene — que es la forma más rápida de que dejes de creerla.
            .onChange(of: fase) { _, nueva in
                guard nueva == .active else { return }
                Task {
                    pendientes = await PuestaAPunto.pendientes()
                    pidiendo = []
                }
            }
    }

    @ViewBuilder private var contenido: some View {
        if pendientes.isEmpty {
            Color.clear.frame(height: 0)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                Text("PARA QUE SIRVA DE ALGO").rubrica()
                    .padding(.bottom, 12)
                ForEach(pendientes, id: \.self) { permiso in
                    fila(permiso)
                    if permiso != pendientes.last { separador }
                }
        }
        .padding(16)
        .background(Papel.bgSide, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12)
            .strokeBorder(Papel.hairline, lineWidth: 1))
        .padding(.horizontal, 16)
        }
    }

    private var separador: some View {
        Rectangle().fill(Papel.hairline).frame(height: 1)
            .padding(.vertical, 11)
    }

    private func fila(_ permiso: Permiso) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: permiso.icono)
                .font(.system(size: 14))
                .foregroundStyle(Papel.accentInk)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(permiso.titulo)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Papel.ink)
                Text(permiso.motivo)
                    .font(.system(size: 13))
                    .foregroundStyle(Papel.inkFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Button {
                pidiendo.insert(permiso)
                Task {
                    await PuestaAPunto.pedir(permiso)
                    alConceder(permiso)
                    // Se relee en vez de quitar la fila a mano: quien decide si
                    // sigue pendiente es el sistema.
                    pendientes = await PuestaAPunto.pendientes()
                    pidiendo.remove(permiso)
                }
            } label: {
                Text(pidiendo.contains(permiso) ? "…" : "Activar")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Papel.accentInk)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 6)
                    .background(Papel.accent.opacity(0.16), in: Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            // Solo se apaga el que está preguntando. Apagarlos todos mientras
            // uno espera convierte un permiso atascado en una tarjeta muerta: no
            // podías ni intentar los otros dos.
            .disabled(pidiendo.contains(permiso))
        }
    }
}
