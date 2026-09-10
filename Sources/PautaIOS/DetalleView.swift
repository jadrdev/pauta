import SwiftUI
import PautaCore

/// La ficha de una tarea: lo justo para decidir sin abrir el Mac.
///
/// Título, notas, cuándo, la hora y si se repite. Sin fecha límite y sin
/// etiquetas: eso se configura una vez sentado, y ofrecerlo todo en una hoja de
/// teléfono la convierte en un formulario que nadie rellena.
///
/// La repetición estaba fuera por esa misma regla y era la excepción: «esto es
/// todos los días» no se decide sentado delante del Mac, se decide en el
/// momento en que te das cuenta —tomando la pastilla, regando, estirando— y ese
/// momento pasa con el teléfono en la mano. Y cabe en una fila, que es lo que
/// la separa de un formulario.
///
/// Lo que no sube es **hasta cuándo**: «cada día hasta el 15 de octubre» sí es
/// una decisión de sentarse. Si el Mac le puso un fin, aquí se dice para no
/// mentir sobre una serie que acaba, pero no se cambia.
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
                    // Y cualquier otro día. Sin esto, «para más adelante» eran
                    // mañana y la semana que viene y nada más: para el viernes
                    // había que abrir el Mac.
                    //
                    // El calendario se ata **al día de la tarea** en vez de a un
                    // estado propio de la vista: así no hay que sembrarlo al
                    // aparecer —lo que dispararía un cambio de fecha sin que
                    // nadie lo pidiera— y siempre enseña lo que la tarea tiene.
                    DatePicker("Otro día", selection: Binding(
                        get: { actual?.when ?? Self.manana },
                        set: { conFecha($0, cerrando: false) }
                    ), displayedComponents: .date)
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
                // Solo si hay alguno: un selector con «Ninguno» y nada más
                // sería una fila que no hace nada. Se crean en «Más».
                if !store.projects.isEmpty {
                    Section("PROYECTO") {
                        Picker("En", selection: Binding(
                            get: { actual?.projectID },
                            set: { ponerProyecto($0) }
                        )) {
                            Text("Ninguno").tag(Optional<UUID>.none)
                            ForEach(store.projects) { proyecto in
                                Text(proyecto.icon.isEmpty ? proyecto.name
                                                           : "\(proyecto.icon) \(proyecto.name)")
                                    .tag(Optional(proyecto.id))
                            }
                        }
                    }
                }
                Section("REPETICIÓN") {
                    Picker("Se repite", selection: Binding(
                        get: { actual?.recurrence },
                        set: { store.setRecurrence(item, to: $0) }
                    )) {
                        Text("No se repite").tag(Optional<Recurrence>.none)
                        ForEach(Recurrence.allCases, id: \.self) { cada in
                            Text(cada.title).tag(Optional(cada))
                        }
                    }
                    // Informativo y no un control: el fin de la serie se pone en
                    // el Mac, pero callarlo aquí haría parecer eterna una
                    // repetición que tiene fecha de caducidad.
                    if let fin = actual?.recurrenceEnd {
                        HStack {
                            Text("Acaba el")
                            Spacer()
                            Text(fin.formatted(.dateTime.day().month(.abbreviated).year()))
                                .foregroundStyle(Papel.inkSoft)
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

    private func conFecha(_ fecha: Date?, cerrando: Bool = true) {
        guardar()
        store.schedule(item, to: fecha)
        // Los atajos cierran la ficha —era una decisión y ya está tomada—, pero
        // el calendario no: se abre, se elige un día y se ve que el día quedó
        // puesto sin que la pantalla se vaya debajo del dedo.
        if cerrando { cerrar() }
    }

    /// Meter la tarea en un proyecto, o sacarla.
    ///
    /// Sacarla **solo le quita el proyecto**: no se usa «mover a la bandeja»,
    /// que además le quitaría el día. Una tarea de mañana que sale de un
    /// proyecto sigue siendo de mañana.
    private func ponerProyecto(_ id: UUID?) {
        guardar()
        if let id {
            store.move(item, to: .project(id))
        } else if var copia = actual {
            copia.projectID = nil
            store.update(copia)
        }
    }

    private static var manana: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
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
