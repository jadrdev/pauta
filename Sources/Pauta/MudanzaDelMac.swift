import AppKit
import PautaCore

/// La mudanza de este Mac al contenedor de iCloud, y la transición de después.
///
/// Arranca con la app y va **en segundo plano**: la copia de seguridad puede
/// esperar a que iCloud baje archivos, y una app que no abre hasta que iCloud
/// termine es la 0.4.12 otra vez.
///
/// En orden, y cada paso solo si el anterior salió:
///
/// 1. La copia completa de antes (`Mudanza.resguardar`), una vez por Mac.
/// 2. El cruce de la carpeta vieja con el contenedor, y la comprobación.
/// 3. Si cuadra, se apunta en las preferencias de este Mac, y **el almacén lo
///    usa desde el siguiente arranque**: cambiar de carpeta con la app abierta
///    es justo el momento en que más fácil sería perder algo.
///
/// Y mientras dure la transición —hasta que todos los aparatos estén en la
/// versión nueva—, la carpeta vieja y el contenedor se cruzan al arrancar,
/// cada minuto y al salir. Así lo que toque un aparato todavía en la versión
/// anterior llega al contenedor, y lo de aquí le llega a él. Si algo de esto
/// falla, se vuelve a intentar en la vuelta siguiente: la mudanza es un cruce
/// y repetirlo no estropea nada.
enum MudanzaDelMac {
    /// Qué pasó la última vez, para `Pauta --mudanza` y para quien pregunte.
    private static let claveEstado = "mudanza.estado"
    private static let claveResguardo = "mudanza.resguardo"

    static var estado: String? { UserDefaults.standard.string(forKey: claveEstado) }
    static var resguardo: String? { UserDefaults.standard.string(forKey: claveResguardo) }

    private static func apuntar(_ texto: String) {
        UserDefaults.standard.set("\(Date.now.formatted(date: .abbreviated, time: .standard)) · \(texto)",
                                  forKey: claveEstado)
    }

    static func arrancar() {
        // Al salir, un último cruce: lo escrito en el último minuto en una
        // carpeta tiene que estar en la otra antes del siguiente arranque.
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: nil
        ) { _ in
            if let vieja = Store.iCloudRoot, let contenedor = Contenedor.rutaEnElMac,
               FileManager.default.fileExists(atPath: contenedor.path) {
                Puente.cruzar(contenedor, vieja)
            }
        }
        Task.detached(priority: .utility) {
            while true {
                await vuelta()
                try? await Task.sleep(for: .seconds(60))
            }
        }
    }

    private static func vuelta() async {
        // Sin iCloud Drive no hay de dónde mudarse ni adónde.
        guard let vieja = Store.iCloudRoot,
              FileManager.default.fileExists(atPath: vieja.path) else { return }
        // Bloquea la primera vez, y por eso va aquí y no al arrancar el
        // almacén. `nil` es iCloud apagado o una firma sin el contenedor.
        guard let contenedor = Contenedor.documentos() else {
            apuntar("sin contenedor de iCloud")
            return
        }

        if Mudanza.mudadoDesde() != nil {
            // Transición: las dos carpetas, cruzadas.
            Puente.cruzar(contenedor, vieja)
            return
        }

        // 1. La copia de antes, una sola vez por Mac: la carpeta vieja no se
        //    borra nunca, así que la de la primera vez sigue protegiendo.
        let hecha = resguardo.map { FileManager.default.fileExists(atPath: $0) } ?? false
        if !hecha {
            do {
                let r = try await Mudanza.resguardar(vieja, en: Mudanza.carpetaDelResguardo())
                UserDefaults.standard.set(r.carpeta.path, forKey: claveResguardo)
            } catch {
                apuntar("sin copia de antes, no se muda: \(error)")
                return
            }
        }

        // 2. Cruzar y comprobar.
        let resultado = Mudanza.mudar(desde: vieja, a: contenedor)
        guard resultado.cuadra else {
            let muestra = resultado.discrepancias.prefix(3).joined(separator: ", ")
            apuntar("aún no cuadra (\(resultado.discrepancias.count)): \(muestra)")
            return
        }

        // 3. Apuntado: el almacén lo usará desde el siguiente arranque.
        Mudanza.marcarMudado()
        dejarAviso(en: vieja)
        apuntar("mudado: \(resultado.balance.llevadas) archivos llevados, "
                + "\(resultado.copias) copias; se usa al volver a abrir Pauta")
    }

    /// Una nota en la carpeta vieja para quien la abra en el Finder.
    private static func dejarAviso(en vieja: URL) {
        let aviso = """
        Pauta se está mudando al contenedor de iCloud de la app.

        Desde el \(Date.now.formatted(date: .long, time: .omitted)), este Mac guarda sus datos allí.
        Mientras haya aparatos con una versión anterior, esta carpeta se sigue
        cruzando con la nueva, así que NO la borres todavía. Cuando todos estén
        actualizados dejará de usarse, y entonces podrás borrarla tú.
        """
        try? aviso.write(to: vieja.appendingPathComponent("LEEME - mudanza.txt"),
                         atomically: true, encoding: .utf8)
    }
}
