import CloudKit
import Foundation

/// **Andamio de la fase 0 del plan de CloudKit** (docs/plan-cloudkit.md). Se
/// quita entero al cerrar la fase.
///
/// Una prueba aparte que no toca las tareas: escribe registros de prueba en una
/// zona propia, `Prueba`, de la base privada del contenedor de la app, y mide
/// lo que el plan necesita saber antes de escribir nada en serio:
///
/// - que el Mac firmado con Developer ID y el iPhone de TestFlight hablan con
///   CloudKit, y en qué entorno;
/// - que el otro aparato lee lo escrito;
/// - que **el aviso silencioso llega**, y cuánto tarda desde que se escribe.
///
/// Cada registro lleva la hora a la que se escribió y quién lo escribió. Al
/// llegar un aviso se lee el último y se apunta el retraso: la diferencia entre
/// relojes de dos aparatos con hora de red es de milisegundos, mucho menos que
/// lo que se mide.
public enum PruebaCloudKit {
    public static let contenedor = "iCloud.dev.jadrdev.pauta"
    static let zona = CKRecordZone.ID(zoneName: "Prueba")
    static let tipo = "Prueba"
    static let suscripcion = "prueba-zona"

    static var base: CKDatabase { CKContainer(identifier: contenedor).privateCloudDatabase }

    /// Un registro de prueba, leído.
    public struct Registro: Sendable {
        public let aparato: String
        public let escrito: Date
        public let llegadoAlServidor: Date?
    }

    /// Un aviso recibido, con lo que traía detrás.
    public struct Aviso: Codable, Sendable {
        public let recibido: Date
        public let ultimoDe: String?
        public let escrito: Date?
        public var retraso: TimeInterval? { escrito.map { recibido.timeIntervalSince($0) } }
    }

    // MARK: - Cuenta

    public static func cuenta() async -> String {
        do {
            switch try await CKContainer(identifier: contenedor).accountStatus() {
            case .available: return "disponible"
            case .noAccount: return "sin cuenta de iCloud"
            case .restricted: return "restringida"
            case .couldNotDetermine: return "no se pudo saber"
            case .temporarilyUnavailable: return "no disponible por ahora"
            @unknown default: return "desconocida"
            }
        } catch {
            return "error: \(describir(error))"
        }
    }

    // MARK: - Zona y suscripción

    /// Crea la zona y la suscripción a sus cambios, con aviso silencioso. Se
    /// puede repetir: si ya están, se sobrescriben.
    public static func preparar() async throws {
        _ = try await base.modifyRecordZones(saving: [CKRecordZone(zoneID: zona)], deleting: [])
        let sub = CKRecordZoneSubscription(zoneID: zona, subscriptionID: suscripcion)
        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true
        sub.notificationInfo = info
        _ = try await base.modifySubscriptions(saving: [sub], deleting: [])
    }

    /// Borra la zona —y con ella todos sus registros— y la suscripción. Lo que
    /// deja la base como estaba antes de la prueba, salvo el tipo `Prueba` en el
    /// esquema, que en producción no se puede quitar.
    public static func borrarTodo() async throws {
        _ = try? await base.modifySubscriptions(saving: [], deleting: [suscripcion])
        _ = try await base.modifyRecordZones(saving: [], deleting: [zona])
    }

    // MARK: - Escribir y leer

    @discardableResult
    public static func escribir(desde aparato: String) async throws -> Date {
        let ahora = Date()
        let registro = CKRecord(recordType: tipo,
                                recordID: CKRecord.ID(recordName: UUID().uuidString, zoneID: zona))
        registro["aparato"] = aparato as CKRecordValue
        registro["escrito"] = ahora as CKRecordValue
        _ = try await base.modifyRecords(saving: [registro], deleting: [])
        return ahora
    }

    /// Todos los registros de la zona, del más reciente al más antiguo.
    public static func leer() async throws -> [Registro] {
        var registros: [Registro] = []
        var desde: CKServerChangeToken?
        var mas = true
        while mas {
            let r = try await base.recordZoneChanges(inZoneWith: zona, since: desde)
            for (_, resultado) in r.modificationResultsByID {
                guard let rec = try? resultado.get().record else { continue }
                registros.append(Registro(
                    aparato: rec["aparato"] as? String ?? "?",
                    escrito: rec["escrito"] as? Date ?? .distantPast,
                    llegadoAlServidor: rec.creationDate))
            }
            desde = r.changeToken
            mas = r.moreComing
        }
        return registros.sorted { $0.escrito > $1.escrito }
    }

    // MARK: - Avisos

    private static let claveAvisos = "pruebaCloudKit.avisos"

    /// Lo que hace un aparato al recibir el aviso silencioso: leer el último
    /// registro y apuntar cuánto tardó.
    @discardableResult
    public static func alRecibirAviso(_ momento: Date = Date()) async -> Aviso {
        let ultimo = try? await leer().first
        let aviso = Aviso(recibido: momento, ultimoDe: ultimo?.aparato, escrito: ultimo?.escrito)
        var todos = avisos
        todos.insert(aviso, at: 0)
        if let datos = try? JSONEncoder().encode(Array(todos.prefix(50))) {
            UserDefaults.standard.set(datos, forKey: claveAvisos)
        }
        return aviso
    }

    public static var avisos: [Aviso] {
        guard let datos = UserDefaults.standard.data(forKey: claveAvisos) else { return [] }
        return (try? JSONDecoder().decode([Aviso].self, from: datos)) ?? []
    }

    public static func olvidarAvisos() {
        UserDefaults.standard.removeObject(forKey: claveAvisos)
    }

    /// Si un aviso remoto es de la suscripción de la prueba.
    public static func esDeLaPrueba(_ userInfo: [AnyHashable: Any]) -> Bool {
        CKNotification(fromRemoteNotificationDictionary: userInfo)?.subscriptionID == suscripcion
    }

    public static func describir(_ error: Error) -> String {
        if let ck = error as? CKError {
            return "CKError \(ck.code.rawValue) (\(ck.code)): \(ck.localizedDescription)"
        }
        return error.localizedDescription
    }
}
