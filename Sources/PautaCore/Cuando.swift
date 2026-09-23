import Foundation

/// Sacar el día y la hora de lo que escribes o dictas.
///
/// «Llamar a la gestoría mañana a las 10» es una tarea para mañana a las diez,
/// y escribir eso y luego abrir un selector de fecha para repetirlo es hacer dos
/// veces el mismo trabajo.
///
/// Quien entiende el español es `NSDataDetector`, que trae el sistema: sabe de
/// «pasado mañana», «el viernes» y «el 3 de octubre» sin que aquí haya una sola
/// lista de meses. Lo que se hace aquí es lo que él no hace — decidir qué es
/// título, no tragarse las horas que se inventa, y juntar dos trozos sueltos.
public enum Cuando {
    public struct Lectura: Equatable, Sendable {
        /// Lo que queda al quitarle la fecha, ya limpio de preposiciones sueltas.
        public let titulo: String
        /// El día, a las cero horas. `nil` si no había ninguno.
        public let dia: Date?
        /// Minutos desde medianoche. `nil` si dijiste el día pero no la hora.
        public let minuto: Int?
    }

    /// Uno solo y reutilizado: construirlo compila expresiones y cuesta.
    private nonisolated(unsafe) static let detector = try? NSDataDetector(
        types: NSTextCheckingResult.CheckingType.date.rawValue)

    public static func leer(_ linea: String, calendar: Calendar = .current) -> Lectura {
        let intacta = Lectura(titulo: linea, dia: nil, minuto: nil)
        guard let detector else { return intacta }
        let ns = linea as NSString
        let trozos = detector.matches(
            in: linea, range: NSRange(location: 0, length: ns.length))
        guard !trozos.isEmpty else { return intacta }

        var dia: Date?
        var minuto: Int?
        var rangos: [NSRange] = []
        for trozo in trozos {
            guard let fecha = trozo.date else { continue }
            let texto = ns.substring(with: trozo.range)
            rangos.append(trozo.range)
            // La hora solo si la dijiste. El detector rellena las doce del
            // mediodía cuando no hay ninguna, y tragárselo le pondría a la tarea
            // una hora inventada —con su aviso—.
            if minuto == nil, dice(hora: texto) {
                let c = calendar.dateComponents([.hour, .minute], from: fecha)
                minuto = (c.hour ?? 0) * 60 + (c.minute ?? 0)
            }
            // Y el día solo del trozo que habla de un día: «18:00» a secas lo
            // resuelve como hoy, y si eso ganara, «28 de septiembre … 18:00»
            // acabaría siendo hoy.
            if dia == nil, !soloHora(texto) {
                dia = calendar.startOfDay(for: fecha)
            }
        }
        // Una hora a secas es hoy: una hora sin día no dice cuándo.
        if dia == nil, minuto != nil { dia = calendar.startOfDay(for: .now) }
        guard dia != nil else { return intacta }

        let titulo = limpiar(quitando: rangos, de: ns)
        // Si no queda título, la línea **era** la fecha. Una tarea en blanco con
        // día puesto es peor que una tarea que se llama «mañana».
        guard !titulo.isEmpty else { return intacta }
        return Lectura(titulo: titulo, dia: dia, minuto: minuto)
    }

    /// Si el trozo nombra una hora. Se mira el texto y no la fecha resuelta,
    /// porque la fecha siempre trae hora: la que el detector se inventó.
    private static func dice(hora texto: String) -> Bool {
        let t = texto.lowercased()
        if t.range(of: #"\d{1,2}[:.]\d{2}"#, options: .regularExpression) != nil { return true }
        if t.range(of: #"\ba\s+las?\s+\d"#, options: .regularExpression) != nil { return true }
        if t.range(of: #"\d\s*(h|hs|horas|am|pm)\b"#, options: .regularExpression) != nil { return true }
        return false
    }

    /// Si el trozo es **solo** una hora: «18:00», «a las 18».
    private static func soloHora(_ texto: String) -> Bool {
        let t = texto.lowercased().trimmingCharacters(in: .whitespaces)
        return t.range(of: #"^(a\s+las?\s+)?\d{1,2}([:.]\d{2})?\s*(h|hs|horas|am|pm)?$"#,
                       options: .regularExpression) != nil
    }

    /// Quita los trozos de fecha y deja un título legible.
    ///
    /// Al sacar la fecha del medio quedan preposiciones colgando —«Cita con el
    /// dentista **el**», «**de** Sección de Inicio de Uned **a las**»— que no son
    /// título de nada. Se podan por los dos extremos, y también los huecos
    /// dobles que deja el recorte.
    private static func limpiar(quitando rangos: [NSRange], de ns: NSString) -> String {
        var texto = ns as String
        for rango in rangos.sorted(by: { $0.location > $1.location }) {
            texto = (texto as NSString).replacingCharacters(in: rango, with: " ")
        }
        texto = texto.replacingOccurrences(of: #"\s+"#, with: " ",
                                           options: .regularExpression)
        let sueltas: Set<String> = ["el", "la", "los", "las", "de", "del",
                                    "a", "al", "en", "para", "por", "y", "-", "·"]
        var partes = texto.split(separator: " ").map(String.init)
        while let primera = partes.first, sueltas.contains(primera.lowercased()) {
            partes.removeFirst()
        }
        while let ultima = partes.last, sueltas.contains(ultima.lowercased()) {
            partes.removeLast()
        }
        return partes.joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
