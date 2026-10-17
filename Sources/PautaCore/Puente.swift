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

    /// Si el archivo está de verdad en el disco, y en su última versión.
    ///
    /// Un archivo de iCloud puede existir en el listado y no estar bajado.
    /// Sin esta comprobación, leerlo dispara la descarga y **espera**: es lo
    /// que congelaba la app en el primer cruce con una carpeta de verdad.
    /// Lo que no es de iCloud no tiene este estado y se da por bueno.
    public static func enLocal(_ url: URL) -> Bool {
        guard let valores = try? url.resourceValues(
                forKeys: [.ubiquitousItemDownloadingStatusKey]),
              let estado = valores.ubiquitousItemDownloadingStatus else { return true }
        return estado == .current
    }

    /// Cruza dos carpetas de datos. Devuelve qué se movió.
    ///
    /// No borra nunca un archivo: lo que sobrescribe es la versión perdedora, y
    /// un borrado viaja como lápida. Así un cruce con la carpeta equivocada se
    /// deshace volviendo a cruzar con la buena.
    ///
    /// `enLocal` solo lo cambian los tests: fuera de iCloud no hay archivos a
    /// medio bajar con los que probar.
    @discardableResult
    public static func cruzar(_ aqui: URL, _ alla: URL,
                              enLocal: (URL) -> Bool = Puente.enLocal) -> Balance {
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
            ///
            /// Y se descartan también los que iCloud tiene sin bajar **sin
            /// marcador visible**, que es el caso de una carpeta compartida por
            /// el selector de archivos. Ahí `Data(contentsOf:)` no falla: se
            /// queda esperando la descarga, y con sesenta archivos eso es una
            /// app que parece colgada. Se pide la descarga y se dejan para el
            /// cruce siguiente.
            ///
            /// Los que se quedan fuera se anotan en `aMedias`: existen, solo que
            /// aún no se pueden leer, y eso **no es lo mismo que faltar**.
            var aMedias: Set<String> = []
            func nombres(_ dir: URL) -> Set<String> {
                let todo = (try? fm.contentsOfDirectory(at: dir,
                            includingPropertiesForKeys: [.ubiquitousItemDownloadingStatusKey])) ?? []
                var buenos: Set<String> = []
                for url in todo {
                    if url.pathExtension == "icloud" {
                        balance.pendientesDeBajar += 1
                        continue
                    }
                    guard url.pathExtension == "json" else { continue }
                    if enLocal(url) {
                        buenos.insert(url.lastPathComponent)
                    } else {
                        balance.pendientesDeBajar += 1
                        aMedias.insert(url.lastPathComponent)
                        try? fm.startDownloadingUbiquitousItem(at: url)
                    }
                }
                return buenos
            }

            let deAqui = nombres(dirAqui)
            let deAlla = nombres(dirAlla)

            // Lo que está a medio bajar en cualquiera de los dos lados no se
            // toca hasta el cruce siguiente. Antes se tomaba por ausente y se
            // le copiaba encima la versión del otro lado, **más vieja**: el
            // teléfono cruzaba antes de que iCloud le bajara lo tachado en el
            // Mac, y lo destachaba. Así volvió una «Revisión diaria» que se
            // había hecho, y junto a su sucesora parecía una tarea repetida.
            for nombre in deAqui.union(deAlla).subtracting(aMedias) {
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
        cruzarAdjuntos(aqui, alla, balance: &balance, enLocal: enLocal)
        return balance
    }

    /// Lleva a cada lado los ficheros adjuntos que le faltan.
    ///
    /// Va **después** de las tareas, porque son ellas las que dicen qué
    /// ficheros hacen falta: solo cruzan los vigentes de alguna tarea. Copiar
    /// todo lo que haya en la carpeta devolvería al otro lado lo que su
    /// limpieza ya se llevó —una tarea hecha hace más de siete días, un adjunto
    /// quitado— y no se acabaría de borrar nunca.
    ///
    /// Aquí no hay versiones que comparar: un adjunto no cambia nunca, así que
    /// o está o falta.
    private static func cruzarAdjuntos(_ aqui: URL, _ alla: URL, balance: inout Balance,
                                       enLocal: (URL) -> Bool) {
        let fm = FileManager.default
        let decoder = ISODate.decodificador()

        var vigentes: [Adjunto] = []
        var vistos: Set<UUID> = []
        for raiz in [aqui, alla] {
            let dir = raiz.appendingPathComponent("items", isDirectory: true)
            let todo = (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
            for url in todo where url.pathExtension == "json" && enLocal(url) {
                guard let datos = try? Data(contentsOf: url),
                      let item = try? decoder.decode(Item.self, from: datos) else { continue }
                for adjunto in item.adjuntosVigentes() where vistos.insert(adjunto.id).inserted {
                    vigentes.append(adjunto)
                }
            }
        }

        enum Estado { case falta, aMedias, listo(URL) }
        func estado(_ raiz: URL, _ adjunto: Adjunto) -> Estado {
            let carpeta = raiz.appendingPathComponent("adjuntos", isDirectory: true)
                .appendingPathComponent(adjunto.id.uuidString, isDirectory: true)
            let fichero = carpeta.appendingPathComponent(adjunto.nombre)
            // El marcador de iCloud de un fichero desalojado: está, pero no aquí.
            let marcador = carpeta.appendingPathComponent(".\(adjunto.nombre).icloud")
            if fm.fileExists(atPath: marcador.path) {
                try? fm.startDownloadingUbiquitousItem(at: fichero)
                return .aMedias
            }
            guard fm.fileExists(atPath: fichero.path) else { return .falta }
            guard enLocal(fichero) else {
                try? fm.startDownloadingUbiquitousItem(at: fichero)
                return .aMedias
            }
            return .listo(fichero)
        }

        func copiar(_ origen: URL, a raiz: URL, _ adjunto: Adjunto) -> Bool {
            let carpeta = raiz.appendingPathComponent("adjuntos", isDirectory: true)
                .appendingPathComponent(adjunto.id.uuidString, isDirectory: true)
            try? fm.createDirectory(at: carpeta, withIntermediateDirectories: true)
            // `copyItem` y no leer y escribir: un vídeo no tiene por qué caber
            // en memoria.
            return (try? fm.copyItem(at: origen, to: carpeta.appendingPathComponent(adjunto.nombre))) != nil
        }

        for adjunto in vigentes {
            switch (estado(aqui, adjunto), estado(alla, adjunto)) {
            case (.aMedias, _), (_, .aMedias):
                balance.pendientesDeBajar += 1
            case (.listo(let origen), .falta):
                if copiar(origen, a: alla, adjunto) { balance.llevadas += 1 }
            case (.falta, .listo(let origen)):
                if copiar(origen, a: aqui, adjunto) { balance.traidas += 1 }
            case (.listo, .listo), (.falta, .falta):
                continue
            }
        }
    }
}
