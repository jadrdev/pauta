import Foundation
import Testing
@testable import PautaCore

/// El troceo de texto pegado en títulos de tarea.
@MainActor
struct TitleParsingTests {
    @Test func multilineWithBullets() {
        let text = """
        * Perspectiva `Cualquier momento`
        * Áreas que agrupen proyectos

        - Con guion
        • Con punto gordo
        3. Numerada
        4) Numerada con paréntesis
          indentada sin viñeta
        """
        #expect(Store.titles(from: text) == [
            "Perspectiva `Cualquier momento`",
            "Áreas que agrupen proyectos",
            "Con guion",
            "Con punto gordo",
            "Numerada",
            "Numerada con paréntesis",
            "indentada sin viñeta",
        ])
    }

    @Test func singleLine() {
        #expect(Store.titles(from: "  Comprar pan  ") == ["Comprar pan"])
    }

    @Test func blankTextYieldsNothing() {
        #expect(Store.titles(from: "\n  \n") == [])
    }

    @Test func addItemsCreatesOnePerLine() {
        let store = Store(inMemory: true)
        let created = store.addItems(from: "* uno\n* dos\n* tres", in: .today)
        #expect(created.map(\.title) == ["uno", "dos", "tres"])
        #expect(store.items(for: .today).count == 3)
    }
}

/// Los filtros de las perspectivas sobre un almacén en memoria.
@MainActor
struct PerspectiveTests {
    @Test func anytimeExcludesInboxAndFuture() {
        let store = Store(inMemory: true)
        let project = store.addProject(name: "P")
        store.addItem(title: "en bandeja", in: .inbox)
        store.addItem(title: "para hoy", in: .today)
        store.addItem(title: "de proyecto sin fecha", in: .project(project.id))
        store.addItem(title: "futura", in: .upcoming)
        store.addItem(title: "aparcada", in: .someday)

        let titles = store.items(for: .anytime).map(\.title)
        #expect(titles.contains("para hoy"))
        #expect(titles.contains("de proyecto sin fecha"))
        #expect(!titles.contains("en bandeja"))
        #expect(!titles.contains("futura"))
        #expect(!titles.contains("aparcada"))
    }
}

/// La persistencia: un archivo por objeto, lápidas y migración.
@MainActor
struct PersistenceTests {
    /// Carpeta nueva y vacía por test, para que no se pisen entre ellos.
    private func tempRoot() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("PautaTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test func roundTrip() throws {
        let root = tempRoot()
        do {
            let store = Store(root: root)
            store.addItem(title: "Comprar pan", in: .inbox)
            store.addItem(title: "Llamar al banco", in: .today)
            let project = store.addProject(name: "Mudanza")
            store.setIcon(project, to: "📦")
        }
        let reloaded = Store(root: root)
        #expect(reloaded.items.map(\.title) == ["Comprar pan", "Llamar al banco"])
        #expect(reloaded.projects.map(\.name) == ["Mudanza"])
        #expect(reloaded.projects.first?.icon == "📦")
        #expect(reloaded.count(for: .today) == 1)
    }

    @Test func oneFilePerObject() throws {
        let root = tempRoot()
        let store = Store(root: root)
        store.addItem(title: "una", in: .inbox)
        store.addItem(title: "otra", in: .inbox)
        store.addProject(name: "proyecto")

        let items = try FileManager.default.contentsOfDirectory(
            at: root.appendingPathComponent("items"), includingPropertiesForKeys: nil)
        let projects = try FileManager.default.contentsOfDirectory(
            at: root.appendingPathComponent("projects"), includingPropertiesForKeys: nil)
        #expect(items.filter { $0.pathExtension == "json" }.count == 2)
        #expect(projects.filter { $0.pathExtension == "json" }.count == 1)
    }

    /// Borrar deja lápida: al recargar, la tarea no vuelve.
    @Test func deletionLeavesTombstoneAndDoesNotResurrect() throws {
        let root = tempRoot()
        let doomed: Item
        do {
            let store = Store(root: root)
            store.addItem(title: "se queda", in: .inbox)
            doomed = store.addItem(title: "se borra", in: .inbox)
            store.delete(doomed)
            #expect(store.items.map(\.title) == ["se queda"])
        }
        // El archivo sigue existiendo, con la lápida puesta.
        let file = root.appendingPathComponent("items/\(doomed.id.uuidString).json")
        #expect(FileManager.default.fileExists(atPath: file.path))
        #expect(try String(contentsOf: file, encoding: .utf8).contains("deletedAt"))

        let reloaded = Store(root: root)
        #expect(reloaded.items.map(\.title) == ["se queda"])
    }

    /// Una tarea capturada y luego borrada no debe volver a importarse.
    @Test func buriedCaptureIsNotReimported() throws {
        let root = tempRoot()
        let capture = Captured(sourceID: "recordatorio-1", title: "Comprar pilas", notes: "")
        do {
            let store = Store(root: root)
            #expect(store.addCaptured([capture]) == 1)
            store.delete(store.items[0])
        }
        let reloaded = Store(root: root)
        #expect(reloaded.addCaptured([capture]) == 0)
        #expect(reloaded.items.isEmpty)
    }

    /// El decodificador tolerante: un archivo sin los campos nuevos se lee.
    @Test func readsFilesMissingNewerFields() throws {
        let root = tempRoot()
        let itemsDir = root.appendingPathComponent("items", isDirectory: true)
        try FileManager.default.createDirectory(at: itemsDir, withIntermediateDirectories: true)
        let id = UUID()
        let minimal = #"{"id":"\#(id.uuidString)","title":"Del pasado"}"#
        try minimal.write(to: itemsDir.appendingPathComponent("\(id.uuidString).json"),
                          atomically: true, encoding: .utf8)

        let store = Store(root: root)
        #expect(store.items.map(\.title) == ["Del pasado"])
        #expect(store.items.first?.isSomeday == false)
        #expect(store.items.first?.deletedAt == nil)
    }

    /// Un archivo corrupto se salta y no arrastra al resto.
    @Test func corruptFileDoesNotLoseTheRest() throws {
        let root = tempRoot()
        do {
            let store = Store(root: root)
            store.addItem(title: "sana", in: .inbox)
        }
        let itemsDir = root.appendingPathComponent("items", isDirectory: true)
        try "{ esto no es json".write(to: itemsDir.appendingPathComponent("\(UUID().uuidString).json"),
                                     atomically: true, encoding: .utf8)

        let store = Store(root: root)
        #expect(store.items.map(\.title) == ["sana"])
    }

    /// Migración desde el JSON único, dejando el original como respaldo.
    @Test func migratesFromSingleBlob() throws {
        let root = tempRoot()
        let a = UUID(), b = UUID(), p = UUID()
        let blob = """
        {
          "items": [
            {"id":"\(a.uuidString)","title":"vieja uno"},
            {"id":"\(b.uuidString)","title":"vieja dos","isCompleted":true}
          ],
          "projects": [{"id":"\(p.uuidString)","name":"Proyecto viejo"}]
        }
        """
        let legacy = root.appendingPathComponent("data.json")
        try blob.write(to: legacy, atomically: true, encoding: .utf8)

        let store = Store(root: root)
        #expect(Set(store.items.map(\.title)) == ["vieja uno", "vieja dos"])
        #expect(store.projects.map(\.name) == ["Proyecto viejo"])
        #expect(store.count(for: .completed) == 1)
        // El blob original se conserva.
        #expect(FileManager.default.fileExists(atPath: legacy.path))
        // Y no se vuelve a migrar encima de lo que ya hay.
        let again = Store(root: root)
        #expect(again.items.count == 2)
    }

    /// Mutar una tarea no debe reescribir el archivo de las demás: con la
    /// carpeta sincronizada, tocar archivos intactos hace trabajar de más a
    /// iCloud y multiplica las ocasiones de conflicto.
    @Test func mutatingOneItemLeavesTheOthersUntouched() throws {
        let root = tempRoot()
        let store = Store(root: root)
        let a = store.addItem(title: "la que cambia", in: .inbox)
        let b = store.addItem(title: "la que no", in: .inbox)

        let fileB = root.appendingPathComponent("items/\(b.id.uuidString).json")
        let antes = try Data(contentsOf: fileB)

        store.toggleComplete(a)

        let despues = try Data(contentsOf: fileB)
        #expect(antes == despues)
        // Y la que sí cambió, cambió.
        let fileA = root.appendingPathComponent("items/\(a.id.uuidString).json")
        #expect(try String(contentsOf: fileA, encoding: .utf8).contains("completedAt"))
    }

    /// La migración debe conservar el orden que tenía el blob, aunque sus fechas
    /// empaten: si no, la lista del usuario aparece revuelta tras actualizar.
    @Test func migrationPreservesOrderDespiteTiedDates() throws {
        let root = tempRoot()
        let titulos = ["primera", "segunda", "tercera", "cuarta", "quinta"]
        let mismaFecha = "2026-08-23T14:20:28Z"
        let items = titulos.map {
            #"{"id":"\#(UUID().uuidString)","title":"\#($0)","createdAt":"\#(mismaFecha)"}"#
        }
        let blob = #"{"items":[\#(items.joined(separator: ","))],"projects":[]}"#
        try blob.write(to: root.appendingPathComponent("data.json"),
                       atomically: true, encoding: .utf8)

        let store = Store(root: root)
        #expect(store.items.map(\.title) == titulos)
        // Y sigue igual al recargar desde los archivos ya troceados.
        let reloaded = Store(root: root)
        #expect(reloaded.items.map(\.title) == titulos)
    }

    /// Al estrenar la carpeta sincronizada, adopta lo que hubiera en la local.
    @Test func adoptsDataFromPreviousFolder() throws {
        let local = tempRoot(), nube = tempRoot()
        do {
            let store = Store(root: local)
            store.addItem(title: "venía de local", in: .inbox)
            store.addProject(name: "proyecto local")
        }
        // Dos archivos: la tarea y el proyecto.
        #expect(Store.adoptData(from: local, to: nube) == 2)

        let store = Store(root: nube)
        #expect(store.items.map(\.title) == ["venía de local"])
        #expect(store.projects.map(\.name) == ["proyecto local"])
        // El origen se conserva como respaldo.
        #expect(Store(root: local).items.count == 1)
    }

    /// No debe adoptar encima de datos que ya existen en el destino.
    @Test func doesNotAdoptOverExistingData() throws {
        let local = tempRoot(), nube = tempRoot()
        do {
            Store(root: local).addItem(title: "vieja", in: .inbox)
            Store(root: nube).addItem(title: "la que ya estaba", in: .inbox)
        }
        #expect(Store.adoptData(from: local, to: nube) == 0)
        #expect(Store(root: nube).items.map(\.title) == ["la que ya estaba"])
    }

    /// Adoptar el blob antiguo cuando el origen aún no estaba troceado.
    @Test func adoptsLegacyBlobToo() throws {
        let local = tempRoot(), nube = tempRoot()
        let blob = #"{"items":[{"id":"\#(UUID().uuidString)","title":"del blob"}],"projects":[]}"#
        try blob.write(to: local.appendingPathComponent("data.json"),
                       atomically: true, encoding: .utf8)
        Store.adoptData(from: local, to: nube)

        let store = Store(root: nube)
        #expect(store.items.map(\.title) == ["del blob"])
    }

    /// Recargar recoge lo que otro escribió en la misma carpeta: es el caso de
    /// dos dispositivos sincronizando.
    @Test func reloadPicksUpExternalChanges() throws {
        let root = tempRoot()
        let mio = Store(root: root)
        mio.addItem(title: "la mía", in: .inbox)

        // Otro «dispositivo» escribe en la misma carpeta.
        let otro = Store(root: root)
        otro.addItem(title: "la del otro", in: .inbox)

        #expect(mio.items.map(\.title) == ["la mía"])
        mio.reload()
        #expect(mio.items.map(\.title) == ["la mía", "la del otro"])
    }

    /// Un borrado hecho fuera se refleja al recargar, y no reaparece.
    @Test func reloadPicksUpExternalDeletion() throws {
        let root = tempRoot()
        let mio = Store(root: root)
        let doomed = mio.addItem(title: "se borra fuera", in: .inbox)
        mio.addItem(title: "se queda", in: .inbox)

        let otro = Store(root: root)
        otro.delete(otro.items.first { $0.id == doomed.id }!)

        mio.reload()
        #expect(mio.items.map(\.title) == ["se queda"])
    }

    /// Recargar sin cambios no debe alterar nada: las escrituras de la propia
    /// app disparan el vigilante, y una recarga que reasigna en vano refrescaría
    /// la interfaz e interrumpiría una edición en curso.
    @Test func reloadWithoutChangesIsIdempotent() throws {
        let root = tempRoot()
        let store = Store(root: root)
        store.addItem(title: "una", in: .inbox)
        store.addItem(title: "otra", in: .today)

        let antesItems = store.items
        let antesProyectos = store.projects
        store.reload()
        #expect(store.items == antesItems)
        #expect(store.projects == antesProyectos)
    }

    @Test func inMemoryWritesNothing() throws {
        let root = tempRoot()
        let store = Store(inMemory: true, root: root)
        store.addItem(title: "fantasma", in: .inbox)
        let contents = try FileManager.default.contentsOfDirectory(atPath: root.path)
        #expect(contents.isEmpty)
    }
}
