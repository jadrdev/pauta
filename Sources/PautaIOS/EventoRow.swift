import SwiftUI
import PautaCore

/// Un evento del calendario en la lista de Hoy.
///
/// Se distingue de una tarea a la primera y sin leerlo: **barra de color en vez
/// de casilla**. Un evento no se completa —ocurre—, así que darle algo redondo
/// que parezca pulsable sería prometer un gesto que no existe. El color es el de
/// su calendario, que es como se reconocen de un vistazo.
struct EventoRow: View {
    let evento: Evento

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(color)
                .frame(width: 3.5, height: 19)
                .padding(.leading, 9)
                .padding(.trailing, 5)
            Text(evento.title)
                .font(.system(size: 16.5))
                .foregroundStyle(pasado ? Papel.inkFaint : Papel.inkSoft)
                .strikethrough(pasado, color: Papel.hairline)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Text(evento.timeLabel)
                .font(.system(size: 13.5).monospacedDigit())
                .foregroundStyle(Papel.inkFaint)
        }
    }

    /// Lo que ya pasó se apaga: sigue explicando por qué el día iba lleno, pero
    /// deja de competir por la atención con lo que queda.
    private var pasado: Bool { evento.hasPassed() }

    private var color: Color {
        guard let c = evento.color else { return Papel.inkFaint }
        return Color(.sRGB, red: c.red, green: c.green, blue: c.blue)
            .opacity(pasado ? 0.45 : 1)
    }
}
