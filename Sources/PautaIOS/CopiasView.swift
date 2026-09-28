import SwiftUI
import PautaCore

/// Las copias de seguridad del teléfono, y volver a una.
///
/// Son las de **este** teléfono, de su carpeta: las del Mac están en iCloud,
/// junto a sus datos. Volver a una aquí escribe con fecha nueva, así que el
/// cruce se lo lleva al Mac como cualquier otro cambio.
struct CopiasView: View {
    @Environment(Store.self) private var store
    @State private var copias: [Copias.Guardada] = []
    @State private var aRestaurar: Copias.Guardada?
    @State private var restaurada: String?

    var body: some View {
        List {
            if let restaurada {
                Section { Text(restaurada).foregroundStyle(Papel.accentInk) }
            }
            Section {
                if copias.isEmpty {
                    Text("Todavía ninguna: se hace la primera al abrir la app.")
                        .foregroundStyle(Papel.inkSoft)
                }
                ForEach(copias) { copia in
                    Button { aRestaurar = copia } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(copia.titulo).foregroundStyle(Papel.ink)
                            Text(copia.detalle)
                                .font(.footnote)
                                .foregroundStyle(Papel.inkSoft)
                        }
                    }
                }
            } footer: {
                Text("Una al día, de los últimos \(Copias.cuantas) días. Volver a una deja "
                     + "todo como estaba ese día; lo apuntado después va a la papelera, "
                     + "y antes se guarda una copia de ahora.")
            }
        }
        .navigationTitle("Copias de seguridad")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { copias = store.copias }
        .confirmationDialog(
            "¿Dejar todo como estaba el \(aRestaurar?.titulo.lowercased() ?? "")?",
            isPresented: Binding(get: { aRestaurar != nil },
                                 set: { if !$0 { aRestaurar = nil } }),
            titleVisibility: .visible
        ) {
            Button("Volver a esa copia", role: .destructive) {
                guard let elegida = aRestaurar, let copia = Copias.leer(elegida.url) else { return }
                store.restaurar(copia)
                restaurada = "Hecho: todo está como el \(elegida.titulo.lowercased())."
                copias = store.copias
            }
        } message: {
            Text("Lo que hayas apuntado después irá a la papelera. Antes se guarda una "
                 + "copia de cómo está ahora, por si quieres volver.")
        }
    }
}
