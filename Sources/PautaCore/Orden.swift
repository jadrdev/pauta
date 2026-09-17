import Foundation

/// Lo que el reloj le pide al teléfono.
///
/// Hasta que existió esto el reloj solo recibía: el teléfono le mandaba el
/// `Vistazo` y él lo enseñaba. Lo que va en el otro sentido cambia lo que hay
/// que cuidar — un vistazo que se pierde lo reemplaza el siguiente, pero una
/// orden que se pierde es una tarea que sigue ahí cuando creías haberla quitado,
/// o una que dictaste y no está en ninguna parte.
///
/// Por eso dice **qué hacer** y no «cambia esto»: la entrega puede repetirse
/// —el sistema reintenta cuando los dos vuelven a estar cerca— y un alternar
/// repetido descompletaría justo lo que acabas de tachar. Una orden se puede
/// obedecer dos veces sin consecuencias; un interruptor no.
///
/// Cada caso lleva **lo suyo y nada más**. Antes era una estructura con un campo
/// `tarea` que `refrescar` rellenaba con un identificador cualquiera porque
/// había que poner algo: un campo que a veces no significa nada es un campo que
/// alguien acabará leyendo cuando no debe.
public enum Orden: Codable, Equatable, Sendable {
    /// Marca hecha esa tarea. No alterna: ver `Store.completar(_:)`.
    case completar(UUID)

    /// «Mándame el vistazo otra vez.»
    ///
    /// El reloj no puede saber si lo que tiene sigue valiendo: el contexto de
    /// aplicación lo guarda el sistema y lo último que llegó puede ser de hace
    /// días. Antes solo se refrescaba cuando el teléfono decidía hablar, así que
    /// el reloj se quedaba esperando a que abrieras la app del iPhone.
    case refrescar

    /// «Apunta esto en la bandeja», con lo que se haya dictado.
    ///
    /// El texto viaja **tal cual**, con sus espacios y sus tildes. Quien decide
    /// qué es un título —partir líneas, quitar viñetas, descartar lo vacío— es
    /// el almacén al recibirlo, que es quien ya sabe hacerlo para el campo de
    /// escribir. Limpiarlo aquí sería una segunda opinión sobre lo mismo.
    case apuntar(String)

    /// La llave con la que viaja. En el núcleo y no en cada punta: quien la
    /// manda es el reloj y quien la lee es el teléfono, y dos copias de una
    /// cadena son dos cadenas que un día dejan de coincidir sin que nadie lo
    /// note.
    public static let clave = "orden"

    /// El sobre, tal como lo lleva WatchConnectivity.
    public func carga() -> [String: Any] {
        guard let datos = try? JSONEncoder().encode(self) else { return [:] }
        return [Orden.clave: datos]
    }

    /// Y al abrirlo. `nil` si no se entiende: una orden a medias es peor que
    /// ninguna, porque tacharía la tarea equivocada o apuntaría media frase. Eso
    /// cubre también las de una versión que aún no se conoce — el reloj y el
    /// teléfono se instalan juntos, pero no siempre, y quien se quede atrás
    /// tiene que callarse en vez de adivinar.
    public static func desde(_ carga: [String: Any]) -> Orden? {
        guard let datos = carga[clave] as? Data else { return nil }
        return try? JSONDecoder().decode(Orden.self, from: datos)
    }
}
