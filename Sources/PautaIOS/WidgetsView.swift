import SwiftUI

/// Cómo poner el widget, desde Ajustes.
///
/// Una app no puede añadir su widget: solo el sistema, y solo si se lo pides tú
/// desde la pantalla de inicio. Así que quien no sabe que existe no lo pone
/// nunca, y el widget es justo lo que hace que Pauta se vea sin abrirla. Esto lo
/// cuenta, con los pasos tal como los dice el sistema.
struct WidgetsView: View {
    var body: some View {
        Form {
            Section {
                paso(1, "Mantén pulsado un hueco vacío de la pantalla de inicio, hasta que los iconos se muevan.")
                paso(2, "Toca «Editar», arriba, y luego «Añadir widget».")
                paso(3, "Busca «Pauta», elige el tamaño y toca «Añadir widget».")
            } header: {
                Text("EN LA PANTALLA DE INICIO")
            } footer: {
                Text("Enseña lo que toca hoy y lo que se arrastra de días pasados. El círculo tacha la tarea sin abrir la app.")
            }

            Section {
                paso(1, "Mantén pulsada la pantalla bloqueada y toca «Personalizar».")
                paso(2, "Elige la pantalla bloqueada y toca el hueco de los widgets, debajo de la hora.")
                paso(3, "Busca «Pauta» y tócalo.")
            } header: {
                Text("EN LA PANTALLA BLOQUEADA")
            } footer: {
                Text("Una línea con lo siguiente que toca, sin desbloquear.")
            }

            Section {
                paso(1, "Mantén pulsada la esfera del reloj y toca «Editar».")
                paso(2, "Desliza hasta las complicaciones y toca un hueco.")
                paso(3, "Busca «Pauta» y elígelo.")
            } header: {
                Text("EN EL APPLE WATCH")
            } footer: {
                Text("Cuántas tareas quedan hoy, en la esfera. Hace falta Pauta instalada en el reloj.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Papel.bg)
        .navigationTitle("Widget")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func paso(_ n: Int, _ texto: LocalizedStringKey) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(verbatim: "\(n)")
                .font(.system(size: 13, weight: .semibold).monospacedDigit())
                .foregroundStyle(Papel.accentInk)
                .frame(width: 16)
            Text(texto)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
