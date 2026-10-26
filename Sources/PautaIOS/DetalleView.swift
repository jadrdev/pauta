import SwiftUI
import PhotosUI
import QuickLook
import UniformTypeIdentifiers
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
    /// Cómo se va la ficha cuando no es una hoja. Con el iPhone Duo abierto
    /// vive en el panel de la derecha, y ahí `dismiss` no hace nada: no hay
    /// nada que cerrar, hay que dejar de enseñarla.
    var alCerrar: (() -> Void)? = nil
    /// Si la ficha está dentro de una navegación que no es suya —el panel de
    /// un proyecto abierto desde «Más»—. Ahí una `NavigationStack` propia no
    /// cuenta: el título se pierde y «Listo» se va a la barra de arriba del
    /// todo, lejos de la tarea. Así que la cabecera la dibuja ella.
    var enOtraNavegacion = false

    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var titulo = ""
    @State private var notas = ""
    @State private var importando = false
    @State private var eligiendoFotos = false
    @State private var fotos: [PhotosPickerItem] = []
    @State private var vistaPrevia: URL?

    private var actual: Item? { store.items.first { $0.id == item.id } }

    var body: some View {
        marco {
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
                seccionDeAdjuntos
                Section {
                    Button("Eliminar", role: .destructive) {
                        store.delete(item); cerrar()
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Papel.bg)
        }
        .onAppear {
            titulo = item.title
            notas = item.notes
        }
        .fileImporter(isPresented: $importando, allowedContentTypes: [.item],
                      allowsMultipleSelection: true) { resultado in
            guard case .success(let urls) = resultado else { return }
            for url in urls {
                // Lo que da el selector de Archivos es de otra app: se pide
                // permiso para leerlo el rato justo de copiarlo.
                let permiso = url.startAccessingSecurityScopedResource()
                defer { if permiso { url.stopAccessingSecurityScopedResource() } }
                try? store.adjuntar(url, a: item)
            }
        }
        .photosPicker(isPresented: $eligiendoFotos, selection: $fotos,
                      matching: .any(of: [.images, .videos]))
        .onChange(of: fotos) { _, elegidas in
            guard !elegidas.isEmpty else { return }
            fotos = []
            Task {
                for foto in elegidas {
                    guard let fichero = try? await foto.loadTransferable(type: FicheroDeFotos.self)
                    else { continue }
                    try? store.adjuntar(fichero.url, a: item)
                    try? FileManager.default.removeItem(at: fichero.url.deletingLastPathComponent())
                }
            }
        }
        .quickLookPreview($vistaPrevia)
        // En el panel se puede pasar a otra tarea sin tocar «Listo», y lo
        // escrito no puede irse con la ficha.
        .onDisappear { guardar() }
    }

    private func cerrar() {
        if let alCerrar { alCerrar() } else { dismiss() }
    }

    /// El título y «Listo»: en la barra de su propia navegación o, si está
    /// dentro de otra, en una cabecera que se parece a esa barra.
    @ViewBuilder private func marco(@ViewBuilder _ ficha: () -> some View) -> some View {
        if enOtraNavegacion {
            VStack(spacing: 0) {
                ZStack {
                    Text("Tarea").font(.headline)
                    HStack {
                        Spacer()
                        Button("Listo") { guardar(); cerrar() }
                            .fontWeight(.semibold)
                    }
                }
                .padding(.horizontal, 20)
                .frame(height: 44)
                ficha()
            }
            .background(Papel.bg)
        } else {
            NavigationStack {
                ficha()
                    .navigationTitle("Tarea")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Listo") { guardar(); cerrar() }
                        }
                    }
            }
        }
    }

    /// Los ficheros de la tarea. Se tocan para verlos, se deslizan para
    /// quitarlos, y se añaden desde Archivos o desde Fotos —la foto del ticket,
    /// el PDF que llegó por correo—.
    @ViewBuilder private var seccionDeAdjuntos: some View {
        let vigentes = actual?.adjuntosVigentes() ?? []
        Section {
            ForEach(vigentes) { adjunto in
                Button { vistaPrevia = store.url(de: adjunto) } label: {
                    HStack(spacing: 10) {
                        Image(systemName: Self.icono(de: adjunto))
                            .foregroundStyle(Papel.accentInk)
                            .frame(width: 22)
                        Text(adjunto.nombre)
                            .foregroundStyle(Papel.ink)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Text(adjunto.tamanoLegible)
                            .font(.system(size: 13).monospacedDigit())
                            .foregroundStyle(Papel.inkSoft)
                    }
                }
                .swipeActions {
                    Button("Quitar", role: .destructive) {
                        store.quitarAdjunto(adjunto, de: item)
                    }
                    .tint(Papel.warning)
                }
            }
            Menu {
                Button { importando = true } label: {
                    Label("Desde Archivos", systemImage: "folder")
                }
                // Un botón que abre el selector, y no el selector dentro del
                // menú: metido en un `Menu`, el menú se cerraba y el
                // selector no llegaba a salir.
                Button { eligiendoFotos = true } label: {
                    Label("Desde Fotos", systemImage: "photo.on.rectangle")
                }
            } label: {
                Label("Adjuntar", systemImage: "paperclip")
            }
        } header: {
            Text("ADJUNTOS")
        } footer: {
            // En una hecha, cuánto les queda: que se vayan sin avisar sería
            // perder algo sin haberlo decidido.
            if let aviso = actual?.adjuntosSeVan() { Text(aviso) }
        }
    }

    /// Un icono por familia de fichero, que es lo que se reconoce de un
    /// vistazo; la vista previa ya enseña el resto.
    private static func icono(de adjunto: Adjunto) -> String {
        let tipo = UTType(filenameExtension: (adjunto.nombre as NSString).pathExtension)
        guard let tipo else { return "doc" }
        if tipo.conforms(to: .image) { return "photo" }
        if tipo.conforms(to: .movie) { return "film" }
        if tipo.conforms(to: .audio) { return "waveform" }
        if tipo.conforms(to: .pdf) { return "doc.richtext" }
        if tipo.conforms(to: .archive) { return "doc.zipper" }
        return "doc"
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

/// Una foto o un vídeo de la fototeca, como fichero con su nombre.
///
/// Pedir los datos a secas perdería el nombre y la extensión, y sin extensión
/// el adjunto no sabría con qué abrirse. El sistema entrega una copia
/// temporal que solo vale mientras dura la llamada, así que se copia a otra
/// carpeta temporal antes de soltarla.
private struct FicheroDeFotos: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .image) { Self(url: try copiar($0.file)) }
        FileRepresentation(importedContentType: .movie) { Self(url: try copiar($0.file)) }
    }

    private static func copiar(_ origen: URL) throws -> URL {
        let carpeta = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: carpeta, withIntermediateDirectories: true)
        let destino = carpeta.appendingPathComponent(origen.lastPathComponent)
        try FileManager.default.copyItem(at: origen, to: destino)
        return destino
    }
}
