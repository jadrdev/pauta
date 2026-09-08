import SwiftUI
import UIKit
import PautaCore

/// Una lista de tareas.
///
/// La misma vista para las cinco listas, los proyectos, las áreas y las
/// etiquetas: son consultas sobre las mismas tareas, así que enseñarlas con
/// vistas distintas sería mantener la misma pantalla varias veces.
struct ListaView: View {
    let perspectiva: Perspective

    @Environment(Store.self) private var store
    @Environment(Agenda.self) private var agenda
    @State private var abierta: Item?
    @State private var apuntando = false

    private var items: [Item] { store.items(for: perspectiva) }

    /// Los eventos solo salen en Hoy: en las demás listas no hay día que llenar.
    private var eventos: [Evento] {
        if case .today = perspectiva { return agenda.eventos }
        return []
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 0) {
                    // Fuera de la lista y no dentro: con cero tareas y cero
                    // eventos se dibuja el estado vacío, y ahí dentro la
                    // invitación no llegaba a existir. En un teléfono recién
                    // instalado —que es justo cuando hace falta— era
                    // inalcanzable.
                    avisoDelCalendario
                    contenido
                }
                if !apuntando { BotonDeApuntar { apuntando = true } }
            }
            .background(Papel.bg)
            .navigationTitle(store.title(for: perspectiva))
            .navigationBarTitleDisplayMode(.large)
            // Como franja del área segura y no como superposición: una
            // superposición se queda **debajo** de la barra de pestañas, y el
            // teclado la tapa. Así el sistema la coloca sobre el teclado él.
            .safeAreaInset(edge: .bottom) {
                if apuntando {
                    CapturaView(perspectiva: perspectiva) { apuntando = false }
                }
            }
            // Mientras se apunta, las pestañas se van: no se cambia de sección
            // con el teclado abierto, y su barra flotante robaba el sitio justo
            // donde hay que escribir.
            .toolbar(apuntando ? .hidden : .visible, for: .tabBar)
        }
        .sheet(item: $abierta) { DetalleView(item: $0) }
        .task {
            if case .today = perspectiva { await agenda.load() }
        }
    }

    @ViewBuilder private var contenido: some View {
        if items.isEmpty && eventos.isEmpty {
            // Centrado a mano y no con la altura infinita del vacío: `VacioView`
            // pedía todo el espacio y empujaba la tarjeta fuera de la pantalla
            // —se dibujaba, pero no se veía—.
            VStack(spacing: 26) {
                Spacer(minLength: 20)
                VacioView(perspectiva: perspectiva)
                // La bienvenida solo en Hoy: es la pestaña que se abre al
                // arrancar, y ofrecer permisos desde una etiqueta sería
                // pedirlos donde no se acaba de ver para qué sirven.
                if case .today = perspectiva {
                    PuestaAPuntoView { permiso in
                        Task {
                            switch permiso {
                            case .avisos: await Avisos.reschedule(store.items)
                            case .calendario: await agenda.load(force: true)
                            case .recordatorios:
                                await RemindersInbox().importar(en: store)
                            }
                        }
                    }
                }
                Spacer(minLength: 90)
            }
        } else {
            List {
                // La cuenta va aquí y no en la barra: en la barra, un texto
                // suelto se dibuja dentro de una cápsula y parece un botón que
                // no hace nada.
                Text(cuenta)
                    .rubrica()
                    .listRowBackground(Papel.bg)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 6, trailing: 16))
                // Hoy es el día entero, no solo la lista de tareas: lo que hay
                // que hacer y lo que ya está comprometido, en el orden en que va
                // a ocurrir. La mezcla la hace el núcleo, igual que en el Mac.
                ForEach(Agenda.filas(tareas: items, eventos: eventos)) { fila in
                    switch fila {
                    case .tarea(let item):
                        FilaView(item: item) { abierta = item }
                            .listRowBackground(Papel.bg)
                            .listRowInsets(EdgeInsets(top: 9, leading: 16,
                                                      bottom: 9, trailing: 16))
                            .listRowSeparatorTint(Papel.hairline)
                            .swipeActions(edge: .trailing) {
                                Button("Eliminar", role: .destructive) { store.delete(item) }
                            }
                            .swipeActions(edge: .leading) {
                                // Aplazar a mano es lo que evita que una tarea
                                // se quede mirándote todo el día sin poder
                                // tocarla.
                                Button("Hoy") { store.schedule(item, to: .now) }
                                    .tint(Papel.accentInk)
                            }
                    case .evento(let evento):
                        // Sin gestos: un evento no es tuyo, se lee y punto.
                        EventoRow(evento: evento)
                            .listRowBackground(Papel.bg)
                            .listRowInsets(EdgeInsets(top: 9, leading: 16,
                                                      bottom: 9, trailing: 16))
                            .listRowSeparatorTint(Papel.hairline)
                    }
                }
                // Aire al final: sin esto, el botón de apuntar tapa la última
                // fila y no hay forma de completarla.
                Color.clear.frame(height: 64)
                    .listRowBackground(Papel.bg)
                    .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private var cuenta: String {
        let n = items.count
        let tareas: String
        if case .completed = perspectiva {
            tareas = n == 1 ? "1 TAREA" : "\(n) TAREAS"
        } else {
            tareas = n == 1 ? "1 ABIERTA" : "\(n) ABIERTAS"
        }
        // Los eventos se cuentan aparte: no son cosas que hacer ni se completan,
        // así que sumarlos a las tareas abiertas mentiría sobre el trabajo.
        guard !eventos.isEmpty else { return tareas }
        let e = eventos.count == 1 ? "1 EVENTO" : "\(eventos.count) EVENTOS"
        return "\(e) · \(tareas)"
    }

    /// Lo que hay que decir sobre el calendario, según lo que haya contestado
    /// el sistema.
    ///
    /// Tres estados y no dos. El tercero es el que se escapa: iOS ofrece
    /// **«Solo añadir»** junto a «Acceso completo», y con esa respuesta la app
    /// no puede **leer** ni un evento. Sin decirlo, Hoy se queda vacío y parece
    /// que la función está rota cuando lo que hay es un permiso a medias.
    @ViewBuilder private var avisoDelCalendario: some View {
        if case .today = perspectiva {
            switch Agenda.authorization {
            case .notDetermined where items.isEmpty && eventos.isEmpty:
                // Con la lista vacía manda la tarjeta de bienvenida, que ya
                // ofrece el calendario con su motivo: dos sitios pidiendo lo
                // mismo a la vez se leen como un error.
                EmptyView()
            case .notDetermined:
                franja("calendar.badge.plus", "MOSTRAR LOS EVENTOS DEL CALENDARIO",
                       Papel.accentInk, Papel.accent.opacity(0.12)) {
                    Task {
                        await agenda.requestAccess()
                        await agenda.load(force: true)
                    }
                }
            case .fullAccess:
                EmptyView()
            default:
                // Denegado, restringido o «solo añadir»: la decisión ya está
                // tomada y solo se cambia en los ajustes del sistema, porque el
                // diálogo no vuelve a salir.
                franja("calendar.badge.exclamationmark",
                       "PAUTA NO PUEDE LEER TU CALENDARIO",
                       Papel.warning, Papel.warning.opacity(0.12)) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            }
        }
    }

    private func franja(_ icono: String, _ texto: String, _ tinta: Color,
                        _ fondo: Color, _ accion: @escaping () -> Void) -> some View {
        Button(action: accion) {
            HStack(spacing: 8) {
                Image(systemName: icono).font(.system(size: 13))
                Text(texto).rubrica(tinta)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(tinta)
            .padding(.vertical, 11)
            .padding(.horizontal, 12)
            .background(fondo, in: RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}

/// Lo que se dice cuando no hay nada, que no es lo mismo en cada lista.
struct VacioView: View {
    let perspectiva: Perspective

    var body: some View {
        VStack(spacing: 7) {
            Image(systemName: icono)
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(Papel.hairline)
            Text(texto)
                .font(.system(size: 15))
                .foregroundStyle(Papel.inkFaint)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 40)
    }

    private var icono: String {
        switch perspectiva {
        case .today: "sun.max"
        case .upcoming: "calendar"
        case .inbox: "tray"
        case .completed: "checkmark.circle"
        default: "list.bullet"
        }
    }

    private var texto: String {
        switch perspectiva {
        case .today: "Nada para hoy. Buen día para no hacer nada."
        case .inbox: "La bandeja está vacía."
        case .upcoming: "Nada planificado más adelante."
        case .someday: "Nada aparcado."
        case .completed: "Todavía no has completado nada."
        default: "Nada por aquí."
        }
    }
}
