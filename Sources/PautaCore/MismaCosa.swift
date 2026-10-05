import Foundation

/// Cuándo una tarea y un evento son la misma cosa apuntada dos veces.
///
/// Pasa sin querer: se crea el evento en el calendario y se apunta la tarea
/// para no olvidarla, y Hoy enseña «Sesión Inicio UNED 18:00 – 19:00» y debajo
/// «Sección de Inicio de Uned 18:00». Dos filas para una sola cosa.
///
/// La regla es estricta a propósito, porque juntar dos cosas distintas es peor
/// que enseñar dos veces la misma: **la misma hora de inicio**, al minuto, y
/// **al menos dos palabras del título en común** —o la única, si uno de los dos
/// solo tiene una—. Las palabras se comparan sin mayúsculas ni tildes y sin las
/// que no dicen nada («de», «la», «con»…). «Sesión» y «Sección» no son la misma
/// palabra; «inicio» y «uned» bastan.
public enum MismaCosa {
    static let vacias: Set<String> = [
        "de", "del", "la", "el", "los", "las", "lo", "y", "e", "o", "u", "a", "al",
        "en", "con", "por", "para", "un", "una", "unos", "unas", "que", "se", "mi",
        "tu", "su", "sus", "mis",
    ]

    static func palabras(_ titulo: String) -> Set<String> {
        let plano = titulo.folding(options: [.caseInsensitive, .diacriticInsensitive],
                                   locale: Locale(identifier: "es_ES"))
        let trozos = plano.split { !$0.isLetter && !$0.isNumber }.map(String.init)
        return Set(trozos.filter { !vacias.contains($0) })
    }

    public static func titulos(_ uno: String, _ otro: String) -> Bool {
        let a = palabras(uno), b = palabras(otro)
        guard !a.isEmpty, !b.isEmpty else { return false }
        let comunes = a.intersection(b).count
        return comunes >= min(2, min(a.count, b.count))
    }
}
