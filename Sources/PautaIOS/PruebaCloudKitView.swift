import SwiftUI
import UIKit
import PautaCore

// ANDAMIO-CLOUDKIT: todo este archivo es de la fase 0 del plan de CloudKit
// (docs/plan-cloudkit.md) y se borra al cerrarla. Los textos van con
// `verbatim` a propósito: no son de la app y no entran en el catálogo.

/// Recibe los avisos silenciosos. Pedir el registro no pregunta nada al
/// usuario: los avisos silenciosos no necesitan permiso.
final class DelegadoDePruebaCloudKit: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions opciones: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        application.registerForRemoteNotifications()
        return true
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        UserDefaults.standard.set("no se pudo registrar: \(error.localizedDescription)",
                                  forKey: "pruebaCloudKit.registro")
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken token: Data) {
        UserDefaults.standard.set("registrado para avisos", forKey: "pruebaCloudKit.registro")
    }

    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any]) async
        -> UIBackgroundFetchResult {
        guard PruebaCloudKit.esDeLaPrueba(userInfo) else { return .noData }
        await PruebaCloudKit.alRecibirAviso()
        NotificationCenter.default.post(name: .avisoDePruebaCloudKit, object: nil)
        return .newData
    }
}

extension Notification.Name {
    static let avisoDePruebaCloudKit = Notification.Name("avisoDePruebaCloudKit")
}

/// La pantalla de la prueba: `pauta://cloudkit-prueba` desde Safari o Notas.
struct PruebaCloudKitView: View {
    @State private var cuenta = "…"
    @State private var registros: [PruebaCloudKit.Registro] = []
    @State private var avisos = PruebaCloudKit.avisos
    @State private var linea = ""
    @State private var ocupado = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(verbatim: "Cuenta: \(cuenta)")
                    Text(verbatim: UserDefaults.standard.string(forKey: "pruebaCloudKit.registro")
                         ?? "sin registrar para avisos todavía")
                    if !linea.isEmpty { Text(verbatim: linea).foregroundStyle(.secondary) }
                }
                Section {
                    boton("1. Preparar zona y suscripción") {
                        try await PruebaCloudKit.preparar(); return "preparado"
                    }
                    boton("2. Escribir uno desde el iPhone") {
                        let t = try await PruebaCloudKit.escribir(desde: UIDevice.current.name)
                        return "escrito a las \(hora(t))"
                    }
                    boton("Leer") {
                        registros = try await PruebaCloudKit.leer()
                        return "\(registros.count) registros"
                    }
                    boton("Borrar zona y suscripción") {
                        try await PruebaCloudKit.borrarTodo()
                        PruebaCloudKit.olvidarAvisos()
                        avisos = []; registros = []
                        return "borrado"
                    }
                }
                Section {
                    if avisos.isEmpty { Text(verbatim: "Ninguno todavía").foregroundStyle(.secondary) }
                    ForEach(Array(avisos.enumerated()), id: \.offset) { _, a in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: "Llegó a las \(hora(a.recibido))")
                            Text(verbatim: a.retraso.map { String(format: "%.1f s desde que %@ lo escribió", $0, a.ultimoDe ?? "?") }
                                 ?? "sin registro")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                } header: { Text(verbatim: "AVISOS RECIBIDOS") }
                Section {
                    ForEach(Array(registros.enumerated()), id: \.offset) { _, r in
                        Text(verbatim: "\(hora(r.escrito)) · \(r.aparato)")
                    }
                } header: { Text(verbatim: "REGISTROS") }
            }
            .navigationTitle(Text(verbatim: "Prueba de CloudKit"))
            .navigationBarTitleDisplayMode(.inline)
            .disabled(ocupado)
        }
        .task { cuenta = await PruebaCloudKit.cuenta() }
        .onReceive(NotificationCenter.default.publisher(for: .avisoDePruebaCloudKit)) { _ in
            avisos = PruebaCloudKit.avisos
        }
    }

    private func boton(_ titulo: String, _ accion: @escaping () async throws -> String) -> some View {
        Button {
            ocupado = true
            Task {
                do { linea = try await accion() } catch { linea = PruebaCloudKit.describir(error) }
                ocupado = false
            }
        } label: { Text(verbatim: titulo) }
    }

    private func hora(_ fecha: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss.SSS"
        return f.string(from: fecha)
    }
}
