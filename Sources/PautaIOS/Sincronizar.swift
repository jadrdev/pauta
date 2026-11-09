import Foundation
import UIKit
import PautaCore

/// Cruzar con iCloud, cuando se pueda.
///
/// Vive aparte de la pantalla que lo ofrece porque se llama desde varios
/// sitios: al volver del fondo, al irse, cuando el vigilante ve llegar algo, en
/// segundo plano y a mano desde los ajustes.
///
/// El teléfono guarda en su carpeta, que es local, y cruza con **el
/// contenedor de iCloud de la app** —el mismo que usa el Mac—. Antes cruzaba
/// con una carpeta del Mac que había que elegir a mano, y eso era lo frágil: el
/// permiso caducaba, el marcador se rompía, y el iPad había que prepararlo
/// aparte. El cruce es el de siempre; lo que cambia es con quién.
///
/// Mientras dure la mudanza (docs/plan-contenedor-icloud.md), si había una
/// carpeta elegida se cruza **también** con ella: así lo que haga un Mac todavía
/// en la versión anterior llega aunque el Mac ya mudado esté apagado.
///
/// Y siempre **puede no hacer nada**: sin iCloud devuelve `nil` y la app sigue
/// con sus datos como si nada. Eso es lo que hace que esto sea un puente y no
/// un cordón umbilical.
@MainActor
enum Sincronizar {
    private static let claveCopia = "contenedor.copiaDeAntes"

    /// Cruza **fuera del hilo principal**.
    ///
    /// Esto se escribió primero en el hilo principal y con una carpeta de
    /// verdad —sesenta y siete archivos, la mitad sin bajar de iCloud— dejó la
    /// app congelada hasta que hubo que cerrarla. Leer archivos es trabajo de
    /// disco y de red: no se hace donde se dibuja.
    @discardableResult
    static func conICloud(_ store: Store, vez: Int = 0) async -> Puente.Balance? {
        let origen = store.storageURL
        // Bloquea la primera vez: fuera del hilo principal.
        let contenedor = await Task.detached(priority: .utility) { Contenedor.documentos() }.value
        let carpeta = CarpetaElegida.shared
        let vieja = carpeta.url ?? carpeta.abrir()
        guard contenedor != nil || vieja != nil else { return nil }

        // Antes del primer cruce con el contenedor, una copia de cómo estaba
        // el teléfono. Si no sale, no se cruza con él.
        var conContenedor = contenedor
        if contenedor != nil, !UserDefaults.standard.bool(forKey: claveCopia) {
            if (try? store.copiaAntesDeLaMudanza()) != nil {
                UserDefaults.standard.set(true, forKey: claveCopia)
            } else {
                conContenedor = nil
            }
        }

        let balance = await Task.detached(priority: .utility) {
            var total = Puente.Balance()
            if let conContenedor { total.sumar(Puente.cruzar(origen, conContenedor)) }
            if let vieja { total.sumar(Puente.cruzar(origen, vieja)) }
            return total
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
            await conICloud(store, vez: vez + 1)
        }
    }
}
