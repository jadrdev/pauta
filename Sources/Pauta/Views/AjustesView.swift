import SwiftUI
import AppKit
import ServiceManagement
import os
import PautaCore

/// Abrir Pauta al iniciar sesión.
///
/// No es comodidad: es la diferencia entre que la app funcione y que no. Con
/// Pauta cerrada, ⌃Espacio no existe, el repaso no se reprograma y la cuenta
/// atrás no está en ninguna parte. Una app que hay que acordarse de abrir para
/// que te acuerde de las cosas no sirve.
@MainActor
enum Arranque {
    private static let log = Logger(subsystem: "dev.jadrdev.pauta", category: "arranque")

    static var activo: Bool { SMAppService.mainApp.status == .enabled }

    /// Devuelve si quedó como se pedía.
    @discardableResult
    static func poner(_ encendido: Bool) -> Bool {
        do {
            if encendido { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            return activo == encendido
        } catch {
            log.error("no se pudo cambiar el arranque: \(error.localizedDescription)")
            return false
        }
    }
}

/// La pantalla de ajustes.
struct AjustesView: View {
    @Bindable var ajustes: Ajustes
    let store: Store

    @State private var alArrancar = Arranque.activo
    @State private var falloDeArranque = false
    @State private var grabandoAtajo = false

    private static let horasDeRepaso = [7 * 60, 7 * 60 + 30, 8 * 60, 8 * 60 + 30,
                                        9 * 60, 9 * 60 + 30, 10 * 60]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            grupo("AL ARRANCAR") {
                Toggle(isOn: Binding(get: { alArrancar },
                                     set: { nuevo in
                    alArrancar = nuevo
                    falloDeArranque = !Arranque.poner(nuevo)
                    if falloDeArranque { alArrancar = Arranque.activo }
                })) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Abrir Pauta al iniciar sesión").ajusteStyle()
                        Text("Con la app cerrada no hay atajo, ni avisos nuevos, "
                             + "ni cuenta atrás.")
                            .ajusteNota()
                    }
                }
                .toggleStyle(.switch)
                if falloDeArranque {
                    Text("El sistema no lo aceptó. Suele ser porque la app no está "
                         + "en Aplicaciones.")
                        .ajusteNota(Paper.warning)
                }
            }

            grupo("ALTA RÁPIDA") {
                GrabadorDeAtajo(grabando: $grabandoAtajo, actual: ajustes.atajo) { nuevo in
                    AltaRapida.shared.cambiar(a: nuevo)
                }
                Text("Abre la línea para apuntar algo sin ir a buscar la ventana. "
                     + "Si al pulsarlo no pasa nada, es que otra app o el propio "
                     + "sistema se queda esa combinación: el registro no falla, "
                     + "pero la tecla no llega. Elige otra.")
                    .ajusteNota()
            }

            grupo("REPASO DEL DÍA") {
                Picker(selection: $ajustes.repasoHora) {
                    Text("Desactivado").tag(Int?.none)
                    Divider()
                    ForEach(Self.horasDeRepaso, id: \.self) { m in
                        Text(ItemRowView.hora(m)).tag(Int?.some(m))
                    }
                } label: {
                    Text("Avisar a las").ajusteStyle()
                }
                .pickerStyle(.menu)
                .fixedSize()
                Text("Cuenta qué quedó sin hacer. Si no hay nada que decir, no suena.")
                    .ajusteNota()
            }

            grupo("AVISOS") {
                Picker(selection: $ajustes.margenPorDefecto) {
                    Text("A la hora").tag(0)
                    Divider()
                    ForEach([5, 10, 15, 30, 60], id: \.self) { m in
                        Text(Duracion.etiqueta(m) + " antes").tag(m)
                    }
                } label: {
                    Text("Avisar por defecto").ajusteStyle()
                }
                .pickerStyle(.menu)
                .fixedSize()
                Text("Se le pone a cada hora nueva. Las tareas que ya tengan margen "
                     + "propio no se tocan.")
                    .ajusteNota()

                Picker(selection: $ajustes.minutosAplazados) {
                    ForEach([5, 10, 15, 30], id: \.self) { m in
                        Text(Duracion.etiqueta(m)).tag(m)
                    }
                } label: {
                    Text("Aplazar").ajusteStyle()
                }
                .pickerStyle(.menu)
                .fixedSize()
                .padding(.top, 10)
            }

            grupo("BARRA DE MENÚS") {
                Toggle(isOn: $ajustes.barraConCuenta) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enseñar la cuenta atrás").ajusteStyle()
                        Text("«En 20 min · Recoger a los niños» cuando falta menos "
                             + "de una hora. Si no, solo el icono.")
                            .ajusteNota()
                    }
                }
                .toggleStyle(.switch)
            }

            Rectangle().fill(Paper.hairline).frame(height: 1).padding(.vertical, 14)
            HStack {
                EnlaceDeTexto("Restaurar los valores de fábrica") { ajustes.restaurar() }
                Spacer(minLength: 0)
            }
        }
        .padding(24)
        .frame(width: 460)
        .background(Paper.bg)
        .tint(Paper.accentInk)
        // La hora del repaso cambia lo que hay programado, así que se reprograma
        // al momento: esperar al siguiente cambio en las tareas dejaría la hora
        // nueva sin efecto hasta mañana.
        .onChange(of: ajustes.repasoHora) { Task { await Avisos.reschedule(store.items) } }
        // Y los minutos de aplazar están escritos en el botón del aviso, que se
        // congela al registrar la categoría.
        .onChange(of: ajustes.minutosAplazados) { Avisos.actualizarCategorias() }
        // Un permiso concedido o revocado en los ajustes del sistema mientras
        // esto estaba cerrado.
        .onAppear { alArrancar = Arranque.activo }
    }

    @ViewBuilder
    private func grupo(_ titulo: String,
                       @ViewBuilder _ contenido: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(titulo).rubricStyle()
            contenido()
        }
        .padding(.bottom, 20)
    }
}

private extension View {
    func ajusteStyle() -> some View {
        font(.system(size: 12.5, weight: .medium)).foregroundStyle(Paper.ink)
    }
    func ajusteNota(_ color: Color = Paper.inkFaint) -> some View {
        font(.system(size: 11))
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
    }
}
