import SwiftUI
import PautaCore

/// La tarjeta de bienvenida, debajo de la lista vacía.
///
/// Misma idea que en el Mac y por la misma razón: no hay asistente de páginas.
/// Pedir tres permisos antes de que se haya visto una sola tarea es pedirlos
/// antes de que exista el motivo, y aquí un «no» es **para siempre** porque iOS
/// no vuelve a preguntar. Va donde ya hay hueco, se puede ignorar, y se va
/// cuando los tres están contestados.
struct PuestaAPuntoView: View {
    let alConceder: (Permiso) -> Void
    /// Qué hacer cuando se elige la carpeta del Mac. Lo pone quien tenga el
    /// almacén: aquí no hay ninguno.
    let alElegirCarpeta: () -> Void
    /// No hay ni una tarea en ninguna lista.
    let estrenando: Bool

    @State private var pendientes: [Permiso] = []
    @State private var pidiendo: Permiso?
    @State private var carpeta = CarpetaElegida.shared
    @State private var eligiendo = false
    @Environment(\.scenePhase) private var fase

    /// La carpeta se ofrece mientras no haya una elegida **y no haya nada
    /// apuntado todavía**.
    ///
    /// Las dos condiciones, y la segunda importa más de lo que parece. A un
    /// permiso se le contesta que sí o que no y desaparece; a esto no hay forma
    /// de contestarle «no uso el Mac». Sin la segunda condición, quien nunca haya
    /// usado el Mac se queda la fila puesta para siempre, y un ofrecimiento que
    /// no se va nunca deja de ser una bienvenida y pasa a ser un mueble.
    ///
    /// Atada al estreno se resuelve sola para los dos: quien viene del Mac elige
    /// la carpeta, y quien empieza de cero apunta su primera tarea y la fila se
    /// va. Y es el único momento en que la oferta significa algo — traer tus
    /// tareas se ofrece cuando no hay ninguna.
    ///
    /// Va **la última**, detrás de los permisos: los permisos son de esta app, y
    /// esto es de otra que a lo mejor no tienes. Formulada como pregunta por lo
    /// mismo — quien llega nuevo de verdad la lee, ve que no va con él y sigue.
    /// Una fila que dijera «conecta tu Mac» le haría creer que le falta un paso.
    private var ofreceCarpeta: Bool { estrenando && !carpeta.elegida }

    var body: some View {
        // Un `Color.clear` de altura cero cuando no hay nada, en vez de dejar
        // que la vista sea vacía: un `.task` colgado de una vista que no existe
        // **no se ejecuta**, así que la consulta de los permisos no llegaba a
        // hacerse y la tarjeta no podía aparecer nunca. Hace falta algo real,
        // aunque no se vea, donde colgar la tarea.
        contenido
            .task { pendientes = await PuestaAPunto.pendientes() }
            // Y al volver de fuera. Un permiso se puede conceder en los ajustes
            // del sistema, y también se puede haber concedido aquí sin que la
            // respuesta llegara de vuelta. En los dos casos la tarjeta se
            // corrige sola al volver, en vez de quedarse pidiendo algo que ya
            // tiene — que es la forma más rápida de que dejes de creerla.
            .onChange(of: fase) { _, nueva in
                guard nueva == .active else { return }
                Task {
                    pendientes = await PuestaAPunto.pendientes()
                    pidiendo = nil
                }
            }
    }

    @ViewBuilder private var contenido: some View {
        if pendientes.isEmpty && !ofreceCarpeta {
            Color.clear.frame(height: 0)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                Text("PARA QUE SIRVA DE ALGO").rubrica()
                    .padding(.bottom, 12)
                ForEach(pendientes, id: \.self) { permiso in
                    fila(permiso)
                    if permiso != pendientes.last || ofreceCarpeta { separador }
                }
                if ofreceCarpeta { filaDeCarpeta }
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

    /// La carpeta del Mac, ofrecida donde se mira.
    ///
    /// Hasta ahora esto vivía en `Más ▸ Ajustes`: tres toques y una pantalla que
    /// solo abres si ya sospechas que existe. Quien llega al teléfono con la app
    /// del Mac llena de tareas veía una lista vacía y ningún camino — y quien
    /// perdió los datos del teléfono, tampoco.
    private var filaDeCarpeta: some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 14))
                .foregroundStyle(Papel.accentInk)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text("¿Ya usas Pauta en el Mac?")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Papel.ink)
                // Se nombra la carpeta con todas las letras: elegir la raíz de
                // iCloud Drive no rompe nada, pero tampoco cruza, y quedarse
                // mirando un «nada que cruzar» sin saber por qué es peor que no
                // haberlo intentado.
                Text("Elige su carpeta **Pauta** en iCloud Drive y tus tareas aparecen aquí.")
                    .font(.system(size: 13))
                    .foregroundStyle(Papel.inkFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Button { eligiendo = true } label: {
                Text("Elegir")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Papel.accentInk)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 6)
                    .background(Papel.accent.opacity(0.16), in: Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        // Solo carpetas: lo que hace falta es el permiso sobre el directorio
        // entero, no sobre un archivo.
        .fileImporter(isPresented: $eligiendo, allowedContentTypes: [.folder]) { resultado in
            guard case .success(let elegida) = resultado else { return }
            guard carpeta.elegir(elegida) else { return }
            // Se cruza en el momento: elegirla y no ver pasar nada dejaría la
            // duda de si sirvió.
            alElegirCarpeta()
        }
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
                pidiendo = permiso
                Task {
                    await PuestaAPunto.pedir(permiso)
                    alConceder(permiso)
                    // Se relee en vez de quitar la fila a mano: quien decide si
                    // sigue pendiente es el sistema.
                    pendientes = await PuestaAPunto.pendientes()
                    pidiendo = nil
                }
            } label: {
                Text(pidiendo == permiso ? "…" : "Activar")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Papel.accentInk)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 6)
                    .background(Papel.accent.opacity(0.16), in: Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            // Solo se apaga el que está preguntando. Apagarlos los tres mientras
            // uno espera convierte un permiso atascado en una tarjeta muerta: no
            // podías ni intentar los otros dos.
            .disabled(pidiendo == permiso)
        }
    }
}
