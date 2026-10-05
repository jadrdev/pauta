import Foundation
import WidgetKit
import UserNotifications
import PautaCore

/// Lo que hacen los botones de un aviso en el teléfono.
///
/// Hasta ahora no hacían nada: el Mac le decía al aviso qué hacer y el teléfono
/// nunca, así que «Completar» y «Aplazar» se pulsaban y la tarea seguía igual.
///
/// iOS los atiende **en segundo plano**, sin abrir la app y a veces sin
/// interfaz montada. Por eso cada uno abre su propio almacén —como el refresco
/// en segundo plano—, hace el cambio, lo cruza con el Mac y pone al día los
/// avisos, el widget, el reloj y el globo. Si la app estaba abierta, se le avisa
/// para que relea, igual que cuando apunta el atajo de Siri.
@MainActor
enum DesdeElAviso {
    static func completar(_ id: UUID) async {
        let almacen = Store()
        guard almacen.completar(id) else { return }
        await terminar(almacen)
    }

    static func aplazar(_ id: UUID, minutos: Int) async {
        let almacen = Store()
        guard let tarea = almacen.items.first(where: { $0.id == id }) else { return }
        almacen.snooze(tarea, minutes: minutos)
        await terminar(almacen)
    }

    private static func terminar(_ almacen: Store) async {
        await Avisos.reschedule(almacen.items)
        await Sincronizar.conElMac(almacen)
        let vistazo = Vistazo.de(almacen.items, proyectos: almacen.projects,
                                 limite: Vistazo.limitePublicado)
        WidgetCenter.shared.reloadAllTimelines()
        EnlaceConElReloj.shared.publicar(vistazo)
        try? await UNUserNotificationCenter.current().setBadgeCount(vistazo.atrasadas)
        NotificationCenter.default.post(name: .pautaApuntadoDesdeFuera, object: nil)
    }
}
