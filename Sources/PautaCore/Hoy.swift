import Foundation

/// Una fila del tramo sin hora de Hoy: una tarea suelta, o un proyecto con
/// varias colgando.
///
/// El tramo con hora no se agrupa nunca. Ahí el criterio es el reloj —qué va
/// antes— y meter proyectos dentro rompería lo único para lo que sirve.
public enum BloqueDeHoy: Identifiable, Hashable {
    case suelta(Item)
    case proyecto(GrupoDeProyecto)

    public var id: String {
        switch self {
        case .suelta(let item): "t:\(item.id.uuidString)"
        case .proyecto(let grupo): "p:\(grupo.proyecto.uuidString)"
        }
    }
}

/// Las tareas que hoy tocan de un mismo proyecto, con su contador.
///
/// El contador mide **lo de hoy**, no el proyecto entero. Un proyecto de
/// cuarenta tareas no se mueve en toda la mañana: haces tres y el trozo crece un
/// grado, que no informa de nada. Sobre lo de hoy sí avanza, y se cierra entero
/// cuando has hecho lo que te tocaba — que es lo que se venía a ver.
public struct GrupoDeProyecto: Identifiable, Hashable {
    public let proyecto: UUID
    /// Lo pendiente primero, en su orden manual, y debajo lo ya tachado hoy.
    public let tareas: [Item]

    public var id: UUID { proyecto }
    public var hechas: Int { tareas.filter(\.isCompleted).count }
    public var total: Int { tareas.count }
    public var entero: Bool { total > 0 && hechas == total }

    /// Lo que falta, que es con lo que se decide si te pones ahora.
    public var quedan: Int { total - hechas }

    /// Cuánto queda en minutos, sumando lo que hayas estimado.
    ///
    /// `nil` cuando no has estimado ninguna de las que faltan. Es un extra, no
    /// un requisito: el número de tareas está siempre, así que un proyecto sin
    /// estimaciones enseña «quedan 2» y no se rompe nada. Las que no tengan
    /// estimación no suman, y por eso esto es un suelo y no una promesa.
    public var minutosRestantes: Int? {
        let suma = Duracion.total(tareas)
        return suma > 0 ? suma : nil
    }

    /// Cuántas de las que faltan no llevan estimación.
    ///
    /// Se dice para que los minutos no engañen: «quedan 3 · 45 min» con dos sin
    /// medir no son 45 minutos de trabajo, son 45 y lo que pesen las otras dos.
    public var sinEstimar: Int { Duracion.sinEstimar(tareas) }

    /// Cuánto del bloque está despejado, de 0 a 1.
    ///
    /// Cuenta **tareas**, no minutos, y es a propósito: es la ojeada —«voy por
    /// la mitad»— y tiene que estar definida siempre, también cuando no has
    /// estimado nada. El coste es conocido: cuatro tareas cortas hechas y una
    /// larga pendiente pintan la raya casi entera. Por eso la raya no va sola y
    /// al lado se dice lo que queda de verdad, que es lo exacto.
    public var fraccion: Double { total == 0 ? 0 : Double(hechas) / Double(total) }

    public init(proyecto: UUID, tareas: [Item]) {
        self.proyecto = proyecto
        self.tareas = tareas
    }
}

public enum Hoy {
    /// Cuántas tareas del mismo proyecto hacen falta para que se agrupen.
    ///
    /// Dos. Una sola dentro de una caja con cabecera son tres líneas para decir
    /// lo que decía una, y con el umbral en uno un día variado se convierte en
    /// una lista de títulos con una tarea debajo de cada uno.
    public static let minimoParaAgrupar = 2

    /// Parte el tramo sin hora de Hoy en bloques.
    ///
    /// **Agrupa sin reordenar.** Cada grupo se coloca donde estaba su primera
    /// tarea pendiente, y dentro conserva el orden manual. Agrupar es partir la
    /// lista, no volver a ordenarla: lo que se priorizó arrastrando tiene que
    /// seguir mandando a la mañana siguiente.
    ///
    /// - Parameters:
    ///   - sinHora: las tareas de hoy sin hora, ya en orden manual.
    ///   - hechasHoy: lo tachado hoy, para que el contador no encoja.
    public static func bloques(sinHora: [Item], hechasHoy: [Item],
                               minimo: Int = minimoParaAgrupar) -> [BloqueDeHoy] {
        // Lo que tenía hora vivió arriba, en la línea del reloj; que al tacharlo
        // reapareciera aquí abajo sería moverlo de sitio al terminarlo.
        let hechas = hechasHoy.filter { $0.timeOfDay == nil }

        var porProyecto: [UUID: [Item]] = [:]
        for tarea in sinHora + hechas {
            guard let id = tarea.projectID else { continue }
            porProyecto[id, default: []].append(tarea)
        }
        let agrupables = Set(porProyecto.filter { $0.value.count >= minimo }.map(\.key))

        var salida: [BloqueDeHoy] = []
        var colocados: Set<UUID> = []
        for tarea in sinHora {
            guard let id = tarea.projectID, agrupables.contains(id) else {
                salida.append(.suelta(tarea))
                continue
            }
            guard colocados.insert(id).inserted else { continue }
            salida.append(.proyecto(grupo(id, porProyecto[id] ?? [])))
        }

        // Un proyecto cuyas tareas de hoy están todas hechas ya no tiene una
        // primera pendiente que lo coloque. Se queda al final —con el contador
        // entero, que es el premio— porque ahí ya no hay nada que hacer.
        let rezagados = agrupables.subtracting(colocados)
            .map { grupo($0, porProyecto[$0] ?? []) }
            .sorted { ($0.tareas.first?.completedAt ?? .distantPast)
                    < ($1.tareas.first?.completedAt ?? .distantPast) }
        return salida + rezagados.map(BloqueDeHoy.proyecto)
    }

    /// Lo pendiente en el orden en que venía; lo hecho, debajo y por hora de
    /// tachado. Lo que queda por hacer es lo que se mira.
    private static func grupo(_ id: UUID, _ tareas: [Item]) -> GrupoDeProyecto {
        let pendientes = tareas.filter { !$0.isCompleted }
        let hechas = tareas.filter(\.isCompleted)
            .sorted { ($0.completedAt ?? .distantPast) < ($1.completedAt ?? .distantPast) }
        return GrupoDeProyecto(proyecto: id, tareas: pendientes + hechas)
    }
}
