import SwiftUI
import PautaCore

/// El botón de apuntar.
///
/// Flotante y abajo a la derecha, no una franja fija: el campo de alta se usa a
/// ráfagas y una franja permanente cobra sitio a la lista todo el rato. Aquí el
/// pulgar lo encuentra sin mirar y no tapa nada mientras no se usa.
struct BotonDeApuntar: View {
    let accion: () -> Void

    var body: some View {
        Button(action: accion) {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Papel.bg)
                .frame(width: 56, height: 56)
                .background(Papel.accent, in: Circle())
                .shadow(color: .black.opacity(0.22), radius: 9, y: 4)
        }
        .buttonStyle(.plain)
        .padding(.trailing, 20)
        .padding(.bottom, 20)
    }
}

/// El campo para apuntar, sobre el teclado.
///
/// No se cierra al guardar: guardar y seguir escribiendo es lo que permite
/// vaciar la cabeza de tres cosas seguidas, que es cuando de verdad hace falta.
struct CapturaView: View {
    let perspectiva: Perspective
    let alCerrar: () -> Void

    @Environment(Store.self) private var store
    @State private var texto = ""
    @State private var apuntadas = 0
    @FocusState private var enfocado: Bool

    private var hayTexto: Bool {
        !texto.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .bottom, spacing: 10) {
                TextField(marcador, text: $texto, axis: .vertical)
                    .font(.system(size: 17))
                    .foregroundStyle(Papel.ink)
                    .focused($enfocado)
                    .lineLimit(1...4)
                    .submitLabel(.done)
                    .onSubmit(guardar)
                boton
            }
            pista
        }
        .padding(.leading, 16)
        .padding(.trailing, 10)
        .padding(.top, 11)
        .padding(.bottom, 9)
        // Fondo del papel de la app y no un material del sistema: sobre la lista
        // en crema, `.regularMaterial` se resolvía en una franja gris plana que
        // parecía desactivada.
        .background(Papel.bg)
        .overlay(alignment: .top) {
            Rectangle().fill(Papel.hairline).frame(height: 1)
        }
        .onAppear { enfocado = true }
        // La tecla de retorno de un campo **multilínea** no dispara `onSubmit`:
        // mete un salto de línea. Con el teclado del Mac sí lo dispara, así que
        // en el simulador parecía funcionar y en el teléfono no guardaba nada.
        // El salto de línea **es** la señal de guardar, y de paso pegar varias
        // líneas de golpe sigue creando varias tareas, como en el Mac.
        .onChange(of: texto) { _, nuevo in
            guard nuevo.contains("\n") else { return }
            guardar()
        }
    }

    /// Enviar cuando hay algo escrito, cerrar cuando no.
    ///
    /// Un solo botón, y el que toca en cada momento. Antes solo estaba la X
    /// —cerrar y **perder lo escrito**—, que era el control más destructivo en
    /// el único sitio donde el dedo iba a buscar «añadir».
    @ViewBuilder private var boton: some View {
        if hayTexto {
            Button(action: guardar) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Papel.bg)
                    .frame(width: 32, height: 32)
                    .background(Papel.accent, in: Circle())
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            Button(action: alCerrar) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Papel.inkFaint)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var marcador: String {
        perspectiva.acceptsNewItems ? "Apunta lo que sea" : "Apuntar en la bandeja"
    }

    /// Debajo: a dónde va lo que escribes, o lo que ya llevas apuntado.
    ///
    /// Lo apuntado se dice **en verde y con su marca**, no en gris: la tarea
    /// nueva aparece en la lista, que en ese momento está detrás del teclado, y
    /// sin una confirmación visible parecía que no había pasado nada.
    @ViewBuilder private var pista: some View {
        if apuntadas > 0 {
            HStack(spacing: 5) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 11))
                Text(apuntadas == 1 ? "1 apuntada · sigue escribiendo"
                                    : "\(apuntadas) apuntadas · sigue escribiendo")
                    .font(.system(size: 11.5, weight: .medium))
            }
            .foregroundStyle(Papel.accentInk)
            .padding(.top, 5)
        } else {
            Text(perspectiva.acceptsNewItems ? "Va a \(store.title(for: perspectiva))"
                                             : "Va a la bandeja")
                .font(.system(size: 11.5))
                .foregroundStyle(Papel.inkFaint)
                .padding(.top, 5)
        }
    }

    private func guardar() {
        // Varias líneas pegadas de golpe son varias tareas, igual que en el Mac.
        let creadas = store.addItems(from: texto,
                                    in: perspectiva.acceptsNewItems ? perspectiva : .inbox)
        texto = ""
        enfocado = true
        // Sin nada que guardar —un salto de línea suelto— no se cuenta nada ni
        // se cierra: cerrar el campo porque pulsaste ✓ en blanco es perder el
        // sitio sin haber pedido irte.
        guard !creadas.isEmpty else { return }
        apuntadas += creadas.count
    }
}
