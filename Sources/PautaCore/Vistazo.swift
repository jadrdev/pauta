import Foundation

/// Lo que cabe en un widget.
///
/// Un widget no se abre: se ve de reojo al desbloquear el teléfono, entre otras
/// cosas y sin intención de mirarlo. Eso descarta enseñar «la lista»: lo que
/// tiene que caber es cuántas cosas hay y las tres o cuatro primeras, y nada
/// que obligue a leer.
///
/// Y va en el núcleo porque quien lo dibuja es **otro proceso**. La extensión
/// no comparte memoria con la app: no puede preguntarle al almacén, así que lee
/// la misma carpeta por su cuenta. Todo lo que decide qué se ve está aquí, en
/// funciones puras con la fecha por parámetro, que es lo único que se puede
/// probar de un widget: en su sitio no hay pantalla que mirar.
public struct Vistazo: Equatable, Sendable {
    /// Una tarea, ya resuelta para dibujarla: sin identificadores que haya que
    /// ir a buscar a otra parte, porque en la extensión no hay a quién
    /// preguntar.
    public struct Fila: Identifiable, Equatable, Sendable {
        public let id: UUID
        public let titulo: String
        /// La hora del día en minutos, si la tiene.
        public let minuto: Int?
        /// El nombre del proyecto, ya resuelto.
        public let proyecto: String?
        /// Días que lleva arrastrándose desde el día para el que se planificó.
        public let diasTarde: Int

        public var atrasada: Bool { diasTarde > 0 }

        /// «9:30». Se formatea aquí y no se guarda hecho porque la hora se
        /// escribe distinta en cada idioma y región, y el widget se dibuja en
        /// el del teléfono.
        public var hora: String? {
            guard let minuto else { return nil }
            let base = Calendar.current.startOfDay(for: .now)
            guard let momento = Calendar.current.date(byAdding: .minute, value: minuto, to: base)
            else { return nil }
            return momento.formatted(.dateTime.hour().minute())
        }

        public init(id: UUID, titulo: String, minuto: Int?, proyecto: String?, diasTarde: Int) {
            self.id = id
            self.titulo = titulo
            self.minuto = minuto
            self.proyecto = proyecto
            self.diasTarde = diasTarde
        }
    }

    /// Cuántas hay para hoy, contando las que vienen arrastradas.
    public let hoy: Int
    /// De esas, cuántas se planificaron para un día que ya pasó.
    public let atrasadas: Int
    /// Y cuántas siguen sin decidir en la bandeja.
    public let bandeja: Int
    /// Las primeras, las que caben.
    public let filas: [Fila]
    /// Las que no caben. Se dice el número en vez de recortar en silencio: un
    /// widget que enseña tres de nueve y no lo confiesa está mintiendo.
    public let restantes: Int

    public var vacio: Bool { hoy == 0 }

    /// «3 para hoy», o «Nada para hoy» cuando no hay nada.
    ///
    /// «Nada para hoy» y no una pantalla vacía: el widget ocupa su hueco igual,
    /// y un hueco en blanco parece que la app se rompió.
    public var titular: String {
        hoy == 0 ? "Nada para hoy" : "\(hoy) para hoy"
    }

    /// «2 atrasadas», si hay. Es el dato que cambia lo que haces con el día, y
    /// por eso va aparte del titular en vez de sumado dentro.
    public var apunte: String? {
        guard atrasadas > 0 else { return nil }
        return atrasadas == 1 ? "1 atrasada" : "\(atrasadas) atrasadas"
    }

    // MARK: - Cálculo

    /// Lo que se enseña, a partir de las tareas.
    ///
    /// El orden es **el mismo que la lista de Hoy de la app** —lo que tiene
    /// hora, por hora, y detrás lo que no la tiene— y no uno propio del widget:
    /// dos listas que dicen ser lo mismo y no coinciden hacen que no te fíes de
    /// ninguna.
    public static func de(_ items: [Item], proyectos: [Project] = [],
                          limite: Int, now: Date = .now,
                          calendar: Calendar = .current) -> Vistazo {
        let inicio = calendar.startOfDay(for: now)
        let vivas = items.filter { !$0.isCompleted && $0.deletedAt == nil && !$0.isSomeday }
        let delDia = vivas.filter { esDeHoy($0, inicio, calendar) }.sorted(by: Item.bySchedule)
        let nombres = Dictionary(proyectos.map { ($0.id, $0.name) },
                                 uniquingKeysWith: { primero, _ in primero })

        func tarde(_ item: Item) -> Int {
            guard let cuando = item.when else { return 0 }
            let suyo = calendar.startOfDay(for: cuando)
            return max(0, calendar.dateComponents([.day], from: suyo, to: inicio).day ?? 0)
        }

        return Vistazo(
            hoy: delDia.count,
            atrasadas: delDia.filter { tarde($0) > 0 }.count,
            bandeja: vivas.filter { $0.projectID == nil && $0.when == nil }.count,
            filas: delDia.prefix(limite).map { item in
                Fila(id: item.id,
                     titulo: item.title,
                     minuto: item.timeOfDay,
                     proyecto: item.projectID.flatMap { nombres[$0] },
                     diasTarde: tarde(item))
            },
            restantes: max(0, delDia.count - limite))
    }

    /// La misma regla que `Item.isToday`, con la fecha por parámetro.
    ///
    /// Se repite en vez de llamarla porque `isToday` mira el reloj por dentro,
    /// y un widget que no se puede probar con una fecha fija no se puede probar.
    private static func esDeHoy(_ item: Item, _ inicio: Date, _ calendar: Calendar) -> Bool {
        if let limite = item.deadline,
           calendar.startOfDay(for: limite) <= inicio { return true }
        guard let cuando = item.when else { return false }
        return calendar.startOfDay(for: cuando) <= inicio
    }

    // MARK: - Lectura

    /// Lee la carpeta de datos y devuelve el vistazo.
    ///
    /// Sin `Store`, a propósito: el almacén crea carpetas, adopta datos de
    /// versiones viejas, normaliza posiciones y limpia lápidas —**escribe**—, y
    /// un widget no tiene ningún derecho a escribir en los datos de la app. Esto
    /// solo lee, y lo que no entienda lo salta.
    ///
    /// Una carpeta que no existe tampoco es un error: es un teléfono donde la
    /// app aún no se ha abierto, y ahí el widget dice «Nada para hoy».
    public static func leer(en root: URL, limite: Int, now: Date = .now,
                            calendar: Calendar = .current) -> Vistazo {
        let decoder = ISODate.decodificador()

        func todo<T: Decodable>(_ sub: String, _ tipo: T.Type) -> [T] {
            let dir = root.appendingPathComponent(sub, isDirectory: true)
            let archivos = (try? FileManager.default.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: nil)) ?? []
            return archivos
                .filter { $0.pathExtension == "json" }
                .compactMap { try? Data(contentsOf: $0) }
                .compactMap { try? decoder.decode(T.self, from: $0) }
        }

        return de(todo("items", Item.self), proyectos: todo("projects", Project.self),
                  limite: limite, now: now, calendar: calendar)
    }
}
