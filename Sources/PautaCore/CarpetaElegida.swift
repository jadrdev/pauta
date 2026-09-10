import Foundation

/// La carpeta del Mac, elegida a mano una vez.
///
/// En iOS una app solo entra donde le dejan, y lo que le deja entrar en una
/// carpeta de iCloud Drive es que **tú la elijas** en el selector del sistema.
/// Lo que se guarda de esa elección no es la ruta —una ruta no da permiso— sino
/// un **marcador**: un puñado de bytes que el sistema sabe volver a convertir en
/// una carpeta con permiso.
///
/// El precio, dicho por delante: el marcador se puede romper. Si mueves o
/// renombras la carpeta, deja de resolver, y una sincronización que se detiene
/// en silencio es peor que no tenerla. Por eso esto no falla callando: guarda si
/// caducó, y la pantalla de ajustes lo dice y pide elegirla otra vez.
@MainActor
@Observable
public final class CarpetaElegida {
    public static let shared = CarpetaElegida()

    private let defaults: UserDefaults
    private let clave = "carpetaDelMac"

    /// La carpeta, si se ha podido abrir. Con el permiso ya activo.
    public private(set) var url: URL?
    /// El marcador existía y ya no resuelve: la carpeta se movió, se renombró o
    /// se fue con el permiso.
    public private(set) var caducada = false

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Si hay algo elegido, aunque hoy no se pueda abrir.
    public var elegida: Bool { defaults.data(forKey: clave) != nil }

    /// Guarda la elección. Devuelve si el marcador se pudo crear.
    @discardableResult
    public func elegir(_ carpeta: URL) -> Bool {
        // El ámbito se abre **antes** de crear el marcador: la URL que llega del
        // selector viene con permiso prestado, y sin abrirlo el marcador se
        // crea a medias en algunos casos.
        let abierto = carpeta.startAccessingSecurityScopedResource()
        defer { if abierto { carpeta.stopAccessingSecurityScopedResource() } }
        guard let datos = try? carpeta.bookmarkData() else { return false }
        defaults.set(datos, forKey: clave)
        caducada = false
        abrir()
        return url != nil
    }

    public func olvidar() {
        if let url { url.stopAccessingSecurityScopedResource() }
        defaults.removeObject(forKey: clave)
        url = nil
        caducada = false
    }

    /// Resuelve el marcador y deja el permiso abierto mientras la app viva.
    ///
    /// Se abre y no se cierra a cada rato a propósito: el almacén lee y escribe
    /// cuando le toca, y cerrar el ámbito entre medias dejaría escrituras fuera
    /// del permiso. Al morir el proceso lo cierra el sistema.
    @discardableResult
    public func abrir() -> URL? {
        guard let datos = defaults.data(forKey: clave) else {
            url = nil
            return nil
        }
        var vieja = false
        guard let resuelta = try? URL(resolvingBookmarkData: datos,
                                      options: [],
                                      relativeTo: nil,
                                      bookmarkDataIsStale: &vieja),
              resuelta.startAccessingSecurityScopedResource() else {
            url = nil
            caducada = true
            return nil
        }
        // Un marcador «viejo» sigue sirviendo, pero conviene renovarlo: si no,
        // el siguiente arranque puede ser el que ya no resuelva.
        if vieja, let nuevos = try? resuelta.bookmarkData() {
            defaults.set(nuevos, forKey: clave)
        }
        caducada = false
        url = resuelta
        return resuelta
    }
}
