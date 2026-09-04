import Foundation

/// Cuánto dura algo, y cuánto suma un día.
///
/// Quince cosas en `Hoy` paralizan igual que ninguna, y la razón es que una
/// lista no dice cuánto ocupa: cabe todo hasta que se demuestra que no. La
/// estimación existe para que ese número se vea **antes** de que lo demuestre el
/// día.
///
/// La app no inventa una jornada de ocho horas contra la que comparar. No sabe
/// cuántas horas tienes ni tendría cómo saberlo, y una barra roja apoyada en una
/// cifra inventada sería una regañina sin fundamento. El total dicho en voz
/// alta ya hace el trabajo: «7 h 30 min» en un martes se lee solo.
public enum Duracion {
    /// «45 min», «2 h», «1 h 5 min».
    public static func etiqueta(_ minutos: Int) -> String {
        let horas = minutos / 60
        let resto = minutos % 60
        if horas == 0 { return "\(resto) min" }
        return resto == 0 ? "\(horas) h" : "\(horas) h \(resto) min"
    }

    /// Lo que suman las estimaciones de lo que sigue abierto.
    ///
    /// Lo completado no cuenta: ya no ocupa el día que queda.
    public static func total(_ items: [Item]) -> Int {
        abiertas(items).compactMap(\.estimate).reduce(0, +)
    }

    /// Cuántas de las abiertas no llevan estimación.
    ///
    /// Hay que poder decirlo, o la suma daría a entender que el día está medido
    /// cuando de tres tareas solo se midió una.
    public static func sinEstimar(_ items: [Item]) -> Int {
        abiertas(items).filter { $0.estimate == nil }.count
    }

    private static func abiertas(_ items: [Item]) -> [Item] {
        items.filter { !$0.isCompleted && $0.deletedAt == nil }
    }
}
