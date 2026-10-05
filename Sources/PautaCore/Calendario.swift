import Foundation

/// Leer un calendario pegado: una lista de sesiones, tutorías o clases, y
/// sacar de ella una tarea por día.
///
/// Nace de dos textos de verdad, y entiende sus dos formas:
///
/// ```
/// Fundamentos Sistemas Digitales (Viernes 17 a 18h)
/// Boole: 9, 16 y 23 octubre
/// Combinacionales: 30 octubre; 6, 13 y 20 noviembre
/// ```
///
/// ```
/// Sessiones de Youtbe Octubre L5 (bienvenida), M13, L19, L26
/// Noviembre M3, L9, L16, L23, L30
/// ```
///
/// Primero los días y luego el mes, o primero el mes y luego los días; con
/// una cabecera que dice la hora para lo que viene debajo, o sin ella; con la
/// inicial del día de la semana delante, o sin ella.
///
/// **No crea nada.** Devuelve propuestas, y quien lo llama las enseña antes de
/// crearlas: un lector de texto libre se equivoca, y una lista previa es lo que
/// convierte una equivocación en algo que se ve y se quita, en vez de veinte
/// tareas mal puestas. Y **no adivina**: lo que no entiende lo devuelve aparte,
/// y si la inicial del día o la cabecera dicen un día de la semana que no
/// cuadra con la fecha, lo marca.
public enum Calendario {

    public struct Propuesta: Identifiable, Equatable, Sendable {
        public let id = UUID()
        public var titulo: String
        public var dia: Date
        /// Minuto del día en que empieza, si se sabe.
        public var minuto: Int?
        /// Cuánto dura, en minutos, si se sabe.
        public var duracion: Int?
        /// El apartado del que viene: el nombre de la cabecera, si la había.
        public var seccion: String?
        /// Lo que no cuadra, dicho en una frase. Una propuesta con aviso se
        /// enseña igual: el aviso es para mirarla, no para descartarla.
        public var aviso: String?

        public static func == (a: Propuesta, b: Propuesta) -> Bool {
            a.titulo == b.titulo && a.dia == b.dia && a.minuto == b.minuto
                && a.duracion == b.duracion && a.seccion == b.seccion && a.aviso == b.aviso
        }
    }

    public struct Lectura: Equatable, Sendable {
        public var propuestas: [Propuesta] = []
        /// Las líneas que no dieron ninguna fecha: un título, o algo como
        /// «PEC: noviembre y enero», que tiene mes pero no día.
        public var ignoradas: [String] = []

        public init() {}
        /// Los apartados, en el orden en que salen.
        public var secciones: [String] {
            var vistas: [String] = []
            for p in propuestas { if let s = p.seccion, !vistas.contains(s) { vistas.append(s) } }
            return vistas
        }
    }

    // MARK: - Lo que se reconoce

    private static let meses: [(String, Int)] = [
        ("enero", 1), ("febrero", 2), ("marzo", 3), ("abril", 4), ("mayo", 5), ("junio", 6),
        ("julio", 7), ("agosto", 8), ("septiembre", 9), ("setiembre", 9), ("octubre", 10),
        ("noviembre", 11), ("diciembre", 12),
        // Abreviaturas sin ambigüedad. «Mar» y «may» no: se confunden con
        // martes y con palabras corrientes.
        ("ene", 1), ("feb", 2), ("abr", 4), ("jun", 6), ("jul", 7), ("ago", 8),
        ("sept", 9), ("sep", 9), ("oct", 10), ("nov", 11), ("dic", 12),
    ]

    private static let mesRE = try! NSRegularExpression(
        pattern: "(?<![\\p{L}])(" + meses.map(\.0).joined(separator: "|") + ")\\.?(?![\\p{L}])",
        options: [.caseInsensitive])

    /// Un día: el número, con la inicial del día de la semana delante si la
    /// lleva —«L5», «X16»—. En mayúscula, para no tomar la «y» de «9, 16 y 23».
    private static let diaRE = try! NSRegularExpression(
        pattern: "(?<![\\p{L}\\d])([LMXJVSD])?(\\d{1,2})(?![\\d:%])")

    private static let notaRE = try! NSRegularExpression(pattern: "\\(([^)]*)\\)")

    /// «17 a 18h», «17:00-18:00», «de 9:30 a 11 h».
    private static let franjaRE = try! NSRegularExpression(
        pattern: "(\\d{1,2})(?::(\\d{2}))?\\s*h?\\s*(?:a|-|–|hasta)\\s*(\\d{1,2})(?::(\\d{2}))?\\s*(?:h\\b|horas)",
        options: [.caseInsensitive])
    private static let franjaRelojRE = try! NSRegularExpression(
        pattern: "(\\d{1,2}):(\\d{2})\\s*(?:-|–|a|hasta)\\s*(\\d{1,2}):(\\d{2})",
        options: [.caseInsensitive])
    /// «a las 18:00», «18:00», «18h».
    private static let horaRE = try! NSRegularExpression(
        pattern: "(?:a\\s+las\\s+)?(\\d{1,2})(?::(\\d{2})|\\s*h\\b)",
        options: [.caseInsensitive])

    private static let semana: [(String, Int)] = [
        ("lunes", 2), ("martes", 3), ("mi[eé]rcoles", 4), ("jueves", 5), ("viernes", 6),
        ("s[aá]bado", 7), ("domingo", 1),
    ]
    private static let semanaRE = try! NSRegularExpression(
        pattern: "(?<![\\p{L}])(" + semana.map(\.0).joined(separator: "|") + ")(?![\\p{L}])",
        options: [.caseInsensitive])

    /// La inicial de cada día, en el orden de `Calendar.weekday` (1 = domingo).
    private static let inicial: [Character: Int] = ["D": 1, "L": 2, "M": 3, "X": 4, "J": 5, "V": 6, "S": 7]
    private static let nombreDia = [1: "domingo", 2: "lunes", 3: "martes", 4: "miércoles",
                                    5: "jueves", 6: "viernes", 7: "sábado"]

    /// El proyecto que parece el de un apartado: el que comparte con él dos
    /// palabras del nombre, con la misma regla que junta tareas y eventos.
    /// «Fundamentos Sistemas Digitales» es «F. Sistemas Digitales». Si hay más
    /// de uno, ninguno: elegir a ciegas entre dos es peor que preguntar.
    public static func proyecto(para seccion: String, en proyectos: [Project]) -> Project? {
        let candidatos = proyectos.filter { $0.deletedAt == nil && MismaCosa.titulos(seccion, $0.name) }
        return candidatos.count == 1 ? candidatos[0] : nil
    }

    /// Las propuestas que ya están en Pauta: mismo día y un título que es el
    /// mismo, con la regla de siempre —«Tutoría: Boole» y «Boole» lo son—.
    /// Pegar dos veces el mismo calendario es lo más fácil del mundo, y sin
    /// esto lo segundo duplicaría todo.
    public static func yaEstan(_ propuestas: [Propuesta], en items: [Item],
                               calendar: Calendar = .current) -> Set<UUID> {
        Set(propuestas.filter { p in
            items.contains { i in
                i.deletedAt == nil && i.when.map { calendar.isDate($0, inSameDayAs: p.dia) } == true
                    && MismaCosa.titulos(i.title, p.titulo)
            }
        }.map(\.id))
    }

    // MARK: - Leer

    public static func leer(_ texto: String, hoy: Date = .now,
                            calendar: Calendar = .current) -> Lectura {
        var lectura = Lectura()
        var seccion: String?
        var horaDeSeccion: (minuto: Int, duracion: Int?)?
        var diaDeSeccion: Int?
        /// Una línea sin fechas ni hora: o es el principio de un título que
        /// sigue en la línea de abajo, o es un título suelto.
        var colgando: String?
        /// El título de la última línea con fechas, para las que continúan
        /// sin repetirlo («Noviembre M3, L9»).
        var ultimoTitulo: String?
        /// La última fecha, para saber cuándo se cambia de año.
        var ultima: Date?

        func soltarColgando() {
            if let c = colgando { lectura.ignoradas.append(c) }
            colgando = nil
        }

        let lineas = texto.precomposedStringWithCanonicalMapping
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        for linea in lineas {
            let ns = linea as NSString
            let todo = NSRange(location: 0, length: ns.length)
            let mesesEnLinea = mesRE.matches(in: linea, range: todo)

            // Sin mes: cabecera, título partido o algo que no es una fecha.
            guard !mesesEnLinea.isEmpty else {
                if let franja = franja(en: linea) {
                    soltarColgando()
                    seccion = nombreDeSeccion(linea)
                    horaDeSeccion = franja
                    diaDeSeccion = semanaRE.firstMatch(in: linea, range: todo).flatMap { m in
                        let palabra = ns.substring(with: m.range(at: 1)).lowercased()
                        return semana.first { palabra.range(of: "^\($0.0)$", options: .regularExpression) != nil }?.1
                    }
                    ultimoTitulo = nil
                } else {
                    soltarColgando()
                    colgando = linea
                }
                continue
            }

            // Con mes: dónde acaba el título y empiezan las fechas.
            let primerMes = mesesEnLinea[0].range.location
            let primerDia = diaRE.matches(in: linea, range: todo).first?.range.location ?? Int.max
            let empiezan = min(primerMes, primerDia)
            var titulo: String
            var fechas: String
            if let dosPuntos = linea.firstIndex(of: ":"),
               linea.distance(from: linea.startIndex, to: dosPuntos) < empiezan {
                titulo = String(linea[..<dosPuntos])
                fechas = String(linea[linea.index(after: dosPuntos)...])
            } else {
                titulo = ns.substring(to: empiezan)
                fechas = ns.substring(from: empiezan)
            }
            titulo = titulo.trimmingCharacters(in: CharacterSet(charactersIn: " ,;:-–"))

            // La hora puede venir en la propia línea; se quita antes de buscar
            // días, o «18:00» daría un 18.
            var minuto = horaDeSeccion?.minuto
            var duracion = horaDeSeccion?.duracion
            if let propia = franja(en: fechas) ?? hora(en: fechas) {
                minuto = propia.minuto
                duracion = propia.duracion ?? duracion
                fechas = quitarHoras(fechas)
            }

            let dias = leerDias(fechas)
            guard !dias.isEmpty else {
                // Mes sin día: «PEC (20%): noviembre y enero».
                soltarColgando()
                lectura.ignoradas.append(linea)
                continue
            }

            if titulo.isEmpty {
                titulo = ultimoTitulo ?? colgando ?? ""
                colgando = nil
            } else {
                if let c = colgando { titulo = c + " " + titulo }
                colgando = nil
                ultima = nil
            }
            ultimoTitulo = titulo

            for d in dias {
                var propuesta = Propuesta(titulo: titulo, dia: hoy, minuto: minuto,
                                          duracion: duracion, seccion: seccion)
                if let nota = d.nota, !nota.isEmpty { propuesta.titulo += " (\(nota))" }
                guard let fecha = resolver(mes: d.mes, dia: d.dia, despuesDe: ultima,
                                           hoy: hoy, calendar: calendar) else {
                    lectura.ignoradas.append("\(titulo): el \(d.dia) no existe en ese mes")
                    continue
                }
                ultima = fecha
                propuesta.dia = fecha
                let semanal = calendar.component(.weekday, from: fecha)
                if let letra = d.letra, let dice = inicial[letra], dice != semanal {
                    propuesta.aviso = "Dice \(nombreDia[dice]!), pero ese día es \(nombreDia[semanal]!)"
                } else if let dice = diaDeSeccion, dice != semanal {
                    propuesta.aviso = "La cabecera dice \(nombreDia[dice]!), pero ese día es \(nombreDia[semanal]!)"
                }
                lectura.propuestas.append(propuesta)
            }
        }
        soltarColgando()
        return lectura
    }

    // MARK: - Piezas

    private struct DiaLeido { var mes: Int; var dia: Int; var letra: Character?; var nota: String? }

    /// Los días de un trozo de texto, con su mes.
    ///
    /// Dos órdenes: «9, 16 y 23 octubre» —los días esperan al mes que viene
    /// detrás— y «Octubre L5, M13» —el mes manda sobre lo que le sigue—. Se
    /// decide por lo que sale primero.
    private static func leerDias(_ texto: String) -> [DiaLeido] {
        let ns = texto as NSString
        let todo = NSRange(location: 0, length: ns.length)
        enum Pieza { case mes(Int), dia(Character?, Int), nota(String) }
        var piezas: [(Int, Pieza)] = []
        for m in mesRE.matches(in: texto, range: todo) {
            let palabra = ns.substring(with: m.range(at: 1)).lowercased()
            if let n = meses.first(where: { $0.0 == palabra })?.1 { piezas.append((m.range.location, .mes(n))) }
        }
        let rangosDeMes = mesRE.matches(in: texto, range: todo).map(\.range)
        for m in diaRE.matches(in: texto, range: todo)
        where !rangosDeMes.contains(where: { NSIntersectionRange($0, m.range).length > 0 }) {
            let letra = m.range(at: 1).location == NSNotFound ? nil : ns.substring(with: m.range(at: 1)).first
            if let n = Int(ns.substring(with: m.range(at: 2))) { piezas.append((m.range.location, .dia(letra, n))) }
        }
        for m in notaRE.matches(in: texto, range: todo) {
            piezas.append((m.range.location, .nota(ns.substring(with: m.range(at: 1))
                .trimmingCharacters(in: .whitespaces))))
        }
        // Lo que va dentro de un paréntesis es la nota, no un día.
        let notas = notaRE.matches(in: texto, range: todo).map(\.range)
        piezas = piezas.filter { posicion, pieza in
            if case .nota = pieza { return true }
            return !notas.contains { NSLocationInRange(posicion, $0) }
        }
        piezas.sort { $0.0 < $1.0 }

        let mesPrimero: Bool = {
            for (_, p) in piezas {
                if case .mes = p { return true }
                if case .dia = p { return false }
            }
            return false
        }()
        var salida: [DiaLeido] = []
        var esperando: [DiaLeido] = []
        var mesActual: Int?
        for (_, pieza) in piezas {
            switch pieza {
            case .mes(let n):
                if mesPrimero {
                    salida += esperando.map { var d = $0; d.mes = mesActual ?? n; return d }
                } else {
                    salida += esperando.map { var d = $0; d.mes = n; return d }
                }
                esperando = []
                mesActual = n
            case .dia(let letra, let n):
                esperando.append(DiaLeido(mes: 0, dia: n, letra: letra, nota: nil))
            case .nota(let texto):
                if !esperando.isEmpty { esperando[esperando.count - 1].nota = texto }
                else if !salida.isEmpty { salida[salida.count - 1].nota = texto }
            }
        }
        if let mesActual {
            salida += esperando.map { var d = $0; d.mes = mesActual; return d }
        }
        return salida
    }

    /// La fecha de un día y un mes sin año.
    ///
    /// El primero de una lista cae en este año si no queda muy atrás —dos
    /// meses dan margen para pegar un calendario ya empezado— y si no en el
    /// siguiente. Los demás siguen al anterior, y cuando el mes retrocede
    /// —de diciembre a enero— es que se ha cambiado de año.
    private static func resolver(mes: Int, dia: Int, despuesDe anterior: Date?,
                                 hoy: Date, calendar: Calendar) -> Date? {
        func fecha(_ año: Int) -> Date? {
            var c = DateComponents(year: año, month: mes, day: dia)
            c.calendar = calendar
            guard c.isValidDate(in: calendar) else { return nil }
            return calendar.date(from: c)
        }
        if let anterior {
            let año = calendar.component(.year, from: anterior)
            let mesAnterior = calendar.component(.month, from: anterior)
            return fecha(mes < mesAnterior ? año + 1 : año)
        }
        let año = calendar.component(.year, from: hoy)
        guard let este = fecha(año) else { return nil }
        let limite = calendar.date(byAdding: .day, value: -60, to: calendar.startOfDay(for: hoy))!
        return este < limite ? fecha(año + 1) : este
    }

    private static func franja(en texto: String) -> (minuto: Int, duracion: Int?)? {
        let ns = texto as NSString
        let todo = NSRange(location: 0, length: ns.length)
        for re in [franjaRelojRE, franjaRE] {
            guard let m = re.firstMatch(in: texto, range: todo) else { continue }
            func n(_ i: Int) -> Int? {
                m.range(at: i).location == NSNotFound ? nil : Int(ns.substring(with: m.range(at: i)))
            }
            guard let h1 = n(1), let h2 = n(3), h1 < 24, h2 < 24 else { continue }
            let desde = h1 * 60 + (n(2) ?? 0), hasta = h2 * 60 + (n(4) ?? 0)
            return (desde, hasta > desde ? hasta - desde : nil)
        }
        return nil
    }

    private static func hora(en texto: String) -> (minuto: Int, duracion: Int?)? {
        let ns = texto as NSString
        guard let m = horaRE.firstMatch(in: texto, range: NSRange(location: 0, length: ns.length)),
              let h = Int(ns.substring(with: m.range(at: 1))), h < 24 else { return nil }
        let min = m.range(at: 2).location == NSNotFound ? 0 : Int(ns.substring(with: m.range(at: 2))) ?? 0
        return (h * 60 + min, nil)
    }

    private static func quitarHoras(_ texto: String) -> String {
        var salida = texto
        for re in [franjaRelojRE, franjaRE, horaRE] {
            salida = re.stringByReplacingMatches(in: salida, range: NSRange(location: 0, length: (salida as NSString).length),
                                                 withTemplate: " ")
        }
        return salida
    }

    /// «Fundamentos Sistemas Digitales (Viernes 17 a 18h)» → «Fundamentos
    /// Sistemas Digitales».
    private static func nombreDeSeccion(_ linea: String) -> String {
        var nombre = linea
        if let parentesis = nombre.firstIndex(of: "(") { nombre = String(nombre[..<parentesis]) }
        nombre = quitarHoras(nombre)
        let ns = nombre as NSString
        nombre = semanaRE.stringByReplacingMatches(in: nombre, range: NSRange(location: 0, length: ns.length),
                                                   withTemplate: "")
        return nombre.trimmingCharacters(in: CharacterSet(charactersIn: " ,;:-–"))
    }
}
