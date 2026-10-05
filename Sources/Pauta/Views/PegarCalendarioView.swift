import SwiftUI
import AppKit
import PautaCore

/// Pegar un calendario —un PDF de tutorías, un mensaje con las sesiones— y
/// crear una tarea por día.
///
/// Lo importante es la lista de en medio: **nada se crea sin verlo antes**.
/// Quien lee texto libre se equivoca, y aquí la equivocación se ve y se quita
/// con una casilla, en vez de descubrirla con veinte tareas ya puestas.
struct PegarCalendarioView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var cerrar
    /// El proyecto en el que se estaba, para lo que no traiga apartado.
    let proyectoInicial: UUID?

    @State private var texto = ""
    @State private var lectura = Calendario.Lectura()
    @State private var prefijo = ""
    @State private var fuera: Set<UUID> = []
    /// Las que ya estaban en Pauta: salen desmarcadas y lo dicen.
    @State private var repetidas: Set<UUID> = []
    /// A qué proyecto va cada apartado; la clave vacía es «sin apartado».
    @State private var destino: [String: UUID?] = [:]

    private var elegidas: [Calendario.Propuesta] {
        lectura.propuestas.filter { !fuera.contains($0.id) }
    }

    /// Los apartados, y uno sin nombre para lo que vino sin cabecera.
    private var grupos: [(clave: String, propuestas: [Calendario.Propuesta])] {
        var claves = lectura.secciones
        if lectura.propuestas.contains(where: { $0.seccion == nil }) { claves.insert("", at: 0) }
        return claves.map { clave in
            (clave, lectura.propuestas.filter { ($0.seccion ?? "") == clave })
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Pegar un calendario")
                .font(.display(22))
                .foregroundStyle(Paper.ink)
            Text("Pega el texto de un PDF o de un mensaje con fechas. Antes de crear nada, "
                 + "aquí abajo sale lo que se ha entendido.")
                .font(.system(size: 12))
                .foregroundStyle(Paper.inkSoft)

            TextEditor(text: $texto)
                .font(.system(size: 12).monospaced())
                .frame(height: 120)
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(Paper.bgSide, in: RoundedRectangle(cornerRadius: 6))
                .onChange(of: texto) { releer() }

            HStack(spacing: 8) {
                Text("Delante de cada título").font(.system(size: 12)).foregroundStyle(Paper.inkSoft)
                TextField("por ejemplo «Tutoría: »", text: $prefijo)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                    .frame(width: 200)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if lectura.propuestas.isEmpty {
                        Text(texto.isEmpty ? "Todavía nada." : "No se ha encontrado ninguna fecha con día.")
                            .font(.system(size: 12))
                            .foregroundStyle(Paper.inkFaint)
                    }
                    ForEach(grupos, id: \.clave) { grupo in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text((grupo.clave.isEmpty ? "SIN APARTADO" : grupo.clave.uppercased()))
                                    .rubricStyle()
                                Image(systemName: "arrow.right").font(.system(size: 9))
                                    .foregroundStyle(Paper.inkFaint)
                                selectorDeProyecto(grupo.clave)
                            }
                            ForEach(grupo.propuestas) { fila($0) }
                        }
                    }
                    if !lectura.ignoradas.isEmpty {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("SIN FECHA, NO SE CREA").rubricStyle()
                            ForEach(lectura.ignoradas, id: \.self) { linea in
                                Text(linea).font(.system(size: 11.5)).foregroundStyle(Paper.inkFaint)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: 180)

            HStack {
                Spacer()
                Button("Cancelar") { cerrar() }
                    .keyboardShortcut(.cancelAction)
                Button(elegidas.count == 1 ? "Crear 1 tarea" : "Crear \(elegidas.count) tareas") {
                    let margen = Ajustes.shared.margenPorDefecto
                    store.crear(elegidas, prefijo: prefijo, proyecto: { p in
                        destino[p.seccion ?? ""] ?? nil
                    }, margen: margen)
                    cerrar()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(elegidas.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 620, height: 620)
        .background(Paper.bg)
        .tint(Paper.accentInk)
        .onAppear {
            // Si lo que hay copiado se entiende, ya está pegado: es casi
            // siempre lo que se venía a pegar.
            if texto.isEmpty, let copiado = NSPasteboard.general.string(forType: .string),
               !Calendario.leer(copiado).propuestas.isEmpty {
                texto = copiado
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

    private func selectorDeProyecto(_ clave: String) -> some View {
        let actual = destino[clave] ?? nil
        let nombre = actual.flatMap { id in store.projects.first { $0.id == id } }
            .map { ($0.icon.isEmpty ? "" : $0.icon + " ") + $0.name } ?? "Bandeja"
        return Menu(nombre) {
            Button("Bandeja") { destino[clave] = .some(nil) }
            Divider()
            ForEach(store.projects) { p in
                Button((p.icon.isEmpty ? "" : p.icon + " ") + p.name) { destino[clave] = .some(p.id) }
            }
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .font(.system(size: 12, weight: .medium))
    }

    private func fila(_ p: Calendario.Propuesta) -> some View {
        let dentro = !fuera.contains(p.id)
        return HStack(alignment: .firstTextBaseline, spacing: 10) {
            Toggle("", isOn: Binding(get: { dentro },
                                     set: { if $0 { fuera.remove(p.id) } else { fuera.insert(p.id) } }))
                .labelsHidden()
                .toggleStyle(.checkbox)
            Text(p.dia.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).year()))
                .font(.system(size: 12).monospacedDigit())
                .foregroundStyle(Paper.inkSoft)
                .frame(width: 130, alignment: .leading)
            Text(horario(p))
                .font(.system(size: 12).monospacedDigit())
                .foregroundStyle(Paper.inkSoft)
                .frame(width: 90, alignment: .leading)
            VStack(alignment: .leading, spacing: 1) {
                Text(prefijo + p.titulo)
                    .font(.system(size: 12.5))
                    .foregroundStyle(dentro ? Paper.ink : Paper.inkFaint)
                    .strikethrough(!dentro)
                if repetidas.contains(p.id) {
                    Text("Ya está en Pauta").font(.system(size: 11)).foregroundStyle(Paper.inkFaint)
                }
                if let aviso = p.aviso {
                    Text(aviso).font(.system(size: 11)).foregroundStyle(Paper.warning)
                }
            }
        }
    }

    private func horario(_ p: Calendario.Propuesta) -> String {
        guard let m = p.minuto else { return "sin hora" }
        func reloj(_ m: Int) -> String { String(format: "%d:%02d", m / 60, m % 60) }
        guard let d = p.duracion else { return reloj(m) }
        return reloj(m) + "–" + reloj(m + d)
    }
}
