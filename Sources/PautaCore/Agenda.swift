import Foundation
import EventKit
import Observation
import os

/// Un evento del calendario, tal como lo enseña Pauta.
///
/// Es una copia de lectura y **no se guarda nunca**. Si los eventos entraran en
/// el almacén acabarían escritos en la carpeta como copias del calendario de
/// verdad, y dos copias de lo mismo terminan discrepando: se edita el evento
/// fuera y aquí queda la versión vieja para siempre. La fuente es el calendario;
/// esto es lo que se lee de él cada vez.
public struct Evento: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let start: Date
    public let end: Date
    public let isAllDay: Bool
    public let calendarName: String
    public let color: RGB?

    public init(id: String, title: String, start: Date, end: Date,
                isAllDay: Bool, calendarName: String, color: RGB?) {
        self.id = id
        self.title = title
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.calendarName = calendarName
        self.color = color
    }

    /// «9:00 – 10:30», o solo la hora de inicio si no dura nada.
    public var timeLabel: String {
        if isAllDay { return "Todo el día" }
        let desde = start.formatted(.dateTime.hour().minute())
        guard end > start else { return desde }
        return "\(desde) – \(end.formatted(.dateTime.hour().minute()))"
    }

    public func hasPassed(_ now: Date = .now) -> Bool { !isAllDay && end <= now }
}

/// El color del calendario, ya en sRGB. Se guarda descompuesto y no como
/// `CGColor` para que `PautaCore` siga sin saber nada de dibujar.
public struct RGB: Hashable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }
}

/// Una fila del día: lo que hay que hacer y lo que ya está comprometido.
public enum FilaDelDia: Identifiable, Hashable {
    case tarea(Item)
    case evento(Evento)

    public var id: String {
        switch self {
        case .tarea(let item): "t:\(item.id.uuidString)"
        case .evento(let evento): "e:\(evento.id)"
        }
    }
}

/// Los eventos de hoy, leídos del calendario del sistema.
///
/// Van como fuente aparte y se mezclan **solo en la vista**. Al revés —escribir
/// las tareas de Pauta como eventos del calendario— sería mala idea: duplicaría
/// cada tarea en dos sitios que se editan por separado y hay que reconciliar.
@Observable
@MainActor
public final class Agenda {
    public private(set) var eventos: [Evento] = []
    /// El día que se está enseñando, para no releer sin motivo.
    private var diaCargado: Date?

    private let ek = EKEventStore()
    private let log = Logger(subsystem: "dev.jadrdev.pauta", category: "calendario")
    /// El testigo del observador, en una caja. `deinit` no puede entrar en el
    /// actor principal y una propiedad observable no admite `nonisolated`, así
    /// que la caja —que sí es constante— es lo que permite soltarlo al morir en
    /// vez de dejarlo avisando al vacío.
    @ObservationIgnored private let testigo = Testigo()

    private final class Testigo: @unchecked Sendable {
        var valor: (any NSObjectProtocol)?
    }

    public init() {
        // El calendario cambia por fuera —se acepta una invitación, se mueve una
        // reunión— y la lista tiene que enterarse sin reabrir la app.
        testigo.valor = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged, object: ek, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let dia = self.diaCargado else { return }
                await self.load(dia, force: true)
            }
        }
    }

    deinit {
        if let valor = testigo.valor { NotificationCenter.default.removeObserver(valor) }
    }

    public static var authorization: EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .event)
    }

    public static var isAuthorized: Bool {
        authorization == .fullAccess
    }

    @discardableResult
    public func requestAccess() async -> Bool {
        do {
            let granted = try await ek.requestFullAccessToEvents()
            if !granted { log.notice("acceso al calendario no concedido") }
            return granted
        } catch {
            log.error("no se pudo pedir acceso al calendario: \(error.localizedDescription)")
            return false
        }
    }

    /// Lee los eventos de un día. Sin permiso deja la lista vacía y no insiste.
    public func load(_ day: Date = .now, force: Bool = false) async {
        let inicio = Calendar.current.startOfDay(for: day)
        guard force || diaCargado != inicio else { return }
        diaCargado = inicio

        guard Agenda.isAuthorized else {
            if !eventos.isEmpty { eventos = [] }
            return
        }
        guard let fin = Calendar.current.date(byAdding: .day, value: 1, to: inicio) else { return }

        let predicado = ek.predicateForEvents(withStart: inicio, end: fin, calendars: nil)
        let leidos = ek.events(matching: predicado)
            .filter { $0.status != .canceled }
            .map(Agenda.convertir)
            .sorted(by: Agenda.antes)
        if leidos != eventos { eventos = leidos }
    }

    /// Vacía la lista, para cuando se deja de mirar el día.
    public func clear() {
        diaCargado = nil
        if !eventos.isEmpty { eventos = [] }
    }

    /// Eventos inventados para la maqueta. No tocan el calendario del sistema
    /// ni piden permiso: `--demo` sirve para mirar el diseño, no los datos.
    public func seedForDemo() {
        let cal = Calendar.current
        let base = cal.startOfDay(for: .now)
        func e(_ titulo: String, _ desde: Int, _ minutos: Int,
               _ agenda: String, _ color: RGB, todoElDia: Bool = false) -> Evento {
            let inicio = cal.date(byAdding: .minute, value: desde, to: base) ?? base
            return Evento(id: titulo, title: titulo, start: inicio,
                          end: inicio.addingTimeInterval(TimeInterval(minutos * 60)),
                          isAllDay: todoElDia, calendarName: agenda, color: color)
        }
        eventos = [
            e("Día de la Cruz", 0, 24 * 60, "Festivos",
              RGB(red: 0.95, green: 0.61, blue: 0.16), todoElDia: true),
            e("Reunión de equipo", 10 * 60, 60, "Trabajo",
              RGB(red: 0.30, green: 0.55, blue: 0.95)),
            e("Comida con Ana", 14 * 60, 90, "Personal",
              RGB(red: 0.36, green: 0.78, blue: 0.45)),
            e("Fisioterapeuta", 18 * 60 + 30, 45, "Personal",
              RGB(red: 0.36, green: 0.78, blue: 0.45)),
        ]
    }

    static func antes(_ a: Evento, _ b: Evento) -> Bool {
        if a.isAllDay != b.isAllDay { return a.isAllDay }
        return a.start == b.start ? a.title < b.title : a.start < b.start
    }

    private static func convertir(_ e: EKEvent) -> Evento {
        Evento(id: e.eventIdentifier ?? UUID().uuidString,
               title: (e.title ?? "").isEmpty ? "Sin título" : e.title,
               start: e.startDate,
               end: e.endDate,
               isAllDay: e.isAllDay,
               calendarName: e.calendar?.title ?? "",
               color: e.calendar?.cgColor.flatMap(RGB.init(cgColor:)))
    }

    /// Mezcla las tareas del día con los eventos, en el orden en que se lee un
    /// día: primero lo de todo el día, luego lo que tiene hora —da igual si es
    /// evento o tarea— y por último lo que no tiene hora, en su orden manual.
    ///
    /// Los eventos no se cuelan en el orden manual: no son tuyos, no se
    /// reordenan, y una reunión a las diez es a las diez.
    public static func filas(tareas: [Item], eventos: [Evento]) -> [FilaDelDia] {
        let todoElDia = eventos.filter(\.isAllDay).map(FilaDelDia.evento)

        var conHora: [(Date, FilaDelDia)] = eventos
            .filter { !$0.isAllDay }
            .map { ($0.start, .evento($0)) }
        for tarea in tareas {
            guard let minutos = tarea.timeOfDay else { continue }
            let base = Calendar.current.startOfDay(for: tarea.when ?? .now)
            let momento = Calendar.current.date(byAdding: .minute, value: minutos, to: base) ?? base
            conHora.append((momento, .tarea(tarea)))
        }
        // Estable: a igual hora se respeta el orden en que venían, que para las
        // tareas es su prioridad manual.
        let ordenadas = conHora.enumerated()
            .sorted { $0.element.0 == $1.element.0 ? $0.offset < $1.offset
                                                  : $0.element.0 < $1.element.0 }
            .map(\.element.1)

        let sinHora = tareas.filter { $0.timeOfDay == nil }.map(FilaDelDia.tarea)
        return todoElDia + ordenadas + sinHora
    }
}

extension RGB {
    /// Pasa un color de calendario a sRGB. Puede venir en otro espacio, y
    /// leerle las componentes tal cual daría colores equivocados.
    init?(cgColor: CGColor) {
        guard let sRGB = CGColorSpace(name: CGColorSpace.sRGB),
              let convertido = cgColor.converted(to: sRGB, intent: .defaultIntent, options: nil),
              let c = convertido.components, c.count >= 3
        else { return nil }
        self.init(red: Double(c[0]), green: Double(c[1]), blue: Double(c[2]))
    }
}
