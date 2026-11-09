import Foundation

/// El contenedor de iCloud propio de la app: la carpeta que el Mac, el iPhone y
/// el iPad ven sin que nadie elija nada.
///
/// Hasta noviembre de 2026 no podía existir —la cuenta era un equipo personal,
/// y Apple no emite iCloud para esos—, y por eso el Mac guarda en
/// `iCloud Drive/Pauta` por ruta y el teléfono cruza con una carpeta que eliges
/// a mano. El plan para pasar aquí está en docs/plan-contenedor-icloud.md.
public enum Contenedor {
    public static let identificador = "iCloud.dev.jadrdev.pauta"

    /// La carpeta `Documents` del contenedor, o `nil` si en este aparato no hay
    /// iCloud o la firma no lleva el permiso.
    ///
    /// **Bloquea**: la primera vez el sistema prepara el contenedor, y Apple
    /// pide no llamarlo desde el hilo principal.
    public static func documentos() -> URL? {
        FileManager.default.url(forUbiquityContainerIdentifier: identificador)?
            .appendingPathComponent("Documents", isDirectory: true)
    }

    // MARK: - Fase 0 (temporal: se quita al empezar la mudanza)

    /// Deja una marca de este aparato y cuenta las que han llegado de los demás.
    ///
    /// Es la prueba de la fase 0: que el contenedor existe con esta firma, y
    /// que lo que escribe un aparato llega a otro. No toca el almacén.
    public static func prueba(aparato: String, ahora: Date = .now) -> String {
        guard let raiz = documentos() else {
            return "sin contenedor: iCloud apagado o la firma no lleva \(identificador)"
        }
        let fm = FileManager.default
        let carpeta = raiz.appendingPathComponent("prueba", isDirectory: true)
        var informe = ["contenedor: \(raiz.path)"]
        do {
            try fm.createDirectory(at: carpeta, withIntermediateDirectories: true)
            let marca = carpeta.appendingPathComponent("\(aparato).txt")
            try "\(aparato) estuvo aquí: \(ahora.ISO8601Format())\n"
                .write(to: marca, atomically: true, encoding: .utf8)
            informe.append("escrita: \(marca.lastPathComponent)")
        } catch {
            informe.append("no se pudo escribir: \(error.localizedDescription)")
            return informe.joined(separator: "\n")
        }
        let vistas = (try? fm.contentsOfDirectory(at: carpeta, includingPropertiesForKeys:
                        [.ubiquitousItemDownloadingStatusKey])) ?? []
        for url in vistas.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let nombre = url.lastPathComponent
            if !Puente.enLocal(url) {
                try? fm.startDownloadingUbiquitousItem(at: url)
                informe.append("  · \(nombre): en iCloud, bajando…")
            } else {
                let texto = (try? String(contentsOf: url, encoding: .utf8))?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? "(ilegible)"
                informe.append("  · \(nombre): \(texto)")
            }
        }
        let resultado = informe.joined(separator: "\n")
        // Lo que vio, también escrito: desde el teléfono no hay terminal, y así
        // el Mac puede leer qué encontró el otro.
        try? (resultado + "\n").write(
            to: carpeta.appendingPathComponent("\(aparato) vio.log"),
            atomically: true, encoding: .utf8)
        return resultado
    }
}
