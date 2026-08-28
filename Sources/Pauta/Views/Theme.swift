import SwiftUI
import AppKit

extension NSColor {
    /// Color a partir de un hexadecimal 0xRRGGBB.
    convenience init(rgb hex: UInt32) {
        self.init(srgbRed: Double((hex >> 16) & 0xFF) / 255,
                  green:   Double((hex >> 8) & 0xFF) / 255,
                  blue:    Double(hex & 0xFF) / 255,
                  alpha:   1)
    }
}

extension Color {
    /// Color dinámico: resuelve claro u oscuro según la apariencia del sistema.
    static func dyn(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return NSColor(rgb: isDark ? dark : light)
        })
    }
}

/// Paleta de la identidad: verde de marca sobre casi negro azulado.
///
/// Los grises no están elegidos a ojo: se resolvieron numéricamente para pasar
/// WCAG AA (>= 4.5) sobre los fondos de contenido y de barra lateral en ambos
/// temas. Si tocas un fondo, recalcula los grises.
enum Paper {
    static let bg       = Color.dyn(0xFAFAF8, 0x101317)
    static let bgSide   = Color.dyn(0xF1F2EF, 0x0A0D11)
    static let ink      = Color.dyn(0x0E1114, 0xEDEFF2)
    static let inkSoft  = Color.dyn(0x5A5F66, 0xA0A6AE)
    static let inkFaint = Color.dyn(0x676D75, 0x8B929B)
    static let hairline = Color.dyn(0xE3E4E0, 0x22262B)

    /// Verde de marca. Solo para rellenos, bordes y fondos de selección.
    static let accent   = Color.dyn(0x10E888, 0x10E888)
    /// Verde para texto. El puro sobre fondo claro da contraste 1.56, así que
    /// en tema claro se oscurece a un verde profundo.
    static let accentInk = Color.dyn(0x097D49, 0x10E888)
    /// Aviso: fecha límite vencida o de hoy. Calculado para pasar AA sobre los
    /// cuatro fondos, igual que los grises — el rojo puro se queda en 3.89.
    static let warning  = Color.dyn(0xC13E34, 0xE2493D)
    /// Lo que va encima del verde: el negro de marca.
    static let onAccent = Color.dyn(0x080C10, 0x080C10)
}

/// Tipografía: sans geométrica, como el wordmark de la identidad.
extension Font {
    static func display(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
    /// Rótulo pequeño en mayúsculas espaciadas.
    static let rubric = Font.system(size: 10.5, weight: .semibold)
}

extension View {
    func rubricStyle(_ color: Color = Paper.inkFaint) -> some View {
        self.font(.rubric).tracking(1.3).foregroundStyle(color)
    }
}

/// Assets de marca empaquetados en el bundle.
enum Brand {
    private static func load(_ name: String) -> NSImage? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "png") else { return nil }
        return NSImage(contentsOf: url)
    }
    /// P blanca, para fondos oscuros.
    static let monogramLight = load("monogram")
    /// P en negro de marca, para fondos claros.
    static let monogramInk = load("monogram-ink")

    static func monogram(_ scheme: ColorScheme) -> NSImage? {
        scheme == .dark ? monogramLight : monogramInk
    }

    /// Monograma como plantilla para la barra de menús: el sistema lo tiñe
    /// según el fondo, así que solo cuenta el alfa y vale la variante en tinta.
    static let menuBar: NSImage? = {
        guard let src = monogramInk, let img = src.copy() as? NSImage,
              src.size.height > 0 else { return nil }
        img.isTemplate = true
        img.size = NSSize(width: 16 * src.size.width / src.size.height, height: 16)
        return img
    }()
}

/// El lockup de la identidad: monograma y wordmark.
///
/// Ahora mismo la interfaz no lo muestra — la barra lateral va sin cabecera de
/// marca a propósito. Se mantiene para un panel «Acerca de» o una pantalla de
/// bienvenida; los assets ya viajan en el bundle.
///
/// El wordmark se compone con tipografía en vez de traerse como imagen: así es
/// nítido a cualquier tamaño y sigue el tema sin necesitar dos versiones. El
/// monograma sí es imagen, y cambia de variante según el tema — por eso ya no
/// hace falta ninguna placa oscura de fondo.
struct BrandMark: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 11) {
            if let mono = Brand.monogram(scheme) {
                Image(nsImage: mono)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 25)
            }
            Text("PAUTA")
                .font(.system(size: 14.5, weight: .semibold))
                .tracking(3.2)
                .foregroundStyle(Paper.ink)
            Spacer(minLength: 0)
        }
    }
}
