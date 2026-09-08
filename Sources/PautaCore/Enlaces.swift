import Foundation

/// Los enlaces de la app.
///
/// En el núcleo y no en cada interfaz: son los mismos en el Mac y en el
/// teléfono, y dos copias de una dirección es una dirección que un día apunta a
/// dos sitios distintos.
public enum Enlaces {
    public static let repositorio = URL(string: "https://github.com/jadrdev/pauta")!
    public static let autor = URL(string: "https://github.com/jadrdev")!
    public static let guia = URL(string: "https://github.com/jadrdev/pauta#readme")!
    public static let novedades = URL(string: "https://github.com/jadrdev/pauta/releases")!
    public static let problemas = URL(string: "https://github.com/jadrdev/pauta/issues")!
}
