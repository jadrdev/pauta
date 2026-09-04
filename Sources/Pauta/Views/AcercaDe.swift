import SwiftUI
import AppKit
import PautaCore

/// Enlaces de la app. En un solo sitio para que no se dupliquen a medias.
enum Enlaces {
    static let repositorio = URL(string: "https://github.com/jadrdev/pauta")!
    static let guia = URL(string: "https://github.com/jadrdev/pauta#readme")!
    static let novedades = URL(string: "https://github.com/jadrdev/pauta/releases")!
    static let problemas = URL(string: "https://github.com/jadrdev/pauta/issues")!
}

/// Lo que la app sabe de sí misma, leído del bundle.
///
/// Del `Info.plist` y no de constantes en el código: la versión la pone el
/// empaquetado, y escribirla dos veces es garantizar que un día discrepen.
enum Acercade {
    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }
    static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }
    static var copyright: String {
        Bundle.main.infoDictionary?["NSHumanReadableCopyright"] as? String ?? ""
    }
}

/// El panel «Acerca de».
///
/// Sustituye al del sistema, que enseña el icono, el nombre y la versión y para
/// ahí. Aquí además se dice **dónde están los datos**, que es la pregunta que
/// de verdad se hace quien abre este panel en una app que guarda archivos
/// sueltos en una carpeta y no en una base de datos escondida.
struct AcercaDeView: View {
    @Environment(Store.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            BrandMark()
            Text("Un gestor de tareas para macOS. Las listas son consultas y no "
                 + "carpetas: mover algo es cambiar lo que hace que caiga ahí.")
                .font(.system(size: 12.5))
                .foregroundStyle(Paper.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)

            Text("VERSIÓN \(Acercade.version)  ·  BUILD \(Acercade.build)")
                .rubricStyle()
                .padding(.top, 16)

            Rectangle().fill(Paper.hairline).frame(height: 1).padding(.vertical, 16)

            Text("TUS DATOS").rubricStyle()
            // En maqueta hay que decirlo: enseñar la ruta de iCloud mientras se
            // miran datos inventados sería señalar unos archivos que no son los
            // que hay delante.
            Text(Launch.demo ? "Maqueta en memoria — no se escribe nada en disco"
                             : store.storageLocation)
                .font(.system(size: 11.5).monospaced())
                .foregroundStyle(Paper.inkSoft)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 5)
            if !Launch.demo {
                HStack(spacing: 10) {
                    Text(store.isSynced ? "Sincronizada por iCloud"
                                        : "Solo en este Mac, sin iCloud")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Paper.inkFaint)
                    EnlaceDeTexto("Abrir la carpeta") {
                        NSWorkspace.shared.activateFileViewerSelecting([store.storageURL])
                    }
                }
                .padding(.top, 6)
            }

            Rectangle().fill(Paper.hairline).frame(height: 1).padding(.vertical, 16)

            HStack(spacing: 14) {
                EnlaceDeTexto("Código") { NSWorkspace.shared.open(Enlaces.repositorio) }
                EnlaceDeTexto("Novedades") { NSWorkspace.shared.open(Enlaces.novedades) }
                Spacer(minLength: 0)
                Text(Acercade.copyright.isEmpty ? "Todos los derechos reservados"
                                                 : Acercade.copyright)
                    .font(.system(size: 10.5))
                    .foregroundStyle(Paper.inkFaint)
            }
        }
        .padding(26)
        .frame(width: 420)
        .background(Paper.bg)
    }
}

/// Un enlace que parece texto y no un botón del sistema.
///
/// Con `Button` y no con `Link`: `Link` pinta el azul del sistema y aquí manda
/// la paleta de la app.
struct EnlaceDeTexto: View {
    private let titulo: String
    private let accion: () -> Void
    @State private var encima = false

    init(_ titulo: String, accion: @escaping () -> Void) {
        self.titulo = titulo
        self.accion = accion
    }

    var body: some View {
        Button(action: accion) {
            Text(titulo)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(Paper.accentInk)
                .underline(encima)
        }
        .buttonStyle(.plain)
        .onHover { encima = $0 }
    }
}
