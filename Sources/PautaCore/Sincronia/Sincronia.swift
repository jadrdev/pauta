import Foundation

/// Lo que la sincronía necesita del motor que habla con el servidor.
///
/// En la app es `CKSyncEngine` (`MotorCloudKit`); en las pruebas, uno de
/// mentira que hace de servidor en memoria. Con este protocolo en medio, toda
/// la lógica —qué sube, qué gana, qué se borra, qué pasa si cambia la cuenta—
/// se prueba sin red y sin cuenta de iCloud.
@MainActor
public protocol MotorDeSincronia: AnyObject {
    /// Apunta cambios para subir. De lo que hay que guardar se apunta solo la
    /// clave: la ficha se pide al enviar, así sube siempre la última versión.
    func apuntar(guardar: [Ficha.Clave], borrar: [Ficha.Clave])
    func enviar() async throws
    func traer() async throws
}

/// La sincronía con CloudKit de una carpeta de datos (docs/plan-cloudkit.md).
///
/// **Trabaja sobre los archivos**, no sobre el almacén: cada objeto ya es un
/// archivo con su JSON, y eso es exactamente lo que viaja. Lo que llega del
/// servidor se escribe en la carpeta con la regla de siempre —gana el
/// `updatedAt` más reciente; lo ilegible no gana nunca— y luego se avisa para
/// que el almacén recargue, igual que después de un cruce del Puente.
///
/// El almacén, a su vez, avisa de cada objeto que escribe (`escrito`) y de
/// cada lápida caducada que barre (`purgadas`): es lo que se sube.
@MainActor
public final class Sincronia {
    public let raiz: URL
    public weak var motor: MotorDeSincronia?
    /// Se llama cuando lo traído cambió algún archivo: el almacén recarga.
    public var alTraer: (() -> Void)?

    /// En qué está.
    public enum Estado: Equatable, Sendable {
        /// Sin decidir todavía: no se sabe de qué cuenta es este aparato.
        case esperando
        /// Sincronizando con la cuenta de siempre.
        case activa
        /// Sin cuenta de iCloud: las tareas se quedan en el aparato, como hoy.
        case sinCuenta
        /// Hay sesión con **otra** cuenta que la de antes. No se sube nada
        /// hasta que se decida: lo de una cuenta no se mezcla con lo de otra
        /// sin preguntar.
        case otraCuenta(antes: String, ahora: String)
    }

    public private(set) var estado: Estado = .esperando

    /// Lo que se recuerda entre arranques. **Es de este aparato** y va en una
    /// carpeta local que no se sincroniza: si dos aparatos compartieran el
    /// estado, cada uno se saltaría los cambios del otro.
    struct Guardado: Codable, Equatable {
        /// La cuenta con la que se sincronizó la última vez.
        var cuenta: String?
    }

    private let archivoDeEstado: URL?
    private var guardado: Guardado

    /// - Parameters:
    ///   - raiz: la carpeta de datos del almacén.
    ///   - estado: dónde guardar el estado de este aparato. `nil` en pruebas
    ///     que no lo necesitan.
    public init(raiz: URL, estado: URL? = nil) {
        self.raiz = raiz
        self.archivoDeEstado = estado
        if let estado, let datos = try? Data(contentsOf: estado),
           let leido = try? JSONDecoder().decode(Guardado.self, from: datos) {
            self.guardado = leido
        } else {
            self.guardado = Guardado()
        }
    }

    public var puedeSubir: Bool { estado == .activa }

    // MARK: - La cuenta

    /// La cuenta de iCloud de este aparato, o `nil` si no hay sesión.
    /// El identificador es el del registro de usuario de CloudKit: no dice
    /// quién es, pero es el mismo en todos los aparatos de la misma cuenta.
    public func cuenta(_ id: String?) {
        guard let id else {
            // Se cierra sesión: se deja de sincronizar y **no se borra nada**.
            estado = .sinCuenta
            return
        }
        switch guardado.cuenta {
        case nil:
            // La primera vez: lo que hay en el aparato sube a esta cuenta.
            adoptar(id)
        case id:
            // Si se vuelve de estar sin sesión, se sube todo, y lo que el
            // servidor ya tenga se resuelve al enviar.
            //
            // Al arrancar no: la cola del motor sobrevive a cerrar la app, y lo
            // escrito mientras no se podía subir está en los apuntes. Subirlo
            // todo en cada arranque eran cuatrocientos registros que los demás
            // aparatos tenían que volver a bajar.
            let volvia = estado != .activa && estado != .esperando
            estado = .activa
            if volvia { subirTodo() }
            recogerApuntes()
        case let antes?:
            estado = .otraCuenta(antes: antes, ahora: id)
        }
    }

    /// Lo que se decide cuando hay sesión con otra cuenta: subir lo de este
    /// aparato a la nueva, o dejarlo sin sincronizar.
    public func decidirOtraCuenta(subir: Bool) {
        guard case let .otraCuenta(_, ahora) = estado else { return }
        if subir {
            adoptar(ahora)
        } else {
            estado = .sinCuenta
        }
    }

    private func adoptar(_ id: String) {
        guardado.cuenta = id
        guardar()
        estado = .activa
        subirTodo()
    }

    private func guardar() {
        guard let archivoDeEstado, let datos = try? JSONEncoder().encode(guardado) else { return }
        try? FileManager.default.createDirectory(at: archivoDeEstado.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        try? datos.write(to: archivoDeEstado, options: .atomic)
    }

    /// Apunta para subir todo lo que hay en la carpeta. Lo que el servidor ya
    /// tenga igual o más nuevo se resuelve al enviar, con la regla de siempre.
    public func subirTodo() {
        guard puedeSubir else { return }
        motor?.apuntar(guardar: Sincronia.claves(en: raiz), borrar: [])
    }

    static func claves(en raiz: URL) -> [Ficha.Clave] {
        let fm = FileManager.default
        var claves: [Ficha.Clave] = []
        for tipo in Ficha.Tipo.allCases {
            let dir = raiz.appendingPathComponent(tipo.carpeta, isDirectory: true)
            let archivos = (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
            for archivo in archivos where archivo.pathExtension == "json" {
                if let id = UUID(uuidString: archivo.deletingPathExtension().lastPathComponent) {
                    claves.append(Ficha.Clave(tipo, id))
                }
            }
        }
        return claves
    }

    // MARK: - Lo que dice el almacén

    /// El almacén escribió este objeto.
    ///
    /// Si ahora no se puede subir —arrancando, sin cuenta—, se apunta para
    /// cuando se pueda (`Apuntes`): perderlo sería que ese cambio no saliera
    /// nunca de este aparato.
    public func escrito(_ clave: Ficha.Clave) {
        guard puedeSubir else { return Apuntes.apuntar(guardar: [clave], en: raiz) }
        motor?.apuntar(guardar: [clave], borrar: [])
    }

    /// El almacén barrió estas lápidas caducadas: se borran del servidor
    /// también. Si otro aparato lo hace a la vez, el segundo encuentra el
    /// registro ya borrado y no pasa nada.
    public func purgadas(_ claves: [Ficha.Clave]) {
        guard !claves.isEmpty else { return }
        guard puedeSubir else { return Apuntes.apuntar(borrar: claves, en: raiz) }
        motor?.apuntar(guardar: [], borrar: claves)
    }

    /// Lo que escribieron los almacenes sin enganchar —el widget, Siri, los
    /// botones de un aviso— pasa a la cola (ver `Apuntes`). Sin sincronía
    /// activa se quedan donde están, para cuando la haya.
    public func recogerApuntes() {
        guard puedeSubir else { return }
        let r = Apuntes.recoger(en: raiz)
        guard !r.archivos.isEmpty else { return }
        motor?.apuntar(guardar: r.guardar, borrar: r.borrar)
        Apuntes.olvidar(r.archivos)
    }

    // MARK: - Lo que pide y trae el motor

    /// La ficha que hay que subir para esta clave, leída en el momento.
    public func fichaParaSubir(_ clave: Ficha.Clave) -> Ficha? {
        Ficha.leer(clave, en: raiz)
    }

    /// Fichas que llegan del servidor. Entra la que gana; si la de aquí es más
    /// nueva, se vuelve a apuntar para subir —el servidor tiene una vieja—.
    /// Devuelve cuántas cambiaron algo aquí.
    @discardableResult
    public func recibidas(_ fichas: [Ficha]) -> Int {
        var cambiadas = 0
        var resubir: [Ficha.Clave] = []
        for ficha in fichas {
            if ficha.escribir(en: raiz) {
                cambiadas += 1
            } else if let mia = Ficha.leer(ficha.clave, en: raiz), mia.updatedAt > ficha.updatedAt {
                resubir.append(ficha.clave)
            }
        }
        if !resubir.isEmpty, puedeSubir { motor?.apuntar(guardar: resubir, borrar: []) }
        if cambiadas > 0 { alTraer?() }
        return cambiadas
    }

    /// Registros que el servidor ya no tiene.
    ///
    /// Lo normal es que sean lápidas caducadas que otro aparato barrió: si aquí
    /// también es una lápida, se barre el archivo. Pero si aquí está **viva**,
    /// el borrado del servidor no puede llevársela —nadie decidió borrarla: se
    /// purgó una lápida que aquí había vuelto a la vida—, así que se sube otra
    /// vez.
    @discardableResult
    public func borradasEnServidor(_ claves: [Ficha.Clave]) -> Int {
        var barridas = 0
        var resubir: [Ficha.Clave] = []
        for clave in claves {
            guard let mia = Ficha.leer(clave, en: raiz) else { continue }
            if mia.esLapida {
                if (try? FileManager.default.removeItem(at: Ficha.archivo(clave, en: raiz))) != nil {
                    barridas += 1
                }
            } else {
                resubir.append(clave)
            }
        }
        if !resubir.isEmpty, puedeSubir { motor?.apuntar(guardar: resubir, borrar: []) }
        if barridas > 0 { alTraer?() }
        return barridas
    }

    /// Qué hacer cuando el servidor rechaza una subida porque otro aparato
    /// subió antes.
    public enum Resolucion: Equatable, Sendable {
        /// La de aquí es más nueva: se vuelve a subir, sobre la del servidor.
        case subirLaMia
        /// La del servidor gana: ya está escrita aquí, y no hay nada que subir.
        case quedarseConLaDelServidor
    }

    /// La regla de siempre: gana el `updatedAt` más reciente. En un empate se
    /// queda la del servidor: es la que ya tienen los demás aparatos, y así no
    /// se sube nada.
    public func conflicto(_ clave: Ficha.Clave, servidor: Ficha) -> Resolucion {
        guard let mia = Ficha.leer(clave, en: raiz) else {
            recibidas([servidor])
            return .quedarseConLaDelServidor
        }
        if mia.updatedAt > servidor.updatedAt { return .subirLaMia }
        recibidas([servidor])
        return .quedarseConLaDelServidor
    }
}
