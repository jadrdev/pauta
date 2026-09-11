import Foundation

/// Un número de versión, comparado como número y no como texto.
///
/// Parece una tontería hasta que llega la 0.10.0: como cadena va **antes** que
/// la 0.9.0, y la app dejaría de avisar de versiones nuevas sin que nadie sepa
/// por qué. Los fallos que tardan meses en aparecer son los que nadie relaciona
/// con su causa.
public struct Version: Comparable, Equatable, Sendable, CustomStringConvertible {
    public let mayor: Int
    public let menor: Int
    public let parche: Int

    public init(mayor: Int, menor: Int, parche: Int) {
        self.mayor = mayor
        self.menor = menor
        self.parche = parche
    }

    /// Lee «0.3.0», «0.3» o «v0.3.0». La «v» la ponen las etiquetas del
    /// repositorio y no el plist de la app, así que las dos formas tienen que
    /// entrar por aquí.
    public init?(_ texto: String) {
        var limpio = texto.trimmingCharacters(in: .whitespaces)
        if limpio.first == "v" || limpio.first == "V" { limpio.removeFirst() }
        let partes = limpio.split(separator: ".", omittingEmptySubsequences: false)
        guard !partes.isEmpty, let mayor = Int(partes[0]) else { return nil }
        self.mayor = mayor
        self.menor = partes.count > 1 ? (Int(partes[1]) ?? 0) : 0
        self.parche = partes.count > 2 ? (Int(partes[2]) ?? 0) : 0
    }

    public var description: String { "\(mayor).\(menor).\(parche)" }

    public static func < (a: Version, b: Version) -> Bool {
        (a.mayor, a.menor, a.parche) < (b.mayor, b.menor, b.parche)
    }

    /// Si hay algo que anunciar. Una versión igual o anterior no es novedad, y
    /// avisar de la que ya tienes es la forma más rápida de que dejes de leer
    /// los avisos.
    public static func hayNovedad(tengo: Version, hay: Version) -> Bool { hay > tengo }
}

/// Una versión publicada, tal como la cuenta GitHub.
public struct Lanzamiento: Equatable, Sendable {
    public let version: Version
    public let nombre: String
    public let url: URL

    /// Lee la respuesta de la API. Devuelve `nil` si no se entiende, si la
    /// etiqueta no es un número de versión, o si es un borrador o una previa:
    /// nada de eso es una versión para quien usa la app.
    public static func desde(_ datos: Data) -> Lanzamiento? {
        struct Respuesta: Decodable {
            let tag_name: String
            let name: String?
            let html_url: String
            let draft: Bool?
            let prerelease: Bool?
        }
        guard let r = try? JSONDecoder().decode(Respuesta.self, from: datos) else { return nil }
        guard r.draft != true, r.prerelease != true else { return nil }
        guard let version = Version(r.tag_name), let url = URL(string: r.html_url) else { return nil }
        return Lanzamiento(version: version,
                           nombre: r.name?.isEmpty == false ? r.name! : "Pauta \(version)",
                           url: url)
    }
}


/// Preguntar si hay versión nueva.
///
/// A GitHub y no a un servidor propio: las versiones ya se publican ahí, y
/// montar un sitio para anunciar lo que ya está anunciado es infraestructura
/// que hay que mantener y que se puede caer. La consulta no necesita cuenta ni
/// clave.
///
/// Lo que **no** hace es instalar nada. Instalar sola una app descargada exige
/// que la app verifique la firma de lo que se baja, y esta se firma con un
/// certificado de desarrollo y sin notarizar: ahí el muro vuelve a ser la
/// cuenta de Apple y no el código. Así que esto avisa, y el resto lo haces tú
/// arrastrando, como hasta ahora.
public enum Novedades {
    public static let api = URL(string:
        "https://api.github.com/repos/jadrdev/pauta/releases/latest")!

    /// La última versión publicada, o `nil` si hoy no se puede saber.
    ///
    /// Sin errores hacia arriba a propósito: que no haya red, que GitHub esté
    /// caído o que conteste algo raro **no es un problema del usuario**. Se
    /// intentará mañana.
    public static func ultima(sesion: URLSession = .compartidaParaNovedades) async -> Lanzamiento? {
        var peticion = URLRequest(url: api)
        peticion.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        guard let (datos, respuesta) = try? await sesion.data(for: peticion),
              (respuesta as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return Lanzamiento.desde(datos)
    }
}

extension URLSession {
    /// Una sesión con paciencia corta y sin caché de disco: esto es una
    /// pregunta de fondo, no algo por lo que valga la pena esperar.
    public static let compartidaParaNovedades: URLSession = {
        let c = URLSessionConfiguration.ephemeral
        c.timeoutIntervalForRequest = 10
        c.waitsForConnectivity = false
        return URLSession(configuration: c)
    }()
}
