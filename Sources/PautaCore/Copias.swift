import Foundation

/// Todo lo guardado, en un momento dado: la copia de seguridad.
///
/// Una copia es **aparte** de los datos, no una forma de guardarlos. Los datos
/// siguen siendo un archivo por tarea, que es lo que hace que un fallo de
/// sincronización toque una tarea y no todas; la copia es la foto del día a la
/// que volver si algo sale mal de todos modos.
///
/// Lleva también lo que está en la papelera: restaurar tiene que dejarlo todo
/// como estaba, y eso incluye lo que ese día ya estaba borrado.
public struct Copia: Codable, Equatable {
    public var version = 1
    public var hecha: Date
    public var items: [Item]
    public var projects: [Project]
    public var areas: [Area]

    /// Lo que se ve de una copia antes de elegirla: cuántas tareas pendientes
    /// y cuántos proyectos. Con eso se reconoce el día, sin abrirla entera.
    public var pendientes: Int { items.filter { $0.deletedAt == nil && !$0.isCompleted }.count }
    public var proyectosVivos: Int { projects.filter { $0.deletedAt == nil }.count }
}

/// Dónde y cómo se guardan las copias.
///
/// Un archivo por día, `Pauta-2026-09-28.json.gz`, en `copias/` dentro de la
/// carpeta de datos. En el Mac esa carpeta está en iCloud Drive, así que la copia
/// sobrevive a perder el Mac. El puente con el teléfono no la cruza: solo cruza
/// tareas, proyectos y áreas.
///
/// gzip de verdad y no un formato propio: se abre con `gunzip` sin Pauta, y lo
/// que hay dentro es JSON legible. Una copia que solo sabe abrir la app que se
/// rompió no es una copia.
public enum Copias {
    /// Cuántas se guardan. Un mes da para darse cuenta de que algo falta.
    /// Cuántos días se guardan. Pasado un mes, una copia ya no es a donde se
    /// quiere volver, y solo ocupa sitio.
    public static let cuantas = 30

    static let prefijo = "Pauta-"
    static let extension_ = ".json.gz"

    static func clave(_ fecha: Date, _ calendar: Calendar) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = calendar.timeZone
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: fecha)
    }

    public static func carpeta(en raiz: URL) -> URL {
        raiz.appendingPathComponent("copias", isDirectory: true)
    }

    /// El nombre de la copia de un día. Con la fecha delante y en ese orden,
    /// ordenar por nombre es ordenar por fecha.
    public static func nombre(para dia: Date, calendar: Calendar = .current) -> String {
        prefijo + clave(dia, calendar) + extension_
    }

    /// La que se hace antes de restaurar, para poder deshacerlo. Lleva la hora
    /// porque puede haber varias el mismo día.
    static func nombreAntesDeRestaurar(_ ahora: Date, calendar: Calendar = .current) -> String {
        let hora = calendar.dateComponents([.hour, .minute, .second], from: ahora)
        let reloj = String(format: "%02d%02d%02d", hora.hour ?? 0, hora.minute ?? 0, hora.second ?? 0)
        return prefijo + clave(ahora, calendar)
            + "-antes-de-restaurar-" + reloj + extension_
    }

    /// Las copias que hay, de la más nueva a la más vieja.
    public static func guardadas(en raiz: URL) -> [URL] {
        let archivos = (try? FileManager.default.contentsOfDirectory(
            at: carpeta(en: raiz), includingPropertiesForKeys: nil)) ?? []
        return archivos
            .filter { $0.lastPathComponent.hasPrefix(prefijo)
                      && $0.lastPathComponent.hasSuffix(extension_) }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
    }

    /// Una copia vista desde fuera: lo justo para reconocerla en una lista.
    public struct Guardada: Identifiable, Equatable, Sendable {
        public let url: URL
        public var id: URL { url }
        public let hecha: Date
        public let antesDeRestaurar: Bool
        /// `nil` si la copia está en iCloud sin bajar: no se sabe qué hay
        /// dentro sin leerla, y leerla es esperar a que baje.
        public let pendientes: Int?
        public let proyectos: Int?

        public var enLaNube: Bool { pendientes == nil }

        /// «Domingo, 28 de septiembre», y si es la de antes de restaurar, con
        /// la hora: puede haber varias el mismo día.
        public var titulo: String {
            let dia = hecha.formatted(.dateTime.weekday(.wide).day().month(.wide))
            let bonito = dia.prefix(1).uppercased() + dia.dropFirst()
            guard antesDeRestaurar else { return bonito }
            return bonito + " · antes de restaurar, "
                + hecha.formatted(.dateTime.hour().minute())
        }

        public var detalle: String {
            guard let pendientes, let proyectos else { return "En iCloud, bajando…" }
            return "\(pendientes) \(pendientes == 1 ? "pendiente" : "pendientes") · "
                + "\(proyectos) \(proyectos == 1 ? "proyecto" : "proyectos")"
        }
    }

    /// Las copias que se pueden restaurar, de la más nueva a la más vieja. Las
    /// que no se abren no salen: ofrecer algo que luego falla es peor que no
    /// ofrecerlo.
    ///
    /// Las que iCloud tiene sin bajar salen **sin abrirlas**, con la fecha de
    /// su nombre, y se pide que bajen. Abrirlas era esperar a la descarga, y
    /// como esto se pedía al arrancar, la app del Mac se quedaba colgada sin
    /// llegar a enseñar nada: iCloud había desalojado las copias viejas para
    /// ahorrar sitio, y cada una era una espera.
    public static func resumenes(en raiz: URL) -> [Guardada] {
        guardadas(en: raiz).compactMap { url in
            let antes = url.lastPathComponent.contains("antes-de-restaurar")
            guard bajada(url) else {
                guard let fecha = fecha(delNombre: url.lastPathComponent) else { return nil }
                return Guardada(url: url, hecha: fecha, antesDeRestaurar: antes,
                                pendientes: nil, proyectos: nil)
            }
            guard let copia = leer(url) else { return nil }
            return Guardada(url: url, hecha: copia.hecha, antesDeRestaurar: antes,
                            pendientes: copia.pendientes, proyectos: copia.proyectosVivos)
        }
    }

    /// Si el archivo se puede leer sin esperar. Un archivo de iCloud sin
    /// bajar no: leerlo bloquea hasta que baja. Entonces se pide la descarga y
    /// se contesta que no, para mirarlo la próxima vez.
    public static func bajada(_ url: URL) -> Bool {
        guard let valores = try? url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey]),
              let estado = valores.ubiquitousItemDownloadingStatus else { return true }
        guard estado == .notDownloaded else { return true }
        try? FileManager.default.startDownloadingUbiquitousItem(at: url)
        return false
    }

    /// La fecha que lleva el nombre: el día, y la hora si es la de antes de
    /// restaurar.
    static func fecha(delNombre nombre: String) -> Date? {
        var resto = nombre
        guard resto.hasPrefix(prefijo), resto.hasSuffix(extension_) else { return nil }
        resto = String(resto.dropFirst(prefijo.count).dropLast(extension_.count))
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        if let corte = resto.range(of: "-antes-de-restaurar-") {
            f.dateFormat = "yyyy-MM-dd HHmmss"
            return f.date(from: resto[..<corte.lowerBound] + " " + resto[corte.upperBound...])
        }
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: resto)
    }

    public static func escribir(_ copia: Copia, en url: URL) throws {
        let datos = try ISODate.codificador().encode(copia)
        guard let comprimido = gzip(datos) else { throw CocoaError(.fileWriteUnknown) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try comprimido.write(to: url, options: .atomic)
    }

    /// `nil` también si está en iCloud sin bajar: no se espera a la descarga.
    public static func leer(_ url: URL) -> Copia? {
        guard bajada(url), let datos = try? Data(contentsOf: url),
              let json = gunzip(datos) else { return nil }
        return try? ISODate.decodificador().decode(Copia.self, from: json)
    }

    /// Quita las de más de `dias` días, por la fecha de su nombre.
    ///
    /// Por antigüedad y no por cuántas hay: guardar «las treinta últimas»
    /// estiraba el mes si la app no se abría algún día, y las de antes de
    /// restaurar contaban como una más. **La más reciente se queda siempre**,
    /// aunque sea vieja: quien no abre la app en dos meses no tiene que
    /// encontrarse sin ninguna.
    static func podar(en raiz: URL, dias: Int = cuantas, ahora: Date = .now,
                      calendar: Calendar = .current) {
        let limite = calendar.date(byAdding: .day, value: -dias,
                                   to: calendar.startOfDay(for: ahora))!
        for url in guardadas(en: raiz).dropFirst() {
            guard let fecha = fecha(delNombre: url.lastPathComponent),
                  calendar.startOfDay(for: fecha) < limite else { continue }
            try? FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - gzip

    /// gzip con lo que trae el sistema. `NSData` comprime en DEFLATE crudo; lo
    /// que falta para que sea un `.gz` es la cabecera delante y, detrás, la
    /// suma de comprobación y el tamaño.
    static func gzip(_ datos: Data) -> Data? {
        guard let deflate = try? (datos as NSData).compressed(using: .zlib) as Data else { return nil }
        var salida = Data([0x1f, 0x8b, 0x08, 0x00, 0, 0, 0, 0, 0x00, 0x03])
        salida.append(deflate)
        salida.append(contentsOf: bytes(crc32(datos)))
        salida.append(contentsOf: bytes(UInt32(truncatingIfNeeded: datos.count)))
        return salida
    }

    /// Abre un `.gz`, el nuestro o uno cualquiera, y comprueba que lo que sale
    /// es lo que entró: un archivo cortado a medias no debe restaurarse como si
    /// estuviera entero.
    static func gunzip(_ datos: Data) -> Data? {
        let b = [UInt8](datos)
        guard b.count >= 18, b[0] == 0x1f, b[1] == 0x8b, b[2] == 0x08 else { return nil }
        let banderas = b[3]
        var i = 10
        if banderas & 0x04 != 0 {
            guard i + 2 <= b.count else { return nil }
            i += 2 + Int(b[i]) | Int(b[i + 1]) << 8
        }
        if banderas & 0x08 != 0 { while i < b.count, b[i] != 0 { i += 1 }; i += 1 }
        if banderas & 0x10 != 0 { while i < b.count, b[i] != 0 { i += 1 }; i += 1 }
        if banderas & 0x02 != 0 { i += 2 }
        guard i <= b.count - 8 else { return nil }

        let cuerpo = Data(b[i..<(b.count - 8)])
        guard let salida = try? (cuerpo as NSData).decompressed(using: .zlib) as Data
        else { return nil }
        let suma = UInt32(b[b.count - 8]) | UInt32(b[b.count - 7]) << 8
            | UInt32(b[b.count - 6]) << 16 | UInt32(b[b.count - 5]) << 24
        let tamano = UInt32(b[b.count - 4]) | UInt32(b[b.count - 3]) << 8
            | UInt32(b[b.count - 2]) << 16 | UInt32(b[b.count - 1]) << 24
        guard crc32(salida) == suma, UInt32(truncatingIfNeeded: salida.count) == tamano
        else { return nil }
        return salida
    }

    private static func bytes(_ n: UInt32) -> [UInt8] {
        [UInt8(n & 0xff), UInt8(n >> 8 & 0xff), UInt8(n >> 16 & 0xff), UInt8(n >> 24 & 0xff)]
    }

    private static let tablaCRC: [UInt32] = (0..<256).map { n -> UInt32 in
        var c = UInt32(n)
        for _ in 0..<8 { c = c & 1 != 0 ? 0xEDB8_8320 ^ (c >> 1) : c >> 1 }
        return c
    }

    static func crc32(_ datos: Data) -> UInt32 {
        var c: UInt32 = 0xFFFF_FFFF
        for byte in datos { c = tablaCRC[Int((c ^ UInt32(byte)) & 0xff)] ^ (c >> 8) }
        return c ^ 0xFFFF_FFFF
    }
}
