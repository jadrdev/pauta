import Foundation
import PautaCore

/// Avisa cuando algo cambia en el contenedor de iCloud de la app, **mientras
/// la app está delante**.
///
/// Sin esto el teléfono solo se cruzaba al abrir la app o al volver del fondo:
/// si la dejabas delante y tocabas algo en el Mac, no se enteraba hasta que
/// salías y volvías.
///
/// Lo que sirve es `NSMetadataQuery`, el mecanismo de Apple para un
/// contenedor: se entera de que algo cambió en iCloud **antes** de que baje,
/// que es lo que hace que lo tachado en el Mac llegue en segundos con la app
/// delante. `FolderWatcher` no vale aquí: FSEvents no existe en iOS.
///
/// Hasta la mudanza vigilaba también la carpeta del Mac elegida a mano, con un
/// `NSFilePresenter`. Cerrada la mudanza (docs/plan-contenedor-icloud.md, fase
/// 4), ya no hay otra carpeta que mirar.
@MainActor
final class VigilanteDeCarpeta {
    private var consulta: NSMetadataQuery?
    private var observador: NSObjectProtocol?
    private var pendiente: DispatchWorkItem?

    /// Empieza a vigilar el contenedor.
    func empezar(_ alCambiar: @escaping () -> Void) {
        parar()
        vigilarElContenedor(alCambiar)
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
    }
}
