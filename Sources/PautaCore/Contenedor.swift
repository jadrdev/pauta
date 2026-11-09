import Foundation

/// El contenedor de iCloud propio de la app: la carpeta que el Mac, el iPhone y
/// el iPad ven sin que nadie elija nada.
///
/// Hasta noviembre de 2026 no podía existir —la cuenta era un equipo personal,
/// y Apple no emite iCloud para esos—, y por eso el Mac guarda en
/// `iCloud Drive/Pauta` por ruta y el teléfono cruza con una carpeta que eliges
/// a mano. El plan para pasar aquí está en docs/plan-contenedor-icloud.md.
public enum Contenedor {
    public static let identificador = "iCloud.dev.jadrdev.pauta"

    /// La carpeta `Documents` del contenedor, o `nil` si en este aparato no hay
    /// iCloud o la firma no lleva el permiso.
    ///
    /// **Bloquea**: la primera vez el sistema prepara el contenedor, y Apple
    /// pide no llamarlo desde el hilo principal.
    public static func documentos() -> URL? {
        FileManager.default.url(forUbiquityContainerIdentifier: identificador)?
            .appendingPathComponent("Documents", isDirectory: true)
    }

    /// La misma carpeta en el Mac, calculada sin preguntar al sistema.
    ///
    /// El almacén la necesita al arrancar, y `documentos()` bloquea. En el Mac,
    /// que no va en sandbox, la ruta es fija; si no existe todavía es que este
    /// Mac no ha preparado el contenedor, y entonces no se usa.
    public static var rutaEnElMac: URL? {
        #if os(macOS)
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Mobile Documents", isDirectory: true)
            .appendingPathComponent(identificador.replacingOccurrences(of: ".", with: "~"),
                                    isDirectory: true)
            .appendingPathComponent("Documents", isDirectory: true)
        #else
        nil
        #endif
    }
}
