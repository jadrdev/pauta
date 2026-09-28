import Foundation

/// Los emojis que se ofrecen para proyectos y áreas.
///
/// Curados y no el teclado entero del sistema: entre unas decenas se escoge de
/// un vistazo, entre miles no. Por temas, una fila cada uno, que es lo que hace
/// que cuarenta se sigan leyendo de un vistazo. Viven en el núcleo para que el
/// Mac y el teléfono ofrezcan exactamente los mismos.
public enum Iconos {
    public static let temas: [(nombre: String, emojis: [String])] = [
        ("Trabajo", ["💼", "💻", "📱", "🖥️", "🌐", "🧾", "📊", "🚀"]),
        ("Estudiar y crear", ["📚", "🎓", "✍️", "🎨", "🎬", "📷", "🎸", "🎵"]),
        ("Casa y fuera", ["🏠", "🛒", "🍳", "🧹", "🚗", "✈️", "🎁", "🐾"]),
        ("Cuerpo y ocio", ["💪", "🩺", "⚽️", "🎮", "🌱", "☕️", "❤️", "🧠"]),
        ("Para marcar", ["📌", "⭐️", "🔥", "🎯", "💡", "💰", "🛠️", "📦"]),
    ]

    public static var paleta: [String] { temas.flatMap(\.emojis) }

    /// El último emoji de lo escrito, o `nil` si no hay ninguno: es lo que se
    /// queda cuando alguien escribe o pega en «Otro». El último y no el primero,
    /// porque escribir encima de uno ya puesto es cambiarlo.
    ///
    /// Un número o una almohadilla también son «emoji» para Unicode —pueden
    /// serlo en 1️⃣—, así que sueltos no cuentan: solo lo que se dibuja como
    /// emoji por sí mismo o lo que va compuesto.
    public static func emoji(en texto: String) -> String? {
        texto.reversed().first { c in
            c.unicodeScalars.contains { $0.properties.isEmojiPresentation }
                || (c.unicodeScalars.count > 1
                    && c.unicodeScalars.contains { $0.properties.isEmoji })
        }.map(String.init)
    }
}
