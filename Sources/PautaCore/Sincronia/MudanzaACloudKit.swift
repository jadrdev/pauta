import Foundation

/// La mudanza del almacén del Mac a una carpeta local, para sincronizar con
/// CloudKit (docs/plan-cloudkit.md, fase 2).
///
/// Con CloudKit, lo que viaja son registros y no archivos: el almacén no tiene
/// por qué vivir en iCloud Drive, y vivir ahí es lo que lo hacía depender de
/// que iCloud bajara los archivos. Así que sale del contenedor a una carpeta
/// local, **al lado** de las de siempre y no dentro:
///
/// - `Application Support/Pauta` no: ahí siguen las tareas de agosto de antes
///   de iCloud, y en un Mac sin iCloud es su almacén de hoy.
/// - Una subcarpeta suya tampoco: la copia de antes de la mudanza se copiaría
///   a sí misma.
///
/// Es la misma mudanza que la del contenedor, con las mismas piezas: copia
/// completa de antes, cruce con el Puente y comprobación. Solo si cuadra se
/// apunta, y el almacén la usa **desde el siguiente arranque**.
public enum MudanzaACloudKit {
    /// La carpeta del almacén después de la mudanza.
    public nonisolated static var carpeta: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("dev.jadrdev.pauta", isDirectory: true)
    }

    /// Dónde guarda la sincronía su estado: **dentro** del almacén pero en una
    /// carpeta que el Puente no cruza nunca —solo cruza `items`, `projects`,
    /// `areas` y los adjuntos—. Es de este aparato y no viaja.
    public nonisolated static func carpetaDelEstado(en raiz: URL) -> URL {
        raiz.appendingPathComponent(".sincronia", isDirectory: true)
    }

    static let claveMudado = "cloudkit.mudadoDesde"

    public static func mudadoDesde(_ defaults: UserDefaults = .standard) -> Date? {
        defaults.object(forKey: claveMudado) as? Date
    }

    public static func marcarMudado(_ cuando: Date = .now, _ defaults: UserDefaults = .standard) {
        defaults.set(cuando, forKey: claveMudado)
    }

    /// La carpeta del almacén: la local nueva si la mudanza se comprobó **y**
    /// la carpeta existe; si no, la de antes. Equivocarse hacia la de antes deja
    /// todo como estaba; hacia una carpeta vacía enseñaría una app sin nada.
    public static func raiz(mudado: Bool, nueva: URL, antes: URL) -> URL {
        if mudado, FileManager.default.fileExists(atPath: nueva.path) { return nueva }
        return antes
    }

    /// Lleva lo de `antes` a la carpeta nueva y comprueba que no se queda nada
    /// atrás. Es un cruce: repetirlo no estropea nada, y si se corta a medias
    /// el siguiente intento cruza lo que faltaba.
    public static func mudar(desde antes: URL, a nueva: URL,
                             enLocal: (URL) -> Bool = Puente.enLocal) -> Mudanza.Resultado {
        try? FileManager.default.createDirectory(at: nueva, withIntermediateDirectories: true)
        return Mudanza.mudar(desde: antes, a: nueva, enLocal: enLocal)
    }
}
