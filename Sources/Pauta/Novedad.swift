import Foundation
import Observation
import PautaCore

/// Quien mira si hay versión nueva.
///
/// Una sola consulta, una vez al día, y **solo pregunta**: no manda nada, no
/// lleva cuenta de nadie y se puede apagar en los ajustes. Es la única vez que
/// esta app habla con internet por su cuenta.
///
/// Y avisa, no instala. Instalar sola una app descargada exige verificar la
/// firma de lo que se baja, y esta se firma con un certificado de desarrollo y
/// sin notarizar: ese camino lo cierra la cuenta de Apple, no el código. Así
/// que aquí se dice que hay algo nuevo y el resto es arrastrar, como siempre.
@MainActor
@Observable
final class Novedad {
    static let shared = Novedad()

    /// La versión publicada, **solo si es más nueva que esta**. Avisar de la que
    /// ya tienes es la forma más rápida de que dejes de leer los avisos.
    private(set) var hay: Lanzamiento?
    private(set) var mirando = false
    /// Si la última consulta no se pudo hacer. No es un error que interrumpa a
    /// nadie: sirve para poder decir «no se pudo comprobar» en vez de mentir
    /// con un «estás al día».
    private(set) var falloAlMirar = false

    var mia: Version? { Version(Acercade.version) }

    /// La de todos los días, al arrancar. Si no toca o está apagado, no hace
    /// nada.
    func mirarSiToca() async {
        guard Ajustes.shared.tocaMirarVersiones() else { return }
        await mirar()
    }

    /// La de cuando le das al botón: mira aunque no toque.
    func mirarAhora() async {
        await mirar()
    }

    private func mirar() async {
        guard !mirando else { return }
        mirando = true
        defer { mirando = false }
        let ultima = await Novedades.ultima()
        Ajustes.shared.ultimaMiradaDeVersiones = .now
        guard let ultima, let mia else {
            falloAlMirar = ultima == nil
            return
        }
        falloAlMirar = false
        hay = Version.hayNovedad(tengo: mia, hay: ultima.version) ? ultima : nil
    }
}
