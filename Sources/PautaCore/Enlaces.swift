import Foundation

/// Los enlaces de la app.
///
/// En el núcleo y no en cada interfaz: son los mismos en el Mac y en el
/// teléfono, y dos copias de una dirección es una dirección que un día apunta a
/// dos sitios distintos.
public enum Enlaces {
    public static let repositorio = URL(string: "https://github.com/jadrdev/pauta")!
    public static let autor = URL(string: "https://github.com/jadrdev")!
    public static let guia = URL(string: "https://github.com/jadrdev/pauta#readme")!
    public static let novedades = URL(string: "https://github.com/jadrdev/pauta/releases")!
    public static let problemas = URL(string: "https://github.com/jadrdev/pauta/issues")!

    // MARK: - Enlaces de dentro

    /// El esquema propio de la app. Lo usa el widget para abrirla donde toca:
    /// una extensión no puede llamar a la app: solo pedirle al sistema que la
    /// abra en una dirección.
    public static let esquema = "pauta"

    /// Los sitios a los que se puede llegar desde fuera.
    ///
    /// Pocos y concretos, y **no** una dirección por pantalla: cada uno de
    /// estos es algo que alguien quiere hacer al mirar el teléfono —ver el día,
    /// vaciar lo que hay sin decidir, apuntar algo antes de que se olvide, o
    /// abrir esa tarea de ahí—.
    public enum Destino: Equatable, Sendable {
        case hoy
        case bandeja
        case apuntar
        case tarea(UUID)
    }

    /// La dirección de un destino. Se construye aquí y no en el widget para que
    /// las dos puntas —quien la escribe y quien la lee— salgan del mismo sitio.
    public static func url(_ destino: Destino) -> URL {
        switch destino {
        case .hoy: URL(string: "\(esquema)://hoy")!
        case .bandeja: URL(string: "\(esquema)://bandeja")!
        case .apuntar: URL(string: "\(esquema)://apuntar")!
        case .tarea(let id): URL(string: "\(esquema)://tarea/\(id.uuidString)")!
        }
    }

    /// Y al revés. Devuelve `nil` para cualquier cosa que no reconozca: abrir
    /// la app en una pantalla cualquiera porque llegó una dirección rara es
    /// peor que no hacer nada.
    public static func destino(_ url: URL) -> Destino? {
        guard url.scheme == esquema else { return nil }
        // El «host» es la primera parte: en `pauta://tarea/UUID`, `tarea`.
        switch url.host {
        case "hoy": return .hoy
        case "bandeja": return .bandeja
        case "apuntar": return .apuntar
        case "tarea":
            let resto = url.pathComponents.filter { $0 != "/" }
            guard let texto = resto.first, let id = UUID(uuidString: texto) else { return nil }
            return .tarea(id)
        default: return nil
        }
    }
}
