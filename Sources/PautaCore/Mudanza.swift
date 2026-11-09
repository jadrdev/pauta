import Foundation

/// La mudanza de los datos al contenedor de iCloud de la app.
///
/// El plan entero está en docs/plan-contenedor-icloud.md. Aquí va, de momento,
/// la fase 1: la red de seguridad. Nada se muda sin una copia completa de cómo
/// estaba todo, y la mudanza no empieza si esa copia no sale.
public enum Mudanza {
    /// La copia de antes de la mudanza, ya hecha y comprobada.
    public struct Resguardo: Equatable, Sendable {
        public let carpeta: URL
        public let archivos: Int
        public let bytes: Int64
    }

    public enum Fallo: Error, Equatable, CustomStringConvertible {
        /// Archivos que iCloud no terminó de bajar en el tiempo de espera.
        case sinBajar([String])
        /// Un archivo copiado no es igual que el original.
        case copiaDistinta(String)
        /// La copia no se pudo hacer: sin sitio, sin permiso…
        case noSePudo(String)

        public var description: String {
            switch self {
            case .sinBajar(let faltan):
                let muestra = faltan.prefix(5).joined(separator: ", ")
                return "\(faltan.count) archivos sin bajar de iCloud: \(muestra)"
                    + (faltan.count > 5 ? "…" : "")
            case .copiaDistinta(let ruta): return "la copia de \(ruta) no es igual que el original"
            case .noSePudo(let motivo): return "no se pudo copiar: \(motivo)"
            }
        }
    }

    /// Dónde va la copia de antes de la mudanza: la carpeta de usuario, que no
    /// se sincroniza.
    ///
    /// No en Documentos: con «Escritorio y Documentos» en iCloud —como en el Mac
    /// donde se escribió esto—, Documentos **es** iCloud, y una copia de
    /// seguridad en el mismo sitio que lo que protege no protege nada.
    public static func carpetaDelResguardo(ahora: Date = .now) -> URL {
        let dia = ahora.formatted(.iso8601.year().month().day())
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Pauta antes de la mudanza \(dia)", isDirectory: true)
    }

    /// Copia **todo** `origen` en `destino`, esperando antes a que iCloud baje
    /// lo que tenga desalojado, y comprobando cada archivo.
    ///
    /// Tres cosas que la hacen de fiar:
    ///
    /// - **Espera a que baje todo.** Un archivo desalojado está en el listado
    ///   pero no en el disco: copiarlo así copia la nada. Se pide la descarga
    ///   y se espera; si en `espera` no ha llegado todo, se para y dice cuáles.
    /// - **Comprueba byte a byte.** Cada archivo copiado se compara con el
    ///   original. Una copia que no se ha comprobado es una esperanza.
    /// - **O entera o nada.** Se copia a una carpeta provisional y solo al
    ///   final, si todo cuadra, toma su nombre. Una copia a medias con el
    ///   nombre bueno se tomaría por buena.
    ///
    /// Si `destino` ya existe no se toca: se usa el mismo nombre con un número.
    /// `enLocal` y `pedirBajada` solo los cambian las pruebas, que no tienen
    /// iCloud con el que desalojar nada.
    public static func resguardar(
        _ origen: URL, en destino: URL,
        espera: Duration = .seconds(180),
        enLocal: @Sendable (URL) -> Bool = Puente.enLocal,
        pedirBajada: @Sendable (URL) -> Void = { try? FileManager.default.startDownloadingUbiquitousItem(at: $0) }
    ) async throws -> Resguardo {
        let fm = FileManager.default
        let archivos = listar(origen)

        // 1. Que baje todo lo que falte.
        var faltan = archivos.filter { !enLocal($0) }
        faltan.forEach(pedirBajada)
        let limite = ContinuousClock.now + espera
        while !faltan.isEmpty && ContinuousClock.now < limite {
            try await Task.sleep(for: .milliseconds(500))
            // Con una URL nueva cada vez: Foundation guarda el estado de iCloud
            // en la propia URL, y preguntar a la misma devolvía «sin bajar»
            // para siempre aunque el archivo ya estuviera en el disco. Así se
            // estuvo tres minutos esperando a treinta copias ya bajadas.
            faltan = faltan.filter { !enLocal(URL(fileURLWithPath: $0.path)) }
        }
        guard faltan.isEmpty else {
            throw Fallo.sinBajar(faltan.map { relativa($0, a: origen) }.sorted())
        }

        // 2. Copiar a una carpeta provisional, junto a la definitiva.
        let final = libre(destino)
        let provisional = final.deletingLastPathComponent()
            .appendingPathComponent(".\(final.lastPathComponent).a-medias", isDirectory: true)
        try? fm.removeItem(at: provisional)
        var bytes: Int64 = 0
        do {
            for archivo in archivos {
                let ruta = relativa(archivo, a: origen)
                let copia = provisional.appendingPathComponent(ruta)
                try fm.createDirectory(at: copia.deletingLastPathComponent(),
                                       withIntermediateDirectories: true)
                try fm.copyItem(at: archivo, to: copia)
                // 3. Y comprobarlo, leyendo los dos.
                let original = try Data(contentsOf: archivo)
                guard (try? Data(contentsOf: copia)) == original else {
                    throw Fallo.copiaDistinta(ruta)
                }
                bytes += Int64(original.count)
            }
            try manifiesto(archivos.count, bytes, de: origen)
                .write(to: provisional.appendingPathComponent("LEEME.txt"),
                       atomically: true, encoding: .utf8)
            try fm.moveItem(at: provisional, to: final)
        } catch let fallo as Fallo {
            try? fm.removeItem(at: provisional)
            throw fallo
        } catch {
            try? fm.removeItem(at: provisional)
            throw Fallo.noSePudo(error.localizedDescription)
        }
        return Resguardo(carpeta: final, archivos: archivos.count, bytes: bytes)
    }

    /// Todos los archivos de verdad de una carpeta, a cualquier profundidad.
    ///
    /// Sin los ocultos (`.DS_Store`, los marcadores que deja iCloud), pero con
    /// los desalojados: en macOS siguen en el listado con su nombre de
    /// siempre, que es lo que permite pedir que bajen.
    static func listar(_ carpeta: URL) -> [URL] {
        guard let recorrido = FileManager.default.enumerator(
            at: carpeta, includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]) else { return [] }
        return recorrido.compactMap { $0 as? URL }
            .filter { (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true }
            .sorted { $0.path < $1.path }
    }

    private static func relativa(_ url: URL, a raiz: URL) -> String {
        let base = raiz.standardizedFileURL.resolvingSymlinksInPath().path
        let ruta = url.standardizedFileURL.resolvingSymlinksInPath().path
        guard ruta.hasPrefix(base) else { return url.lastPathComponent }
        return String(ruta.dropFirst(base.count)).trimmingCharacters(in: ["/"])
    }

    /// `destino`, o el mismo nombre con « 2», « 3»… si ya existe.
    private static func libre(_ destino: URL) -> URL {
        let fm = FileManager.default
        guard fm.fileExists(atPath: destino.path) else { return destino }
        let padre = destino.deletingLastPathComponent()
        var n = 2
        while fm.fileExists(atPath: padre.appendingPathComponent(
            "\(destino.lastPathComponent) \(n)").path) { n += 1 }
        return padre.appendingPathComponent("\(destino.lastPathComponent) \(n)", isDirectory: true)
    }

    private static func manifiesto(_ archivos: Int, _ bytes: Int64, de origen: URL,
                                   ahora: Date = .now) -> String {
        """
        Copia de los datos de Pauta de antes de mudarlos al contenedor de iCloud.

        Hecha el \(ahora.formatted(date: .long, time: .standard)), desde:
          \(origen.path)
        \(archivos) archivos, \(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)), comprobados uno a uno.

        Pauta no la lee ni la borra: es tuya. Si algo saliera mal, esta carpeta
        tiene todo como estaba.
        """
    }
}
