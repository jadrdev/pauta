import SwiftUI
import WidgetKit
import UserNotifications
import PautaCore

/// Pauta en el teléfono.
///
/// Comparte con el Mac todo el núcleo —modelo, almacén, consultas, avisos— y no
/// comparte una sola vista, a propósito. Un teléfono no se maneja como un Mac:
/// no hay barra lateral que quepa, no hay clic derecho, y la mano tapa media
/// pantalla.
@main
@MainActor
struct PautaIOSApp: App {
    @State private var store = Store()
    @State private var agenda = Agenda()

    init() {
        // Antes de la interfaz: un aviso pulsado con la app cerrada se entrega
        // sin nadie que lo atienda si el delegado llega tarde.
        Avisos.hookUp()
        // Y la sesión con el reloj, que tarda en activarse: pedirla al arrancar
        // es lo que hace que el primer vistazo salga y no se quede esperando.
        EnlaceConElReloj.shared.activar()
    }

    var body: some Scene {
        WindowGroup {
            RaizView()
                .environment(store)
                .environment(agenda)
                .tint(Papel.accentInk)
        }
    }
}

/// Las pestañas.
///
/// Abajo y no en una tira arriba: es donde llega el pulgar, es un toque para
/// cambiar, y es lo que iOS entiende por «cambiar de sección» —una fila de
/// fichas arriba es un patrón de web, y en un teléfono se lee como un
/// navegador—.
///
/// Cuatro y no siete. Las tres que se usan a diario tienen su sitio fijo; el
/// resto —las listas de fondo, los proyectos, las áreas, las etiquetas— vive en
/// «Más», porque una barra de siete iconos no se lee: se adivina.
struct RaizView: View {
    @Environment(Store.self) private var store
    @Environment(Agenda.self) private var agenda
    @Environment(\.scenePhase) private var fase

    /// La pestaña que se ve. Deja de ser cosa del sistema porque ahora se puede
    /// llegar de fuera: un toque en el widget tiene que abrir **su** lista, no
    /// la última que quedara abierta.
    @State private var pestana = Pestana.hoy
    /// La tarea que pidió el widget, si pidió una.
    @State private var delEnlace: Item?
    /// Un pulso, no un interruptor: cada vez que suba, la lista abre la barra
    /// de apuntar. Con un booleano habría que acordarse de bajarlo, y dos
    /// toques seguidos en el widget no harían nada la segunda vez.
    @State private var pulsoApuntar = 0

    private enum Pestana: Hashable { case hoy, proximamente, bandeja, mas }

    var body: some View {
        TabView(selection: $pestana) {
            ListaView(perspectiva: .today, pidenApuntar: pulsoApuntar)
                .tabItem { Label("Hoy", systemImage: "sun.max") }
                .tag(Pestana.hoy)
            ListaView(perspectiva: .upcoming)
                .tabItem { Label("Próximamente", systemImage: "calendar") }
                .tag(Pestana.proximamente)
            ListaView(perspectiva: .inbox)
                .tabItem { Label("Bandeja", systemImage: "tray") }
                .tag(Pestana.bandeja)
            MasView()
                .tabItem { Label("Más", systemImage: "ellipsis") }
                .tag(Pestana.mas)
        }
        // La tarea del enlace se abre **aquí arriba** y no dentro de la lista:
        // así da igual en qué pestaña estuvieras y no hay que llevar el enlace
        // a mano hasta el fondo de la vista que la enseña.
        .sheet(item: $delEnlace) { DetalleView(item: $0) }
        .onOpenURL { url in
            switch Enlaces.destino(url) {
            case .hoy:
                pestana = .hoy
            case .bandeja:
                pestana = .bandeja
            case .apuntar:
                pestana = .hoy
                pulsoApuntar += 1
            case .tarea(let id):
                // Si ya no existe —se completó desde el Mac, se borró— se
                // aterriza en Hoy sin más: es donde estaba.
                pestana = .hoy
                delEnlace = store.items.first { $0.id == id && $0.deletedAt == nil }
            case .none:
                break
            }
        }
        // Al volver del fondo: el día pudo cambiar mientras la app dormía, y lo
        // que era «de hoy» pasó a ser atrasado.
        .onChange(of: fase) { _, nueva in
            guard nueva == .active else { return }
            store.reload()
            // Al volver del fondo es cuando hace falta cruzar con el Mac: entre
            // dejar el teléfono y volver a cogerlo es cuando se ha estado
            // delante del otro aparato. Sin carpeta elegida no hace nada, y
            // nunca en el hilo principal: son archivos, y algunos hay que
            // bajarlos.
            Task { await Sincronizar.conElMac(store) }
            // Los eventos se releen a la fuerza: pudo aceptarse una invitación
            // o moverse una reunión mientras la app dormía, y el día que se
            // enseña ya no sería el de verdad.
            Task {
                await Avisos.reschedule(store.items)
                await agenda.load(force: true)
            }
        }
        .task(id: store.items) {
            // Un segundo de espera, como en el Mac: escribir un título cambia
            // las tareas en cada tecla.
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            await Avisos.reschedule(store.items)
            avisarAFuera()
        }
        .task {
            // También al arrancar en frío: apoyarse solo en el cambio de fase
            // deja el primer cruce a merced de si el sistema pasa por
            // «inactiva» antes de «activa». Cruzar dos veces no hace nada, así
            // que sobra pedirlo dos veces y falta no pedirlo ninguna.
            await Sincronizar.conElMac(store)
            // Se avisa a fuera **aquí también**, no solo en el bloque de
            // arriba.
            //
            // Ese bloque espera un segundo y se reinicia con cada cambio del
            // almacén; al arrancar hay una ráfaga —recargar, cruzar con el Mac—
            // y entre cancelación y cancelación no llegaba a ejecutarse nunca.
            // Comprobado en el registro del simulador: cero recargas del widget
            // en un arranque entero, y el reloj esperando un vistazo que no
            // salía.
            avisarAFuera()
            // Y quién atiende lo que pida el reloj, que hasta ahora solo
            // recibía. Se instala aquí porque el almacén vive en la vista: el
            // enlace no guarda ninguno a propósito.
            EnlaceConElReloj.shared.obedecer = { orden in
                switch orden {
                case .completar(let tarea):
                    // Solo se avisa a fuera si cambió algo: una orden repetida
                    // —el sistema reintenta— no tiene por qué mover nada.
                    if store.completar(tarea) { avisarAFuera() }
                case .apuntar(let texto):
                    // Lo dictado en la muñeca. Por el mismo camino que el campo
                    // de escribir, que es quien ya sabe partir líneas y
                    // descartar lo que queda en blanco.
                    if !store.addItems(from: texto, in: .inbox).isEmpty {
                        avisarAFuera()
                    }
                case .refrescar:
                    // El reloj no sabe si lo que tiene sigue valiendo, así que
                    // lo pregunta. Se relee del disco antes de contestar: puede
                    // haber cambiado algo desde otro sitio mientras esta app
                    // dormía, y mandarle lo que había en memoria sería
                    // contestarle con lo mismo que él ya tenía.
                    store.reload()
                    WidgetCenter.shared.reloadAllTimelines()
                    // Por mensaje y no solo por contexto: el que pregunta suele
                    // ser un reloj que no tiene el contexto, y el contexto no se
                    // reenvía cuando no ha cambiado.
                    EnlaceConElReloj.shared.responder(
                        Vistazo.de(store.items, proyectos: store.projects,
                                   limite: Vistazo.limitePublicado))
                }
            }
            // El atajo de Siri, que escribe en la carpeta por su
            // cuenta: sin esto, apuntar con la app delante no cambiaría nada en
            // pantalla hasta salir y volver, que es justo cuando parece que se
            // perdió. Este bucle no termina, y va el último a propósito.
            for await _ in NotificationCenter.default
                .notifications(named: .pautaApuntadoDesdeFuera).map({ _ in () }) {
                store.reload()
            }
            // Lo mismo para el atajo de Siri, que escribe en la carpeta por su
            // cuenta: sin esto, apuntar con la app delante no cambiaría nada en
            // pantalla hasta salir y volver.
            for await _ in NotificationCenter.default
                .notifications(named: .pautaApuntadoDesdeFuera).map({ _ in () }) {
                store.reload()
            }
        }
    }

    /// Lo que hay que contarle a lo que vive fuera de la app: el widget y el
    /// reloj. Los dos enseñan el mismo vistazo y ninguno se entera por su
    /// cuenta.
    private func avisarAFuera() {
        let vistazo = Vistazo.de(store.items, proyectos: store.projects,
                                 limite: Vistazo.limitePublicado)
        // El widget, que si no se enteraría cuando el sistema quisiera:
        // completar algo y verlo seguir ahí media hora es lo que hace que un
        // widget deje de creerse.
        WidgetCenter.shared.reloadAllTimelines()
        // Y el reloj. Sin reloj emparejado no hace nada.
        EnlaceConElReloj.shared.publicar(vistazo)
        // Y el globo del icono, del mismo vistazo: las tres cosas cuentan lo
        // mismo porque cuentan lo mismo, no porque coincidan.
        //
        // A diferencia del Mac, aquí el globo lo pone el sistema y sobrevive a
        // cerrar la app — que es justo cuando sirve. El precio es que necesita
        // permiso, y quien concedió los avisos antes de la 0.3.8 lo tiene
        // apagado hasta que lo encienda: se lo dice la pantalla de ajustes.
        Task { try? await UNUserNotificationCenter.current()
            .setBadgeCount(vistazo.atrasadas) }
    }

}
