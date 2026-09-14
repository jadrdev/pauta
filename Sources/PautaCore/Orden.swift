import Foundation

/// Lo que el reloj le pide al teléfono.
///
/// Hasta aquí el reloj solo recibía: el teléfono le mandaba el `Vistazo` y él
/// lo enseñaba. Tachar es lo primero que va en el otro sentido, y eso cambia lo
/// que hay que cuidar — un vistazo que se pierde se reemplaza por el siguiente,
/// pero una orden que se pierde es una tarea que sigue ahí cuando creías
/// haberla quitado.
///
/// Por eso dice **qué hacer** y no «cambia esto»: la entrega puede repetirse
/// —el sistema reintenta cuando los dos vuelven a estar cerca— y un alternar
/// repetido descompletaría justo lo que acabas de tachar. Una orden se puede
/// obedecer dos veces sin consecuencias; un interruptor no.
public struct Orden: Codable, Equatable, Sendable {
    public enum Que: String, Codable, Sendable {
        case completar
        /// «Mándame el vistazo otra vez.»
        ///
        /// El reloj no puede saber si lo que tiene sigue valiendo: el contexto
        /// de aplicación lo guarda el sistema y lo último que llegó puede ser de
        /// hace días. Antes solo se refrescaba cuando el teléfono decidía
        /// hablar, así que el reloj se quedaba esperando a que abrieras la app
        /// del iPhone. Ahora lo pide él al abrirse.
        case refrescar
    }

    public let que: Que
    /// De qué tarea habla. En `refrescar` no habla de ninguna y va un
    /// identificador cualquiera: el sobre es uno solo, y darle una forma
    /// distinta a cada orden es dos formatos que un día dejan de coincidir.
    public let tarea: UUID

    public init(que: Que, tarea: UUID) {
        self.que = que
        self.tarea = tarea
    }

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
    /// ninguna, porque tacharía la tarea equivocada.
    public static func desde(_ carga: [String: Any]) -> Orden? {
        guard let datos = carga[clave] as? Data else { return nil }
        return try? JSONDecoder().decode(Orden.self, from: datos)
    }
}
