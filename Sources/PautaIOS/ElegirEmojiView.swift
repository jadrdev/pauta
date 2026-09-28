import SwiftUI
import PautaCore

/// Elegir el emoji de un proyecto o un área.
///
/// Los mismos cuarenta del Mac, por temas. En el teléfono cada tema lleva su
/// nombre encima: aquí no hay ratón que pase por encima para adivinar, y una
/// rejilla de cuarenta sin rótulos se lee como un teclado.
struct ElegirEmojiView: View {
    let actual: String
    let alElegir: (String) -> Void
    @Environment(\.dismiss) private var cerrar
    @State private var otro = ""

    private let columnas = Array(repeating: GridItem(.flexible(), spacing: 4), count: 8)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(Iconos.temas, id: \.nombre) { tema in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(tema.nombre.uppercased())
                                .font(.system(size: 12, weight: .semibold))
                                .tracking(0.6)
                                .foregroundStyle(Papel.inkFaint)
                            LazyVGrid(columns: columnas, spacing: 4) {
                                ForEach(tema.emojis, id: \.self) { emoji in
                                    Button { elegir(emoji) } label: {
                                        Text(emoji)
                                            .font(.system(size: 26))
                                            .frame(maxWidth: .infinity, minHeight: 42)
                                            .background(actual == emoji ? Papel.accentInk.opacity(0.16)
                                                                        : .clear,
                                                        in: RoundedRectangle(cornerRadius: 8))
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(emoji)
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("OTRO")
                            .font(.system(size: 12, weight: .semibold))
                            .tracking(0.6)
                            .foregroundStyle(Papel.inkFaint)
                        // Cualquiera que no esté: con el teclado de emojis, o
                        // pegado.
                        TextField("Escribe o pega un emoji", text: $otro)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: otro) {
                                guard let elegido = Iconos.emoji(en: otro) else { return }
                                elegir(elegido)
                            }
                    }
                }
                .padding(16)
            }
            .background(Papel.bg)
            .navigationTitle("Emoji")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
                if !actual.isEmpty {
                    ToolbarItem(placement: .destructiveAction) {
                        Button("Quitar") { elegir("") }
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func elegir(_ emoji: String) {
        alElegir(emoji)
        cerrar()
    }
}
