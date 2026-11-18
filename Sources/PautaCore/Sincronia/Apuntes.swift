import Foundation

/// Lo que escribe un almacén que no está enganchado a la sincronía.
///
/// En la app, el almacén de la interfaz avisa a `Sincronia` de cada objeto que
/// escribe (`Store.alEscribir`). Pero no es el único que escribe: el widget
/// completa tareas en su propio proceso, el atajo de Siri apunta con un
/// almacén suyo, los botones de un aviso y el refresco en segundo plano abren
/// el suyo. Ninguno tiene a quién avisar, y lo que escribían se quedaba en el
/// aparato sin subir hasta que otra cosa tocara ese mismo objeto.
///
/// Así que lo apuntan aquí: un archivo vacío por objeto en
/// `<raiz>/.sincronia/apuntes/`, con lo que hay que hacer en el nombre
/// (`guardar-Item-<id>`, `borrar-Item-<id>`). La app los recoge al sincronizar,
/// los pone en la cola y los quita. Un nombre por objeto y no una lista:
/// escribir dos veces el mismo objeto deja un solo apunte, y dos procesos
/// apuntando a la vez no se pisan un archivo común.
///
/// Solo se apunta donde hay sincronía: si no existe `.sincronia` en la carpeta,
/// no hay nadie que vaya a recogerlo, y en un Mac sin mudar esa carpeta es la
/// de iCloud Drive, donde cada apunte sería un archivo más que sincronizar.
public enum Apuntes {
    enum Que: String { case guardar, borrar }

    static func carpeta(en raiz: URL) -> URL {
        MudanzaACloudKit.carpetaDelEstado(en: raiz).appendingPathComponent("apuntes", isDirectory: true)
    }

    /// Si en esta carpeta hay sincronía que vaya a recoger los apuntes.
    public static func hayQuienRecoja(en raiz: URL) -> Bool {
        FileManager.default.fileExists(atPath: MudanzaACloudKit.carpetaDelEstado(en: raiz).path)
    }

    public static func apuntar(guardar: [Ficha.Clave] = [], borrar: [Ficha.Clave] = [], en raiz: URL) {
        guard hayQuienRecoja(en: raiz), !(guardar.isEmpty && borrar.isEmpty) else { return }
        let dir = carpeta(en: raiz)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for (que, claves) in [(Que.guardar, guardar), (.borrar, borrar)] {
            for clave in claves {
                let nombre = "\(que.rawValue)-\(clave.tipo.rawValue)-\(clave.id.uuidString)"
                FileManager.default.createFile(atPath: dir.appendingPathComponent(nombre).path,
                                               contents: nil)
            }
        }
    }

    /// Lo apuntado, y los archivos que lo dicen, para quitarlos una vez en la
    /// cola. Lo que no se entiende se quita también: nadie va a entenderlo
    /// después.
    public static func recoger(en raiz: URL) -> (guardar: [Ficha.Clave], borrar: [Ficha.Clave], archivos: [URL]) {
        let archivos = (try? FileManager.default.contentsOfDirectory(
            at: carpeta(en: raiz), includingPropertiesForKeys: nil)) ?? []
        var guardar: [Ficha.Clave] = []
        var borrar: [Ficha.Clave] = []
        for archivo in archivos {
            let partes = archivo.lastPathComponent.split(separator: "-", maxSplits: 2).map(String.init)
            guard partes.count == 3, let que = Que(rawValue: partes[0]),
                  let tipo = Ficha.Tipo(rawValue: partes[1]), let id = UUID(uuidString: partes[2])
            else { continue }
            switch que {
            case .guardar: guardar.append(Ficha.Clave(tipo, id))
            case .borrar: borrar.append(Ficha.Clave(tipo, id))
            }
        }
        return (guardar, borrar, archivos)
    }

    public static func olvidar(_ archivos: [URL]) {
        for archivo in archivos { try? FileManager.default.removeItem(at: archivo) }
    }
}
