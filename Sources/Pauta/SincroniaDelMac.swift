import AppKit
import CloudKit
import PautaCore

/// La sincronía con CloudKit en el Mac (docs/plan-cloudkit.md, fase 2).
///
/// Tres piezas, y cada una solo si toca:
///
/// 1. **La mudanza** a la carpeta local (`MudanzaACloudKit`), en segundo plano:
///    copia completa de antes, cruce y comprobación. El almacén la usa desde el
///    siguiente arranque.
/// 2. **La sincronía**, una vez mudado: `Sincronia` con `MotorCloudKit`. Sube lo
///    que el almacén escribe, y trae lo de los demás **cada 15 segundos** y al
///    volver a primer plano. Los avisos silenciosos de CloudKit no llegan al Mac
///    (fase 0, sin resolver), así que se pregunta en vez de esperar.
/// 3. **La transición**: mientras haya aparatos en versiones sin CloudKit, el
///    almacén se cruza con el contenedor de iCloud con el Puente, en cuanto
///    cambia cualquiera de los dos. Lo que trae de un aparato viejo se sube a
///    CloudKit; lo que llega de CloudKit se lleva al contenedor.
@MainActor
enum SincroniaDelMac {
    private static var sincronia: Sincronia?
    private static var motor: MotorCloudKit?
    private static var vigilantes: [FolderWatcher] = []
    private static var pendiente: Task<Void, Never>?
    /// Un cruce a la vez: el del vigilante, el del reloj y el de salir podrían
    /// coincidir, y dos cruces escribiendo lo mismo a la vez se pisan.
    private nonisolated static let cerrojo = NSLock()

    private static let claveEstado = "cloudkit.estado"
    private static let claveResguardo = "cloudkit.resguardo"

    /// Qué pasó la última vez, para `Pauta --cloudkit`.
    static var estado: String? { UserDefaults.standard.string(forKey: claveEstado) }
    static var resguardo: String? { UserDefaults.standard.string(forKey: claveResguardo) }

    private static func apuntar(_ texto: String) {
        UserDefaults.standard.set("\(Date.now.formatted(date: .abbreviated, time: .standard)) · \(texto)",
                                  forKey: claveEstado)
    }

    static func arrancar(_ store: Store) {
        if MudanzaACloudKit.mudadoDesde() != nil,
           store.storageURL.standardizedFileURL == MudanzaACloudKit.carpeta.standardizedFileURL {
            conectar(store)
            empezarTransicion(store)
        } else {
            Task { await mudarSiToca(store) }
        }
    }

    // MARK: - 1. La mudanza

    private static func mudarSiToca(_ store: Store) async {
        guard MudanzaACloudKit.mudadoDesde() == nil else { return }
        // Primero la mudanza al contenedor, si este Mac aún no la hizo: dos
        // mudanzas a la vez sobre la misma carpeta se pisarían.
        guard Mudanza.mudadoDesde() != nil else {
            apuntar("espera a la mudanza al contenedor")
            return
        }
        let cuenta = try? await CKContainer(identifier: MotorCloudKit.contenedor).accountStatus()
        guard cuenta == .available else {
            apuntar("sin cuenta de iCloud: no se muda")
            return
        }
        let antes = store.storageURL
        let nueva = MudanzaACloudKit.carpeta

        // La copia de antes, una vez por Mac.
        let hecha = resguardo.map { FileManager.default.fileExists(atPath: $0) } ?? false
        if !hecha && Mudanza.tieneDatos(antes) {
            do {
                let r = try await Mudanza.resguardar(
                    antes, en: Mudanza.carpetaDelResguardo(nombre: "Pauta antes de CloudKit"))
                UserDefaults.standard.set(r.carpeta.path, forKey: claveResguardo)
            } catch {
                apuntar("sin copia de antes, no se muda: \(error)")
                return
            }
        }

        let resultado = await Task.detached(priority: .utility) {
            cerrojo.withLock { MudanzaACloudKit.mudar(desde: antes, a: nueva) }
        }.value
        guard resultado.cuadra else {
            let muestra = resultado.discrepancias.prefix(3).joined(separator: ", ")
            apuntar("aún no cuadra (\(resultado.discrepancias.count)): \(muestra)")
            return
        }
        MudanzaACloudKit.marcarMudado()
        apuntar("mudado: \(resultado.balance.llevadas) archivos llevados; "
                + "CloudKit empieza al volver a abrir Pauta")
    }

    // MARK: - 2. La sincronía

    private static func conectar(_ store: Store) {
        let raiz = store.storageURL
        let estado = MudanzaACloudKit.carpetaDelEstado(en: raiz)
        let s = Sincronia(raiz: raiz, estado: estado.appendingPathComponent("sincronia.json"))
        let m = MotorCloudKit(sincronia: s, carpeta: estado.appendingPathComponent("motor", isDirectory: true))
        store.alEscribir = { s.escrito($0) }
        store.alPurgar = { s.purgadas($0) }
        s.alTraer = { store.reload() }
        sincronia = s
        motor = m

        Task {
            await m.comprobarCuenta()
            apuntar("sincronizando · \(s.estado)")
            await traer()
        }
        // Cada 15 segundos mientras la app está abierta.
        Task {
            while true {
                try? await Task.sleep(for: .seconds(15))
                await traer()
            }
        }
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { _ in Task { @MainActor in await traer() } }
    }

    private static func traer() async {
        guard let motor else { return }
        // Lo que escribió otro almacén —una orden del terminal, por ejemplo—
        // sale con esta vuelta.
        sincronia?.recogerApuntes()
        do {
            try await motor.traer()
        } catch {
            apuntar("al traer: \(error.localizedDescription)")
        }
    }

    /// Para `Pauta --cloudkit`: la cuenta y el estado, desde el terminal.
    static var resumen: String {
        let desde = MudanzaACloudKit.mudadoDesde().map { "sí, desde \($0.formatted())" } ?? "todavía no"
        return """
        mudado a CloudKit: \(desde)
        carpeta: \(MudanzaACloudKit.carpeta.path)
        copia de antes: \(resguardo ?? "sin hacer")
        última vez: \(estado ?? "nada")
        """
    }

    // MARK: - 3. La transición

    private static func empezarTransicion(_ store: Store) {
        guard let contenedor = Contenedor.rutaEnElMac,
              FileManager.default.fileExists(atPath: contenedor.path) else { return }
        let raiz = store.storageURL
        Task { await cruzar(store, contenedor) }
        vigilantes = [raiz, contenedor].compactMap { carpeta in
            FolderWatcher(url: carpeta) { cruzarPronto(store, contenedor) }
        }
        // La red por si un aviso del vigilante se pierde.
        Task {
            while true {
                try? await Task.sleep(for: .seconds(300))
                await cruzar(store, contenedor)
            }
        }
        // Al salir, un último cruce: lo de los últimos segundos tiene que estar
        // en el contenedor antes de que lo lea otro aparato.
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: nil
        ) { _ in cerrojo.withLock { _ = Puente.cruzar(raiz, contenedor) } }
    }

    /// Cruza en cuanto se calman los avisos. Cada cruce escribe y despierta a
    /// los vigilantes otra vez, pero el siguiente ya no encuentra nada que
    /// mover: ahí se acaba.
    private static func cruzarPronto(_ store: Store, _ contenedor: URL) {
        pendiente?.cancel()
        pendiente = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            await cruzar(store, contenedor)
        }
    }

    private static func cruzar(_ store: Store, _ contenedor: URL) async {
        let raiz = store.storageURL
        let balance = await Task.detached(priority: .utility) {
            cerrojo.withLock { Puente.cruzar(raiz, contenedor) }
        }.value
        // Lo que trajo de un aparato viejo, también a CloudKit.
        guard !balance.claveTraidas.isEmpty else { return }
        for clave in balance.claveTraidas { sincronia?.escrito(clave) }
        store.reload()
    }

    #if DEBUG
    /// `Pauta --cloudkit-esquema`, solo en depuración: crea en el entorno de
    /// **desarrollo** los tipos `Item`, `Project` y `Area` con todos sus campos
    /// —`json`, `jsonAsset`, `updatedAt`, `deletedAt`—, subiendo un registro de
    /// muestra de cada forma y borrándolo después. En producción no se pueden
    /// crear tipos: se crean aquí y se publican desde la consola de CloudKit.
    static func crearEsquema() async throws {
        let base = CKContainer(identifier: MotorCloudKit.contenedor).privateCloudDatabase
        _ = try await base.modifyRecordZones(saving: [CKRecordZone(zoneID: Ficha.zona)], deleting: [])
        let temporal = FileManager.default.temporaryDirectory
        var registros: [CKRecord] = []
        for tipo in Ficha.Tipo.allCases {
            let lapida = Ficha(clave: .init(tipo, UUID()), json: Data("{}".utf8),
                               updatedAt: .now, deletedAt: .now)
            let grande = Ficha(clave: .init(tipo, UUID()),
                               json: Data(repeating: 32, count: Ficha.limiteEnElRegistro + 1000),
                               updatedAt: .now, deletedAt: nil)
            registros += [lapida.registro(temporal: temporal), grande.registro(temporal: temporal)]
        }
        _ = try await base.modifyRecords(saving: registros, deleting: [])
        _ = try await base.modifyRecords(saving: [], deleting: registros.map(\.recordID))
    }
    #endif
}
