import SwiftUI
import PautaCore

/// Pegar un calendario en el teléfono: el mismo lector que en el Mac, y la
/// misma regla —nada se crea sin verlo antes—.
struct PegarCalendarioView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var cerrar
    let proyectoInicial: UUID?

    @State private var texto = ""
    @State private var lectura = Calendario.Lectura()
    @State private var prefijo = ""
    @State private var fuera: Set<UUID> = []
    @State private var repetidas: Set<UUID> = []
    @State private var destino: [String: UUID?] = [:]

    private var elegidas: [Calendario.Propuesta] {
        lectura.propuestas.filter { !fuera.contains($0.id) }
    }

    private var grupos: [(clave: String, propuestas: [Calendario.Propuesta])] {
        var claves = lectura.secciones
        if lectura.propuestas.contains(where: { $0.seccion == nil }) { claves.insert("", at: 0) }
        return claves.map { clave in (clave, lectura.propuestas.filter { ($0.seccion ?? "") == clave }) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextEditor(text: $texto)
                        .font(.system(size: 14).monospaced())
                        // Con tope: un PDF entero pegado empujaba la lista de lo
                        // entendido fuera de la pantalla, y la lista es lo que importa.
                        .frame(minHeight: 100, maxHeight: 160)
                        .onChange(of: texto) { releer() }
                    TextField("Delante de cada título, p. ej. «Tutoría: »", text: $prefijo)
                } footer: {
                    Text("Pega el texto de un PDF o de un mensaje con fechas. Abajo sale lo que se "
                         + "ha entendido, antes de crear nada.")
                }
                ForEach(grupos, id: \.clave) { grupo in
                    Section {
                        Picker("Va a", selection: Binding(
                            get: { destino[grupo.clave] ?? nil },
                            set: { destino[grupo.clave] = .some($0) })) {
                            Text("Bandeja").tag(UUID?.none)
                            ForEach(store.projects) { p in
                                Text((p.icon.isEmpty ? "" : p.icon + " ") + p.name).tag(UUID?.some(p.id))
                            }
                        }
                        ForEach(grupo.propuestas) { fila($0) }
                    } header: {
                        Text(grupo.clave.isEmpty ? "SIN APARTADO" : grupo.clave.uppercased())
                    }
                }
                if !lectura.ignoradas.isEmpty {
                    Section("SIN FECHA, NO SE CREA") {
                        ForEach(lectura.ignoradas, id: \.self) { linea in
                            Text(linea).font(.footnote).foregroundStyle(Papel.inkFaint)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Papel.bg)
            .navigationTitle("Pegar un calendario")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(elegidas.count == 1 ? "Crear 1" : "Crear \(elegidas.count)") {
                        store.crear(elegidas, prefijo: prefijo, proyecto: { p in
                            destino[p.seccion ?? ""] ?? nil
                        }, margen: Ajustes.shared.margenPorDefecto)
                        cerrar()
                    }
                    .disabled(elegidas.isEmpty)
                }
            }
        }
    }

    private func releer() {
        lectura = Calendario.leer(texto)
        repetidas = Calendario.yaEstan(lectura.propuestas, en: store.items)
        fuera = repetidas
        var nuevo: [String: UUID?] = [:]
        for clave in grupos.map(\.clave) {
            nuevo[clave] = destino[clave]
                ?? (clave.isEmpty ? proyectoInicial
                                  : Calendario.proyecto(para: clave, en: store.projects)?.id ?? proyectoInicial)
        }
        destino = nuevo
    }

    private func fila(_ p: Calendario.Propuesta) -> some View {
        let dentro = !fuera.contains(p.id)
        return Button {
            if dentro { fuera.insert(p.id) } else { fuera.remove(p.id) }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: dentro ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(dentro ? Papel.accentInk : Papel.inkFaint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(prefijo + p.titulo)
                        .foregroundStyle(dentro ? Papel.ink : Papel.inkFaint)
                        .strikethrough(!dentro)
                    Text(p.dia.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).year())
                         + " · " + horario(p))
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(Papel.inkSoft)
                    if repetidas.contains(p.id) {
                        Text("Ya está en Pauta").font(.footnote).foregroundStyle(Papel.inkFaint)
                    }
                    if let aviso = p.aviso {
                        Text(aviso).font(.footnote).foregroundStyle(Papel.warning)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func horario(_ p: Calendario.Propuesta) -> String {
        guard let m = p.minuto else { return "sin hora" }
        func reloj(_ m: Int) -> String { String(format: "%d:%02d", m / 60, m % 60) }
        guard let d = p.duracion else { return reloj(m) }
        return reloj(m) + "–" + reloj(m + d)
    }
}
