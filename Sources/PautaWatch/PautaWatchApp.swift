import SwiftUI
import PautaCore

/// Pauta en la muñeca.
///
/// Lo que una muñeca hace mejor que un teléfono es **decirte lo que hay sin que
/// lo pidas**. Y dos de las tres cosas que se pueden querer aquí ya funcionaban
/// sin app: los avisos del iPhone se reenvían al reloj, y a Siri se le puede
/// dictar una tarea desde aquí. Lo que faltaba era el vistazo: mirar la esfera y
/// saber cuántas quedan.
///
/// Así que esto es **de solo lectura**, y a propósito. El reloj no tiene los
/// datos: recibe del teléfono el mismo `Vistazo` que dibuja el widget —lo que
/// cabe en un golpe de vista— y lo enseña. Sin almacén, sin cruces y sin nada
/// que se pueda perder aquí.
@main
struct PautaWatchApp: App {
    @State private var enlace = EnlaceConElTelefono()

    var body: some Scene {
        WindowGroup {
            HoyWatchView(vistazo: enlace.vistazo, esperando: enlace.esperando,
                         enCamino: enlace.enCamino,
                         tachar: { enlace.tachar($0) })
                .task { enlace.activar() }
        }
    }
}
