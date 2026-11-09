import Foundation
import PautaCore

/// Avisa cuando algo cambia en la carpeta del Mac, **mientras la app está
/// delante**.
///
/// Hasta ahora el teléfono solo se cruzaba al abrir la app o al volver del
/// fondo. Si la dejabas delante y tocabas algo en el Mac, no se enteraba hasta
/// que salías y volvías.
///
/// No se usa `FolderWatcher`: FSEvents no existe en iOS. Y tampoco
/// `DispatchSource` sobre un descriptor, que es la tentación: solo se entera de
/// altas y bajas de entradas, no de que cambie el **contenido** de un archivo
/// que ya estaba — que es exactamente lo que hace iCloud al traer una edición de
/// otro aparato. Lo que sirve es `NSFilePresenter`, que es como el sistema
/// cuenta los cambios coordinados de una carpeta.
///
/// La carpeta es de ámbito seguro —viene del selector del sistema— así que el
/// permiso se abre mientras dure la vigilancia y se cierra al soltarla.
///
/// **Y el contenedor de iCloud de la app**, que es con lo que se cruza desde la
/// mudanza. Ahí lo que sirve es `NSMetadataQuery`, el mecanismo de Apple para
/// un contenedor: se entera de que algo cambió en iCloud **antes** de que baje,
/// que es lo que hace que lo tachado en el Mac llegue en segundos con la app
/// delante. La carpeta elegida se sigue vigilando mientras dure la transición.
@MainActor
final class VigilanteDeCarpeta {
    private var presentador: Presentador?
    private var consulta: NSMetadataQuery?
    private var observador: NSObjectProtocol?
    private var pendiente: DispatchWorkItem?

    /// Empieza a vigilar el contenedor y, si la hay, la carpeta elegida.
    func empezar(_ alCambiar: @escaping () -> Void) {
        parar()
        vigilarElContenedor(alCambiar)
        guard let carpeta = CarpetaElegida.shared.abrir() else { return }
        let p = Presentador(carpeta: carpeta, alCambiar: alCambiar)
        NSFileCoordinator.addFilePresenter(p)
        presentador = p
    }

    /// Avisa cuando cambia cualquier dato del contenedor. Los avisos llegan a
    /// ráfagas —uno por archivo, y otro por cada paso de su descarga—, así que
    /// se agrupan: un cruce por ráfaga, un segundo después de la última.
    private func vigilarElContenedor(_ alCambiar: @escaping () -> Void) {
        let q = NSMetadataQuery()
        q.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        q.predicate = NSPredicate(format: "%K LIKE %@", NSMetadataItemFSNameKey, "*.json")
        observador = NotificationCenter.default.addObserver(
            forName: .NSMetadataQueryDidUpdate, object: q, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.pendiente?.cancel()
                let trabajo = DispatchWorkItem(block: alCambiar)
                self?.pendiente = trabajo
                DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: trabajo)
            }
        }
        q.start()
        consulta = q
    }

    func parar() {
        pendiente?.cancel()
        consulta?.stop()
        consulta = nil
        if let observador { NotificationCenter.default.removeObserver(observador) }
        observador = nil
        guard let p = presentador else { return }
        NSFileCoordinator.removeFilePresenter(p)
        p.soltar()
        presentador = nil
    }

    deinit {
        if let p = presentador { NSFileCoordinator.removeFilePresenter(p) }
    }

    private final class Presentador: NSObject, NSFilePresenter {
        let presentedItemURL: URL?
        let presentedItemOperationQueue = OperationQueue.main
        private let alCambiar: () -> Void
        private var pendiente: DispatchWorkItem?

        init(carpeta: URL, alCambiar: @escaping () -> Void) {
            self.presentedItemURL = carpeta
            self.alCambiar = alCambiar
            super.init()
        }

        func soltar() {
            pendiente?.cancel()
            presentedItemURL?.stopAccessingSecurityScopedResource()
        }

        /// Cambió algo dentro. Se agrupa un segundo: iCloud trae una edición como
        /// varias escrituras seguidas, y cruzar una vez por archivo sería cruzar
        /// diez veces por un cambio.
        func presentedSubitemDidChange(at url: URL) { avisar() }
        func presentedItemDidChange() { avisar() }

        private func avisar() {
            pendiente?.cancel()
            let trabajo = DispatchWorkItem { [alCambiar] in alCambiar() }
            pendiente = trabajo
            DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: trabajo)
        }
    }
}
