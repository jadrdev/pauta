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
/// Se cierra con la X o tocando fuera.
struct CapturaView: View {
    let perspectiva: Perspective
    let alCerrar: () -> Void

    @Environment(Store.self) private var store
    @State private var texto = ""
    @State private var apuntadas = 0
    @FocusState private var enfocado: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 11) {
                    Circle()
                        .strokeBorder(Papel.accent.opacity(0.85),
                                      style: StrokeStyle(lineWidth: 1.6, dash: [2.5, 2.5]))
                        .frame(width: 21, height: 21)
                    TextField(marcador, text: $texto, axis: .vertical)
                        .font(.system(size: 17))
                        .foregroundStyle(Papel.ink)
                        .focused($enfocado)
                        .lineLimit(1...4)
                        .submitLabel(.done)
                        .onSubmit(guardar)
                    Button(action: alCerrar) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Papel.hairline)
                    }
                    .buttonStyle(.plain)
                }
                Text(pista)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Papel.inkFaint)
                    .padding(.top, 6)
                    .padding(.leading, 32)
        }
        .padding(.horizontal, 16)
        .padding(.top, 13)
        .padding(.bottom, 11)
        .background(.regularMaterial)
        .overlay(alignment: .top) {
            Rectangle().fill(Papel.hairline).frame(height: 1)
        }
        .onAppear { enfocado = true }
    }

    private var marcador: String {
        perspectiva.acceptsNewItems ? "Apunta lo que sea" : "Apuntar en la bandeja"
    }

    /// La pista dice a dónde va, porque desde «Más» se puede estar en un
    /// proyecto o en una etiqueta y no es obvio.
    private var pista: String {
        if apuntadas > 0 {
            return apuntadas == 1 ? "1 apuntada · sigue escribiendo"
                                  : "\(apuntadas) apuntadas · sigue escribiendo"
        }
        return perspectiva.acceptsNewItems
            ? "Va a \(store.title(for: perspectiva))"
            : "Va a la bandeja"
    }

    private func guardar() {
        let limpio = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !limpio.isEmpty else { alCerrar(); return }
        // Varias líneas pegadas de golpe son varias tareas, igual que en el Mac.
        let creadas = store.addItems(from: texto,
                                    in: perspectiva.acceptsNewItems ? perspectiva : .inbox)
        apuntadas += creadas.count
        texto = ""
        enfocado = true
    }
}
