import Foundation

/// La app con tareas de muestra, para las capturas de la App Store.
///
/// Solo se activa lanzándola con `-demo`, cosa que un usuario no puede hacer:
/// el almacén es el de muestra del Mac (`Store.demo()`), en memoria, y no
/// cruza con iCloud ni hace copias. Tampoco toca nada de fuera: ni programa
/// avisos (ni pide permiso para ellos), ni publica al widget, al reloj o al
/// globo del icono. Así las capturas enseñan una app con vida
/// sin enseñar las tareas de nadie.
///
///     -demo                       tareas de muestra
///     -vista proximamente         la pestaña de arranque (hoy, proximamente,
///                                 bandeja, mas)
///     -abrir "Regar las plantas"  abre esa tarea en Hoy
enum Maqueta {
    static let activa = ProcessInfo.processInfo.arguments.contains("-demo")

    static var vista: String? { valor("-vista") }
    static var abrir: String? { valor("-abrir") }

    private static func valor(_ clave: String) -> String? {
        let args = ProcessInfo.processInfo.arguments
        guard activa, let i = args.firstIndex(of: clave), i + 1 < args.count else { return nil }
        return args[i + 1]
    }
}
