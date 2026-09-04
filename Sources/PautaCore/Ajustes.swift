import Foundation
import Observation

/// Las preferencias de la app.
///
/// Hay pocas a propósito. Un ajuste por cada decisión de diseño convierte la app
/// en un panel de control y hace que todos los valores por defecto parezcan
/// arbitrarios; la lista de abajo es corta porque solo está lo que **cambia de
/// persona a persona**: a qué hora te viene bien el repaso, cuánto necesitas de
/// margen, cuánto es «un ratito» para ti, y cuánto sitio te sobra en la barra de
/// menús.
///
/// Lo que no está y no va a estar: el umbral de lo rancio, la ventana de la
/// cuenta atrás, la duración de una jornada contra la que medir el día. Son
/// juicios de la app, y volverlos ajustables sería pedirle al usuario que los
/// tome él sin darle con qué.
///
/// Se guarda en `UserDefaults` y no en la carpeta de datos: son preferencias de
/// **este Mac** —la hora a la que te levantas aquí, el sitio que te sobra en
/// esta pantalla— y no cosas que deban viajar con las tareas.
@Observable
@MainActor
public final class Ajustes {
    /// `var` y no `let` para que la maqueta pueda sustituirlo por uno de
    /// mentira antes de que nada lo use: `--demo` promete no tocar tus datos, y
    /// las preferencias son datos.
    public static var shared = Ajustes()

    /// Preferencias de usar y tirar, en su propio dominio y en blanco.
    public static func paraMaqueta() -> Ajustes {
        let nombre = "dev.jadrdev.pauta.maqueta"
        let d = UserDefaults(suiteName: nombre)!
        d.removePersistentDomain(forName: nombre)
        return Ajustes(defaults: d)
    }

    @ObservationIgnored private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // Tres casos y no dos: sin nada guardado va el de fábrica, el centinela
        // de apagado vuelve a `nil`, y cualquier otro es la hora elegida. Sin
        // esta traducción, apagarlo se leería como «las 23:59 menos un minuto».
        switch Ajustes.leer(defaults, .repaso) {
        case nil: repasoHora = Ajustes.repasoPorDefecto
        case Ajustes.apagado: repasoHora = nil
        case let guardada: repasoHora = guardada
        }
        margenPorDefecto = Ajustes.leer(defaults, .margen) ?? 0
        minutosAplazados = Ajustes.leer(defaults, .aplazar) ?? 10
        barraConCuenta = defaults.object(forKey: Clave.barra.rawValue) as? Bool ?? true
    }

    private enum Clave: String {
        case repaso = "repaso.hora"
        case margen = "aviso.margen"
        case aplazar = "aviso.aplazar"
        case barra = "barra.cuenta"
    }

    /// El apagado se guarda como valor propio y no como ausencia: sin
    /// distinguirlos, apagar el repaso duraría hasta el siguiente arranque, que
    /// volvería a leer «no hay nada guardado» y lo daría por encendido.
    static let apagado = -1
    public static let repasoPorDefecto = 8 * 60 + 30

    private static func leer(_ d: UserDefaults, _ clave: Clave) -> Int? {
        d.object(forKey: clave.rawValue) as? Int
    }

    /// A qué hora suena el repaso, en minutos desde medianoche. `nil` = apagado.
    public var repasoHora: Int? {
        didSet {
            defaults.set(repasoHora.map { max(0, min(24 * 60 - 1, $0)) } ?? Ajustes.apagado,
                         forKey: Clave.repaso.rawValue)
        }
    }

    /// Minutos de antelación que se le ponen a una hora nueva. 0 = a la hora.
    ///
    /// Es un valor **inicial y no una regla**: se aplica al ponerle la hora a una
    /// tarea, y desde ahí la tarea manda. Si fuera una regla viva, cambiarlo
    /// reescribiría en silencio el margen de todas las tareas ya puestas.
    public var margenPorDefecto: Int {
        didSet { defaults.set(max(0, min(24 * 60, margenPorDefecto)),
                              forKey: Clave.margen.rawValue) }
    }

    /// Cuánto aplaza el botón de aplazar.
    public var minutosAplazados: Int {
        didSet { defaults.set(max(1, min(24 * 60, minutosAplazados)),
                              forKey: Clave.aplazar.rawValue) }
    }

    /// Si la barra de menús enseña la cuenta atrás además del icono.
    public var barraConCuenta: Bool {
        didSet { defaults.set(barraConCuenta, forKey: Clave.barra.rawValue) }
    }

    /// Vuelve a dejarlo todo como venía de fábrica.
    public func restaurar() {
        repasoHora = Ajustes.repasoPorDefecto
        margenPorDefecto = 0
        minutosAplazados = 10
        barraConCuenta = true
    }
}
