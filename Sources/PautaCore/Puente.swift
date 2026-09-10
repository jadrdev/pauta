import Foundation

/// El puente entre la carpeta del teléfono y la del Mac.
///
/// El Mac guarda sus tareas en una carpeta de iCloud Drive y las lee por ruta,
/// porque no está en sandbox. El teléfono no puede hacer eso: en iOS una app no
/// recorre rutas, y el contenedor de iCloud —la puerta buena— la cierra la
/// cuenta. Lo que sí puede es leer **una carpeta que le des tú** con el selector
/// de archivos del sistema, que devuelve un permiso con ámbito.
///
/// Y con esa carpeta a mano, la tentación es apuntar el almacén ahí. No se hace:
/// la carpeta puede no estar —sin red, con el permiso caducado, con el archivo
/// todavía en la nube— y entonces la app se quedaría sin datos en vez de
/// funcionar sola. Cada lado guarda lo suyo y esto los cruza.
///
/// La regla es la del almacén y no una nueva: **gana la versión modificada más
/// recientemente**, archivo a archivo. Es lo que hace que dos aparatos tocando
/// tareas distintas no se pisen nunca, y lo que hace que una lápida borre en el
/// otro lado en vez de resucitar la tarea.
public enum Puente {
    /// Qué se movió en un cruce. Sirve para contarlo y para saber si hubo algo
    /// que hacer: dos cruces seguidos sin tocar nada deben dar cero.
    public struct Balance: Equatable, Sendable {
        /// Archivos que vinieron de la otra carpeta.
        public var traidas = 0
        /// Archivos que se llevaron a la otra carpeta.
        public var llevadas = 0
        /// Marcadores de iCloud encontrados: hay datos que aún no han bajado y
        /// que aparecerán en el siguiente cruce.
        public var pendientesDeBajar = 0

        public init() {}
    }

    /// Solo hace falta la fecha para decidir quién gana, así que no se decodifica
    /// la tarea entera: un objeto con miles de pasos y notas se compara por dos
    /// campos.
    private struct Version: Decodable {
        let updatedAt: Date
    }

    private static let subcarpetas = ["items", "projects", "areas"]

    /// Cruza dos carpetas de datos. Devuelve qué se movió.
    ///
    /// No borra nunca un archivo: lo que sobrescribe es la versión perdedora, y
    /// un borrado viaja como lápida. Así un cruce con la carpeta equivocada se
    /// deshace volviendo a cruzar con la buena.
    @discardableResult
    public static func cruzar(_ aqui: URL, _ alla: URL) -> Balance {
        var balance = Balance()
        let fm = FileManager.default
        let decoder = ISODate.decodificador()

        /// La fecha de un archivo, o `nil` si no se entiende. Un archivo que no
        /// se puede leer no gana nunca: sobrescribir datos buenos con algo
        /// ilegible es la única forma de perder información aquí.
        func version(_ url: URL) -> Date? {
            guard let datos = try? Data(contentsOf: url), !datos.isEmpty else { return nil }
            return (try? decoder.decode(Version.self, from: datos))?.updatedAt
        }

        func copiar(_ origen: URL, a destino: URL) -> Bool {
            try? fm.createDirectory(at: destino.deletingLastPathComponent(),
                                    withIntermediateDirectories: true)
            guard let datos = try? Data(contentsOf: origen) else { return false }
            // Atómico, como todo lo que escribe la app: al otro lado puede haber
            // alguien leyendo justo ahora.
            return (try? datos.write(to: destino, options: .atomic)) != nil
        }

        for sub in subcarpetas {
            let dirAqui = aqui.appendingPathComponent(sub, isDirectory: true)
            let dirAlla = alla.appendingPathComponent(sub, isDirectory: true)

            /// Los nombres de archivo de datos, y de paso la cuenta de lo que
            /// iCloud tiene desalojado. Un `.nombre.json.icloud` es un marcador
            /// vacío: copiarlo sería copiar la nada encima de una tarea.
            func nombres(_ dir: URL) -> Set<String> {
                let todo = (try? fm.contentsOfDirectory(at: dir,
                            includingPropertiesForKeys: nil)) ?? []
                for url in todo where url.pathExtension == "icloud" {
                    balance.pendientesDeBajar += 1
                }
                return Set(todo.filter { $0.pathExtension == "json" }.map(\.lastPathComponent))
            }

            let deAqui = nombres(dirAqui)
            let deAlla = nombres(dirAlla)

            for nombre in deAqui.union(deAlla) {
                let uno = dirAqui.appendingPathComponent(nombre)
                let otro = dirAlla.appendingPathComponent(nombre)
                switch (deAqui.contains(nombre), deAlla.contains(nombre)) {
                case (true, false):
                    if copiar(uno, a: otro) { balance.llevadas += 1 }
                case (false, true):
                    if copiar(otro, a: uno) { balance.traidas += 1 }
                case (true, true):
                    guard let mia = version(uno), let suya = version(otro) else {
                        // Uno de los dos no se entiende: gana el que sí, y si
                        // ninguno se entiende no se toca nada.
                        if version(uno) != nil, copiar(uno, a: otro) { balance.llevadas += 1 }
                        else if version(otro) != nil, copiar(otro, a: uno) { balance.traidas += 1 }
                        continue
                    }
                    if suya > mia, copiar(otro, a: uno) { balance.traidas += 1 }
                    else if mia > suya, copiar(uno, a: otro) { balance.llevadas += 1 }
                case (false, false):
                    continue
                }
            }
        }
        return balance
    }
}
