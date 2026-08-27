import Foundation
import EventKit
import os

/// Una tarea capturada en una fuente externa.
public struct Captured: Sendable {
    public let sourceID: String
    public let title: String
    public let notes: String
}

/// Captura desde Recordatorios de Apple.
///
/// Recordatorios sincroniza por iCloud y funciona con Siri, así que una lista
/// dedicada hace de bandeja de entrada remota: lo que apuntas en el iPhone
/// aparece aquí sin necesidad de una app de iOS.
///
/// Se usa **una lista propia**, nunca las del usuario. Así la app solo escribe
/// donde manda ella: al importar, el recordatorio se marca completado para que
/// no vuelva a entrar, y eso no debe pasarle a los recordatorios de nadie.
@MainActor
public final class RemindersInbox {
    /// Nombre de la lista dedicada. La app la crea si no existe.
    public static let listName = "Pauta"

    private let ek = EKEventStore()
    private let log = Logger(subsystem: "dev.jadrdev.pauta", category: "recordatorios")

    public init() {}

    public static var authorization: EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .reminder)
    }

    @discardableResult
    public func requestAccess() async throws -> Bool {
        let granted = try await ek.requestFullAccessToReminders()
        if !granted {
            log.notice("acceso a Recordatorios no concedido; la captura remota queda inactiva")
        }
        return granted
    }

    // MARK: - Lista dedicada

    /// La lista de la app, creándola si hace falta. Devuelve `nil` si no hay
    /// ninguna fuente capaz de guardar recordatorios.
    private func dedicatedList() throws -> EKCalendar? {
        let existing = ek.calendars(for: .reminder).first { $0.title == Self.listName }
        if let existing { return existing }

        guard let source = ek.defaultCalendarForNewReminders()?.source
                ?? ek.sources.first(where: { $0.calendars(for: .reminder).isEmpty == false })
                ?? ek.sources.first
        else { return nil }

        let list = EKCalendar(for: .reminder, eventStore: ek)
        list.title = Self.listName
        list.source = source
        try ek.saveCalendar(list, commit: true)
        return list
    }

    // MARK: - Importación

    /// Trae los recordatorios pendientes de la lista y los marca completados.
    ///
    /// El marcado va después de leerlos y en una sola confirmación: si algo
    /// falla, o se marcan todos o ninguno, y los que queden pendientes se
    /// reintentarán en la siguiente importación sin duplicarse (la tarea guarda
    /// el identificador de origen).
    public func drain() async throws -> [Captured] {
        guard let list = try dedicatedList() else { return [] }

        let predicate = ek.predicateForIncompleteReminders(
            withDueDateStarting: nil, ending: nil, calendars: [list])
        let pending: [EKReminder] = await withCheckedContinuation { continuation in
            ek.fetchReminders(matching: predicate) { found in
                continuation.resume(returning: found ?? [])
            }
        }
        guard !pending.isEmpty else { return [] }

        let captured = pending.map {
            Captured(sourceID: $0.calendarItemIdentifier,
                     title: ($0.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
                     notes: $0.notes ?? "")
        }

        for reminder in pending {
            reminder.isCompleted = true
            try ek.save(reminder, commit: false)
        }
        try ek.commit()

        return captured.filter { !$0.title.isEmpty }
    }

    /// Crea un recordatorio en la lista dedicada. Solo se usa para probar la
    /// integración de punta a punta sin tocar el iPhone.
    public func seedForTesting(title: String) throws {
        guard let list = try dedicatedList() else { return }
        let reminder = EKReminder(eventStore: ek)
        reminder.title = title
        reminder.calendar = list
        try ek.save(reminder, commit: true)
    }
}
