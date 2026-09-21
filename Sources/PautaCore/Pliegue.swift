import Foundation
import Observation

/// Qué grupos de `Hoy` has cerrado, y hasta cuándo se recuerda.
///
/// Un proyecto con diez tareas se come la lista. Cerrarlo devuelve la vista del
/// día sin renunciar a nada: la cabecera se queda, y como el rótulo dice **lo
/// que queda** —«QUEDAN 2 · 45 MIN»— un grupo cerrado sigue informando. Ese es
/// el pago de haber elegido lo que falta en vez de lo que llevas hecho: «3 de 5»
/// plegado no diría nada útil.
///
/// **Se olvida al cambiar el día.** Lo que cerraste ayer hablaba de las tareas
/// de ayer; `Hoy` se rehace cada mañana y dejarlo cerrado escondería trabajo
/// nuevo detrás de una decisión que ya no era sobre esto. Un bloque escondido es
/// estado invisible, que es justo lo que esta app no se permite.
///
/// Va en `UserDefaults` y no en la carpeta: es cómo tienes puesta la ventana en
/// **este** Mac, no algo que deba viajar con las tareas.
@Observable
@MainActor
public final class Pliegue {
    public static var shared = Pliegue()

    /// De usar y tirar, para la maqueta y las pruebas.
    public static func paraMaqueta() -> Pliegue {
        let nombre = "dev.jadrdev.pauta.maqueta.pliegue"
        let d = UserDefaults(suiteName: nombre)!
        d.removePersistentDomain(forName: nombre)
        return Pliegue(defaults: d)
    }

    @ObservationIgnored private let defaults: UserDefaults
    private var cerrados: Set<UUID>
    private var dia: Date

    private enum Clave: String {
        case cerrados = "pliegueCerrados"
        case dia = "pliegueDia"
    }

    public init(defaults: UserDefaults = .standard, ahora: Date = .now) {
        self.defaults = defaults
        dia = defaults.object(forKey: Clave.dia.rawValue) as? Date ?? .distantPast
        cerrados = Set((defaults.stringArray(forKey: Clave.cerrados.rawValue) ?? [])
                       .compactMap(UUID.init(uuidString:)))
        caducar(ahora)
    }

    public func estaCerrado(_ proyecto: UUID, ahora: Date = .now) -> Bool {
        caducar(ahora)
        return cerrados.contains(proyecto)
    }

    public func alternar(_ proyecto: UUID, ahora: Date = .now) {
        caducar(ahora)
        if cerrados.remove(proyecto) == nil { cerrados.insert(proyecto) }
        dia = Calendar.current.startOfDay(for: ahora)
        guardar()
    }

    /// Si el día guardado no es el de ahora, se abre todo — y se escribe, que si
    /// solo se olvidara en memoria volvería cerrado al reabrir la app.
    private func caducar(_ ahora: Date) {
        guard !Calendar.current.isDate(dia, inSameDayAs: ahora) else { return }
        dia = Calendar.current.startOfDay(for: ahora)
        guard !cerrados.isEmpty else { return }
        cerrados = []
        guardar()
    }

    private func guardar() {
        defaults.set(cerrados.map(\.uuidString), forKey: Clave.cerrados.rawValue)
        defaults.set(dia, forKey: Clave.dia.rawValue)
    }
}
