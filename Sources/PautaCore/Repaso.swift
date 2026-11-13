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
        /// Las rancias con nombre, de la más antigua a la más nueva. Contarlas
        /// sin decir cuáles era un acertijo: con una sola, nadie sabía a cuál
        /// se refería el aviso.
        public let paradas: [Parada]

        public struct Parada: Equatable, Sendable {
            public let titulo: String
            public let dias: Int
        }

        public var vacio: Bool { atrasadas == 0 && deHoy == 0 && rancias == 0 }

        /// «2 sin hacer de días pasados · 1 para hoy · 4 sin fecha desde hace
        /// semanas». En ese orden: primero lo que ya falló, luego lo que toca, y
        /// al final lo que lleva ahí tanto que a lo mejor había que soltarlo.
        ///
        /// Lo último dice «sin fecha» y no «parada»: «parada desde hace
        /// semanas» se leía como un retraso, y lo que tiene fecha y se pasó ya
        /// es la primera parte. Y con una o dos **se nombran**, porque la
        /// pregunta que deja el aviso es cuál.
        public var cuerpo: String {
            var partes: [String] = []
            if atrasadas > 0 {
                partes.append(String(localized: "\(atrasadas) sin hacer de días pasados",
                                             comment: "Repaso de la mañana: tareas con fecha de días anteriores"))
            }
            if deHoy > 0 {
                partes.append(String(localized: "\(deHoy) para hoy",
                                     comment: "Repaso de la mañana: tareas que tocan hoy"))
            }
            switch paradas.count {
            case 0:
                break
            case 1:
                let una = paradas[0]
                let titulo = Resumen.corto(una.titulo)
                let tiempo = Resumen.tiempo(una.dias)
                partes.append(String(localized: "«\(titulo)» lleva \(tiempo) sin fecha",
                                     comment: "Repaso de la mañana: una tarea sin fecha desde hace tiempo; el segundo hueco es «4 semanas», «2 meses»"))
            case 2:
                let una = Resumen.corto(paradas[0].titulo)
                let otra = Resumen.corto(paradas[1].titulo)
                partes.append(String(localized: "«\(una)» y «\(otra)» llevan semanas sin fecha",
                                     comment: "Repaso de la mañana: dos tareas sin fecha desde hace semanas"))
            default:
                partes.append(String(localized: "\(rancias) sin fecha desde hace semanas",
                                     comment: "Repaso de la mañana: tres o más tareas sin fecha desde hace semanas"))
            }
            return partes.joined(separator: " · ")
        }

        /// Un título entero puede ser una frase larga, y el aviso se corta
        /// solo por donde quiere.
        static func corto(_ titulo: String) -> String {
            titulo.count <= 40 ? titulo : String(titulo.prefix(39)) + "…"
        }

        /// «4 semanas», «2 meses». En palabras y no «4 sem»: esto se lee en la
        /// pantalla bloqueada, no en una fila apretada.
        static func tiempo(_ dias: Int) -> String {
            if dias < 63 {
                let semanas = dias / 7
                return semanas == 1 ? String(localized: "1 semana", comment: "Repaso de la mañana: tiempo sin fecha")
                                 : String(localized: "\(semanas) semanas", comment: "Repaso de la mañana: tiempo sin fecha")
            }
            let meses = dias / 30
            return String(localized: "\(meses) meses", comment: "Repaso de la mañana: tiempo sin fecha")
        }

        public var titulo: String { String(localized: "Repaso del día", comment: "Título del aviso del repaso de la mañana") }
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
        var atrasadas = 0, deHoy = 0
        var paradas: [Resumen.Parada] = []
        for item in vivas {
            if let cuando = item.when {
                let suyo = calendar.startOfDay(for: cuando)
                if suyo < inicio { atrasadas += 1 } else if suyo == inicio { deHoy += 1 }
            } else if item.estaRancia(now: dia, calendar: calendar),
                      let dias = item.staleDays(now: dia, calendar: calendar) {
                paradas.append(.init(titulo: item.title, dias: dias))
            }
        }
        paradas.sort { $0.dias != $1.dias ? $0.dias > $1.dias : $0.titulo < $1.titulo }
        return Resumen(atrasadas: atrasadas, deHoy: deHoy, rancias: paradas.count,
                       paradas: paradas)
    }

    /// Identificador del aviso. Fijo, para que reprogramar reemplace el de ayer
    /// en vez de acumular uno por día.
    public static let identificador = "repaso"

    /// Las ocho y media: después de levantarse y antes de que el día empiece a
    /// mandar. La hora y el apagado viven en `Ajustes`, que es donde el usuario
    /// los cambia; aquí solo se leen.
    @MainActor public static var hora: Int? { Ajustes.shared.repasoHora }

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
