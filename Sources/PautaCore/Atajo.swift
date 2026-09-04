import Foundation

/// Una combinación de teclas: el código de la tecla y los modificadores.
///
/// Los valores de los modificadores son **los de Carbon**, que es quien registra
/// el atajo global. Se definen aquí, donde vive la preferencia, para que no haya
/// dos tablas de bits que puedan discrepar; la app las pasa tal cual a
/// `RegisterEventHotKey`.
public struct Atajo: Equatable, Sendable, Codable {
    public static let control = 0x1000
    public static let option = 0x0800
    public static let command = 0x0100
    public static let shift = 0x0200

    /// Código de tecla virtual (`kVK_…`).
    public let tecla: Int
    public let modificadores: Int

    public init(tecla: Int, modificadores: Int) {
        self.tecla = tecla
        self.modificadores = modificadores
    }

    /// El de fábrica: ⌃Espacio, que es el que la gente ya tiene en los dedos
    /// —lo usa Things— y no pisa a Spotlight.
    public static let porDefecto = Atajo(tecla: 49, modificadores: control)

    /// Si sirve como atajo global.
    ///
    /// Hace falta ⌃, ⌥ o ⌘. Sin uno de esos, el atajo se comería una tecla en
    /// **todas las apps**: dejar «A» como alta rápida es dejar de poder escribir
    /// una a en cualquier sitio. Mayúsculas no cuenta, que ⇧A sigue siendo
    /// escribir.
    public var esUsable: Bool {
        modificadores & (Atajo.control | Atajo.option | Atajo.command) != 0
    }

    /// Los símbolos de los modificadores, en el orden en que los escribe macOS.
    public var simbolos: String {
        var s = ""
        if modificadores & Atajo.control != 0 { s += "⌃" }
        if modificadores & Atajo.option != 0 { s += "⌥" }
        if modificadores & Atajo.shift != 0 { s += "⇧" }
        if modificadores & Atajo.command != 0 { s += "⌘" }
        return s
    }
}
