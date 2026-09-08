import SwiftUI
import PautaCore

/// Pauta en el teléfono.
///
/// Comparte con el Mac todo el núcleo —modelo, almacén, consultas, avisos— y no
/// comparte una sola vista, a propósito. Un teléfono no se maneja como un Mac:
/// no hay barra lateral que quepa, no hay clic derecho, y la mano tapa media
/// pantalla. Las listas son las mismas; la forma de andar por ellas, no.
@main
@MainActor
struct PautaIOSApp: App {
    @State private var store = Store()

    init() {
        // Antes de la interfaz: un aviso pulsado con la app cerrada se entrega
        // sin nadie que lo atienda si el delegado llega tarde.
        Avisos.hookUp()
    }

    var body: some Scene {
        WindowGroup {
            ListaView()
                .environment(store)
        }
    }
}

/// Las listas que caben en un teléfono.
///
/// Cinco y no las siete del Mac: «Completadas» es un archivo que se consulta
/// sentado, y las áreas son una forma de ordenar muchos proyectos que aquí no
/// tiene dónde enseñarse todavía.
private let perspectivas: [Perspective] = [.inbox, .today, .upcoming, .anytime, .someday]

struct ListaView: View {
    @Environment(Store.self) private var store
    @Environment(\.scenePhase) private var fase

    @State private var perspectiva: Perspective = .today
    @State private var borrador = ""
    @State private var abierta: Item?

    private var items: [Item] { store.items(for: perspectiva) }

    var body: some View {
        VStack(spacing: 0) {
            selector
            Divider().overlay(Papel.hairline)
            lista
            Divider().overlay(Papel.hairline)
            alta
        }
        .background(Papel.bg)
        .sheet(item: $abierta) { DetalleView(item: $0) }
        // Al volver del fondo: otro dispositivo pudo tocar los datos, y el día
        // pudo cambiar mientras la app estaba dormida.
        .onChange(of: fase) { _, nueva in
            guard nueva == .active else { return }
            store.reload()
            Task { await Avisos.reschedule(store.items) }
        }
        .task(id: store.items) {
            // Un segundo de espera, como en el Mac: escribir un título cambia
            // las tareas en cada tecla.
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            await Avisos.reschedule(store.items)
        }
    }

    /// Fichas en una fila que se desliza, en vez de la barra lateral del Mac:
    /// cinco listas no caben de pie en 390 puntos, y un menú desplegable
    /// esconde dónde estás.
    private var selector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(perspectivas, id: \.self) { p in
                    let activa = p == perspectiva
                    Button {
                        perspectiva = p
                    } label: {
                        HStack(spacing: 6) {
                            Text(p.title)
                                .font(.system(size: 13, weight: .semibold))
                            let cuenta = store.count(for: p)
                            if cuenta > 0 {
                                Text("\(cuenta)")
                                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                                    .foregroundStyle(activa ? Papel.accentInk : Papel.inkFaint)
                            }
                        }
                        .foregroundStyle(activa ? Papel.ink : Papel.inkSoft)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(activa ? Papel.accent.opacity(0.16) : Color.clear,
                                    in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Papel.bgSide)
    }

    @ViewBuilder private var lista: some View {
        if items.isEmpty {
            VStack(spacing: 6) {
                Text(perspectiva.title.uppercased()).rubrica()
                Text("Nada por aquí.")
                    .font(.system(size: 15))
                    .foregroundStyle(Papel.inkFaint)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                ForEach(items) { item in
                    FilaView(item: item) { abierta = item }
                        .listRowBackground(Papel.bg)
                        .listRowSeparatorTint(Papel.hairline)
                        .swipeActions(edge: .trailing) {
                            Button("Eliminar", role: .destructive) { store.delete(item) }
                        }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    /// El campo de alta, fijo abajo y siempre a la vista.
    ///
    /// Abajo porque ahí llega el pulgar, y siempre porque apuntar es lo que más
    /// se hace: esconderlo detrás de un botón «+» añade un gesto a lo único que
    /// no puede costar nada.
    private var alta: some View {
        HStack(spacing: 11) {
            Circle()
                .strokeBorder(Papel.accent.opacity(0.8),
                              style: StrokeStyle(lineWidth: 1.5, dash: [2.5, 2.5]))
                .frame(width: 19, height: 19)
            TextField(altaLabel, text: $borrador)
                .font(.system(size: 16))
                .foregroundStyle(Papel.ink)
                .submitLabel(.done)
                .onSubmit(guardar)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Papel.bgSide)
    }

    private var altaLabel: String {
        perspectiva.acceptsNewItems ? "Apunta lo que sea" : "Apuntar en la bandeja"
    }

    private func guardar() {
        let limpio = borrador.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !limpio.isEmpty else { return }
        // En una lista que no admite altas cae en la bandeja, que es donde va lo
        // que aún no se ha decidido.
        store.addItem(title: limpio,
                      in: perspectiva.acceptsNewItems ? perspectiva : .inbox)
        borrador = ""
    }
}

struct FilaView: View {
    let item: Item
    let alPulsar: () -> Void
    @Environment(Store.self) private var store

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 13) {
            // Área de toque holgada: el círculo mide 20 puntos y el dedo, 44.
            Button { store.toggleComplete(item) } label: {
                Circle()
                    .strokeBorder(item.isCompleted ? Papel.accentInk : Papel.inkFaint,
                                  lineWidth: 1.5)
                    .background(item.isCompleted ? Papel.accent.opacity(0.9) : .clear,
                                in: Circle())
                    .frame(width: 20, height: 20)
                    .overlay {
                        if item.isCompleted {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Papel.bg)
                        }
                    }
                    .padding(12)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(-12)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title.isEmpty ? "Sin título" : item.title)
                    .font(.system(size: 16))
                    .foregroundStyle(item.isCompleted ? Papel.inkFaint : Papel.ink)
                    .strikethrough(item.isCompleted, color: Papel.inkFaint)
                if let sub = subtitulo {
                    Text(sub).font(.system(size: 12.5)).foregroundStyle(Papel.inkFaint)
                }
            }
            Spacer(minLength: 8)
            if let hora = item.timeLabel, !item.isCompleted {
                Text(hora)
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Papel.inkSoft)
            }
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle())
        .onTapGesture(perform: alPulsar)
    }

    /// Una sola línea de contexto, y solo si dice algo que no se ve ya.
    private var subtitulo: String? {
        var partes: [String] = []
        if item.daysLate > 0, let dia = item.day {
            partes.append("desde el \(dia.formatted(.dateTime.day().month(.abbreviated)))")
        } else if let dia = item.day, !Calendar.current.isDateInToday(dia) {
            partes.append(dia.formatted(.dateTime.day().month(.abbreviated)))
        }
        if let proyecto = item.projectID.flatMap(store.project) { partes.append(proyecto.name) }
        if !item.checklist.isEmpty {
            partes.append("\(item.checklistDone)/\(item.checklist.count)")
        }
        partes.append(contentsOf: item.tags)
        return partes.isEmpty ? nil : partes.joined(separator: "  ·  ")
    }
}

/// La ficha de una tarea: el título y cuándo. Lo mínimo para poder decidir sin
/// abrir el Mac.
struct DetalleView: View {
    let item: Item
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var cerrar
    @State private var titulo = ""
    @State private var notas = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Título", text: $titulo, axis: .vertical)
                        .font(.system(size: 17, weight: .medium))
                    TextField("Notas", text: $notas, axis: .vertical)
                        .font(.system(size: 15))
                        .frame(minHeight: 60, alignment: .top)
                }
                Section("Cuándo") {
                    Button("Hoy") { store.schedule(item, to: .now); cerrar() }
                    Button("Mañana") {
                        store.schedule(item, to: Calendar.current.date(byAdding: .day,
                                                                       value: 1, to: .now))
                        cerrar()
                    }
                    Button("Algún día") { store.park(item); cerrar() }
                    Button("Sin fecha") { store.schedule(item, to: nil); cerrar() }
                }
                Section {
                    Button("Eliminar", role: .destructive) { store.delete(item); cerrar() }
                }
            }
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

    /// Se guarda al cerrar y no en cada tecla: en el teléfono cada pulsación
    /// escribiría un archivo, y el teclado se abre y se cierra a menudo.
    private func guardar() {
        guard var actual = store.items.first(where: { $0.id == item.id }) else { return }
        actual.title = titulo
        actual.notes = notas
        store.update(actual)
    }
}
