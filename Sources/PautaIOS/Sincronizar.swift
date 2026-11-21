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
/// Y siempre **puede no hacer nada**: sin iCloud devuelve `nil` y la app sigue
/// con sus datos como si nada. Eso es lo que hace que esto sea un puente y no
/// un cordón umbilical.
@MainActor
enum Sincronizar {
    private static let claveCopia = "contenedor.copiaDeAntes"

    /// Si hay un cruce en marcha.
    private static var cruzando = false
    /// Si alguien pidió cruzar mientras había uno en marcha, y si alguno de
    /// esos pidió también traer de CloudKit.
    private static var otraVez = false
    private static var otraVezTrayendo = false
    /// Quienes esperan al cruce que empezará cuando acabe el de ahora.
    private static var esperando: [CheckedContinuation<Puente.Balance?, Never>] = []

    /// Cruza, **de uno en uno**.
    ///
    /// Se pide desde muchos sitios —el vigilante, cada cambio de las tareas,
    /// volver del fondo, el arranque—, y en un aparato recién instalado con
    /// tareas en iCloud llegan a la vez: iCloud avisa archivo a archivo, cada
    /// cruce que trae algo recarga, y recargar cambia las tareas, que vuelve a
    /// pedir otro. En el iPad cada cruce con el contenedor tarda de seis a
    /// once segundos, así que se montaban unos encima de otros y la app se
    /// quedaba trabada justo en el primer arranque (un iPad recién formateado,
    /// noviembre de 2026).
    ///
    /// Ahora, si llega una petición con un cruce en marcha, no se lanza otro:
    /// se apunta, y al acabar el de ahora se hace **uno más** por todas las
    /// que llegaron mientras tanto —trayendo de CloudKit si alguna lo pidió—.
    /// Uno y no ninguno, porque lo que las motivó pudo pasar después de que el
    /// cruce en marcha leyera las carpetas.
    private static func cruzarUnaVez(_ store: Store, traer: Bool, vez: Int) async -> Puente.Balance? {
        if cruzando {
            otraVez = true
            if traer { otraVezTrayendo = true }
            return await withCheckedContinuation { esperando.append($0) }
        }
        cruzando = true
        var balance = await cruzarUnaVez(store, traer: traer, vez: vez)
        while otraVez {
            let trayendo = otraVezTrayendo
            otraVez = false
            otraVezTrayendo = false
            let estos = esperando
            esperando = []
            balance = await cruzarUnaVez(store, traer: trayendo, vez: vez)
            for espera in estos { espera.resume(returning: balance) }
        }
        cruzando = false
        return balance
    }

    /// Un cruce, **fuera del hilo principal**.
    ///
    /// Esto se escribió primero en el hilo principal y con una carpeta de
    /// verdad —sesenta y siete archivos, la mitad sin bajar de iCloud— dejó la
    /// app congelada hasta que hubo que cerrarla. Leer archivos es trabajo de
    /// disco y de red: no se hace donde se dibuja.
    ///
    /// Con CloudKit (docs/plan-cloudkit.md, fase 3) hace dos cosas: sube lo
    /// pendiente a CloudKit —y trae lo de los demás si se pide con `traer`—, y
    /// mientras dure la transición sigue cruzando con el contenedor de iCloud,
    /// para que lo vean los aparatos que aún no tienen esta versión. Lo que
    /// trae el contenedor sube a CloudKit; lo que llega de CloudKit sale al
    /// contenedor en el cruce siguiente. Gana lo más reciente en los dos lados,
    /// así que llegan a lo mismo.
    @discardableResult
    static func conICloud(_ store: Store, traer: Bool = false, vez: Int = 0) async -> Puente.Balance? {
        // La maqueta de las capturas no toca iCloud: llevaría sus tareas de
        // muestra a las de verdad.
        guard !Maqueta.activa else { return nil }
        let nube = SincroniaDelTelefono.shared
        nube.enganchar(store)
        // CloudKit primero: es lo rápido. El cruce con el contenedor lee
        // cientos de archivos y tarda segundos en el teléfono, y lo que llega
        // de CloudKit no tiene por qué esperarlo.
        await nube.sincronizar(traer: traer)
        let origen = store.storageURL
        // Bloquea la primera vez: fuera del hilo principal.
        let contenedor = await Task.detached(priority: .utility) { Contenedor.documentos() }.value
        guard contenedor != nil else { return nil }
        // El marcador de la carpeta del Mac que se elegía antes de la mudanza.
        // Ya no se usa: se suelta para no guardar un permiso para nada.
        UserDefaults.standard.removeObject(forKey: "carpetaDelMac")

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
            return total
        }.value
        // Solo se relee si algo llegó: recargar por costumbre agita las fechas
        // de todo y da trabajo a iCloud por nada.
        if balance.traidas > 0 { store.reload() }
        // Lo que trajo el contenedor, de un aparato que aún no usa CloudKit,
        // sube también; el motor lo envía solo en medio segundo.
        nube.traidasDelContenedor(balance.claveTraidas)
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
