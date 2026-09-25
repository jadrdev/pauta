import Foundation
import UIKit
import PautaCore

/// Cruzar con la carpeta del Mac, cuando se pueda.
///
/// Vive aparte de la pantalla que lo ofrece porque se llama desde dos sitios: al
/// volver del fondo —que es cuando de verdad hace falta, después de haber estado
/// en el Mac— y a mano desde los ajustes.
///
/// Y siempre **puede no hacer nada**: sin carpeta elegida, o con el permiso
/// caducado, devuelve `nil` y la app sigue con sus datos como si nada. Eso es lo
/// que hace que esto sea un puente y no un cordón umbilical.
@MainActor
enum Sincronizar {
    /// Cruza **fuera del hilo principal**.
    ///
    /// Esto se escribió primero en el hilo principal y con una carpeta de
    /// verdad —sesenta y siete archivos, la mitad sin bajar de iCloud— dejó la
    /// app congelada hasta que hubo que cerrarla. Leer archivos es trabajo de
    /// disco y de red: no se hace donde se dibuja.
    @discardableResult
    static func conElMac(_ store: Store, vez: Int = 0) async -> Puente.Balance? {
        let carpeta = CarpetaElegida.shared
        guard let destino = carpeta.url ?? carpeta.abrir() else { return nil }
        let origen = store.storageURL
        let balance = await Task.detached(priority: .utility) {
            Puente.cruzar(origen, destino)
        }.value
        // Solo se relee si algo llegó: recargar por costumbre agita las fechas
        // de todo y da trabajo a iCloud por nada.
        if balance.traidas > 0 { store.reload() }
        reintentar(store, quedan: balance.pendientesDeBajar, vez: vez)
        return balance
    }

    private static var reintento: Task<Void, Never>?

    /// Lo que quedó a medio bajar se vuelve a mirar a los pocos segundos.
    ///
    /// El cruce no toca lo que iCloud aún no ha bajado —copiarle encima lo de
    /// aquí era perder lo hecho en el Mac— y pide la descarga. Pero sin esto
    /// nadie volvía a mirar hasta el siguiente cambio o la siguiente vez que se
    /// abriera la app, y mientras tanto el teléfono enseñaba lo viejo. Solo con
    /// la app delante, y unas pocas veces: si algo no baja en medio minuto, ya
    /// lo traerá el cruce siguiente.
    private static func reintentar(_ store: Store, quedan: Int, vez: Int) {
        reintento?.cancel()
        guard quedan > 0, vez < 6 else { return }
        reintento = Task { @MainActor in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled,
                  UIApplication.shared.applicationState == .active else { return }
            await conElMac(store, vez: vez + 1)
        }
    }
}
