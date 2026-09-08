import SwiftUI
import PautaCore

/// La ficha de una tarea: lo justo para decidir sin abrir el Mac.
///
/// Título, notas, cuándo y la hora. Sin repetición, sin fecha límite, sin
/// etiquetas: eso se configura una vez sentado, y ofrecerlo todo en una hoja de
/// teléfono la convierte en un formulario que nadie rellena.
struct DetalleView: View {
    let item: Item

    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var cerrar
    @State private var titulo = ""
    @State private var notas = ""

    private var actual: Item? { store.items.first { $0.id == item.id } }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Título", text: $titulo, axis: .vertical)
                        .font(.system(size: 17, weight: .medium))
                    TextField("Notas", text: $notas, axis: .vertical)
                        .font(.system(size: 15))
                        .lineLimit(3...8)
                }
                Section("CUÁNDO") {
                    Button("Hoy") { conFecha(.now) }
                    Button("Mañana") {
                        conFecha(Calendar.current.date(byAdding: .day, value: 1, to: .now))
                    }
                    Button("Próxima semana") {
                        conFecha(Calendar.current.date(byAdding: .day, value: 7, to: .now))
                    }
                    Button("Algún día") { guardar(); store.park(item); cerrar() }
                    Button("Sin fecha") { conFecha(nil) }
                }
                if let actual, actual.when != nil {
                    Section("HORA") {
                        Picker("A las", selection: Binding(
                            get: { actual.timeOfDay ?? -1 },
                            set: { store.setTime(item, to: $0 < 0 ? nil : $0,
                                                 margenInicial: Ajustes.shared.margenPorDefecto) }
                        )) {
                            Text("Sin hora").tag(-1)
                            ForEach(Array(stride(from: 6 * 60, through: 22 * 60, by: 30)),
                                    id: \.self) { m in
                                Text(Self.hora(m)).tag(m)
                            }
                        }
                    }
                }
                Section {
                    Button("Eliminar", role: .destructive) {
                        store.delete(item); cerrar()
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Papel.bg)
            .navigationTitle("Tarea")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { guardar(); cerrar() }
                }
            }
        }
        .onAppear {
            titulo = item.title
            notas = item.notes
        }
    }

    private func conFecha(_ fecha: Date?) {
        guardar()
        store.schedule(item, to: fecha)
        cerrar()
    }

    /// Se guarda al salir y no en cada tecla: en el teléfono cada pulsación
    /// escribiría un archivo, y el teclado se abre y se cierra a cada rato.
    private func guardar() {
        guard var copia = actual else { return }
        guard copia.title != titulo || copia.notes != notas else { return }
        copia.title = titulo
        copia.notes = notas
        store.update(copia)
    }

    static func hora(_ minutos: Int) -> String {
        let base = Calendar.current.startOfDay(for: .now)
        return Calendar.current.date(byAdding: .minute, value: minutos, to: base)?
            .formatted(.dateTime.hour().minute()) ?? ""
    }
}
