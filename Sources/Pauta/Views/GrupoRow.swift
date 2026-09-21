import SwiftUI
import PautaCore

/// La cabecera de un grupo de proyecto dentro de Hoy.
///
/// El filete que separa la cabecera de sus tareas **es** el indicador: se
/// entinta según despejas el bloque y queda entero al terminarlo. Hace dos
/// trabajos con una raya —separa y mide— y habla el idioma de la app, que es de
/// papel: filetes, rúbricas y tinta. Un gráfico de sectores sería de otra hoja.
///
/// Al lado, lo que queda. No lo que llevas hecho: «3 de 5» es información sobre
/// la mañana que ya pasó, y con lo que se decide si te pones ahora es con
/// «quedan 2 · 45 min». Y es lo que permite cerrar el grupo sin perder nada:
/// plegado, el rótulo sigue diciendo lo que hay dentro — «3 de 5» plegado no
/// diría nada.
///
/// **La cabecera pliega, no navega.** Cerrar es lo que se hace muchas veces al
/// día; ir al proyecto, de vez en cuando, y para eso está la barra lateral ahí
/// al lado y el menú secundario aquí mismo. Darle el clic a lo raro y esconder
/// lo frecuente detrás de un gesto sería al revés.
struct GrupoRow: View {
    @Environment(Store.self) private var store
    @Environment(Navigation.self) private var nav
    let grupo: GrupoDeProyecto
    let cerrado: Bool
    let alternar: () -> Void

    @State private var hovering = false

    private var proyecto: Project? { store.project(grupo.proyecto) }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                // Siempre visible, y no solo al pasar por encima: si el único
                // aviso de que esto se pliega apareciera con el ratón encima,
                // nadie sabría que se pliega.
                Image(systemName: "chevron.down")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundStyle(hovering ? Paper.accentInk : Paper.inkFaint)
                    .rotationEffect(.degrees(cerrado ? -90 : 0))
                    .frame(width: 9)
                if let icon = proyecto?.icon, !icon.isEmpty {
                    Text(icon).font(.system(size: 12))
                }
                Text(nombre)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(hovering ? Paper.accentInk : Paper.ink)
                Spacer(minLength: 12)
                Text(restante)
                    .rubricStyle()
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: alternar)
            .onHover { hovering = $0 }
            .help(detalle)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint(cerrado ? "Abrir el grupo" : "Cerrar el grupo")
            .contextMenu {
                Button(cerrado ? "Abrir" : "Cerrar", action: alternar)
                Divider()
                Button("Ir al proyecto") { nav.perspective = .project(grupo.proyecto) }
            }

            filete
        }
        .padding(.top, 14)
        .padding(.bottom, 4)
    }

    private var nombre: String {
        let puesto = proyecto?.name ?? ""
        return puesto.isEmpty ? "Sin título" : puesto
    }

    /// La raya. Entintada la parte despejada, filete la que falta.
    private var filete: some View {
        GeometryReader { medida in
            ZStack(alignment: .leading) {
                Rectangle().fill(Paper.hairline)
                Rectangle()
                    .fill(Paper.accent)
                    .frame(width: medida.size.width * grupo.fraccion)
            }
        }
        .frame(height: 2)
        .clipShape(Capsule())
        .animation(.easeOut(duration: 0.25), value: grupo.fraccion)
        .accessibilityLabel("\(grupo.hechas) de \(grupo.total) hechas")
    }

    /// «quedan 2 · 45 min».
    ///
    /// No hay estado «hecho»: al tachar la última, el bloque entero se va de
    /// Hoy, igual que se va una tarea suelta. Los minutos solo salen si has
    /// estimado algo —son un extra y no un requisito—, así que un proyecto sin
    /// estimar enseña «quedan 2» y ya.
    private var restante: String {
        guard let minutos = grupo.minutosRestantes else { return "QUEDAN \(grupo.quedan)" }
        return "QUEDAN \(grupo.quedan) · \(Duracion.etiqueta(minutos).uppercased())"
    }

    /// Lo de segundo orden, al pasar por encima: cómo va el proyecto entero —que
    /// el filete no mide— y si los minutos son toda la verdad o solo un suelo.
    private var detalle: String {
        var partes = ["\(grupo.hechas) de \(grupo.total) hechas hoy"]
        let abiertas = store.items(for: .project(grupo.proyecto)).count
        if abiertas > grupo.quedan {
            partes.append("\(abiertas) abiertas en el proyecto")
        }
        if grupo.sinEstimar > 0, grupo.minutosRestantes != nil {
            partes.append("\(grupo.sinEstimar) sin estimar")
        }
        return partes.joined(separator: " · ")
             + (cerrado ? " — clic para abrir" : " — clic para cerrar")
    }
}
