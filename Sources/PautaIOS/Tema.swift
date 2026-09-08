import SwiftUI
import UIKit
import PautaCore

extension UIColor {
    convenience init(rgb hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  alpha: 1)
    }
}

extension Color {
    /// Color dinámico: lo resuelve el sistema según el modo claro u oscuro.
    ///
    /// Los números salen de `Paleta`, en el núcleo, y no de una copia: son los
    /// mismos que usa el Mac, y así una corrección de contraste vale para las
    /// dos interfaces.
    static func dyn(_ par: Paleta.Par) -> Color {
        Color(UIColor { rasgos in
            UIColor(rgb: rasgos.userInterfaceStyle == .dark ? par.oscuro : par.claro)
        })
    }
}

/// La misma paleta del Mac, resuelta para el teléfono.
enum Papel {
    static let bg = Color.dyn(Paleta.bg)
    static let bgSide = Color.dyn(Paleta.bgSide)
    static let ink = Color.dyn(Paleta.ink)
    static let inkSoft = Color.dyn(Paleta.inkSoft)
    static let inkFaint = Color.dyn(Paleta.inkFaint)
    static let hairline = Color.dyn(Paleta.hairline)
    static let accent = Color.dyn(Paleta.accent)
    static let accentInk = Color.dyn(Paleta.accentInk)
    static let warning = Color.dyn(Paleta.warning)
}

extension Font {
    /// Los rótulos en versalitas del Mac, un punto más grandes: en un teléfono
    /// se lee a un brazo de distancia y en movimiento.
    static let rubrica = Font.system(size: 11.5, weight: .semibold)
}

extension View {
    func rubrica(_ color: Color = Papel.inkFaint) -> some View {
        font(.rubrica).tracking(1.2).foregroundStyle(color)
    }
}
