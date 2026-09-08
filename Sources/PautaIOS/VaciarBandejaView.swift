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
/// No se puede reordenar ni priorizar a propósito. Esto no es para organizar la
/// bandeja: es para dejarla vacía.
struct VaciarBandejaView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var cerrar

    /// Las de la bandeja congeladas al abrir.
    ///
    /// Congeladas y no leídas en vivo: despachar una la saca de la bandeja, así
    /// que una lista viva se reordenaría bajo el dedo y perdería la cuenta de
    /// cuántas quedan. También deja que entre algo nuevo por Siri sin empujar
    /// nada.
    @State private var cola: [Item] = []
    @State private var indice = 0
    @State private var saltadas = 0
    @State private var eligiendoProyecto = false

    private var actual: Item? {
        guard indice < cola.count else { return nil }
        // Se relee del almacén: la copia congelada puede tener el título viejo
        // si se editó mientras esto estaba abierto.
        return store.items.first { $0.id == cola[indice].id } ?? cola[indice]
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let item = actual {
                    tarjeta(item)
                } else {
                    final
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Papel.bg)
            .navigationTitle("Vaciar la bandeja")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { cerrar() }
                }
                if actual != nil {
                    ToolbarItem(placement: .principal) {
                        Text("\(indice + 1) DE \(cola.count)").rubrica()
                    }
                }
            }
        }
        .task {
            guard cola.isEmpty else { return }
            cola = store.items(for: .inbox)
        }
    }

    private func tarjeta(_ item: Item) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 20)
            Text(item.title.isEmpty ? "Sin título" : item.title)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(Papel.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 24)
            if !item.notes.isEmpty {
                Text(item.notes)
                    .font(.system(size: 15))
                    .foregroundStyle(Papel.inkFaint)
                    .multilineTextAlignment(.center)
                    .padding(.top, 10)
                    .padding(.horizontal, 30)
            }
            Spacer(minLength: 24)
            botones(item)
        }
    }

    private func botones(_ item: Item) -> some View {
        VStack(spacing: 9) {
            ForEach(Despacho.sueltas.filter { !$0.esDestructiva }, id: \.self) { d in
                boton(d) { store.despachar(item, d); avanzar() }
            }
            if !store.projects.isEmpty {
                boton(.proyecto(UUID())) { eligiendoProyecto = true }
            }
            HStack(spacing: 9) {
                // Saltar deja la tarea donde está: hay cosas que de verdad no se
                // pueden decidir ahora, y forzar una decisión es como se acaba
                // con una lista llena de fechas falsas.
                Button("Saltar") { saltadas += 1; avanzar() }
                    .buttonStyle(.plain)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Papel.inkSoft)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Papel.bgSide, in: RoundedRectangle(cornerRadius: 11))
                Button("Eliminar") { store.despachar(item, .eliminar); avanzar() }
                    .buttonStyle(.plain)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Papel.warning)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Papel.warning.opacity(0.10),
                                in: RoundedRectangle(cornerRadius: 11))
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
        .confirmationDialog("¿A qué proyecto?", isPresented: $eligiendoProyecto) {
            ForEach(store.projects) { p in
                Button(p.name) { store.despachar(item, .proyecto(p.id)); avanzar() }
            }
        }
    }

    private func boton(_ d: Despacho, _ accion: @escaping () -> Void) -> some View {
        Button(action: accion) {
            HStack(spacing: 10) {
                Image(systemName: d.icono).font(.system(size: 15)).frame(width: 22)
                Text(d.titulo).font(.system(size: 16, weight: .medium))
                Spacer()
            }
            .foregroundStyle(Papel.ink)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Papel.bgSide, in: RoundedRectangle(cornerRadius: 11))
        }
        .buttonStyle(.plain)
    }

    private var final: some View {
        VStack(spacing: 10) {
            Image(systemName: saltadas == 0 ? "tray" : "tray.full")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(Papel.accent)
            Text(saltadas == 0 ? "Bandeja vacía" : "Bandeja casi vacía")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Papel.ink)
            if saltadas > 0 {
                Text(saltadas == 1 ? "Dejaste 1 para luego."
                                   : "Dejaste \(saltadas) para luego.")
                    .font(.system(size: 15))
                    .foregroundStyle(Papel.inkFaint)
            }
            Button("Listo") { cerrar() }
                .font(.system(size: 16, weight: .semibold))
                .padding(.top, 10)
        }
    }

    private func avanzar() { indice += 1 }
}
