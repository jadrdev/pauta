import SwiftUI
import AppKit
import Carbon.HIToolbox
import PautaCore

extension Atajo {
    /// «⌃Espacio», «⌥⌘K». Los modificadores los sabe el propio atajo; la tecla
    /// hay que preguntarla al teclado.
    var descripcion: String { simbolos + Teclas.nombre(tecla) }
}

/// Cómo se llama cada tecla.
enum Teclas {
    /// Las que no escriben nada. Sin esta tabla, «Espacio» saldría como un
    /// espacio en blanco y ↩ como un salto de línea.
    private static let especiales: [Int: String] = [
        kVK_Space: "Espacio", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Delete: "⌫",
        kVK_Escape: "esc", kVK_ForwardDelete: "⌦", kVK_ANSI_KeypadEnter: "⌤",
        kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_DownArrow: "↓", kVK_UpArrow: "↑",
        kVK_PageUp: "⇞", kVK_PageDown: "⇟", kVK_Home: "↖", kVK_End: "↘",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5",
        kVK_F6: "F6", kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10",
        kVK_F11: "F11", kVK_F12: "F12",
    ]

    static func nombre(_ codigo: Int) -> String {
        if let nombre = especiales[codigo] { return nombre }
        return traducir(codigo)?.uppercased() ?? "tecla \(codigo)"
    }

    /// Le pregunta al teclado **de verdad** qué letra es ese código.
    ///
    /// Con una tabla fija saldría el QWERTY americano, y en un teclado español
    /// la tecla de la ñ diría «;». El código de tecla es físico: el mismo botón
    /// escribe cosas distintas según la distribución.
    private static func traducir(_ codigo: Int) -> String? {
        guard let fuente = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let puntero = TISGetInputSourceProperty(fuente, kTISPropertyUnicodeKeyLayoutData)
        else { return nil }
        let datos = Unmanaged<CFData>.fromOpaque(puntero).takeUnretainedValue() as Data

        var muertas: UInt32 = 0
        var largo = 0
        var buffer = [UniChar](repeating: 0, count: 4)
        let estado = datos.withUnsafeBytes { bytes -> OSStatus in
            guard let mapa = bytes.bindMemory(to: UCKeyboardLayout.self).baseAddress
            else { return -1 }
            // `kUCKeyActionDisplay` es lo que se pinta en la tecla, que es lo que
            // hay que enseñar; `kUCKeyActionDown` daría lo que se escribiría.
            return UCKeyTranslate(mapa, UInt16(codigo), UInt16(kUCKeyActionDisplay), 0,
                                  UInt32(LMGetKbdType()),
                                  UInt32(kUCKeyTranslateNoDeadKeysBit),
                                  &muertas, buffer.count, &largo, &buffer)
        }
        guard estado == noErr, largo > 0 else { return nil }
        let texto = String(utf16CodeUnits: buffer, count: largo)
        return texto.trimmingCharacters(in: .whitespaces).isEmpty ? nil : texto
    }
}

/// El campo que graba una combinación.
///
/// Captura teclas de verdad, con el foco puesto en esta ventana: no hace falta
/// ningún permiso ni ningún monitor global, porque solo escucha mientras está
/// grabando y solo lo que llega a la app.
struct GrabadorDeAtajo: View {
    @Binding var grabando: Bool
    let actual: Atajo
    /// Devuelve si el atajo entró; si no, se dice y se sigue con el de antes.
    let alElegir: (Atajo) -> Bool

    @State private var error: String?

    var body: some View {
        HStack(spacing: 10) {
            Button {
                grabando.toggle()
                error = nil
            } label: {
                Text(grabando ? "Pulsa la combinación…" : actual.descripcion)
                    .font(.system(size: 12, weight: .semibold).monospaced())
                    .foregroundStyle(grabando ? Paper.accentInk : Paper.ink)
                    .frame(minWidth: 132)
                    .padding(.vertical, 5)
                    .padding(.horizontal, 10)
                    .background(grabando ? Paper.accent.opacity(0.14)
                                         : Paper.ink.opacity(0.06),
                                in: RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(
                        grabando ? Paper.accentInk.opacity(0.6) : Paper.hairline, lineWidth: 1))
                    .contentShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .background(CapturaDeTeclas(grabando: $grabando, alPulsar: recibir))

            if grabando {
                Text("esc para dejarlo").ayudaTenue()
            } else if let error {
                Text(error).ayudaTenue(Paper.warning)
            }
            Spacer(minLength: 0)
        }
    }

    private func recibir(_ atajo: Atajo) {
        guard atajo.esUsable else {
            error = "Hace falta ⌃, ⌥ o ⌘: si no, esa tecla dejaría de escribir "
                  + "en todas las apps."
            grabando = false
            return
        }
        if alElegir(atajo) {
            error = nil
        } else {
            error = "Esa combinación no la suelta el sistema. Prueba otra."
        }
        grabando = false
    }
}

private extension View {
    func ayudaTenue(_ color: Color = Paper.inkFaint) -> some View {
        font(.system(size: 10.5)).foregroundStyle(color)
    }
}

/// El trozo de AppKit que oye las teclas.
private struct CapturaDeTeclas: NSViewRepresentable {
    @Binding var grabando: Bool
    let alPulsar: (Atajo) -> Void

    func makeNSView(context: Context) -> VistaQueOye {
        let vista = VistaQueOye()
        vista.alPulsar = alPulsar
        vista.alDejarlo = { grabando = false }
        return vista
    }

    func updateNSView(_ vista: VistaQueOye, context: Context) {
        vista.alPulsar = alPulsar
        vista.grabando = grabando
        // El foco se pide aquí y no al pulsar el botón: mientras la vista no sea
        // el primer respondedor, las teclas se las lleva otro.
        if grabando { vista.window?.makeFirstResponder(vista) }
        else if vista.window?.firstResponder === vista { vista.window?.makeFirstResponder(nil) }
    }

    final class VistaQueOye: NSView {
        var grabando = false
        var alPulsar: ((Atajo) -> Void)?
        var alDejarlo: (() -> Void)?

        override var acceptsFirstResponder: Bool { grabando }

        override func keyDown(with event: NSEvent) {
            guard grabando else { super.keyDown(with: event); return }
            if event.keyCode == UInt16(kVK_Escape) { alDejarlo?(); return }
            alPulsar?(Atajo(tecla: Int(event.keyCode),
                            modificadores: VistaQueOye.carbon(event.modifierFlags)))
        }

        /// Sin esto no se podría grabar nada con ⌘: los atajos de menú se
        /// resuelven antes de que la tecla llegue a ninguna vista.
        override func performKeyEquivalent(with event: NSEvent) -> Bool {
            guard grabando else { return false }
            keyDown(with: event)
            return true
        }

        /// De las banderas de AppKit a las de Carbon, que es quien registra el
        /// atajo global.
        static func carbon(_ banderas: NSEvent.ModifierFlags) -> Int {
            var mods = 0
            if banderas.contains(.control) { mods |= Atajo.control }
            if banderas.contains(.option) { mods |= Atajo.option }
            if banderas.contains(.command) { mods |= Atajo.command }
            if banderas.contains(.shift) { mods |= Atajo.shift }
            return mods
        }
    }
}
