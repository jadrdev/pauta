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
/// versión nueva—, la carpeta vieja y el contenedor se cruzan **en cuanto
/// cambia cualquiera de las dos**, además de al arrancar, al salir y cada cinco
/// minutos por si acaso. Así lo que toque un aparato todavía en la versión
/// anterior llega al contenedor en segundos, y lo de aquí le llega a él. Al
/// principio era cada minuto, y un minuto es lo que se tarda en tachar algo en
/// el Mac y mirar el iPhone: la prueba salió «no llega». Si algo falla, se
/// vuelve a intentar en la vuelta siguiente: la mudanza es un cruce y
/// repetirlo no estropea nada.
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

    /// La carpeta que usa el almacén en esta sesión, fijada al arrancar: si el
    /// Mac se muda con la app abierta, el almacén sigue en ella hasta el
    /// siguiente arranque, y lo que se escriba ahí tiene que llegar al
    /// contenedor igual.
    private static var raizDeLaSesion: URL?

    /// Las carpetas que se cruzan con el contenedor una vez mudado: la de esta
    /// sesión si no es el contenedor, y la de iCloud Drive mientras exista,
    /// que es la de los aparatos todavía en una versión anterior.
    private static func carpetasQueCruzar(_ contenedor: URL) -> [URL] {
        var carpetas: [URL] = []
        for carpeta in [raizDeLaSesion, Store.iCloudRoot].compactMap({ $0 })
        where carpeta.standardizedFileURL != contenedor.standardizedFileURL
            && FileManager.default.fileExists(atPath: carpeta.path)
            && !carpetas.contains(carpeta) {
            carpetas.append(carpeta)
        }
        return carpetas
    }

    static func arrancar() {
        raizDeLaSesion = Store.defaultRoot
        // Al salir, un último cruce: lo escrito en el último minuto en una
        // carpeta tiene que estar en la otra antes del siguiente arranque.
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: nil
        ) { _ in cruzarLaTransicion() }
        Task.detached(priority: .utility) {
            while true {
                let mudado = await vuelta()
                if mudado { await vigilar() }
                // Sin mudar, se reintenta cada minuto; mudado, lo normal es que
                // cruce el vigilante, y esto es solo la red por si un aviso se
                // pierde.
                try? await Task.sleep(for: .seconds(mudado ? 300 : 60))
            }
        }
    }

    // MARK: - La transición

    /// Los vigilantes de las dos carpetas, una vez mudado.
    @MainActor private static var vigilantes: [FolderWatcher] = []
    @MainActor private static var pendiente: Task<Void, Never>?
    /// Un cruce a la vez: el del vigilante, el de la vuelta y el de salir
    /// podrían coincidir, y dos cruces escribiendo lo mismo a la vez se pisan.
    private static let cerrojo = NSLock()

    @MainActor private static func vigilar() {
        guard vigilantes.isEmpty, let contenedor = Contenedor.rutaEnElMac else { return }
        let otras = carpetasQueCruzar(contenedor)
        guard !otras.isEmpty else { return }
        vigilantes = ([contenedor] + otras).compactMap { carpeta in
            FolderWatcher(url: carpeta) { cruzarPronto() }
        }
    }

    /// Cruza en cuanto se calman los avisos. Cada cruce escribe en las carpetas
    /// y eso despierta a los vigilantes otra vez, pero el cruce siguiente ya no
    /// encuentra nada que mover y no escribe nada: ahí se acaba.
    @MainActor private static func cruzarPronto() {
        pendiente?.cancel()
        pendiente = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            await Task.detached(priority: .utility) { cruzarLaTransicion() }.value
        }
    }

    private static func cruzarLaTransicion() {
        guard Mudanza.mudadoDesde() != nil, let contenedor = Contenedor.rutaEnElMac,
              FileManager.default.fileExists(atPath: contenedor.path) else { return }
        cerrojo.withLock {
            for carpeta in carpetasQueCruzar(contenedor) { _ = Puente.cruzar(contenedor, carpeta) }
        }
    }

    /// Una vuelta: la mudanza si aún no está hecha, o un cruce si ya lo está.
    /// Devuelve si este Mac está mudado.
    private static func vuelta() async -> Bool {
        // De la carpeta que se estaba usando: la de iCloud Drive para quien
        // venía de antes, la local para quien empezó sin iCloud o es nuevo.
        let vieja = Store.carpetaDeAntes
        // Bloquea la primera vez, y por eso va aquí y no al arrancar el
        // almacén. `nil` es iCloud apagado o una firma sin el contenedor.
        guard let contenedor = Contenedor.documentos() else {
            apuntar("sin contenedor de iCloud")
            return false
        }

        if Mudanza.mudadoDesde() != nil {
            cruzarLaTransicion()
            return true
        }

        // 1. La copia de antes, una sola vez por Mac: la carpeta vieja no se
        //    borra nunca, así que la de la primera vez sigue protegiendo. Y
        //    solo si hay algo que proteger: un Mac nuevo no deja una copia
        //    vacía en tu carpeta de usuario.
        let hecha = resguardo.map { FileManager.default.fileExists(atPath: $0) } ?? false
        if !hecha && Mudanza.tieneDatos(vieja) {
            do {
                let r = try await Mudanza.resguardar(vieja, en: Mudanza.carpetaDelResguardo())
                UserDefaults.standard.set(r.carpeta.path, forKey: claveResguardo)
            } catch {
                apuntar("sin copia de antes, no se muda: \(error)")
                return false
            }
        }

        // 2. Cruzar y comprobar. Si esta sesión trabaja en otra carpeta con
        //    datos —empezó sin iCloud, y al activarlo ya había una carpeta de
        //    iCloud Drive de otro aparato—, también entra: si no, lo apuntado
        //    aquí se quedaría fuera de la mudanza.
        if let sesion = raizDeLaSesion, sesion != vieja,
           sesion.standardizedFileURL != contenedor.standardizedFileURL, Mudanza.tieneDatos(sesion) {
            cerrojo.withLock { _ = Puente.cruzar(sesion, contenedor) }
        }
        let resultado = Mudanza.mudar(desde: vieja, a: contenedor)
        guard resultado.cuadra else {
            let muestra = resultado.discrepancias.prefix(3).joined(separator: ", ")
            apuntar("aún no cuadra (\(resultado.discrepancias.count)): \(muestra)")
            return false
        }

        // 3. Apuntado: el almacén lo usará desde el siguiente arranque.
        Mudanza.marcarMudado()
        // La nota, solo en la de iCloud Drive: la local no la abre nadie.
        if vieja == Store.iCloudRoot { dejarAviso(en: vieja) }
        apuntar("mudado: \(resultado.balance.llevadas) archivos llevados, "
                + "\(resultado.copias) copias; se usa al volver a abrir Pauta")
        return true
    }

    /// Una nota en la carpeta vieja para quien la abra en el Finder.
    private static func dejarAviso(en vieja: URL) {
        let aviso = String(localized: """
        Pauta se está mudando al contenedor de iCloud de la app.

        Desde el \(Date.now.formatted(date: .long, time: .omitted)), este Mac guarda sus datos allí.
        Mientras haya aparatos con una versión anterior, esta carpeta se sigue
        cruzando con la nueva, así que NO la borres todavía. Cuando todos estén
        actualizados dejará de usarse, y entonces podrás borrarla tú.
        """, comment: "Nota de texto que se deja en la carpeta vieja de iCloud Drive")
        try? aviso.write(to: vieja.appendingPathComponent("LEEME - mudanza.txt"),
                         atomically: true, encoding: .utf8)
    }
}
