import CloudKit
import Foundation

/// Un objeto tal como viaja: tarea, proyecto o área, **con su JSON entero
/// dentro** (docs/plan-cloudkit.md, «Registros»).
///
/// El esquema de CloudKit en producción solo crece: un campo no se puede quitar
/// ni cambiar de tipo. Con un campo por propiedad, cada cambio del modelo sería
/// un cambio de esquema para siempre; con el JSON dentro, el modelo sigue
/// evolucionando como hoy y el esquema no se toca. Al lado van las dos fechas
/// que deciden: la de la última modificación y la del borrado.
///
/// Es lo mismo que hay en cada archivo de la carpeta, y por eso la ficha se lee
/// y se escribe **en la carpeta**: lo que llega del servidor entra en el
/// almacén por el mismo camino que lo que trae un cruce.
public struct Ficha: Equatable, Sendable {
    public let clave: Clave
    public let json: Data
    public let updatedAt: Date
    public let deletedAt: Date?

    /// Qué objeto es: su tipo y su identificador.
    public struct Clave: Hashable, Codable, Sendable, CustomStringConvertible {
        public let tipo: Tipo
        public let id: UUID

        public init(_ tipo: Tipo, _ id: UUID) {
            self.tipo = tipo
            self.id = id
        }

        public var description: String { "\(tipo.rawValue)/\(id.uuidString)" }
    }

    /// Los tres tipos de objeto, con la carpeta donde vive cada uno y el tipo de
    /// registro que le corresponde en CloudKit.
    public enum Tipo: String, Codable, CaseIterable, Sendable {
        case tarea = "Item"
        case proyecto = "Project"
        case area = "Area"

        public var carpeta: String {
            switch self {
            case .tarea: "items"
            case .proyecto: "projects"
            case .area: "areas"
            }
        }

        init?(carpeta: String) {
            guard let tipo = Tipo.allCases.first(where: { $0.carpeta == carpeta }) else { return nil }
            self = tipo
        }
    }

    public init(clave: Clave, json: Data, updatedAt: Date, deletedAt: Date?) {
        self.clave = clave
        self.json = json
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }

    /// Solo hace falta saber las dos fechas: no se decodifica el objeto entero.
    private struct Fechas: Decodable {
        let updatedAt: Date
        let deletedAt: Date?
    }

    /// Una ficha desde el JSON de un objeto. `nil` si no se entiende: lo
    /// ilegible no viaja, porque no podría ganar a nada sin arriesgar datos.
    public init?(clave: Clave, json: Data) {
        guard !json.isEmpty,
              let fechas = try? ISODate.decodificador().decode(Fechas.self, from: json)
        else { return nil }
        self.init(clave: clave, json: json, updatedAt: fechas.updatedAt, deletedAt: fechas.deletedAt)
    }

    public var esLapida: Bool { deletedAt != nil }

    // MARK: - En la carpeta

    public static func archivo(_ clave: Clave, en raiz: URL) -> URL {
        raiz.appendingPathComponent(clave.tipo.carpeta, isDirectory: true)
            .appendingPathComponent("\(clave.id.uuidString).json")
    }

    /// La ficha de un objeto según está en la carpeta, o `nil` si no está o no
    /// se entiende.
    public static func leer(_ clave: Clave, en raiz: URL) -> Ficha? {
        guard let datos = try? Data(contentsOf: archivo(clave, en: raiz)) else { return nil }
        return Ficha(clave: clave, json: datos)
    }

    /// La escribe en la carpeta **si gana**: si no hay nada, si lo que hay no se
    /// entiende, o si la de aquí es más reciente. Es la regla del Puente, la
    /// misma de siempre. Devuelve si escribió.
    @discardableResult
    public func escribir(en raiz: URL) -> Bool {
        if let actual = Ficha.leer(clave, en: raiz), actual.updatedAt >= updatedAt { return false }
        let destino = Ficha.archivo(clave, en: raiz)
        try? FileManager.default.createDirectory(at: destino.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        return (try? json.write(to: destino, options: .atomic)) != nil
    }

    // MARK: - En CloudKit

    /// La zona propia de Pauta en la base privada.
    public static let zona = CKRecordZone.ID(zoneName: "Pauta")

    /// A partir de cuánto el JSON va como fichero (`CKAsset`) y no dentro del
    /// registro. Un registro admite 1 MB en total; se deja margen.
    public static let limiteEnElRegistro = 700 * 1024

    public var recordID: CKRecord.ID {
        CKRecord.ID(recordName: clave.id.uuidString, zoneID: Ficha.zona)
    }

    /// La ficha en un registro. Si se le pasa el registro que ya se conoce del
    /// servidor, se escribe **sobre él**: así va con su etiqueta de versión, y el
    /// servidor sabe si alguien lo cambió entretanto.
    ///
    /// `temporal` es la carpeta donde dejar el fichero si el JSON es grande;
    /// CloudKit lo sube desde ahí.
    public func registro(sobre conocido: CKRecord? = nil,
                         temporal: URL = FileManager.default.temporaryDirectory) -> CKRecord {
        let r = conocido ?? CKRecord(recordType: clave.tipo.rawValue, recordID: recordID)
        if json.count > Ficha.limiteEnElRegistro {
            let fichero = temporal.appendingPathComponent("pauta-\(clave.id.uuidString).json")
            try? json.write(to: fichero, options: .atomic)
            r["jsonAsset"] = CKAsset(fileURL: fichero)
            r["json"] = nil
        } else {
            r["json"] = json as CKRecordValue
            r["jsonAsset"] = nil
        }
        r["updatedAt"] = updatedAt as CKRecordValue
        r["deletedAt"] = deletedAt.map { $0 as CKRecordValue }
        return r
    }

    /// Y al revés. `nil` si el registro no es de un tipo conocido o no se
    /// entiende —un registro de una versión futura con otra forma, por
    /// ejemplo—.
    public init?(registro r: CKRecord) {
        guard let tipo = Tipo(rawValue: r.recordType),
              let id = UUID(uuidString: r.recordID.recordName) else { return nil }
        let datos: Data?
        if let enLinea = r["json"] as? Data {
            datos = enLinea
        } else if let fichero = (r["jsonAsset"] as? CKAsset)?.fileURL {
            datos = try? Data(contentsOf: fichero)
        } else {
            datos = nil
        }
        guard let datos else { return nil }
        self.init(clave: Clave(tipo, id), json: datos)
    }
}
