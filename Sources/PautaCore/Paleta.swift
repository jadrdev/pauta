import Foundation

/// Los colores de la app, en crudo.
///
/// Números y no `Color`: quien los convierte en color es cada plataforma —AppKit
/// en el Mac, UIKit en el teléfono— y cada una lo hace a su manera. Si cada
/// interfaz llevara su propia tabla, en la primera corrección de contraste una de
/// las dos se quedaría atrás sin que nadie se enterase.
///
/// Van en pares claro/oscuro. El verde es el mismo en los dos: es la marca.
public enum Paleta {
    public typealias Par = (claro: UInt32, oscuro: UInt32)

    public static let bg:        Par = (0xFAFAF8, 0x101317)
    public static let bgSide:    Par = (0xF1F2EF, 0x0A0D11)
    public static let ink:       Par = (0x0E1114, 0xEDEFF2)
    public static let inkSoft:   Par = (0x5A5F66, 0xA0A6AE)
    public static let inkFaint:  Par = (0x676D75, 0x8B929B)
    public static let hairline:  Par = (0xE3E4E0, 0x22262B)
    public static let accent:    Par = (0x10E888, 0x10E888)
    /// El verde puro no contrasta sobre fondo claro: para texto y trazos finos
    /// va la variante en tinta.
    public static let accentInk: Par = (0x097D49, 0x10E888)
    public static let warning:   Par = (0xC13E34, 0xE2493D)
    public static let onAccent:  Par = (0x080C10, 0x080C10)
}
