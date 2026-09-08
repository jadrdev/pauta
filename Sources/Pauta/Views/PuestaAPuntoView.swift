import SwiftUI
import AppKit
import PautaCore

/// La tarjeta de bienvenida, debajo de la lista vacía.
///
/// No es un asistente de páginas a propósito: pedir tres permisos antes de que
/// se haya visto una sola tarea es pedirlos antes de que exista el motivo, y
/// aquí un «no» es **para siempre** porque el sistema no vuelve a preguntar. Va
/// donde ya hay hueco —el vacío de Hoy—, se puede ignorar, y desaparece cuando
/// los tres están contestados.
struct PuestaAPuntoView: View {
    /// Qué hacer después de conceder cada uno: recargar el calendario, traer
    /// los recordatorios, reprogramar los avisos. La tarjeta pide; lo que va
    /// detrás lo sabe la app.
    let alConceder: (Permiso) -> Void

    @State private var pendientes: [Permiso] = []
    @State private var pidiendo: Permiso?

    var body: some View {
        // Un `Color.clear` de altura cero cuando no hay nada, en vez de dejar
        // que la vista sea vacía: un `.task` colgado de una vista que no existe
        // **no se ejecuta**, así que la consulta de los permisos no llegaba a
        // hacerse y la tarjeta no podía aparecer nunca. Hace falta algo real,
        // aunque no se vea, donde colgar la tarea.
        contenido
            .task { pendientes = await PuestaAPunto.pendientes() }
    }

    @ViewBuilder private var contenido: some View {
        if pendientes.isEmpty {
            Color.clear.frame(height: 0)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                Text("PARA QUE SIRVA DE ALGO").rubricStyle()
                    .padding(.bottom, 10)
                ForEach(pendientes, id: \.self) { permiso in
                    fila(permiso)
                    if permiso != pendientes.last {
                        Rectangle().fill(Paper.hairline).frame(height: 1)
                            .padding(.vertical, 9)
                    }
                }
        }
        .padding(14)
        .background(Paper.bgSide, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10)
            .strokeBorder(Paper.hairline, lineWidth: 1))
        .frame(maxWidth: 420)
        }
    }

    private func fila(_ permiso: Permiso) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: permiso.icono)
                .font(.system(size: 12))
                .foregroundStyle(Paper.accentInk)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(permiso.titulo)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Paper.ink)
                Text(permiso.motivo)
                    .font(.system(size: 12))
                    .foregroundStyle(Paper.inkFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Button {
                pidiendo = permiso
                Task {
                    await PuestaAPunto.pedir(permiso)
                    alConceder(permiso)
                    // Se relee en vez de quitar la fila a mano: quien decide si
                    // sigue pendiente es el sistema, y si el diálogo no llegó a
                    // salir la fila tiene que quedarse.
                    pendientes = await PuestaAPunto.pendientes()
                    pidiendo = nil
                }
            } label: {
                Text(pidiendo == permiso ? "…" : "Activar")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Paper.accentInk)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 4)
                    .background(Paper.accent.opacity(0.14), in: Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(pidiendo != nil)
        }
    }
}
