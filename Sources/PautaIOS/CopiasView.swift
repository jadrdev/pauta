import SwiftUI
import UniformTypeIdentifiers
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
    /// La copia a exportar, ya hecha: el selector del sistema la escribe
    /// donde se elija.
    @State private var aExportar: CopiaExportada?
    @State private var importando = false
    /// La copia importada, esperando a que se confirme.
    @State private var importada: Copia?

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
                Text("Una al día, de los últimos \(Copias.cuantas) días. Volver a una deja todo como estaba ese día; lo apuntado después va a la papelera, y antes se guarda una copia de ahora.")
            }
            // Fuera de la app: para quien no usa iCloud, y para pasar las
            // tareas a otro aparato.
            Section {
                Button {
                    do {
                        let (datos, nombre) = try store.exportar()
                        aExportar = CopiaExportada(datos: datos, nombre: nombre)
                    } catch {
                        restaurada = String(localized: "Aún faltan tareas por bajar de iCloud. Prueba en un momento.")
                    }
                } label: {
                    Label("Exportar una copia…", systemImage: "square.and.arrow.up")
                }
                Button { importando = true } label: {
                    Label("Importar una copia…", systemImage: "square.and.arrow.down")
                }
            } header: {
                Text("FUERA DE LA APP")
            } footer: {
                Text("Guarda tus tareas, proyectos y áreas en Archivos, en otra nube o donde quieras, y recupéralas en este u otro aparato. Los adjuntos no van dentro.")
            }
        }
        .fileExporter(isPresented: Binding(get: { aExportar != nil },
                                           set: { if !$0 { aExportar = nil } }),
                      document: aExportar, contentType: .gzip,
                      defaultFilename: aExportar?.nombre) { resultado in
            if case .success = resultado { restaurada = String(localized: "Copia exportada.") }
            aExportar = nil
        }
        .fileImporter(isPresented: $importando, allowedContentTypes: [.gzip, .json]) { resultado in
            guard case .success(let url) = resultado else { return }
            // Lo que da el selector es de otra app: se pide permiso para
            // leerlo el rato justo.
            let permiso = url.startAccessingSecurityScopedResource()
            defer { if permiso { url.stopAccessingSecurityScopedResource() } }
            guard let datos = try? Data(contentsOf: url),
                  let copia = Copias.leer(datos: datos) else {
                restaurada = String(localized: "Ese archivo no es una copia de Pauta.")
                return
            }
            importada = copia
        }
        .confirmationDialog(
            "¿Dejar todo como en la copia importada?",
            isPresented: Binding(get: { importada != nil },
                                 set: { if !$0 { importada = nil } }),
            titleVisibility: .visible
        ) {
            Button("Importar", role: .destructive) {
                guard let copia = importada else { return }
                store.restaurar(copia)
                restaurada = String(localized: "Hecho: \(copia.items.count) tareas importadas.")
                Task { await leerCopias() }
            }
        } message: {
            Text("Lo que no esté en ella irá a la papelera. Antes se guarda una copia de cómo está ahora, por si quieres volver.")
        }
        .navigationTitle("Copias de seguridad")
        .navigationBarTitleDisplayMode(.inline)
        // Fuera del hilo principal: en el Mac, leerlas en él colgó la app.
        .task { await leerCopias() }
        .confirmationDialog(
            "¿Dejar todo como estaba el \(aRestaurar?.titulo.lowercased() ?? "")?",
            isPresented: Binding(get: { aRestaurar != nil },
                                 set: { if !$0 { aRestaurar = nil } }),
            titleVisibility: .visible
        ) {
            Button("Volver a esa copia", role: .destructive) {
                guard let elegida = aRestaurar else { return }
                guard let copia = Copias.leer(elegida.url) else {
                    restaurada = String(localized: "Esa copia aún está bajando. Prueba en un momento.")
                    return
                }
                store.restaurar(copia)
                restaurada = String(localized: "Hecho: todo está como el \(elegida.titulo.lowercased()).")
                Task { await leerCopias() }
            }
        } message: {
            Text("Lo que hayas apuntado después irá a la papelera. Antes se guarda una copia de cómo está ahora, por si quieres volver.")
        }
    }

    private func leerCopias() async {
        let raiz = store.storageURL
        copias = await Task.detached(priority: .utility) { Copias.resumenes(en: raiz) }.value
    }
}

/// Una copia lista para que el selector del sistema la guarde.
struct CopiaExportada: FileDocument {
    static let readableContentTypes: [UTType] = [.gzip]
    let datos: Data
    /// «Pauta-2026-11-10.json»: el selector le pone el `.gz` del tipo.
    let nombre: String

    init(datos: Data, nombre: String) {
        self.datos = datos
        self.nombre = nombre.replacingOccurrences(of: ".gz", with: "")
    }

    init(configuration: ReadConfiguration) throws {
        datos = configuration.file.regularFileContents ?? Data()
        nombre = "Pauta"
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: datos)
    }
}
