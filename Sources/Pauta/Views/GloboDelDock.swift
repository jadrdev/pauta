import AppKit

/// El globo con las atrasadas, pintado sobre el icono del Dock.
///
/// **A mano y no con `badgeLabel`.** Esa era la vía obvia y no funciona para
/// quien ya tiene la app instalada: AppKit acepta el valor y lo devuelve al
/// releerlo, pero quien decide si se dibuja es el sistema, y el globo es un
/// permiso que se concede —o no— al aceptar los avisos. Pauta pedía `.alert` y
/// `.sound`. Añadir `.badge` después no lo arregla: medido en este Mac,
/// `request()` contesta `true` y el globo sigue denegado, y Ajustes del Sistema
/// ni siquiera enseña el interruptor porque la app nunca lo pidió.
///
/// Pintarlo nosotros no pide permiso a nadie. El precio es dibujar también el
/// icono, porque poner una vista propia sustituye el contenido de la baldosa
/// entera.
@MainActor
final class GloboDelDock {
    static let compartido = GloboDelDock()

    private let vista = Baldosa()
    private var puesta = false

    private init() {}


    /// `nil` quita el globo y devuelve la baldosa al icono de siempre: con cero
    /// atrasadas no queda nuestra vista pintando un icono a mano por nada.
    func poner(_ texto: String?) {
        let tile = NSApp.dockTile
        guard let texto else {
            if puesta { tile.contentView = nil; puesta = false; tile.display() }
            return
        }
        vista.texto = texto
        if !puesta { tile.contentView = vista; puesta = true }
        tile.display()
    }

    /// El icono de la app con un disco rojo arriba a la derecha.
    ///
    /// Las medidas van en proporción al lado de la baldosa y no en puntos: el
    /// Dock la dibuja al tamaño que tenga puesto cada uno, y un radio fijo se
    /// vería enorme con iconos pequeños y ridículo con los grandes.
    private final class Baldosa: NSView {
        var texto: String = ""

        override func draw(_ dirtyRect: NSRect) {
            NSApp.applicationIconImage?.draw(
                in: bounds, from: .zero, operation: .sourceOver, fraction: 1)

            let lado = min(bounds.width, bounds.height)
            // Más ancho cuando hay dos cifras, como el del sistema: un círculo
            // con «12» dentro deja el número pegado al borde.
            let alto = lado * 0.30
            let ancho = max(alto, alto * 0.62 * CGFloat(texto.count) + alto * 0.38)
            let caja = NSRect(x: bounds.maxX - ancho - lado * 0.04,
                              y: bounds.maxY - alto - lado * 0.04,
                              width: ancho, height: alto)

            let forma = NSBezierPath(roundedRect: caja,
                                     xRadius: alto / 2, yRadius: alto / 2)
            // El filo blanco es lo que despega el globo de un icono oscuro; sin
            // él, sobre fondo negro el disco rojo parece un recorte.
            NSColor.white.setStroke()
            forma.lineWidth = lado * 0.035
            forma.stroke()
            NSColor.systemRed.setFill()
            forma.fill()

            let fuente = NSFont.systemFont(ofSize: alto * 0.68, weight: .bold)
            let atributos: [NSAttributedString.Key: Any] = [
                .font: fuente,
                .foregroundColor: NSColor.white,
            ]
            let medida = (texto as NSString).size(withAttributes: atributos)
            (texto as NSString).draw(
                at: NSPoint(x: caja.midX - medida.width / 2,
                            y: caja.midY - medida.height / 2),
                withAttributes: atributos)
        }
    }
}
