import Foundation

/// El repaso de la mañana.
///
/// Nada te dice qué quedó sin hacer: hay que abrir la app y, antes, acordarse de
/// abrirla. Ese «acordarse» es justo lo que una app de tareas no puede pedir. El
/// repaso es un aviso a hora fija que lo dice sin que nadie vaya a preguntar.
///
/// No es un aviso de tarea: no lleva una tarea dentro, no se completa y no
/// insiste. Es la invitación a decidir qué entra hoy, que es la decisión que
/// hace que `Hoy` signifique algo.
public enum Repaso {
    /// Lo que hay que contar, ya contado.
    public struct Resumen: Equatable, Sendable {
        public let atrasadas: Int
        public let deHoy: Int
        public let rancias: Int

        public var vacio: Bool { atrasadas == 0 && deHoy == 0 && rancias == 0 }

        /// «2 sin hacer de días pasados · 1 para hoy · 4 paradas desde hace
        /// semanas». En ese orden: primero lo que ya falló, luego lo que toca, y
        /// al final lo que lleva ahí tanto que a lo mejor había que soltarlo.
        public var cuerpo: String {
            var partes: [String] = []
            if atrasadas > 0 {
                partes.append("\(atrasadas) sin hacer de días pasados")
            }
            if deHoy > 0 { partes.append("\(deHoy) para hoy") }
            if rancias > 0 {
                partes.append(rancias == 1 ? "1 parada desde hace semanas"
                                           : "\(rancias) paradas desde hace semanas")
            }
            return partes.joined(separator: " · ")
        }

        public var titulo: String { "Repaso del día" }
    }

    /// Cuenta lo pendiente **para el día del repaso**.
    ///
    /// Para ese día y no para hoy: el aviso se programa la noche antes, y contar
    /// desde el momento de programarlo llamaría «de hoy» a algo que por la
    /// mañana ya será de ayer.
    public static func resumen(_ items: [Item], para dia: Date,
                               calendar: Calendar = .current) -> Resumen {
        let inicio = calendar.startOfDay(for: dia)
        let vivas = items.filter { !$0.isCompleted && $0.deletedAt == nil }
        var atrasadas = 0, deHoy = 0, rancias = 0
        for item in vivas {
            if let cuando = item.when {
                let suyo = calendar.startOfDay(for: cuando)
                if suyo < inicio { atrasadas += 1 } else if suyo == inicio { deHoy += 1 }
            } else if item.estaRancia(now: dia, calendar: calendar) {
                rancias += 1
            }
        }
        return Resumen(atrasadas: atrasadas, deHoy: deHoy, rancias: rancias)
    }

    /// Identificador del aviso. Fijo, para que reprogramar reemplace el de ayer
    /// en vez de acumular uno por día.
    public static let identificador = "repaso"

    /// Las ocho y media: después de levantarse y antes de que el día empiece a
    /// mandar. Se puede cambiar y se puede apagar, porque un repaso a una hora
    /// que no te sirve es un aviso que se aprende a ignorar —y un aviso que se
    /// ignora enseña a ignorar los demás—.
    public static let horaPorDefecto = 8 * 60 + 30

    private static let clave = "repaso.hora"
    /// Lo apagado se guarda como valor propio y no como ausencia: sin
    /// distinguirlos, apagar el repaso duraría hasta el siguiente arranque, que
    /// volvería a leer «no hay nada guardado» y lo daría por encendido.
    private static let apagado = -1

    public static func hora(in defaults: UserDefaults = .standard) -> Int? {
        guard let guardada = defaults.object(forKey: clave) as? Int else {
            return horaPorDefecto
        }
        return guardada == apagado ? nil : guardada
    }

    public static func setHora(_ minutos: Int?, in defaults: UserDefaults = .standard) {
        defaults.set(minutos.map { max(0, min(24 * 60 - 1, $0)) } ?? apagado, forKey: clave)
    }

    /// Cuándo toca el siguiente: hoy si su hora no ha llegado, y mañana si pasó.
    public static func proximo(hora: Int?, after now: Date = .now,
                               calendar: Calendar = .current) -> Date? {
        guard let hora else { return nil }
        guard let hoy = calendar.date(byAdding: .minute, value: hora,
                                      to: calendar.startOfDay(for: now)) else { return nil }
        if hoy > now { return hoy }
        return calendar.date(byAdding: .day, value: 1, to: hoy)
    }
}
