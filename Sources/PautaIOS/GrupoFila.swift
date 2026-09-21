import SwiftUI
import PautaCore

/// La cabecera de un grupo de proyecto en `Hoy`, en el teléfono.
///
/// Lo mismo que en el Mac y por las mismas razones: el filete que separa la
/// cabecera de sus tareas **es** el indicador, y al lado se dice lo que queda y
/// no lo que llevas hecho. Aquí pesa aún más, porque en una pantalla de teléfono
/// un proyecto con diez tareas es la lista entera: un toque y se pliega.
///
/// Sin ratón no hay rótulo emergente donde esconder nada, así que el galón va
/// siempre visible —como en el Mac, y por el mismo motivo— y lo de ir al
/// proyecto vive en el menú de mantener pulsado.
struct GrupoFila: View {
    let grupo: GrupoDeProyecto
    let cerrado: Bool
    let alternar: () -> Void

    @Environment(Store.self) private var store

    private var proyecto: Project? { store.project(grupo.proyecto) }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 7) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Papel.inkFaint)
                    .rotationEffect(.degrees(cerrado ? -90 : 0))
                    .frame(width: 11)
                if let icon = proyecto?.icon, !icon.isEmpty {
                    Text(icon).font(.system(size: 14))
                }
                Text(nombre)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Papel.ink)
                    .lineLimit(1)
                Spacer(minLength: 8)
                // Que se encoja antes el nombre del proyecto que la cuenta: el
                // nombre lo puedes adivinar por el emoji y por lo que cuelga
                // debajo; lo que queda, no.
                Text(restante)
                    .rubrica()
                    .fixedSize()
            }
            filete
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: alternar)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(cerrado ? "Abrir el grupo" : "Cerrar el grupo")
    }

    private var nombre: String {
        let puesto = proyecto?.name ?? ""
        return puesto.isEmpty ? "Sin título" : puesto
    }

    private var filete: some View {
        GeometryReader { medida in
            ZStack(alignment: .leading) {
                Rectangle().fill(Papel.hairline)
                Rectangle()
                    .fill(Papel.accent)
                    .frame(width: medida.size.width * grupo.fraccion)
            }
        }
        .frame(height: 2)
        .clipShape(Capsule())
        .animation(.easeOut(duration: 0.25), value: grupo.fraccion)
        .accessibilityHidden(true)
    }

    /// No hay estado «hecho»: al tachar la última, el bloque se va de Hoy.
    private var restante: String {
        guard let minutos = grupo.minutosRestantes else { return "QUEDAN \(grupo.quedan)" }
        return "QUEDAN \(grupo.quedan) · \(Duracion.etiqueta(minutos).uppercased())"
    }
}
