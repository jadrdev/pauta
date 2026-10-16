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
    /// Cuando sube, se abre la barra de apuntar. Viene del widget, que no puede
    /// llamar a esta vista: solo pedirle al sistema que abra la app con una
    /// dirección.
    var pidenApuntar: Int = 0

    @Environment(Store.self) private var store
    @Environment(Agenda.self) private var agenda
    @Environment(\.horizontalSizeClass) private var ancho
    @State private var abierta: Item?
    /// La hoja solo existe en una columna. Al abrir el teléfono con una tarea
    /// delante, la hoja se va y la tarea pasa al panel; al plegarlo, vuelve a
    /// la hoja. La tarea es siempre `abierta`; esto solo dice si va en hoja.
    ///
    /// Estado propio y no una `Binding` calculada: esa se quedaba con la vista
    /// de **antes** de desplegar, y cuando el sistema cerraba la hoja le
    /// devolvía su `nil` creyendo que seguía en una columna. La tarea se
    /// perdía justo al abrir el teléfono para verla mejor.
    @State private var enHoja: Item?
    @State private var apuntando = false
    @State private var vaciando = false
    @State private var eligiendoEmoji = false
    @State private var pegando = false

    /// El emoji de lo que se está viendo, si es un proyecto o un área; `nil` en
    /// las demás listas, que no llevan.
    private var emojiEditable: String? {
        switch perspectiva {
        case .project(let id): store.projects.first { $0.id == id }?.icon
        case .area(let id): store.area(id)?.icon
        default: nil
        }
    }

    private var items: [Item] { store.items(for: perspectiva) }
    private var pliegue: Pliegue { Pliegue.shared }

    /// Los eventos solo salen en Hoy: en las demás listas no hay día que llenar.
    private var eventos: [Evento] {
        if case .today = perspectiva { return agenda.eventos }
        return []
    }

    /// Con el iPhone Duo abierto hay sitio para la lista **y** la tarea, y
    /// estirar la vista de una mano a esa anchura era ponerle a cada fila un
    /// palmo entre el texto y su botón. Abierto, la tarea va a la derecha en
    /// vez de en una hoja; plegado —o en cualquier otro iPhone— todo sigue
    /// igual. Lo decide el ancho y no el modelo de teléfono: es lo que cambia
    /// al abrirlo.
    private var enDosPaneles: Bool { ancho == .regular }


    var body: some View {
        // La lista va siempre en el mismo sitio del árbol, con panel o sin él:
        // si cambiara de rama al abrir el teléfono, se perdería la navegación
        // y el desplazamiento justo en el gesto de desplegarlo.
        GeometryReader { geo in
            HStack(spacing: 0) {
                lista.frame(width: enDosPaneles ? Self.bisagra(geo) : nil)
                if enDosPaneles {
                    Divider()
                    panel.frame(maxWidth: .infinity)
                }
            }
        }
        .sheet(item: $enHoja) { DetalleView(item: $0) }
        .onChange(of: abierta) { _, tarea in enHoja = enDosPaneles ? nil : tarea }
        .onChange(of: enDosPaneles) { _, dos in enHoja = dos ? nil : abierta }
        // La hoja se cerró. Si fue a mano —deslizando, «Listo»—, se acabó la
        // tarea; si fue por desplegar, la tarea sigue, ahora en el panel. Aquí
        // `enDosPaneles` ya es el de ahora, que es lo que distingue los dos.
        .onChange(of: enHoja) { _, tarea in
            if tarea == nil && !enDosPaneles { abierta = nil }
        }
        .onChange(of: pidenApuntar) { _, _ in apuntando = true }
        .sheet(isPresented: $vaciando) { VaciarBandejaView() }
        .task {
            if case .today = perspectiva { await agenda.load() }
        }
    }

    /// Dónde cae la bisagra, medido desde el borde del área segura.
    ///
    /// La bisagra está en el centro de la **pantalla**, no del área segura: el
    /// sistema guarda una franja a la derecha para la hora y las pestañas, y
    /// repartir mitad y mitad de lo que queda dejaba la división un dedo a la
    /// izquierda del pliegue —con la lista doblada encima de él—.
    private static func bisagra(_ geo: GeometryProxy) -> CGFloat {
        let margen = geo.safeAreaInsets
        return (margen.leading + geo.size.width + margen.trailing) / 2 - margen.leading
    }

    /// La mitad derecha con el teléfono abierto: la tarea elegida o, si no hay
    /// ninguna, qué hacer para que la haya.
    @ViewBuilder private var panel: some View {
        // Contra el almacén y no contra `abierta` sin más: si la tarea se borra
        // —aquí o desde el Mac—, el panel no puede seguir enseñando su ficha.
        if let abierta, store.items.contains(where: { $0.id == abierta.id && $0.deletedAt == nil }) {
            DetalleView(item: abierta) { self.abierta = nil }
                // Una ficha por tarea: sin esto, al tocar otra fila se
                // quedarían el título y las notas de la anterior.
                .id(abierta.id)
        } else {
            VStack(spacing: 10) {
                Image(systemName: "hand.point.left")
                    .font(.system(size: 26, weight: .light))
                Text("Toca una tarea para verla aquí.")
                    .font(.system(size: 15))
            }
            .foregroundStyle(Papel.inkSoft)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Papel.bg)
        }
    }

    private var lista: some View {
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
            .toolbar {
                // El emoji de un proyecto o un área, arriba y a mano: es donde
                // se mira cuando se está dentro.
                if let emoji = emojiEditable {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { eligiendoEmoji = true } label: {
                            if emoji.isEmpty {
                                Image(systemName: "face.smiling")
                            } else {
                                Text(emoji).font(.system(size: 20))
                            }
                        }
                        .accessibilityLabel("Cambiar emoji")
                    }
                }
                // Lo que se hace con un proyecto entero: ordenarlo por fecha
                // —una vez; el orden sigue siendo tuyo— y llenarlo pegando un
                // calendario, que tiene sentido también cuando está vacío.
                if case .project(let id) = perspectiva,
                   let proyecto = store.projects.first(where: { $0.id == id }) {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            if items.count > 1 {
                                Button {
                                    withAnimation { store.ordenarPorFecha(proyecto) }
                                } label: {
                                    Label("Ordenar por fecha", systemImage: "calendar")
                                }
                            }
                            Button { pegando = true } label: {
                                Label("Pegar un calendario", systemImage: "calendar.badge.plus")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                        .accessibilityLabel("Más acciones del proyecto")
                    }
                }
                // Solo en la bandeja y solo si hay algo: es la única lista que
                // se supone que se vacía.
                if case .inbox = perspectiva, !items.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { vaciando = true } label: {
                            Label("Vaciar", systemImage: "tray.and.arrow.down")
                        }
                    }
                }
            }
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
            .sheet(isPresented: $pegando) {
                PegarCalendarioView(proyectoInicial: {
                    if case .project(let id) = perspectiva { id } else { nil }
                }())
            }
            .sheet(isPresented: $eligiendoEmoji) {
                ElegirEmojiView(actual: emojiEditable ?? "") { emoji in
                    switch perspectiva {
                    case .project(let id):
                        if let p = store.projects.first(where: { $0.id == id }) { store.setIcon(p, to: emoji) }
                    case .area(let id):
                        if let a = store.area(id) { store.setIcon(a, to: emoji) }
                    default: break
                    }
                }
            }
        }
    }

    @ViewBuilder private var contenido: some View {
        if items.isEmpty && eventos.isEmpty {
            // Centrado a mano y no con la altura infinita del vacío: `VacioView`
            // pedía todo el espacio y empujaba la tarjeta fuera de la pantalla
            // —se dibujaba, pero no se veía—.
            VStack(spacing: 26) {
                Spacer(minLength: 20)
                // «Buen día para no hacer nada» es verdad cuando has vaciado
                // el día, y mentira en un teléfono recién instalado: ahí no
                // estás libre, es que aún no has empezado.
                VacioView(perspectiva: perspectiva, estrenando: store.items.isEmpty)
                // La bienvenida solo en Hoy: es la pestaña que se abre al
                // arrancar, y ofrecer permisos desde una etiqueta sería
                // pedirlos donde no se acaba de ver para qué sirven.
                if case .today = perspectiva {
                    PuestaAPuntoView(alConceder: { permiso in
                        Task {
                            switch permiso {
                            case .avisos: await Avisos.reschedule(store.items)
                            case .calendario: await agenda.load(force: true)
                            }
                        }
                    }, alElegirCarpeta: {
                        Task { await Sincronizar.conElMac(store) }
                    }, estrenando: store.items.isEmpty)
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
                //
                // Y en Hoy el tramo sin hora se agrupa por proyecto, también
                // igual que en el Mac: quien decide es `Hoy.bloques`, así que
                // las dos pantallas no pueden discrepar. Aquí pesa más, que en
                // un teléfono un proyecto con diez tareas es la lista entera.
                if case .today = perspectiva {
                    let dia = Agenda.dia(tareas: items, eventos: eventos)
                    ForEach(dia.conHora) { fila in
                        switch fila {
                        case .tarea(let item): filaDeTarea(item)
                        case .evento(let evento): filaDeEvento(evento)
                        case .juntos(let evento, let item): filaDeTarea(item, evento: evento)
                        }
                    }
                    ForEach(Hoy.bloques(sinHora: dia.sinHora,
                                        hechasHoy: store.hechasHoy)) { bloque in
                        switch bloque {
                        case .suelta(let item):
                            filaDeTarea(item)
                        case .proyecto(let grupo):
                            GrupoFila(grupo: grupo,
                                      cerrado: pliegue.estaCerrado(grupo.proyecto)) {
                                withAnimation(.easeOut(duration: 0.18)) {
                                    pliegue.alternar(grupo.proyecto)
                                }
                            }
                            .listRowBackground(Papel.bg)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 16, leading: 16,
                                                      bottom: 4, trailing: 16))
                            if !pliegue.estaCerrado(grupo.proyecto) {
                                ForEach(grupo.tareas) { tarea in
                                    filaDeTarea(tarea, enGrupo: true)
                                }
                            }
                        }
                    }
                } else {
                    ForEach(Agenda.filas(tareas: items, eventos: eventos)) { fila in
                        switch fila {
                        case .tarea(let item): filaDeTarea(item)
                        case .evento(let evento): filaDeEvento(evento)
                        case .juntos(let evento, let item): filaDeTarea(item, evento: evento)
                        }
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

    /// Una fila de tarea con sus gestos. En una función y no repetida tres
    /// veces: las listas de siempre, el tramo con hora y lo que cuelga de un
    /// bloque son la misma fila, y tres copias acaban discrepando.
    @ViewBuilder
    private func filaDeTarea(_ item: Item, enGrupo: Bool = false,
                             evento: Evento? = nil) -> some View {
        FilaView(item: item, enGrupo: enGrupo, evento: evento) { abierta = item }
            // Con dos paneles, la fila de la tarea que está a la derecha se
            // marca: sin hoja que la tape, la lista sigue a la vista y hay que
            // saber cuál es. La misma marca que en el Mac —un filete en el
            // margen, sin pastillas—. En una columna no hace falta: la hoja
            // ya dice cuál es.
            .listRowBackground(Papel.bg.overlay(alignment: .leading) {
                if enDosPaneles && abierta?.id == item.id {
                    Rectangle().fill(Papel.accent).frame(width: 3)
                }
            })
            // Sangrada cuando cuelga de un proyecto: es lo que dice que cuelga.
            .listRowInsets(EdgeInsets(top: 9, leading: enGrupo ? 34 : 16,
                                      bottom: 9, trailing: 16))
            .listRowSeparatorTint(Papel.hairline)
            .swipeActions(edge: .trailing) {
                // En verde —el tinte de la app se come el papel destructivo—
                // era idéntico al de programar del otro lado.
                Button("Eliminar", role: .destructive) { store.delete(item) }
                    .tint(Papel.warning)
            }
            .swipeActions(edge: .leading) {
                // Aplazar a mano es lo que evita que una tarea se quede
                // mirándote todo el día sin poder tocarla.
                Button("Hoy") { store.schedule(item, to: .now) }
                    .tint(Papel.accentInk)
            }
    }

    /// Sin gestos: un evento no es tuyo, se lee y punto.
    private func filaDeEvento(_ evento: Evento) -> some View {
        EventoRow(evento: evento)
            .listRowBackground(Papel.bg)
            .listRowInsets(EdgeInsets(top: 9, leading: 16, bottom: 9, trailing: 16))
            .listRowSeparatorTint(Papel.hairline)
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
            switch agenda.permiso {
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
    /// No hay ni una tarea en ninguna lista: es el primer arranque, o uno que
    /// se quedó sin datos.
    var estrenando = false

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
        if estrenando { return "Todavía no hay nada. Pulsa + y apunta lo primero." }
        return switch perspectiva {
        case .today: "Nada para hoy. Buen día para no hacer nada."
        case .inbox: "La bandeja está vacía."
        case .upcoming: "Nada planificado más adelante."
        case .someday: "Nada aparcado."
        case .completed: "Todavía no has completado nada."
        default: "Nada por aquí."
        }
    }
}
