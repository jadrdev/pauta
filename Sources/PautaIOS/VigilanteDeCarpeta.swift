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
@MainActor
final class VigilanteDeCarpeta {
    private var presentador: Presentador?

    /// Empieza a vigilar la carpeta elegida. Sin carpeta, no hace nada.
    func empezar(_ alCambiar: @escaping () -> Void) {
        parar()
        guard let carpeta = CarpetaElegida.shared.abrir() else { return }
        let p = Presentador(carpeta: carpeta, alCambiar: alCambiar)
        NSFileCoordinator.addFilePresenter(p)
        presentador = p
    }

    func parar() {
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
