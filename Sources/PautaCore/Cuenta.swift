import Foundation

/// Cuánto falta para lo siguiente.
///
/// Un aviso puntual no arregla la ceguera temporal: llega, se oye, y entre
/// medias no hay forma de saber cuánto queda sin abrir algo y mirarlo. Esto es
/// lo que permite tener el dato a la vista —en la barra de menús— sin abrir la
/// app y sin tener que preguntar.
///
/// Cuenta **solo tareas**. Los eventos del calendario ya los avisa el sistema, y
/// contarlos aquí también sería avisar dos veces de lo mismo.
public enum Cuenta {
    /// Desde cuándo merece la pena decirlo en voz alta.
    ///
    /// Sin ventana, la barra de menús llevaría un rótulo puesto todo el día
    /// —«en 9 h»—, que es ruido: se deja de leer, y entonces tampoco avisa
    /// cuando falta un cuarto de hora. Avisa cuando falta poco y por lo demás se
    /// calla.
    public static let ventana: TimeInterval = 60 * 60

    /// Lo siguiente que toca: la tarea con hora más próxima que aún no ha
    /// pasado, y cuándo.
    ///
    /// Lo atrasado cuenta si su hora aún no ha llegado hoy: sigue pendiente y va
    /// a sonar. Lo aparcado en «Algún día» no, porque aparcarlo fue decir que no
    /// toca.
    public static func proxima(_ items: [Item], now: Date = .now,
                               calendar: Calendar = .current) -> (item: Item, cuando: Date)? {
        items
            .filter { !$0.isCompleted && $0.deletedAt == nil && !$0.isSomeday }
            .compactMap { item -> (item: Item, cuando: Date)? in
                guard let cuando = item.nextOccurrence(after: now, calendar: calendar)
                else { return nil }
                return (item, cuando)
            }
            // Desempate por título para que dos tareas a la misma hora no se
            // turnen en el rótulo cada vez que pasa el minuto.
            .min { $0.cuando == $1.cuando ? $0.item.title < $1.item.title
                                          : $0.cuando < $1.cuando }
    }

    /// Lo siguiente, pero solo si ya entra en la ventana.
    public static func inminente(_ items: [Item], now: Date = .now,
                                 calendar: Calendar = .current) -> (item: Item, cuando: Date)? {
        guard let proxima = proxima(items, now: now, calendar: calendar),
              proxima.cuando.timeIntervalSince(now) <= ventana
        else { return nil }
        return proxima
    }

    /// «En 20 min», «En 1 h 5 min», «Ahora».
    ///
    /// A mano y no con un formateador relativo, que diría «dentro de 20 minutos»
    /// —demasiado largo para la barra de menús— y redondea a la baja, dejando
    /// «en 0 minutos» treinta segundos antes.
    public static func restante(_ cuando: Date, now: Date = .now) -> String {
        let segundos = cuando.timeIntervalSince(now)
        guard segundos > 0 else { return "Ahora" }
        // Hacia arriba: faltando treinta segundos, «en 1 min» se entiende y «en
        // 0 min» no dice nada.
        let minutos = Int((segundos / 60).rounded(.up))
        if minutos < 60 { return "En \(minutos) min" }
        let horas = minutos / 60
        let resto = minutos % 60
        return resto == 0 ? "En \(horas) h" : "En \(horas) h \(resto) min"
    }
}
