import SwiftUI
import PautaCore

/// El vaciado de la bandeja: una tarea delante, una decisión, la siguiente.
///
/// La bandeja existe para apuntar sin decidir, y el precio es decidir después
/// —un después que no llega—. Mirar sesenta cosas y elegir por dónde empezar es
/// otra decisión, la más cara de todas, y es la que hace que se cierre la lista
/// y no se vuelva. Aquí no hay nada que elegir: hay algo delante y hay que
/// contestar.
///
/// **Va con el teclado**, que es lo que un Mac puede hacer y un teléfono no:
/// veinte tareas en veinte pulsaciones, sin soltar la mano. Los atajos son la
/// inicial de cada decisión y se enseñan en el propio botón, porque un atajo
/// que hay que aprenderse en otro sitio no se usa.
struct VaciarBandejaView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var cerrar

    /// Las de la bandeja congeladas al abrir: despachar una la saca de la
    /// bandeja, así que una lista viva se reordenaría bajo la mano y perdería la
    /// cuenta de cuántas quedan.
    @State private var cola: [Item] = []
    @State private var indice = 0
    @State private var saltadas = 0
    @State private var eligiendoProyecto = false

    private var actual: Item? {
        guard indice < cola.count else { return nil }
        return store.items.first { $0.id == cola[indice].id } ?? cola[indice]
    }

    /// Las decisiones con su tecla. La inicial de cada una, salvo eliminar
    /// —retroceso, como en todas partes— y saltar, que es seguir.
    ///
    /// La letra se traduce con la palabra: «Today» no se despacha con la H. Si
    /// una traducción deja dos letras iguales —en inglés «Today» y «Tomorrow»
    /// empiezan por T—, dos botones tendrían la misma tecla y uno no
    /// funcionaría sin que nada lo dijera; entonces se vuelve a las del español.
    private var teclas: [(Despacho, KeyEquivalent, String)] {
        let decisiones: [Despacho] = [.hoy, .manana, .proximaSemana, .algunDia]
        let traducidas = [
            String(localized: "H", comment: "Tecla de «Hoy» en Vaciar la bandeja: una letra, distinta de las otras tres"),
            String(localized: "M", comment: "Tecla de «Mañana» en Vaciar la bandeja: una letra, distinta de las otras tres"),
            String(localized: "S", comment: "Tecla de «Próxima semana» en Vaciar la bandeja: una letra, distinta de las otras tres"),
            String(localized: "A", comment: "Tecla de «Algún día» en Vaciar la bandeja: una letra, distinta de las otras tres"),
        ].map { $0.uppercased() }
        let validas = traducidas.allSatisfy { $0.count == 1 && $0.first!.isLetter }
            && Set(traducidas).count == traducidas.count
        let letras = validas ? traducidas : ["H", "M", "S", "A"]
        return zip(decisiones, letras).map { decision, letra in
            (decision, KeyEquivalent(Character(letra.lowercased())), letra)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            cabecera
            Rectangle().fill(Paper.hairline).frame(height: 1)
            if let item = actual {
                tarjeta(item)
            } else {
                final
            }
        }
        .frame(width: 460)
        .background(Paper.bg)
        .task {
            guard cola.isEmpty else { return }
            cola = store.items(for: .inbox)
        }
    }

    private var cabecera: some View {
        HStack {
            Text("VACIAR LA BANDEJA").rubricStyle(Paper.inkSoft)
            Spacer()
            if actual != nil {
                Text("\(indice + 1) DE \(cola.count)").rubricStyle()
            }
            Button("Cerrar") { cerrar() }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Paper.accentInk)
                .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 13)
    }

    private func tarjeta(_ item: Item) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(item.title.isEmpty ? String(localized: "Sin título") : item.title)
                .font(.display(24))
                .tracking(-0.4)
                .foregroundStyle(Paper.ink)
                .fixedSize(horizontal: false, vertical: true)
            if !item.notes.isEmpty {
                Text(item.notes)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Paper.inkFaint)
                    .padding(.top, 7)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(spacing: 7) {
                ForEach(teclas, id: \.0) { decision, tecla, rotulo in
                    boton(decision.titulo, decision.icono, rotulo, Paper.ink) {
                        store.despachar(item, decision); avanzar()
                    }
                    .keyboardShortcut(tecla, modifiers: [])
                }
                if !store.projects.isEmpty {
                    // Con botón y popover, y no con `Menu`: el menú sin borde
                    // ignora la decoración de su etiqueta y aplica su propio
                    // tinte, así que la fila salía sin fondo y en verde, distinta
                    // de las otras cinco. Aquí las seis se ven iguales.
                    boton(String(localized: "A un proyecto"), "folder", "▾", Paper.ink) {
                        eligiendoProyecto = true
                    }
                    .popover(isPresented: $eligiendoProyecto, arrowEdge: .trailing) {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(store.projects) { p in
                                Button {
                                    store.despachar(item, .proyecto(p.id))
                                    eligiendoProyecto = false
                                    avanzar()
                                } label: {
                                    HStack(spacing: 7) {
                                        if !p.icon.isEmpty { Text(p.icon).font(.system(size: 12)) }
                                        Text(p.name).font(.system(size: 13))
                                        Spacer(minLength: 0)
                                    }
                                    .foregroundStyle(Paper.ink)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 6)
                        .frame(minWidth: 190)
                        .background(Paper.bg)
                    }
                }
                HStack(spacing: 7) {
                    // Saltar deja la tarea donde está: hay cosas que de verdad
                    // no se pueden decidir ahora, y forzar una decisión es como
                    // se acaba con una lista llena de fechas falsas.
                    boton(String(localized: "Saltar"), "arrow.right", "↩", Paper.inkSoft) {
                        saltadas += 1; avanzar()
                    }
                    .keyboardShortcut(.defaultAction)
                    boton(String(localized: "Eliminar"), "trash", "⌫", Paper.warning) {
                        store.despachar(item, .eliminar); avanzar()
                    }
                    .keyboardShortcut(.delete, modifiers: [])
                }
            }
            .padding(.top, 22)
        }
        .padding(18)
    }

    private func boton(_ titulo: String, _ icono: String, _ tecla: String,
                       _ tinta: Color, _ accion: @escaping () -> Void) -> some View {
        Button(action: accion) {
            HStack(spacing: 9) {
                Image(systemName: icono).font(.system(size: 12)).frame(width: 16)
                Text(titulo).font(.system(size: 13.5, weight: .medium))
                Spacer()
                Text(tecla).rubricStyle()
            }
            .foregroundStyle(tinta)
            .padding(.horizontal, 13)
            .padding(.vertical, 10)
            .background(tinta == Paper.warning ? Paper.warning.opacity(0.10) : Paper.bgSide,
                        in: RoundedRectangle(cornerRadius: 8))
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private var final: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(saltadas == 0 ? "Bandeja vacía" : "Bandeja casi vacía")
                .font(.display(22))
                .foregroundStyle(Paper.ink)
            if saltadas > 0 {
                Text(saltadas == 1 ? "Dejaste 1 para luego."
                                   : "Dejaste \(saltadas) para luego.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Paper.inkFaint)
            }
            Button("Listo") { cerrar() }
                .keyboardShortcut(.defaultAction)
                .padding(.top, 8)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func avanzar() { indice += 1 }
}
