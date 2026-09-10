import Foundation
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
    @discardableResult
    static func conElMac(_ store: Store) -> Puente.Balance? {
        let carpeta = CarpetaElegida.shared
        guard let destino = carpeta.url ?? carpeta.abrir() else { return nil }
        let balance = Puente.cruzar(store.storageURL, destino)
        // Solo se relee si algo se movió: recargar por costumbre agita las
        // fechas de todo y da trabajo a iCloud por nada.
        if balance.traidas > 0 { store.reload() }
        return balance
    }
}
