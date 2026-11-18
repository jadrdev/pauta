import CloudKit
import Foundation

/// El motor de verdad: `CKSyncEngine` sobre la zona `Pauta` de la base privada
/// del contenedor de la app (docs/plan-cloudkit.md).
///
/// Es solo el adaptador. Lo que se sube, lo que gana y lo que se borra lo
/// decide `Sincronia`, que es lo que está probado sin red; aquí se traduce
/// entre sus fichas y los registros y eventos de CloudKit.
///
/// Dos cosas que guarda por su cuenta, **en local y por aparato**:
///
/// - El estado del motor (`CKSyncEngine.State.Serialization`): por dónde va y
///   qué falta por subir. Sobrevive a cerrar la app con cambios pendientes.
/// - Los campos de sistema del último registro conocido de cada objeto. Subir
///   sobre ellos es lo que le dice al servidor qué versión se vio; subir sin
///   ellos haría que cada cambio pareciera un conflicto.
@MainActor
public final class MotorCloudKit: MotorDeSincronia, CKSyncEngineDelegate {
    public static let contenedor = "iCloud.dev.jadrdev.pauta"

    private let sincronia: Sincronia
    private let carpeta: URL
    private var motor: CKSyncEngine!
    private var conocidos: [String: Data] = [:]

    /// - Parameters:
    ///   - carpeta: una carpeta **local** que no se sincroniza, para el estado.
    public init(sincronia: Sincronia, carpeta: URL) {
        self.sincronia = sincronia
        self.carpeta = carpeta
        try? FileManager.default.createDirectory(at: carpeta, withIntermediateDirectories: true)
        conocidos = (try? Data(contentsOf: archivoDeConocidos))
            .flatMap { try? PropertyListDecoder().decode([String: Data].self, from: $0) } ?? [:]
        let estado = (try? Data(contentsOf: archivoDeEstado))
            .flatMap { try? JSONDecoder().decode(CKSyncEngine.State.Serialization.self, from: $0) }
        let base = CKContainer(identifier: MotorCloudKit.contenedor).privateCloudDatabase
        var configuracion = CKSyncEngine.Configuration(database: base, stateSerialization: estado,
                                                       delegate: self)
        configuracion.automaticallySync = true
        motor = CKSyncEngine(configuracion)
        sincronia.motor = self
        // La zona se crea si no está; si ya está, no pasa nada.
        motor.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: Ficha.zona))])
    }

    private var archivoDeEstado: URL { carpeta.appendingPathComponent("motor.json") }
    private var archivoDeConocidos: URL { carpeta.appendingPathComponent("conocidos.plist") }

    /// La cuenta de este aparato al arrancar. Los cambios de después llegan
    /// como evento.
    public func comprobarCuenta() async {
        let contenedor = CKContainer(identifier: MotorCloudKit.contenedor)
        guard (try? await contenedor.accountStatus()) == .available,
              let usuario = try? await contenedor.userRecordID() else {
            sincronia.cuenta(nil)
            return
        }
        sincronia.cuenta(usuario.recordName)
    }

    // MARK: - MotorDeSincronia

    public func apuntar(guardar: [Ficha.Clave], borrar: [Ficha.Clave]) {
        let cambios = guardar.map { CKSyncEngine.PendingRecordZoneChange.saveRecord(id($0)) }
            + borrar.map { CKSyncEngine.PendingRecordZoneChange.deleteRecord(id($0)) }
        guard !cambios.isEmpty else { return }
        motor.state.add(pendingRecordZoneChanges: cambios)
        enviarPronto()
    }

    /// Sube en cuanto se calma la ráfaga, sin esperar a que el motor lo decida.
    ///
    /// Solo, `CKSyncEngine` agrupa y sube cuando le parece: medido el 18 de
    /// noviembre, entre 1,5 y 6 segundos después de tachar en el Mac, y eso
    /// era más de la mitad de lo que tardaba en verse en el iPhone. Medio
    /// segundo basta para que un título escrito tecla a tecla salga de una vez.
    private var pendiente: Task<Void, Never>?
    private func enviarPronto() {
        pendiente?.cancel()
        pendiente = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            try? await self?.enviar()
        }
    }

    /// Con prioridad de algo que alguien está esperando. Sin grupo, el motor
    /// pide a prioridad de fondo, y el sistema puede dejar la petición en
    /// espera: medido, cinco segundos entre saber que había cambios y pedirlos.
    private static func grupo(_ nombre: String) -> CKOperationGroup {
        let grupo = CKOperationGroup()
        grupo.name = nombre
        grupo.defaultConfiguration.qualityOfService = .userInitiated
        return grupo
    }

    public func enviar() async throws {
        try await motor.sendChanges(CKSyncEngine.SendChangesOptions(
            scope: .all, operationGroup: Self.grupo("Pauta: subir")))
    }

    public func traer() async throws {
        try await motor.fetchChanges(CKSyncEngine.FetchChangesOptions(
            scope: .all, operationGroup: Self.grupo("Pauta: traer")))
    }

    private func id(_ clave: Ficha.Clave) -> CKRecord.ID {
        CKRecord.ID(recordName: clave.id.uuidString, zoneID: Ficha.zona)
    }

    /// La clave de un registro que solo se conoce por su identificador: el tipo
    /// sale de la carpeta donde está el archivo. Los identificadores son UUID,
    /// así que no se repiten entre tipos.
    private func clave(de id: CKRecord.ID) -> Ficha.Clave? {
        guard let uuid = UUID(uuidString: id.recordName) else { return nil }
        return Ficha.Tipo.allCases.map { Ficha.Clave($0, uuid) }.first {
            FileManager.default.fileExists(atPath: Ficha.archivo($0, en: sincronia.raiz).path)
        }
    }

    // MARK: - Lo conocido

    private func conocido(_ id: CKRecord.ID) -> CKRecord? {
        guard let datos = conocidos[id.recordName],
              let lector = try? NSKeyedUnarchiver(forReadingFrom: datos) else { return nil }
        lector.requiresSecureCoding = true
        return CKRecord(coder: lector)
    }

    private func recordar(_ registro: CKRecord) {
        let escritor = NSKeyedArchiver(requiringSecureCoding: true)
        registro.encodeSystemFields(with: escritor)
        escritor.finishEncoding()
        conocidos[registro.recordID.recordName] = escritor.encodedData
    }

    private func olvidar(_ id: CKRecord.ID) { conocidos[id.recordName] = nil }

    private func guardarConocidos() {
        guard let datos = try? PropertyListEncoder().encode(conocidos) else { return }
        try? datos.write(to: archivoDeConocidos, options: .atomic)
    }

    // MARK: - CKSyncEngineDelegate

    public func handleEvent(_ evento: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        switch evento {
        case .stateUpdate(let e):
            if let datos = try? JSONEncoder().encode(e.stateSerialization) {
                try? datos.write(to: archivoDeEstado, options: .atomic)
            }

        case .accountChange(let e):
            switch e.changeType {
            case .signIn(let usuario):
                sincronia.cuenta(usuario.recordName)
            case .signOut:
                sincronia.cuenta(nil)
            case .switchAccounts(_, let actual):
                // Lo conocido era de la otra cuenta: no sirve para esta.
                conocidos = [:]
                guardarConocidos()
                sincronia.cuenta(actual.recordName)
            @unknown default:
                break
            }

        case .fetchedRecordZoneChanges(let e):
            var fichas: [Ficha] = []
            for cambio in e.modifications {
                recordar(cambio.record)
                if let ficha = Ficha(registro: cambio.record) { fichas.append(ficha) }
            }
            var borradas: [Ficha.Clave] = []
            for borrado in e.deletions {
                olvidar(borrado.recordID)
                if let tipo = Ficha.Tipo(rawValue: borrado.recordType),
                   let uuid = UUID(uuidString: borrado.recordID.recordName) {
                    borradas.append(Ficha.Clave(tipo, uuid))
                }
            }
            guardarConocidos()
            sincronia.recibidas(fichas)
            sincronia.borradasEnServidor(borradas)

        case .sentRecordZoneChanges(let e):
            for registro in e.savedRecords { recordar(registro) }
            for id in e.deletedRecordIDs { olvidar(id) }
            var reintentar: [CKSyncEngine.PendingRecordZoneChange] = []
            for fallo in e.failedRecordSaves {
                let id = fallo.record.recordID
                switch fallo.error.code {
                case .serverRecordChanged:
                    // Otro aparato subió antes: la regla de siempre.
                    guard let suyo = fallo.error.serverRecord else { break }
                    recordar(suyo)
                    if let clave = clave(de: id), let ficha = Ficha(registro: suyo),
                       sincronia.conflicto(clave, servidor: ficha) == .subirLaMia {
                        reintentar.append(.saveRecord(id))
                    }
                case .zoneNotFound:
                    syncEngine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: Ficha.zona))])
                    reintentar.append(.saveRecord(id))
                case .unknownItem:
                    // Lo conocido ya no está en el servidor: se sube como nuevo.
                    olvidar(id)
                    reintentar.append(.saveRecord(id))
                default:
                    // Red, cuota, límites: el propio motor reintenta lo que tiene
                    // sentido reintentar.
                    break
                }
            }
            guardarConocidos()
            if !reintentar.isEmpty { syncEngine.state.add(pendingRecordZoneChanges: reintentar) }

        case .fetchedDatabaseChanges(let e):
            // Si la zona entera desaparece —se borraron los datos de iCloud de
            // la app desde Ajustes—, lo conocido no vale y hay que volver a
            // subir lo de este aparato.
            if e.deletions.contains(where: { $0.zoneID == Ficha.zona }) {
                conocidos = [:]
                guardarConocidos()
                syncEngine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: Ficha.zona))])
                sincronia.subirTodo()
            }

        default:
            break
        }
    }

    public func nextRecordZoneChangeBatch(_ contexto: CKSyncEngine.SendChangesContext,
                                          syncEngine: CKSyncEngine) async -> CKSyncEngine.RecordZoneChangeBatch? {
        guard sincronia.puedeSubir else { return nil }
        let pendientes = syncEngine.state.pendingRecordZoneChanges.filter { contexto.options.scope.contains($0) }
        guard !pendientes.isEmpty else { return nil }
        let temporal = carpeta.appendingPathComponent("subiendo", isDirectory: true)
        try? FileManager.default.createDirectory(at: temporal, withIntermediateDirectories: true)
        return await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: pendientes) { id in
            await MainActor.run {
                guard let clave = self.clave(de: id), let ficha = self.sincronia.fichaParaSubir(clave) else {
                    // Ya no está: no hay nada que subir. Se quita de la cola.
                    syncEngine.state.remove(pendingRecordZoneChanges: [.saveRecord(id)])
                    return nil
                }
                return ficha.registro(sobre: self.conocido(id), temporal: temporal)
            }
        }
    }
}
