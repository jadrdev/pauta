import Foundation

/// Avisa cuando algo cambia dentro de una carpeta, incluidos los subdirectorios.
///
/// Se usa FSEvents y no `DispatchSource.makeFileSystemObjectSource`: este último
/// vigila un descriptor y solo se entera de altas y bajas de entradas, no de que
/// cambie el **contenido** de un archivo que ya existía. Y eso es justo lo que
/// hace iCloud al traer una edición hecha en otro dispositivo.
///
/// Los avisos vienen coalescidos: iCloud escribe varios archivos seguidos al
/// sincronizar, y no interesa recargar una vez por archivo.
public final class FolderWatcher {
    private var stream: FSEventStreamRef?
    private let onChange: () -> Void
    private let queue = DispatchQueue(label: "dev.jadrdev.pauta.folderwatcher")

    /// - Parameters:
    ///   - url: carpeta a vigilar, con sus subdirectorios.
    ///   - coalescing: segundos que se esperan para agrupar avisos seguidos.
    ///   - onChange: se llama en la cola principal.
    public init?(url: URL, coalescing: TimeInterval = 1.0, onChange: @escaping () -> Void) {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        self.onChange = onChange

        let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
            guard let info else { return }
            let watcher = Unmanaged<FolderWatcher>.fromOpaque(info).takeUnretainedValue()
            watcher.fire()
        }
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil, release: nil, copyDescription: nil)

        guard let stream = FSEventStreamCreate(
            nil, callback, &context,
            [url.path] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            coalescing,
            // FileEvents para enterarse de cada archivo, no solo del directorio.
            UInt32(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer)
        ) else { return nil }

        self.stream = stream
        FSEventStreamSetDispatchQueue(stream, queue)
        FSEventStreamStart(stream)
    }

    private func fire() {
        DispatchQueue.main.async { [onChange] in onChange() }
    }

    public func stop() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    deinit { stop() }
}
