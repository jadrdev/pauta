import CloudKit
import Foundation
import Testing
@testable import PautaCore

// La sincronía con CloudKit, sin red (docs/plan-cloudkit.md, fase 1).
//
// Un servidor de mentira en memoria y un motor de mentira por aparato, con un
// almacén de verdad en una carpeta temporal cada uno. El motor imita lo que
// importa de `CKSyncEngine`: sube lo apuntado, rechaza la subida si el registro
// cambió en el servidor desde la última vez que este aparato lo vio, y trae los
// cambios desde una marca.

private struct SinRed: Error {}

@MainActor
private final class ServidorDeMentira {
    struct Version { var ficha: Ficha; var etiqueta: Int; var orden: Int }
    var registros: [Ficha.Clave: Version] = [:]
    var borrados: [(clave: Ficha.Clave, orden: Int)] = []
    var orden = 0

    func guardar(_ ficha: Ficha) -> Int {
        orden += 1
        let etiqueta = (registros[ficha.clave]?.etiqueta ?? 0) + 1
        registros[ficha.clave] = Version(ficha: ficha, etiqueta: etiqueta, orden: orden)
        return etiqueta
    }

    func borrar(_ clave: Ficha.Clave) {
        guard registros.removeValue(forKey: clave) != nil else { return }
        orden += 1
        borrados.append((clave, orden))
    }

    func cambios(desde marca: Int) -> (cambiadas: [Version], borradas: [Ficha.Clave], marca: Int) {
        (registros.values.filter { $0.orden > marca }.sorted { $0.orden < $1.orden },
         borrados.filter { $0.orden > marca }.map(\.clave),
         orden)
    }
}

@MainActor
private final class MotorDeMentira: MotorDeSincronia {
    let servidor: ServidorDeMentira
    unowned let sincronia: Sincronia
    var porGuardar: Set<Ficha.Clave> = []
    var porBorrar: Set<Ficha.Clave> = []
    /// La etiqueta de cada registro según la vio este aparato por última vez.
    var conocidas: [Ficha.Clave: Int] = [:]
    var marca = 0
    var enLinea = true
    var subidas = 0

    init(_ servidor: ServidorDeMentira, _ sincronia: Sincronia) {
        self.servidor = servidor
        self.sincronia = sincronia
    }

    func apuntar(guardar: [Ficha.Clave], borrar: [Ficha.Clave]) {
        porGuardar.formUnion(guardar)
        porBorrar.formUnion(borrar)
        porGuardar.subtract(borrar)
    }

    func enviar() async throws {
        guard enLinea else { throw SinRed() }
        guard sincronia.puedeSubir else { return }
        for clave in porGuardar {
            guard let ficha = sincronia.fichaParaSubir(clave) else { continue }
            if let enServidor = servidor.registros[clave], enServidor.etiqueta != conocidas[clave] {
                // `serverRecordChanged`: alguien subió antes.
                switch sincronia.conflicto(clave, servidor: enServidor.ficha) {
                case .subirLaMia:
                    conocidas[clave] = servidor.guardar(ficha)
                    subidas += 1
                case .quedarseConLaDelServidor:
                    conocidas[clave] = enServidor.etiqueta
                }
            } else {
                conocidas[clave] = servidor.guardar(ficha)
                subidas += 1
            }
        }
        porGuardar = []
        for clave in porBorrar {
            servidor.borrar(clave)
            conocidas[clave] = nil
        }
        porBorrar = []
    }

    func traer() async throws {
        guard enLinea else { throw SinRed() }
        let r = servidor.cambios(desde: marca)
        for v in r.cambiadas { conocidas[v.ficha.clave] = v.etiqueta }
        for clave in r.borradas { conocidas[clave] = nil }
        sincronia.recibidas(r.cambiadas.map(\.ficha))
        sincronia.borradasEnServidor(r.borradas)
        marca = r.marca
    }
}

/// Un aparato: almacén, sincronía y motor, en su carpeta.
@MainActor
private final class Aparato {
    let raiz: URL
    let store: Store
    let sincronia: Sincronia
    let motor: MotorDeMentira

    init(_ servidor: ServidorDeMentira, cuenta: String? = "yo") {
        raiz = FileManager.default.temporaryDirectory
            .appendingPathComponent("pauta-sincronia-\(UUID().uuidString)", isDirectory: true)
        store = Store(root: raiz)
        sincronia = Sincronia(raiz: raiz)
        motor = MotorDeMentira(servidor, sincronia)
        sincronia.motor = motor
        store.alEscribir = { [sincronia] in sincronia.escrito($0) }
        store.alPurgar = { [sincronia] in sincronia.purgadas($0) }
        sincronia.alTraer = { [store] in store.reload() }
        sincronia.cuenta(cuenta)
    }

    func sincronizar() async throws {
        try await motor.enviar()
        try await motor.traer()
    }

    func tarea(_ id: UUID) -> Item? { store.items.first { $0.id == id } }

    func renombrar(_ id: UUID, _ titulo: String) {
        guard var t = tarea(id) else { return }
        t.title = titulo
        store.update(t)
    }

    deinit { try? FileManager.default.removeItem(at: raiz) }
}

/// Las fechas se redondean al milisegundo: entre dos cambios que tienen que
/// ordenarse, se deja pasar un poco.
private func respirar() async { try? await Task.sleep(for: .milliseconds(5)) }

// MARK: - La ficha

@MainActor
struct FichaTests {
    private func ficha(_ tamano: Int = 0) -> Ficha {
        var item = Item(title: String(repeating: "x", count: max(1, tamano)))
        item.updatedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let json = try! ISODate.codificador().encode(item)
        return Ficha(clave: .init(.tarea, item.id), json: json)!
    }

    /// Ida y vuelta: el JSON va entero dentro, y las fechas al lado.
    @Test func roundTripThroughARecord() throws {
        let f = ficha()
        let r = f.registro()
        #expect(r.recordType == "Item")
        #expect(r.recordID.recordName == f.clave.id.uuidString)
        #expect(r.recordID.zoneID.zoneName == "Pauta")
        #expect(r["updatedAt"] as? Date == f.updatedAt)
        #expect(r["jsonAsset"] == nil)
        #expect(Ficha(registro: r) == f)
    }

    /// Un JSON que no cabe en el registro va como fichero, y vuelve igual.
    @Test func aBigOneGoesAsAnAsset() throws {
        let f = ficha(Ficha.limiteEnElRegistro + 1000)
        let temporal = FileManager.default.temporaryDirectory
        let r = f.registro(temporal: temporal)
        #expect(r["json"] == nil)
        let asset = try #require(r["jsonAsset"] as? CKAsset)
        #expect(asset.fileURL != nil)
        #expect(Ficha(registro: r) == f)
    }

    /// Lo que no se entiende no viaja: un tipo desconocido, o sin JSON.
    @Test func whatIsNotUnderstoodIsDropped() {
        let raro = CKRecord(recordType: "Otra", recordID: .init(recordName: UUID().uuidString, zoneID: Ficha.zona))
        raro["json"] = Data("{}".utf8) as CKRecordValue
        #expect(Ficha(registro: raro) == nil)
        let vacio = CKRecord(recordType: "Item", recordID: .init(recordName: UUID().uuidString, zoneID: Ficha.zona))
        #expect(Ficha(registro: vacio) == nil)
    }

    /// En la carpeta solo entra si gana: si no hay nada, si lo que hay no se
    /// entiende, o si es más nueva.
    @Test func itOnlyLandsIfItWins() throws {
        let raiz = FileManager.default.temporaryDirectory
            .appendingPathComponent("pauta-ficha-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: raiz) }
        let f = ficha()
        #expect(f.escribir(en: raiz))
        #expect(!f.escribir(en: raiz), "la misma no vuelve a escribirse")

        var vieja = try ISODate.decodificador().decode(Item.self, from: f.json)
        vieja.updatedAt = f.updatedAt.addingTimeInterval(-60)
        let fv = Ficha(clave: f.clave, json: try ISODate.codificador().encode(vieja))!
        #expect(!fv.escribir(en: raiz), "una más vieja no pisa")

        try Data("basura".utf8).write(to: Ficha.archivo(f.clave, en: raiz))
        #expect(fv.escribir(en: raiz), "lo ilegible pierde siempre")
    }
}

// MARK: - Dos aparatos

@MainActor
struct SincroniaTests {

    /// Lo de uno llega al otro.
    @Test func whatOneWritesTheOtherGets() async throws {
        let servidor = ServidorDeMentira()
        let mac = Aparato(servidor), iphone = Aparato(servidor)
        let t = mac.store.addItem(title: "Llamar al fontanero", in: .today)
        try await mac.sincronizar()
        try await iphone.sincronizar()
        #expect(iphone.tarea(t.id)?.title == "Llamar al fontanero")
    }

    /// Dos aparatos tocando tareas distintas no se pisan nunca.
    @Test func differentTasksNeverClash() async throws {
        let servidor = ServidorDeMentira()
        let mac = Aparato(servidor), iphone = Aparato(servidor)
        let a = mac.store.addItem(title: "A", in: .today)
        let b = mac.store.addItem(title: "B", in: .today)
        try await mac.sincronizar(); try await iphone.sincronizar()

        await respirar()
        mac.renombrar(a.id, "A del Mac")
        iphone.renombrar(b.id, "B del iPhone")
        try await mac.sincronizar(); try await iphone.sincronizar(); try await mac.sincronizar()

        for aparato in [mac, iphone] {
            #expect(aparato.tarea(a.id)?.title == "A del Mac")
            #expect(aparato.tarea(b.id)?.title == "B del iPhone")
        }
    }

    /// Los dos tocando la misma: gana la última, en los dos. Y el que pierde el
    /// conflicto al subir no vuelve a subir la suya.
    @Test func theSameTaskTheLatestWins() async throws {
        let servidor = ServidorDeMentira()
        let mac = Aparato(servidor), iphone = Aparato(servidor)
        let t = mac.store.addItem(title: "Original", in: .today)
        try await mac.sincronizar(); try await iphone.sincronizar()

        await respirar()
        mac.renombrar(t.id, "Del Mac")
        await respirar()
        iphone.renombrar(t.id, "Del iPhone, más tarde")
        // Sube primero el Mac: el iPhone se encuentra el conflicto y gana él.
        try await mac.sincronizar(); try await iphone.sincronizar(); try await mac.sincronizar()
        #expect(mac.tarea(t.id)?.title == "Del iPhone, más tarde")
        #expect(iphone.tarea(t.id)?.title == "Del iPhone, más tarde")

        // Y al revés: el cambio viejo que sube tarde pierde y no se queda.
        await respirar()
        iphone.renombrar(t.id, "iPhone, antes")
        await respirar()
        mac.renombrar(t.id, "Mac, después")
        try await mac.sincronizar(); try await iphone.sincronizar(); try await mac.sincronizar()
        #expect(iphone.tarea(t.id)?.title == "Mac, después")
        #expect(mac.tarea(t.id)?.title == "Mac, después")
        #expect(servidor.registros[.init(.tarea, t.id)].flatMap { try? ISODate.decodificador().decode(Item.self, from: $0.ficha.json) }?.title == "Mac, después")
    }

    /// Un borrado contra una edición: gana lo último, también cuando lo último
    /// es el borrado. Una lápida es una versión más.
    @Test func aDeleteAgainstAnEdit() async throws {
        let servidor = ServidorDeMentira()
        let mac = Aparato(servidor), iphone = Aparato(servidor)
        let t = mac.store.addItem(title: "Revisar", in: .today)
        try await mac.sincronizar(); try await iphone.sincronizar()

        await respirar()
        iphone.renombrar(t.id, "Revisado")
        await respirar()
        mac.store.delete(mac.tarea(t.id)!)
        try await iphone.sincronizar(); try await mac.sincronizar(); try await iphone.sincronizar()
        #expect(iphone.tarea(t.id) == nil, "el borrado era posterior: se va")
        #expect(iphone.store.borradas.contains { $0.id == t.id }, "y está en la papelera")

        // Devolverla desde la papelera es otra versión, más nueva: vuelve en los dos.
        await respirar()
        iphone.store.restaurar(t.id)
        try await iphone.sincronizar(); try await mac.sincronizar()
        #expect(mac.tarea(t.id) != nil)
    }

    /// Una semana sin red: lo apuntado se queda esperando, y al volver sube lo
    /// suyo y recibe lo de los demás, con la regla de siempre.
    @Test func aWeekOffline() async throws {
        let servidor = ServidorDeMentira()
        let mac = Aparato(servidor), iphone = Aparato(servidor)
        let a = mac.store.addItem(title: "A", in: .today)
        let b = mac.store.addItem(title: "B", in: .today)
        try await mac.sincronizar(); try await iphone.sincronizar()

        iphone.motor.enLinea = false
        await respirar()
        iphone.renombrar(a.id, "A sin red")
        let nueva = iphone.store.addItem(title: "Apuntada sin red", in: .today)
        await respirar()
        mac.renombrar(b.id, "B en el Mac")
        try await mac.sincronizar()
        await #expect(throws: SinRed.self) { try await iphone.sincronizar() }

        iphone.motor.enLinea = true
        try await iphone.sincronizar(); try await mac.sincronizar()
        for aparato in [mac, iphone] {
            #expect(aparato.tarea(a.id)?.title == "A sin red")
            #expect(aparato.tarea(b.id)?.title == "B en el Mac")
            #expect(aparato.tarea(nueva.id)?.title == "Apuntada sin red")
        }
    }

    /// Una lápida caducada: el aparato que la barre la borra del servidor; el
    /// otro, si también la tiene como lápida, barre su archivo.
    @Test func anExpiredTombstone() async throws {
        let servidor = ServidorDeMentira()
        let mac = Aparato(servidor), iphone = Aparato(servidor)
        let t = mac.store.addItem(title: "Vieja", in: .today)
        try await mac.sincronizar(); try await iphone.sincronizar()
        mac.store.delete(mac.tarea(t.id)!)
        try await mac.sincronizar(); try await iphone.sincronizar()
        let clave = Ficha.Clave(.tarea, t.id)
        #expect(Ficha.leer(clave, en: iphone.raiz)?.esLapida == true)

        // Pasa el plazo y el Mac barre.
        let dentroDeUnMes = Date.now.addingTimeInterval(Retention.tombstones + 3600)
        #expect(mac.store.purgeOldTombstones(now: dentroDeUnMes) == 1)
        try await mac.sincronizar()
        #expect(servidor.registros[clave] == nil)

        try await iphone.sincronizar()
        #expect(Ficha.leer(clave, en: iphone.raiz) == nil, "el teléfono barre su lápida también")
    }

    /// Si el servidor borra algo que aquí está **vivo**, no se lo lleva: se vuelve
    /// a subir.
    @Test func aServerDeletionDoesNotTakeALiveOne() async throws {
        let servidor = ServidorDeMentira()
        let mac = Aparato(servidor), iphone = Aparato(servidor)
        let t = mac.store.addItem(title: "Viva", in: .today)
        try await mac.sincronizar(); try await iphone.sincronizar()
        let clave = Ficha.Clave(.tarea, t.id)
        servidor.borrar(clave)
        try await iphone.sincronizar()
        #expect(iphone.tarea(t.id) != nil)
        try await iphone.sincronizar()
        #expect(servidor.registros[clave] != nil, "volvió a subir")
    }

    /// La cuenta. La primera vez sube lo que hay; sin sesión no sube nada y no
    /// se borra nada; con otra cuenta, espera a que se decida.
    @Test func theAccount() async throws {
        let servidor = ServidorDeMentira()
        let mac = Aparato(servidor, cuenta: nil)
        #expect(mac.sincronia.estado == .sinCuenta)
        let t = mac.store.addItem(title: "Antes de iCloud", in: .today)
        try await mac.sincronizar()
        #expect(servidor.registros.isEmpty, "sin cuenta no sube nada")

        // Entra con su cuenta: sube lo que había.
        mac.sincronia.cuenta("yo")
        #expect(mac.sincronia.estado == .activa)
        try await mac.sincronizar()
        #expect(servidor.registros[.init(.tarea, t.id)] != nil)

        // Cierra sesión: se para, y la tarea sigue aquí.
        mac.sincronia.cuenta(nil)
        let mientras = mac.store.addItem(title: "Sin sesión", in: .today)
        try await mac.sincronizar()
        #expect(servidor.registros[.init(.tarea, mientras.id)] == nil)
        #expect(mac.tarea(t.id) != nil)

        // Vuelve con la misma: sube lo que se hizo mientras tanto.
        mac.sincronia.cuenta("yo")
        try await mac.sincronizar()
        #expect(servidor.registros[.init(.tarea, mientras.id)] != nil)

        // Entra con otra: no se mezcla nada hasta decidir.
        let otroServidor = ServidorDeMentira()
        mac.motor.porGuardar = []
        let otroMotor = MotorDeMentira(otroServidor, mac.sincronia)
        mac.sincronia.motor = otroMotor
        mac.sincronia.cuenta("otra")
        #expect(mac.sincronia.estado == .otraCuenta(antes: "yo", ahora: "otra"))
        _ = mac.store.addItem(title: "Con la otra", in: .today)
        try await otroMotor.enviar()
        #expect(otroServidor.registros.isEmpty, "no sube nada sin preguntar")

        mac.sincronia.decidirOtraCuenta(subir: true)
        #expect(mac.sincronia.estado == .activa)
        try await otroMotor.enviar()
        #expect(otroServidor.registros.count == mac.store.items.count)
    }

    /// El estado de la cuenta se recuerda entre arranques, en la carpeta local.
    @Test func theAccountIsRemembered() {
        let carpeta = FileManager.default.temporaryDirectory
            .appendingPathComponent("pauta-estado-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: carpeta) }
        let estado = carpeta.appendingPathComponent("sincronia.json")
        let una = Sincronia(raiz: carpeta, estado: estado)
        una.cuenta("yo")
        let otra = Sincronia(raiz: carpeta, estado: estado)
        otra.cuenta("tu")
        #expect(otra.estado == .otraCuenta(antes: "yo", ahora: "tu"))
    }

    /// Lo que entra por el servidor no se vuelve a subir: no es un cambio de
    /// este aparato.
    @Test func whatComesInIsNotSentBack() async throws {
        let servidor = ServidorDeMentira()
        let mac = Aparato(servidor), iphone = Aparato(servidor)
        _ = mac.store.addItem(title: "Una", in: .today)
        try await mac.sincronizar()
        try await iphone.sincronizar()
        let antes = iphone.motor.subidas
        try await iphone.sincronizar()
        #expect(iphone.motor.subidas == antes)
        #expect(iphone.motor.porGuardar.isEmpty)
    }
}

// MARK: - La mudanza del Mac y la transición

@MainActor
struct MudanzaACloudKitTests {
    private func carpeta(_ nombre: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("pauta-\(nombre)-\(UUID().uuidString)", isDirectory: true)
    }

    /// La carpeta nueva solo si la mudanza se comprobó **y** existe.
    @Test func theRootOnlyMovesWhenItIsThere() throws {
        let antes = carpeta("antes"), nueva = carpeta("nueva")
        defer { [antes, nueva].forEach { try? FileManager.default.removeItem(at: $0) } }
        #expect(MudanzaACloudKit.raiz(mudado: false, nueva: nueva, antes: antes) == antes)
        #expect(MudanzaACloudKit.raiz(mudado: true, nueva: nueva, antes: antes) == antes,
                "mudado pero sin carpeta: se queda en la de antes")
        try FileManager.default.createDirectory(at: nueva, withIntermediateDirectories: true)
        #expect(MudanzaACloudKit.raiz(mudado: true, nueva: nueva, antes: antes) == nueva)
    }

    /// Se lleva todo, cuadra, y repetirla no cambia nada.
    @Test func itMovesEverythingAndCanBeRepeated() throws {
        let antes = carpeta("antes"), nueva = carpeta("nueva")
        defer { [antes, nueva].forEach { try? FileManager.default.removeItem(at: $0) } }
        let store = Store(root: antes)
        let p = store.addProject(name: "Casa")
        _ = store.addItem(title: "Una", in: .today)
        _ = store.addItem(title: "Otra", in: .project(p.id))
        let r = MudanzaACloudKit.mudar(desde: antes, a: nueva, enLocal: { _ in true })
        #expect(r.cuadra)
        #expect(Store(root: nueva).items.count == 2)
        let otra = MudanzaACloudKit.mudar(desde: antes, a: nueva, enLocal: { _ in true })
        #expect(otra.cuadra)
        #expect(otra.balance.llevadas == 0)
    }

    /// El Puente dice qué objetos trajo, por clave.
    @Test func theBridgeSaysWhatItBrought() throws {
        let aqui = carpeta("aqui"), alla = carpeta("alla")
        defer { [aqui, alla].forEach { try? FileManager.default.removeItem(at: $0) } }
        let suyo = Store(root: alla)
        let t = suyo.addItem(title: "Del otro lado", in: .today)
        _ = Store(root: aqui)
        let b = Puente.cruzar(aqui, alla, enLocal: { _ in true })
        #expect(b.claveTraidas == [Ficha.Clave(.tarea, t.id)])
    }

    /// La transición: un iPhone viejo trabaja en la carpeta del contenedor; el
    /// Mac la cruza con su almacén y sube a CloudKit lo que trae. Y lo que llega
    /// de CloudKit acaba en el contenedor para el iPhone viejo.
    @Test func anOldDeviceReachesCloudKitThroughTheMac() async throws {
        let contenedor = carpeta("contenedor")
        defer { try? FileManager.default.removeItem(at: contenedor) }
        let servidor = ServidorDeMentira()
        let mac = Aparato(servidor), otroMac = Aparato(servidor)
        let viejo = Store(root: contenedor)

        // El viejo apunta algo; el Mac cruza y lo sube.
        let t = viejo.addItem(title: "Desde el iPhone viejo", in: .today)
        let b = Puente.cruzar(mac.raiz, contenedor, enLocal: { _ in true })
        for clave in b.claveTraidas { mac.sincronia.escrito(clave) }
        mac.store.reload()
        try await mac.sincronizar()
        try await otroMac.sincronizar()
        #expect(otroMac.tarea(t.id)?.title == "Desde el iPhone viejo")

        // El otro Mac lo cambia por CloudKit; el Mac lo trae y lo cruza al
        // contenedor, donde lo lee el viejo.
        await respirar()
        otroMac.renombrar(t.id, "Cambiada en el otro Mac")
        try await otroMac.sincronizar()
        try await mac.sincronizar()
        _ = Puente.cruzar(mac.raiz, contenedor, enLocal: { _ in true })
        viejo.reload()
        #expect(viejo.items.first { $0.id == t.id }?.title == "Cambiada en el otro Mac")
    }
}
