import Foundation
import Testing
@testable import PautaCore

/// El troceo de texto pegado en títulos de tarea.
@MainActor
struct TitleParsingTests {
    @Test func multilineWithBullets() {
        let text = """
        * Perspectiva `Cualquier momento`
        * Áreas que agrupen proyectos

        - Con guion
        • Con punto gordo
        3. Numerada
        4) Numerada con paréntesis
          indentada sin viñeta
        """
        #expect(Store.titles(from: text) == [
            "Perspectiva `Cualquier momento`",
            "Áreas que agrupen proyectos",
            "Con guion",
            "Con punto gordo",
            "Numerada",
            "Numerada con paréntesis",
            "indentada sin viñeta",
        ])
    }

    @Test func singleLine() {
        #expect(Store.titles(from: "  Comprar pan  ") == ["Comprar pan"])
    }

    @Test func blankTextYieldsNothing() {
        #expect(Store.titles(from: "\n  \n") == [])
    }

    @Test func addItemsCreatesOnePerLine() {
        let store = Store(inMemory: true)
        let created = store.addItems(from: "* uno\n* dos\n* tres", in: .today)
        #expect(created.map(\.title) == ["uno", "dos", "tres"])
        #expect(store.items(for: .today).count == 3)
    }
}

/// Los filtros de las perspectivas sobre un almacén en memoria.
@MainActor
struct PerspectiveTests {
    @Test func anytimeExcludesInboxAndFuture() {
        let store = Store(inMemory: true)
        let project = store.addProject(name: "P")
        store.addItem(title: "en bandeja", in: .inbox)
        store.addItem(title: "para hoy", in: .today)
        store.addItem(title: "de proyecto sin fecha", in: .project(project.id))
        store.addItem(title: "futura", in: .upcoming)
        store.addItem(title: "aparcada", in: .someday)

        let titles = store.items(for: .anytime).map(\.title)
        #expect(titles.contains("para hoy"))
        #expect(titles.contains("de proyecto sin fecha"))
        #expect(!titles.contains("en bandeja"))
        #expect(!titles.contains("futura"))
        #expect(!titles.contains("aparcada"))
    }
}

/// Mover una tarea de lista: «mover» es cambiar los campos que la hacen caer en
/// esa consulta, porque las listas no son carpetas.
@MainActor
struct MoveTests {
    private func store() -> Store { Store(inMemory: true) }

    @Test func toTodayGivesItTodaysDate() {
        let s = store()
        let item = s.addItem(title: "x", in: .someday)
        s.move(item, to: .today)
        #expect(s.count(for: .today) == 1)
        #expect(s.count(for: .someday) == 0)
    }

    @Test func toUpcomingUsesTomorrowWhenUndated() {
        let s = store()
        let item = s.addItem(title: "x", in: .inbox)
        s.move(item, to: .upcoming)
        #expect(s.count(for: .upcoming) == 1)
    }

    /// Si ya estaba planificada para más adelante, mover a Próximamente no debe
    /// adelantarla a mañana.
    @Test func toUpcomingKeepsAnExistingFutureDate() {
        let s = store()
        let item = s.addItem(title: "x", in: .inbox)
        let enUnaSemana = Calendar.current.date(byAdding: .day, value: 7, to: .now)!
        s.schedule(item, to: enUnaSemana)
        s.move(s.items[0], to: .upcoming)
        let esperado = Calendar.current.startOfDay(for: enUnaSemana)
        #expect(s.items[0].when == esperado)
    }

    @Test func toSomedayParksAndClearsDate() {
        let s = store()
        let item = s.addItem(title: "x", in: .today)
        s.move(item, to: .someday)
        #expect(s.items[0].isSomeday)
        #expect(s.items[0].when == nil)
        #expect(s.count(for: .today) == 0)
    }

    /// A la bandeja se va sin nada decidido: ni fecha, ni aparcado, ni proyecto.
    @Test func toInboxClearsEverything() {
        let s = store()
        let p = s.addProject(name: "proyecto")
        let item = s.addItem(title: "x", in: .project(p.id))
        s.schedule(item, to: .now)
        s.move(s.items[0], to: .inbox)
        #expect(s.count(for: .inbox) == 1)
        #expect(s.items[0].projectID == nil)
        #expect(s.items[0].when == nil)
    }

    @Test func toProjectAssignsItKeepingTheDate() {
        let s = store()
        let p = s.addProject(name: "proyecto")
        let item = s.addItem(title: "x", in: .today)
        s.move(item, to: .project(p.id))
        #expect(s.items[0].projectID == p.id)
        #expect(s.count(for: .today) == 1)
    }

    /// Mover una completada a una lista de pendientes la reabre: si no, se
    /// movería a un sitio donde no aparece y parecería que se ha perdido.
    @Test func movingACompletedTaskReopensIt() {
        let s = store()
        let item = s.addItem(title: "x", in: .inbox)
        s.toggleComplete(item)
        #expect(s.count(for: .completed) == 1)
        s.move(s.items[0], to: .today)
        #expect(s.count(for: .completed) == 0)
        #expect(s.count(for: .today) == 1)
    }

    @Test func toCompletedMarksItDone() {
        let s = store()
        let item = s.addItem(title: "x", in: .today)
        s.move(item, to: .completed)
        #expect(s.count(for: .completed) == 1)
    }
}

/// Fechas límite: cuándo tiene que estar, distinto de cuándo pienso ponerme.
@MainActor
struct DeadlineTests {
    private func fecha(_ dias: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: dias, to: .now)!
    }

    /// Es independiente de la planificación: se puede tener entrega el viernes
    /// sin haber decidido cuándo ponerse.
    @Test func deadlineIsIndependentOfScheduling() {
        let s = Store(inMemory: true)
        let t = s.addItem(title: "Entregar informe", in: .inbox)
        s.setDeadline(t, to: fecha(5))
        #expect(s.items[0].when == nil)
        #expect(s.items[0].deadline != nil)
        // Sigue en la bandeja: tener entrega no es haberla planificado.
        #expect(s.count(for: .inbox) == 1)
    }

    /// Una entrega que vence arrastra la tarea a Hoy aunque no estuviera
    /// planificada: si no saliera el día que toca, no serviría de nada.
    @Test func aDueDeadlinePullsTheTaskIntoToday() {
        let s = Store(inMemory: true)
        let t = s.addItem(title: "Entregar hoy", in: .inbox)
        #expect(s.count(for: .today) == 0)
        s.setDeadline(t, to: .now)
        #expect(s.count(for: .today) == 1)
    }

    @Test func anOverdueDeadlineAlsoPullsItIn() {
        let s = Store(inMemory: true)
        let t = s.addItem(title: "Se pasó", in: .inbox)
        s.setDeadline(t, to: fecha(-3))
        #expect(s.count(for: .today) == 1)
        #expect(s.items[0].isOverdue)
        #expect(s.items[0].deadlineIsDue)
    }

    /// Una entrega futura no adelanta nada.
    @Test func aFutureDeadlineDoesNotPullItIn() {
        let s = Store(inMemory: true)
        let t = s.addItem(title: "Para la semana que viene", in: .inbox)
        s.setDeadline(t, to: fecha(7))
        #expect(s.count(for: .today) == 0)
        #expect(!s.items[0].isOverdue)
        #expect(!s.items[0].deadlineIsDue)
    }

    /// Lo aparcado se respeta: aparcarlo fue una decisión explícita.
    @Test func parkedTasksStayParkedEvenIfOverdue() {
        let s = Store(inMemory: true)
        let t = s.addItem(title: "Aparcada con entrega", in: .someday)
        s.setDeadline(t, to: fecha(-2))
        #expect(s.count(for: .today) == 0)
        #expect(s.count(for: .someday) == 1)
    }

    /// Completar apaga el aviso: ya no hay nada que entregar.
    @Test func completingClearsTheUrgency() {
        let s = Store(inMemory: true)
        let t = s.addItem(title: "Entregada", in: .inbox)
        s.setDeadline(t, to: fecha(-1))
        s.toggleComplete(s.items[0])
        #expect(!s.items[0].isOverdue)
        #expect(s.count(for: .today) == 0)
    }

    @Test func clearingTheDeadlineRemovesItFromToday() {
        let s = Store(inMemory: true)
        let t = s.addItem(title: "x", in: .inbox)
        s.setDeadline(t, to: .now)
        #expect(s.count(for: .today) == 1)
        s.setDeadline(s.items[0], to: nil)
        #expect(s.count(for: .today) == 0)
    }
}

/// Tareas repetitivas: al completar una nace la siguiente, y la completada se
/// queda en el historial.
@MainActor
struct RecurrenceTests {
    @Test func completingSpawnsTheNextOne() {
        let s = Store(inMemory: true)
        var tarea = s.addItem(title: "Sacar la basura", in: .today)
        tarea.recurrence = .diaria
        s.update(tarea)

        s.toggleComplete(s.items[0])
        #expect(s.count(for: .completed) == 1)
        #expect(s.count(for: .today) == 0)   // la siguiente es mañana
        #expect(s.count(for: .upcoming) == 1)
        #expect(s.items(for: .upcoming)[0].recurrence == .diaria)
    }

    /// La sucesora hereda notas y proyecto: es la misma rutina otra vez.
    @Test func theSuccessorInheritsNotesAndProject() {
        let s = Store(inMemory: true)
        let p = s.addProject(name: "Casa")
        var tarea = s.addItem(title: "Regar las plantas", in: .project(p.id))
        tarea.notes = "Las del balcón también"
        tarea.recurrence = .semanal
        tarea.when = Calendar.current.startOfDay(for: .now)
        s.update(tarea)

        s.toggleComplete(s.items[0])
        let siguiente = s.items.first { !$0.isCompleted }
        #expect(siguiente?.notes == "Las del balcón también")
        #expect(siguiente?.projectID == p.id)
    }

    /// Se cuenta desde la fecha que tenía, no desde hoy: completar tarde una
    /// tarea semanal no debe desplazar su día para siempre.
    @Test func theNextDateCountsFromTheScheduledDayNotToday() {
        let s = Store(inMemory: true)
        let hace3 = Calendar.current.date(byAdding: .day, value: -3, to: .now)!
        var tarea = s.addItem(title: "Semanal", in: .inbox)
        tarea.recurrence = .semanal
        s.update(tarea)
        s.schedule(s.items[0], to: hace3)

        s.toggleComplete(s.items[0])
        let siguiente = s.items.first { !$0.isCompleted }
        let esperado = Recurrence.semanal.next(after: Calendar.current.startOfDay(for: hace3))
        #expect(siguiente?.when == esperado)
    }

    /// Marcar y desmarcar no debe dejar copias acumuladas.
    @Test func uncompletingRetiresTheSpawnedSuccessor() {
        let s = Store(inMemory: true)
        var tarea = s.addItem(title: "Repetitiva", in: .today)
        tarea.recurrence = .diaria
        s.update(tarea)

        s.toggleComplete(s.items[0])
        #expect(s.items.filter { !$0.isCompleted }.count == 1)
        s.toggleComplete(s.items.first { $0.isCompleted }!)
        #expect(s.items.filter { !$0.isCompleted }.count == 1)
        #expect(s.count(for: .completed) == 0)
    }

    /// Una tarea sin repetición no genera nada.
    @Test func nonRecurringTasksSpawnNothing() {
        let s = Store(inMemory: true)
        let tarea = s.addItem(title: "Normal", in: .today)
        s.toggleComplete(tarea)
        #expect(s.items.count == 1)
    }

    /// Con fecha de fin, la serie para: la última se completa y no nace otra.
    @Test func recurrenceStopsAtItsEndDate() {
        let s = Store(inMemory: true)
        let cal = Calendar.current
        var tarea = s.addItem(title: "Diaria hasta mañana", in: .today)
        tarea.recurrence = .diaria
        tarea.when = cal.startOfDay(for: .now)
        tarea.recurrenceEnd = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: .now))
        s.update(tarea)

        // Primera: la siguiente cae mañana, que aún entra.
        s.toggleComplete(s.items[0])
        #expect(s.items.filter { !$0.isCompleted }.count == 1)

        // Segunda: la siguiente caería pasado mañana, ya fuera de plazo.
        s.toggleComplete(s.items.first { !$0.isCompleted }!)
        #expect(s.items.filter { !$0.isCompleted }.isEmpty)
        #expect(s.count(for: .completed) == 2)
    }

    /// La sucesora hereda el fin: si no, la serie sería infinita a la segunda.
    @Test func theSuccessorInheritsTheEndDate() {
        let s = Store(inMemory: true)
        let fin = Calendar.current.date(byAdding: .day, value: 30, to: .now)!
        var tarea = s.addItem(title: "Semanal", in: .today)
        tarea.recurrence = .semanal
        tarea.recurrenceEnd = Calendar.current.startOfDay(for: fin)
        s.update(tarea)

        s.toggleComplete(s.items[0])
        let siguiente = s.items.first { !$0.isCompleted }
        #expect(siguiente?.recurrenceEnd == Calendar.current.startOfDay(for: fin))
    }

    /// Sin fecha de fin no acaba nunca, que es el caso normal.
    @Test func withoutAnEndDateItNeverStops() {
        let s = Store(inMemory: true)
        var tarea = s.addItem(title: "Para siempre", in: .today)
        tarea.recurrence = .diaria
        s.update(tarea)
        for _ in 1...5 {
            s.toggleComplete(s.items.first { !$0.isCompleted }!)
        }
        #expect(s.items.filter { !$0.isCompleted }.count == 1)
        #expect(s.count(for: .completed) == 5)
    }

    /// Quitar la repetición borra su fin: un «hasta» suelto no significa nada.
    @Test func removingRecurrenceClearsItsEnd() {
        let s = Store(inMemory: true)
        let t = s.addItem(title: "x", in: .today)
        s.setRecurrence(t, to: .semanal)
        s.setRecurrenceEnd(s.items[0], to: Date())
        #expect(s.items[0].recurrenceEnd != nil)
        s.setRecurrence(s.items[0], to: nil)
        #expect(s.items[0].recurrenceEnd == nil)
    }

    @Test func nextDatesAreCorrect() {
        let cal = Calendar.current
        let base = cal.startOfDay(for: Date(timeIntervalSince1970: 1_780_000_000))
        #expect(Recurrence.diaria.next(after: base) == cal.date(byAdding: .day, value: 1, to: base))
        #expect(Recurrence.semanal.next(after: base) == cal.date(byAdding: .weekOfYear, value: 1, to: base))
        #expect(Recurrence.mensual.next(after: base) == cal.date(byAdding: .month, value: 1, to: base))
        #expect(Recurrence.anual.next(after: base) == cal.date(byAdding: .year, value: 1, to: base))
    }
}

/// La purga de lápidas: dejan de proteger cuando todos los dispositivos ya han
/// visto el borrado, y a partir de ahí solo estorban.
@MainActor
struct TombstoneTests {
    private func tempRoot() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("PautaLapidas-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func archivos(_ root: URL) -> Int {
        ((try? FileManager.default.contentsOfDirectory(
            at: root.appendingPathComponent("items"), includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.pathExtension == "json" }.count
    }

    @Test func removesTombstonesPastRetention() throws {
        let root = tempRoot()
        let store = Store(root: root)
        store.addItem(title: "se queda", in: .inbox)
        let vieja = store.addItem(title: "borrada hace mucho", in: .inbox)
        store.delete(vieja)
        #expect(archivos(root) == 2)

        // 40 días después.
        let futuro = Date().addingTimeInterval(40 * 24 * 3600)
        #expect(store.purgeOldTombstones(now: futuro) == 1)
        #expect(archivos(root) == 1)
        #expect(Store(root: root).items.map(\.title) == ["se queda"])
    }

    /// Una lápida reciente no se toca: es justo cuando hace falta.
    @Test func keepsRecentTombstones() throws {
        let root = tempRoot()
        let store = Store(root: root)
        let borrada = store.addItem(title: "recién borrada", in: .inbox)
        store.delete(borrada)
        #expect(store.purgeOldTombstones() == 0)
        #expect(archivos(root) == 1)
    }

    /// Las tareas vivas nunca se tocan, por antiguas que sean.
    @Test func neverTouchesLiveItems() throws {
        let root = tempRoot()
        let store = Store(root: root)
        store.addItem(title: "viva y vieja", in: .inbox)
        store.toggleComplete(store.items[0])
        let futuro = Date().addingTimeInterval(365 * 24 * 3600)
        #expect(store.purgeOldTombstones(now: futuro) == 0)
        #expect(archivos(root) == 1)
        // Las completadas se conservan: son historial, no basura.
        #expect(Store(root: root).count(for: .completed) == 1)
    }
}

/// El orden manual: prioridad arrastrando.
@MainActor
struct OrderingTests {
    private func tempRoot() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("PautaOrden-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test func newItemsGoToTheEnd() {
        let s = Store(inMemory: true)
        s.addItem(title: "a", in: .inbox)
        s.addItem(title: "b", in: .inbox)
        s.addItem(title: "c", in: .inbox)
        #expect(s.items(for: .inbox).map(\.title) == ["a", "b", "c"])
    }

    @Test func placingBeforeMovesIt() {
        let s = Store(inMemory: true)
        s.addItem(title: "a", in: .inbox)
        s.addItem(title: "b", in: .inbox)
        let c = s.addItem(title: "c", in: .inbox)
        s.place(c, before: s.items(for: .inbox)[0], in: .inbox)
        #expect(s.items(for: .inbox).map(\.title) == ["c", "a", "b"])
    }

    @Test func placingWithoutTargetSendsItToTheEnd() {
        let s = Store(inMemory: true)
        let a = s.addItem(title: "a", in: .inbox)
        s.addItem(title: "b", in: .inbox)
        s.place(a, before: nil, in: .inbox)
        #expect(s.items(for: .inbox).map(\.title) == ["b", "a"])
    }

    /// Reordenar debe escribir un solo archivo: con la carpeta sincronizada,
    /// reasignar posiciones a toda la lista sería tráfico por nada.
    @Test func reorderingWritesOnlyOneFile() throws {
        let root = tempRoot()
        let s = Store(root: root)
        s.addItem(title: "a", in: .inbox)
        let b = s.addItem(title: "b", in: .inbox)
        s.addItem(title: "c", in: .inbox)

        let fileA = root.appendingPathComponent("items/\(s.items(for: .inbox)[0].id.uuidString).json")
        let antes = try Data(contentsOf: fileA)
        s.place(b, before: nil, in: .inbox)
        #expect(try Data(contentsOf: fileA) == antes)
        #expect(s.items(for: .inbox).map(\.title) == ["a", "c", "b"])
    }

    /// Datos anteriores al campo valen todas 0; hay que poder reordenarlos.
    @Test func canReorderDataSavedBeforePositionsExisted() throws {
        let root = tempRoot()
        let itemsDir = root.appendingPathComponent("items", isDirectory: true)
        try FileManager.default.createDirectory(at: itemsDir, withIntermediateDirectories: true)
        for (i, titulo) in ["a", "b", "c"].enumerated() {
            let id = UUID()
            let fecha = "2026-08-2\(i)T10:00:00Z"
            let json = #"{"id":"\#(id.uuidString)","title":"\#(titulo)","createdAt":"\#(fecha)"}"#
            try json.write(to: itemsDir.appendingPathComponent("\(id.uuidString).json"),
                           atomically: true, encoding: .utf8)
        }
        let s = Store(root: root)
        #expect(s.items(for: .inbox).map(\.title) == ["a", "b", "c"])
        let c = s.items(for: .inbox)[2]
        s.place(c, before: s.items(for: .inbox)[0], in: .inbox)
        #expect(s.items(for: .inbox).map(\.title) == ["c", "a", "b"])
        // Y sobrevive a recargar.
        #expect(Store(root: root).items(for: .inbox).map(\.title) == ["c", "a", "b"])
    }
}

/// Arrastrar en «Próximamente», donde soltar dice también en qué día.
@MainActor
struct UpcomingDropTests {
    private func dia(_ n: Int) -> Date {
        let cal = Calendar.current
        return cal.startOfDay(for: cal.date(byAdding: .day, value: n, to: .now)!)
    }

    @Test func droppingOnAnotherDayChangesTheDate() {
        let s = Store(inMemory: true)
        let a = s.addItem(title: "a", in: .inbox)
        let b = s.addItem(title: "b", in: .inbox)
        s.schedule(a, to: dia(1))
        s.schedule(b, to: dia(3))

        s.place(a, before: s.items(for: .upcoming).first { $0.title == "b" }, in: .upcoming)
        #expect(s.items(for: .upcoming).first { $0.title == "a" }?.day == dia(3))
    }

    @Test func andItLandsExactlyWhereYouDroppedIt() {
        let s = Store(inMemory: true)
        let a = s.addItem(title: "a", in: .inbox)
        let b = s.addItem(title: "b", in: .inbox)
        let c = s.addItem(title: "c", in: .inbox)
        s.schedule(a, to: dia(1))
        s.schedule(b, to: dia(3))
        s.schedule(c, to: dia(3))

        s.place(a, before: s.items(for: .upcoming).first { $0.title == "c" }, in: .upcoming)
        #expect(s.items(for: .upcoming).map(\.title) == ["b", "a", "c"])
    }

    /// Las posiciones son globales y el orden de la lista lo manda la fecha, así
    /// que la fila de encima de la primera tarea de un día es de otro día. Si el
    /// punto medio se calculara con ella, soltar sobre la primera de un día
    /// podría dejar la tarea detrás.
    @Test func neighboursAreTakenFromTheTargetDayOnly() {
        let s = Store(inMemory: true)
        // x se crea primero, así que tiene la posición más baja pese a caer el
        // último día: es justo el caso que rompía la cuenta.
        let x = s.addItem(title: "x", in: .inbox)
        let y = s.addItem(title: "y", in: .inbox)
        let z = s.addItem(title: "z", in: .inbox)
        s.schedule(x, to: dia(3))
        s.schedule(y, to: dia(1))
        s.schedule(z, to: dia(5))
        #expect(s.items(for: .upcoming).map(\.title) == ["y", "x", "z"])

        s.place(z, before: s.items(for: .upcoming).first { $0.title == "x" }, in: .upcoming)
        #expect(s.items(for: .upcoming).map(\.title) == ["y", "z", "x"])
    }

    /// En las listas sin agrupar soltar sigue siendo solo prioridad: cambiarles
    /// la fecha las sacaría de la lista que estás mirando.
    @Test func droppingInsideTodayLeavesDatesAlone() {
        let s = Store(inMemory: true)
        let a = s.addItem(title: "a", in: .inbox)
        let b = s.addItem(title: "b", in: .inbox)
        s.schedule(a, to: dia(0))
        s.schedule(b, to: dia(-2))

        s.place(a, before: s.items(for: .today).first { $0.title == "b" }, in: .today)
        #expect(s.items(for: .today).map(\.title) == ["a", "b"])
        #expect(s.items(for: .today).first { $0.title == "a" }?.day == dia(0))
    }

    /// Soltar en el hueco del final no señala ningún día: es prioridad y nada más.
    @Test func droppingAtTheEndKeepsTheDay() {
        let s = Store(inMemory: true)
        let a = s.addItem(title: "a", in: .inbox)
        let b = s.addItem(title: "b", in: .inbox)
        s.schedule(a, to: dia(1))
        s.schedule(b, to: dia(3))

        s.place(a, before: nil, in: .upcoming)
        #expect(s.items(for: .upcoming).first { $0.title == "a" }?.day == dia(1))
    }

    /// Aparcada en «Algún día» y con fecha a la vez sería contradictorio.
    @Test func aParkedTaskDroppedOnADayComesBack() {
        let s = Store(inMemory: true)
        let a = s.addItem(title: "a", in: .inbox)
        let b = s.addItem(title: "b", in: .inbox)
        s.move(a, to: .someday)
        s.schedule(b, to: dia(3))

        s.place(a, before: s.items(for: .upcoming).first { $0.title == "b" }, in: .upcoming)
        let movida = s.items.first { $0.title == "a" }
        #expect(movida?.isSomeday == false)
        #expect(movida?.day == dia(3))
    }
}

/// La persistencia: un archivo por objeto, lápidas y migración.
@MainActor
struct PersistenceTests {
    /// Carpeta nueva y vacía por test, para que no se pisen entre ellos.
    private func tempRoot() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("PautaTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test func roundTrip() throws {
        let root = tempRoot()
        do {
            let store = Store(root: root)
            store.addItem(title: "Comprar pan", in: .inbox)
            store.addItem(title: "Llamar al banco", in: .today)
            let project = store.addProject(name: "Mudanza")
            store.setIcon(project, to: "📦")
        }
        let reloaded = Store(root: root)
        #expect(reloaded.items.map(\.title) == ["Comprar pan", "Llamar al banco"])
        #expect(reloaded.projects.map(\.name) == ["Mudanza"])
        #expect(reloaded.projects.first?.icon == "📦")
        #expect(reloaded.count(for: .today) == 1)
    }

    @Test func oneFilePerObject() throws {
        let root = tempRoot()
        let store = Store(root: root)
        store.addItem(title: "una", in: .inbox)
        store.addItem(title: "otra", in: .inbox)
        store.addProject(name: "proyecto")

        let items = try FileManager.default.contentsOfDirectory(
            at: root.appendingPathComponent("items"), includingPropertiesForKeys: nil)
        let projects = try FileManager.default.contentsOfDirectory(
            at: root.appendingPathComponent("projects"), includingPropertiesForKeys: nil)
        #expect(items.filter { $0.pathExtension == "json" }.count == 2)
        #expect(projects.filter { $0.pathExtension == "json" }.count == 1)
    }

    /// Borrar deja lápida: al recargar, la tarea no vuelve.
    @Test func deletionLeavesTombstoneAndDoesNotResurrect() throws {
        let root = tempRoot()
        let doomed: Item
        do {
            let store = Store(root: root)
            store.addItem(title: "se queda", in: .inbox)
            doomed = store.addItem(title: "se borra", in: .inbox)
            store.delete(doomed)
            #expect(store.items.map(\.title) == ["se queda"])
        }
        // El archivo sigue existiendo, con la lápida puesta.
        let file = root.appendingPathComponent("items/\(doomed.id.uuidString).json")
        #expect(FileManager.default.fileExists(atPath: file.path))
        #expect(try String(contentsOf: file, encoding: .utf8).contains("deletedAt"))

        let reloaded = Store(root: root)
        #expect(reloaded.items.map(\.title) == ["se queda"])
    }

    /// Una tarea capturada y luego borrada no debe volver a importarse.
    @Test func buriedCaptureIsNotReimported() throws {
        let root = tempRoot()
        let capture = Captured(sourceID: "recordatorio-1", title: "Comprar pilas", notes: "")
        do {
            let store = Store(root: root)
            #expect(store.addCaptured([capture]) == 1)
            store.delete(store.items[0])
        }
        let reloaded = Store(root: root)
        #expect(reloaded.addCaptured([capture]) == 0)
        #expect(reloaded.items.isEmpty)
    }

    /// El decodificador tolerante: un archivo sin los campos nuevos se lee.
    @Test func readsFilesMissingNewerFields() throws {
        let root = tempRoot()
        let itemsDir = root.appendingPathComponent("items", isDirectory: true)
        try FileManager.default.createDirectory(at: itemsDir, withIntermediateDirectories: true)
        let id = UUID()
        let minimal = #"{"id":"\#(id.uuidString)","title":"Del pasado"}"#
        try minimal.write(to: itemsDir.appendingPathComponent("\(id.uuidString).json"),
                          atomically: true, encoding: .utf8)

        let store = Store(root: root)
        #expect(store.items.map(\.title) == ["Del pasado"])
        #expect(store.items.first?.isSomeday == false)
        #expect(store.items.first?.deletedAt == nil)
    }

    /// Un archivo corrupto se salta y no arrastra al resto.
    @Test func corruptFileDoesNotLoseTheRest() throws {
        let root = tempRoot()
        do {
            let store = Store(root: root)
            store.addItem(title: "sana", in: .inbox)
        }
        let itemsDir = root.appendingPathComponent("items", isDirectory: true)
        try "{ esto no es json".write(to: itemsDir.appendingPathComponent("\(UUID().uuidString).json"),
                                     atomically: true, encoding: .utf8)

        let store = Store(root: root)
        #expect(store.items.map(\.title) == ["sana"])
    }

    /// Migración desde el JSON único, dejando el original como respaldo.
    @Test func migratesFromSingleBlob() throws {
        let root = tempRoot()
        let a = UUID(), b = UUID(), p = UUID()
        let blob = """
        {
          "items": [
            {"id":"\(a.uuidString)","title":"vieja uno"},
            {"id":"\(b.uuidString)","title":"vieja dos","isCompleted":true}
          ],
          "projects": [{"id":"\(p.uuidString)","name":"Proyecto viejo"}]
        }
        """
        let legacy = root.appendingPathComponent("data.json")
        try blob.write(to: legacy, atomically: true, encoding: .utf8)

        let store = Store(root: root)
        #expect(Set(store.items.map(\.title)) == ["vieja uno", "vieja dos"])
        #expect(store.projects.map(\.name) == ["Proyecto viejo"])
        #expect(store.count(for: .completed) == 1)
        // El blob original se conserva.
        #expect(FileManager.default.fileExists(atPath: legacy.path))
        // Y no se vuelve a migrar encima de lo que ya hay.
        let again = Store(root: root)
        #expect(again.items.count == 2)
    }

    /// Mutar una tarea no debe reescribir el archivo de las demás: con la
    /// carpeta sincronizada, tocar archivos intactos hace trabajar de más a
    /// iCloud y multiplica las ocasiones de conflicto.
    @Test func mutatingOneItemLeavesTheOthersUntouched() throws {
        let root = tempRoot()
        let store = Store(root: root)
        let a = store.addItem(title: "la que cambia", in: .inbox)
        let b = store.addItem(title: "la que no", in: .inbox)

        let fileB = root.appendingPathComponent("items/\(b.id.uuidString).json")
        let antes = try Data(contentsOf: fileB)

        store.toggleComplete(a)

        let despues = try Data(contentsOf: fileB)
        #expect(antes == despues)
        // Y la que sí cambió, cambió.
        let fileA = root.appendingPathComponent("items/\(a.id.uuidString).json")
        #expect(try String(contentsOf: fileA, encoding: .utf8).contains("completedAt"))
    }

    /// La migración debe conservar el orden que tenía el blob, aunque sus fechas
    /// empaten: si no, la lista del usuario aparece revuelta tras actualizar.
    @Test func migrationPreservesOrderDespiteTiedDates() throws {
        let root = tempRoot()
        let titulos = ["primera", "segunda", "tercera", "cuarta", "quinta"]
        let mismaFecha = "2026-08-23T14:20:28Z"
        let items = titulos.map {
            #"{"id":"\#(UUID().uuidString)","title":"\#($0)","createdAt":"\#(mismaFecha)"}"#
        }
        let blob = #"{"items":[\#(items.joined(separator: ","))],"projects":[]}"#
        try blob.write(to: root.appendingPathComponent("data.json"),
                       atomically: true, encoding: .utf8)

        let store = Store(root: root)
        #expect(store.items.map(\.title) == titulos)
        // Y sigue igual al recargar desde los archivos ya troceados.
        let reloaded = Store(root: root)
        #expect(reloaded.items.map(\.title) == titulos)
    }

    /// Al estrenar la carpeta sincronizada, adopta lo que hubiera en la local.
    @Test func adoptsDataFromPreviousFolder() throws {
        let local = tempRoot(), nube = tempRoot()
        do {
            let store = Store(root: local)
            store.addItem(title: "venía de local", in: .inbox)
            store.addProject(name: "proyecto local")
        }
        // Dos archivos: la tarea y el proyecto.
        #expect(Store.adoptData(from: local, to: nube) == 2)

        let store = Store(root: nube)
        #expect(store.items.map(\.title) == ["venía de local"])
        #expect(store.projects.map(\.name) == ["proyecto local"])
        // El origen se conserva como respaldo.
        #expect(Store(root: local).items.count == 1)
    }

    /// No debe adoptar encima de datos que ya existen en el destino.
    @Test func doesNotAdoptOverExistingData() throws {
        let local = tempRoot(), nube = tempRoot()
        do {
            Store(root: local).addItem(title: "vieja", in: .inbox)
            Store(root: nube).addItem(title: "la que ya estaba", in: .inbox)
        }
        #expect(Store.adoptData(from: local, to: nube) == 0)
        #expect(Store(root: nube).items.map(\.title) == ["la que ya estaba"])
    }

    /// Adoptar el blob antiguo cuando el origen aún no estaba troceado.
    @Test func adoptsLegacyBlobToo() throws {
        let local = tempRoot(), nube = tempRoot()
        let blob = #"{"items":[{"id":"\#(UUID().uuidString)","title":"del blob"}],"projects":[]}"#
        try blob.write(to: local.appendingPathComponent("data.json"),
                       atomically: true, encoding: .utf8)
        Store.adoptData(from: local, to: nube)

        let store = Store(root: nube)
        #expect(store.items.map(\.title) == ["del blob"])
    }

    /// Recargar recoge lo que otro escribió en la misma carpeta: es el caso de
    /// dos dispositivos sincronizando.
    @Test func reloadPicksUpExternalChanges() throws {
        let root = tempRoot()
        let mio = Store(root: root)
        mio.addItem(title: "la mía", in: .inbox)

        // Otro «dispositivo» escribe en la misma carpeta.
        let otro = Store(root: root)
        otro.addItem(title: "la del otro", in: .inbox)

        #expect(mio.items.map(\.title) == ["la mía"])
        mio.reload()
        #expect(mio.items.map(\.title) == ["la mía", "la del otro"])
    }

    /// Un borrado hecho fuera se refleja al recargar, y no reaparece.
    @Test func reloadPicksUpExternalDeletion() throws {
        let root = tempRoot()
        let mio = Store(root: root)
        let doomed = mio.addItem(title: "se borra fuera", in: .inbox)
        mio.addItem(title: "se queda", in: .inbox)

        let otro = Store(root: root)
        otro.delete(otro.items.first { $0.id == doomed.id }!)

        mio.reload()
        #expect(mio.items.map(\.title) == ["se queda"])
    }

    /// Recargar sin cambios no debe alterar nada: las escrituras de la propia
    /// app disparan el vigilante, y una recarga que reasigna en vano refrescaría
    /// la interfaz e interrumpiría una edición en curso.
    @Test func reloadWithoutChangesIsIdempotent() throws {
        let root = tempRoot()
        let store = Store(root: root)
        store.addItem(title: "una", in: .inbox)
        store.addItem(title: "otra", in: .today)

        let antesItems = store.items
        let antesProyectos = store.projects
        store.reload()
        #expect(store.items == antesItems)
        #expect(store.projects == antesProyectos)
    }

    @Test func inMemoryWritesNothing() throws {
        let root = tempRoot()
        let store = Store(inMemory: true, root: root)
        store.addItem(title: "fantasma", in: .inbox)
        let contents = try FileManager.default.contentsOfDirectory(atPath: root.path)
        #expect(contents.isEmpty)
    }
}

/// La recarga incremental: releer solo lo que cambió.
///
/// Se comprueba por la puerta de atrás: se estropea el contenido de un archivo
/// **sin tocar su sello** —misma fecha de modificación y mismo tamaño—. Si la
/// tarea sigue entera, es que nadie volvió a abrirlo.
@MainActor
struct IncrementalLoadTests {
    private func tempRoot() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("PautaIncr-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func archivo(_ root: URL, _ id: UUID) -> URL {
        root.appendingPathComponent("items/\(id.uuidString).json")
    }

    /// Una fecha redonda, puesta a mano. Conservar la real leyéndola y
    /// volviéndola a escribir no sirve: `Date` es un `Double` de segundos y no
    /// representa exactamente los nanosegundos del archivo, así que la fecha
    /// vuelve distinta unas veces sí y otras no, y el test sale intermitente.
    private static let fechaFija = Date(timeIntervalSince1970: 1_700_000_000)

    private func fija(_ file: URL) throws {
        try FileManager.default.setAttributes([.modificationDate: Self.fechaFija],
                                              ofItemAtPath: file.path)
    }

    @Test func unchangedFilesAreNotReadAgain() throws {
        let root = tempRoot()
        let store = Store(root: root)
        let a = store.addItem(title: "intacta", in: .inbox)
        let file = archivo(root, a.id)
        let bytes = try Data(contentsOf: file).count

        try fija(file)
        // Dos caminos para llenar la caché: quien escribió el archivo y quien
        // solo lo leyó. Los dos tienen que quedar sellados igual.
        store.reload()
        let otro = Store(root: root)

        try Data(repeating: 0x78, count: bytes).write(to: file)
        try fija(file)

        store.reload()
        otro.reload()
        #expect(store.items(for: .inbox).map(\.title) == ["intacta"])
        #expect(otro.items(for: .inbox).map(\.title) == ["intacta"])

        // Y uno que estrena caché sí lo abre, y lo encuentra ilegible: la
        // basura estaba escrita de verdad.
        #expect(Store(root: root).items.isEmpty)
    }

    /// El tamaño forma parte del sello porque dos escrituras seguidas pueden
    /// caer en la misma fecha de modificación.
    @Test func aChangeOfSizeIsEnoughToReread() throws {
        let root = tempRoot()
        let store = Store(root: root)
        let a = store.addItem(title: "vieja", in: .inbox)
        let file = archivo(root, a.id)
        let bytes = try Data(contentsOf: file).count

        try fija(file)
        store.reload()

        let json = #"{"id":"\#(a.id.uuidString)","title":"nueva","createdAt":"2026-01-01T00:00:00Z"}"#
        #expect(Data(json.utf8).count != bytes)
        try Data(json.utf8).write(to: file)
        try fija(file)

        store.reload()
        #expect(store.items(for: .inbox).map(\.title) == ["nueva"])
    }

    /// Un archivo que desaparece sale de la caché aunque nunca se relea.
    @Test func aDeletedFileLeavesTheCache() throws {
        let root = tempRoot()
        let store = Store(root: root)
        let a = store.addItem(title: "efímera", in: .inbox)
        store.addItem(title: "queda", in: .inbox)

        try FileManager.default.removeItem(at: archivo(root, a.id))
        store.reload()
        #expect(store.items(for: .inbox).map(\.title) == ["queda"])
    }
}

/// El orden de los proyectos en la barra lateral: a mano o alfabético.
@MainActor
struct ProjectOrderingTests {
    private func tempRoot() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("PautaProy-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test func newProjectsGoToTheEnd() {
        let s = Store(inMemory: true)
        s.addProject(name: "uno")
        s.addProject(name: "dos")
        s.addProject(name: "tres")
        #expect(s.projects.map(\.name) == ["uno", "dos", "tres"])
    }

    @Test func placingBeforeMovesIt() {
        let s = Store(inMemory: true)
        s.addProject(name: "uno")
        s.addProject(name: "dos")
        let tres = s.addProject(name: "tres")
        s.place(tres, before: s.projects[0])
        #expect(s.projects.map(\.name) == ["tres", "uno", "dos"])
    }

    @Test func placingWithoutTargetSendsItToTheEnd() {
        let s = Store(inMemory: true)
        let uno = s.addProject(name: "uno")
        s.addProject(name: "dos")
        s.place(uno, before: nil)
        #expect(s.projects.map(\.name) == ["dos", "uno"])
    }

    /// Mover uno escribe un archivo, no la lista entera.
    @Test func reorderingWritesOnlyOneFile() throws {
        let root = tempRoot()
        let s = Store(root: root)
        s.addProject(name: "uno")
        let dos = s.addProject(name: "dos")
        s.addProject(name: "tres")

        let primero = root.appendingPathComponent("projects/\(s.projects[0].id.uuidString).json")
        let antes = try Data(contentsOf: primero)
        s.place(dos, before: nil)
        #expect(try Data(contentsOf: primero) == antes)
        #expect(s.projects.map(\.name) == ["uno", "tres", "dos"])
    }

    @Test func theOrderSurvivesAReload() throws {
        let root = tempRoot()
        let s = Store(root: root)
        s.addProject(name: "uno")
        s.addProject(name: "dos")
        let tres = s.addProject(name: "tres")
        s.place(tres, before: s.projects[0])
        #expect(Store(root: root).projects.map(\.name) == ["tres", "uno", "dos"])
    }

    /// El alfabético es el del idioma: la ñ va tras la n y los acentos cuentan
    /// como su letra. Comparando cadenas con `<` irían las dos al final.
    @Test func alphabeticalUsesTheLanguagesOrder() {
        let s = Store(inMemory: true)
        for nombre in ["Zeta", "ñu", "banco", "Ávila", "Casa"] { s.addProject(name: nombre) }
        s.sortAlphabetically()
        #expect(s.projects.map(\.name) == ["Ávila", "banco", "Casa", "ñu", "Zeta"])
    }

    /// Ordenar dos veces seguidas no debe reescribir nada la segunda: con la
    /// carpeta sincronizada, cada archivo tocado es tráfico y una ocasión de
    /// conflicto.
    @Test func sortingTwiceWritesNothingTheSecondTime() throws {
        let root = tempRoot()
        let s = Store(root: root)
        for nombre in ["Zeta", "banco", "Casa"] { s.addProject(name: nombre) }
        s.sortAlphabetically()

        let dir = root.appendingPathComponent("projects")
        let archivos = try FileManager.default.contentsOfDirectory(at: dir,
                                                                   includingPropertiesForKeys: nil)
        let antes = try archivos.map { try Data(contentsOf: $0) }
        s.sortAlphabetically()
        #expect(try archivos.map { try Data(contentsOf: $0) } == antes)
    }

    /// Los proyectos guardados antes de que existiera el campo valen todos 0, y
    /// entre dos ceros no hay punto medio: sin renumerarlos el primer arrastre
    /// no movería nada.
    @Test func canReorderProjectsSavedBeforePositionsExisted() throws {
        let root = tempRoot()
        let dir = root.appendingPathComponent("projects", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for (i, nombre) in ["uno", "dos", "tres"].enumerated() {
            let id = UUID()
            let json = #"{"id":"\#(id.uuidString)","name":"\#(nombre)","createdAt":"2026-08-2\#(i)T10:00:00Z"}"#
            try json.write(to: dir.appendingPathComponent("\(id.uuidString).json"),
                           atomically: true, encoding: .utf8)
        }
        let s = Store(root: root)
        #expect(s.projects.map(\.name) == ["uno", "dos", "tres"])
        s.place(s.projects[2], before: s.projects[0])
        #expect(s.projects.map(\.name) == ["tres", "uno", "dos"])
        #expect(Store(root: root).projects.map(\.name) == ["tres", "uno", "dos"])
    }
}

/// Áreas: cajones de proyectos.
@MainActor
struct AreaTests {
    private func tempRoot() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("PautaArea-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test func anAreaShowsWhatItsProjectsHavePending() {
        let s = Store(inMemory: true)
        let casa = s.addArea(name: "Casa")
        let mudanza = s.addProject(name: "Mudanza")
        let bici = s.addProject(name: "Bicicleta")
        let trabajo = s.addProject(name: "Trabajo")
        s.move(mudanza, toArea: casa.id)
        s.move(bici, toArea: casa.id)

        s.addItem(title: "cajas", in: .project(mudanza.id))
        s.addItem(title: "cadena", in: .project(bici.id))
        s.addItem(title: "informe", in: .project(trabajo.id))

        #expect(Set(s.items(for: .area(casa.id)).map(\.title)) == ["cajas", "cadena"])
        #expect(s.count(for: .area(casa.id)) == 2)
    }

    @Test func completedTasksDoNotCount() {
        let s = Store(inMemory: true)
        let casa = s.addArea(name: "Casa")
        let p = s.addProject(name: "Mudanza")
        s.move(p, toArea: casa.id)
        let cajas = s.addItem(title: "cajas", in: .project(p.id))
        s.toggleComplete(cajas)
        #expect(s.items(for: .area(casa.id)).isEmpty)
    }

    /// Sacar un proyecto de un área lo saca también de su lista.
    @Test func takingAProjectOutEmptiesTheArea() {
        let s = Store(inMemory: true)
        let casa = s.addArea(name: "Casa")
        let p = s.addProject(name: "Mudanza")
        s.move(p, toArea: casa.id)
        s.addItem(title: "cajas", in: .project(p.id))
        #expect(s.count(for: .area(casa.id)) == 1)

        s.move(p, toArea: nil)
        #expect(s.count(for: .area(casa.id)) == 0)
        #expect(s.projects(in: nil).map(\.name) == ["Mudanza"])
    }

    /// Borrar el área no se lleva por delante lo que había dentro: agrupa, no
    /// contiene. Perder proyectos enteros por borrar un cajón sería difícil de
    /// deshacer.
    @Test func deletingAnAreaKeepsItsProjects() {
        let s = Store(inMemory: true)
        let casa = s.addArea(name: "Casa")
        let p = s.addProject(name: "Mudanza")
        s.move(p, toArea: casa.id)
        let tarea = s.addItem(title: "cajas", in: .project(p.id))

        s.delete(casa)
        #expect(s.areas.isEmpty)
        #expect(s.projects.map(\.name) == ["Mudanza"])
        #expect(s.projects(in: nil).count == 1)
        #expect(s.items(for: .project(p.id)).map(\.id) == [tarea.id])
    }

    @Test func anAreaAcceptsNoTasksOfItsOwn() {
        let s = Store(inMemory: true)
        let casa = s.addArea(name: "Casa")
        s.addItem(title: "suelta", in: .area(casa.id))
        // Nace sin proyecto, así que cae en la bandeja y no en el área.
        #expect(s.items(for: .inbox).map(\.title) == ["suelta"])
        #expect(s.items(for: .area(casa.id)).isEmpty)
        #expect(Perspective.area(casa.id).acceptsNewItems == false)
    }

    @Test func areasReorderAndSurviveAReload() throws {
        let root = tempRoot()
        let s = Store(root: root)
        s.addArea(name: "Casa")
        s.addArea(name: "Trabajo")
        let estudios = s.addArea(name: "Estudios")
        s.place(estudios, before: s.areas[0])
        #expect(s.areas.map(\.name) == ["Estudios", "Casa", "Trabajo"])
        #expect(Store(root: root).areas.map(\.name) == ["Estudios", "Casa", "Trabajo"])
    }

    @Test func membershipSurvivesAReload() throws {
        let root = tempRoot()
        let s = Store(root: root)
        let casa = s.addArea(name: "Casa")
        let p = s.addProject(name: "Mudanza")
        s.move(p, toArea: casa.id)

        let otro = Store(root: root)
        #expect(otro.projects(in: casa.id).map(\.name) == ["Mudanza"])
        #expect(otro.projects(in: nil).isEmpty)
    }

    /// El alfabético ordena los proyectos dentro de su grupo, no en una sola
    /// lista: en la barra lateral se leen por grupos.
    @Test func alphabeticalSortsWithinEachGroup() {
        let s = Store(inMemory: true)
        let casa = s.addArea(name: "Casa")
        for nombre in ["zapatos", "armario"] {
            s.move(s.addProject(name: nombre), toArea: casa.id)
        }
        for nombre in ["zoo", "banco"] { s.addProject(name: nombre) }

        s.sortAlphabetically()
        #expect(s.projects(in: nil).map(\.name) == ["banco", "zoo"])
        #expect(s.projects(in: casa.id).map(\.name) == ["armario", "zapatos"])
    }

    /// Las posiciones tienen que seguir siendo únicas entre todos los proyectos:
    /// si se repitieran entre grupos, el arranque lo tomaría por un empate y
    /// los renumeraría, deshaciendo el orden.
    @Test func positionsStayUniqueAcrossGroups() {
        let s = Store(inMemory: true)
        let casa = s.addArea(name: "Casa")
        for nombre in ["zapatos", "armario"] {
            s.move(s.addProject(name: nombre), toArea: casa.id)
        }
        for nombre in ["zoo", "banco"] { s.addProject(name: nombre) }
        s.sortAlphabetically()
        #expect(Set(s.projects.map(\.position)).count == s.projects.count)
    }

    @Test func sortingTwiceWritesNothingTheSecondTime() throws {
        let root = tempRoot()
        let s = Store(root: root)
        let casa = s.addArea(name: "Casa")
        s.move(s.addProject(name: "zapatos"), toArea: casa.id)
        s.addProject(name: "banco")
        s.addArea(name: "Trabajo")
        s.sortAlphabetically()

        let dirs = ["projects", "areas"].map { root.appendingPathComponent($0) }
        let archivos = try dirs.flatMap {
            try FileManager.default.contentsOfDirectory(at: $0, includingPropertiesForKeys: nil)
        }
        let antes = try archivos.map { try Data(contentsOf: $0) }
        s.sortAlphabetically()
        #expect(try archivos.map { try Data(contentsOf: $0) } == antes)
    }

    /// Los datos escritos antes de que existieran las áreas no traen ni el campo
    /// ni la carpeta, y tienen que seguir abriéndose.
    @Test func dataWrittenBeforeAreasExistedStillOpens() throws {
        let root = tempRoot()
        let dir = root.appendingPathComponent("projects", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let id = UUID()
        let json = #"{"id":"\#(id.uuidString)","name":"viejo","createdAt":"2026-08-20T10:00:00Z"}"#
        try json.write(to: dir.appendingPathComponent("\(id.uuidString).json"),
                       atomically: true, encoding: .utf8)

        let s = Store(root: root)
        #expect(s.areas.isEmpty)
        #expect(s.projects(in: nil).map(\.name) == ["viejo"])
    }
}

/// Listas de comprobación: pasos dentro de una tarea.
@MainActor
struct ChecklistTests {
    private func tempRoot() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("PautaLista-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func recargar(_ s: Store, _ id: UUID) -> Item? { s.items.first { $0.id == id } }

    @Test func stepsKeepTheirOrder() {
        let s = Store(inMemory: true)
        let a = s.addItem(title: "mudanza", in: .inbox)
        for paso in ["cajas", "furgoneta", "llaves"] { s.addStep(to: a, title: paso) }
        #expect(recargar(s, a.id)?.checklist.map(\.title) == ["cajas", "furgoneta", "llaves"])
    }

    @Test func blankStepsAreNotCreated() {
        let s = Store(inMemory: true)
        let a = s.addItem(title: "mudanza", in: .inbox)
        s.addStep(to: a, title: "   ")
        s.addStep(to: a, title: "")
        #expect(recargar(s, a.id)?.checklist.isEmpty == true)
    }

    @Test func togglingCountsProgress() {
        let s = Store(inMemory: true)
        let a = s.addItem(title: "mudanza", in: .inbox)
        for paso in ["cajas", "furgoneta"] { s.addStep(to: a, title: paso) }
        let primero = recargar(s, a.id)!.checklist[0]
        s.toggleStep(a, primero.id)
        #expect(recargar(s, a.id)?.checklistDone == 1)
        s.toggleStep(a, primero.id)
        #expect(recargar(s, a.id)?.checklistDone == 0)
    }

    /// Un paso sin texto no dice nada: vaciarlo es borrarlo.
    @Test func emptyingAStepDeletesIt() {
        let s = Store(inMemory: true)
        let a = s.addItem(title: "mudanza", in: .inbox)
        s.addStep(to: a, title: "cajas")
        s.addStep(to: a, title: "llaves")
        let primero = recargar(s, a.id)!.checklist[0]
        s.renameStep(a, primero.id, to: "  ")
        #expect(recargar(s, a.id)?.checklist.map(\.title) == ["llaves"])
    }

    /// Completar la tarea entera no toca sus pasos: si la reabres, la lista
    /// sigue por donde iba.
    @Test func completingTheTaskLeavesTheStepsAlone() {
        let s = Store(inMemory: true)
        let a = s.addItem(title: "mudanza", in: .inbox)
        s.addStep(to: a, title: "cajas")
        s.toggleComplete(a)
        #expect(recargar(s, a.id)?.checklist.count == 1)
        #expect(recargar(s, a.id)?.checklistDone == 0)
    }

    @Test func stepsSurviveAReload() throws {
        let root = tempRoot()
        let s = Store(root: root)
        let a = s.addItem(title: "mudanza", in: .inbox)
        s.addStep(to: a, title: "cajas")
        let paso = s.items.first { $0.id == a.id }!.checklist[0]
        s.toggleStep(a, paso.id)

        let leido = Store(root: root).items.first { $0.id == a.id }
        #expect(leido?.checklist.map(\.title) == ["cajas"])
        #expect(leido?.checklistDone == 1)
    }

    /// La otra lectura de un texto pegado: una tarea y el resto como pasos.
    @Test func pastedTextCanBecomeOneTaskWithSteps() {
        let s = Store(inMemory: true)
        s.addItemWithChecklist(from: "Mudanza\n- cajas\n- furgoneta", in: .inbox)
        #expect(s.items.count == 1)
        #expect(s.items[0].title == "Mudanza")
        #expect(s.items[0].checklist.map(\.title) == ["cajas", "furgoneta"])
    }

    @Test func orTheSameTextCanBecomeManyTasks() {
        let s = Store(inMemory: true)
        s.addItems(from: "Mudanza\n- cajas\n- furgoneta", in: .inbox)
        #expect(s.items.map(\.title) == ["Mudanza", "cajas", "furgoneta"])
        #expect(s.items.allSatisfy { $0.checklist.isEmpty })
    }
}

/// Etiquetas: transversales a listas y proyectos.
@MainActor
struct TagTests {
    private func recargar(_ s: Store, _ id: UUID) -> Item? { s.items.first { $0.id == id } }

    @Test func aTagIsAListOfItsOwn() {
        let s = Store(inMemory: true)
        let a = s.addItem(title: "llamar", in: .inbox)
        let b = s.addItem(title: "comprar", in: .today)
        s.addTag(a, "recados")
        s.addTag(b, "recados")
        s.addItem(title: "otra", in: .inbox)

        #expect(Set(s.items(for: .tag("recados")).map(\.title)) == ["llamar", "comprar"])
        #expect(s.allTags == ["recados"])
    }

    /// «Casa» y «casa» son la misma etiqueta, y ponerla dos veces no la duplica.
    @Test func tagsIgnoreCaseAndDoNotRepeat() {
        let s = Store(inMemory: true)
        let a = s.addItem(title: "regar", in: .inbox)
        s.addTag(a, "Casa")
        s.addTag(a, "casa")
        s.addTag(a, "  CASA  ")
        #expect(recargar(s, a.id)?.tags == ["Casa"])
        #expect(s.items(for: .tag("casa")).count == 1)
    }

    @Test func whitespaceIsCollapsed() {
        let s = Store(inMemory: true)
        let a = s.addItem(title: "x", in: .inbox)
        s.addTag(a, "  por   hacer \n")
        #expect(recargar(s, a.id)?.tags == ["por hacer"])
    }

    @Test func aTaskCreatedInsideATagIsBornWithIt() {
        let s = Store(inMemory: true)
        let a = s.addItem(title: "nueva", in: .tag("recados"))
        #expect(recargar(s, a.id)?.tags == ["recados"])
        #expect(s.items(for: .tag("recados")).count == 1)
    }

    /// Soltar una tarea sobre una etiqueta se la pone y no le quita las otras:
    /// las etiquetas no son excluyentes, a diferencia de las listas.
    @Test func droppingOnATagAddsItWithoutRemovingTheRest() {
        let s = Store(inMemory: true)
        let a = s.addItem(title: "x", in: .inbox)
        s.addTag(a, "casa")
        s.move(a, to: .tag("urgente"))
        #expect(recargar(s, a.id)?.tags == ["casa", "urgente"])
    }

    @Test func removingATagLeavesTheTask() {
        let s = Store(inMemory: true)
        let a = s.addItem(title: "x", in: .inbox)
        s.addTag(a, "casa")
        s.removeTag(a, "CASA")
        #expect(recargar(s, a.id)?.tags.isEmpty == true)
        #expect(s.items.count == 1)
    }

    @Test func renamingReachesEveryTaskThatCarriesIt() {
        let s = Store(inMemory: true)
        let a = s.addItem(title: "uno", in: .inbox)
        let b = s.addItem(title: "dos", in: .inbox)
        s.addTag(a, "recados")
        s.addTag(b, "recados")
        s.renameTag("recados", to: "encargos")
        #expect(s.allTags == ["encargos"])
        #expect(s.items(for: .tag("encargos")).count == 2)
    }

    /// Renombrar a una que la tarea ya llevaba las funde en una, no la deja dos
    /// veces puesta.
    @Test func renamingIntoAnExistingTagMergesThem() {
        let s = Store(inMemory: true)
        let a = s.addItem(title: "uno", in: .inbox)
        s.addTag(a, "recados")
        s.addTag(a, "casa")
        s.renameTag("recados", to: "casa")
        #expect(recargar(s, a.id)?.tags == ["casa"])
    }

    @Test func deletingATagOnlyRemovesTheLabel() {
        let s = Store(inMemory: true)
        let a = s.addItem(title: "uno", in: .inbox)
        s.addTag(a, "recados")
        s.deleteTag("recados")
        #expect(s.allTags.isEmpty)
        #expect(s.items.map(\.title) == ["uno"])
    }

    /// Las etiquetas salen de las tareas vivas: al completar la última que la
    /// llevaba, la etiqueta deja de estorbar en la barra lateral.
    @Test func aTagDisappearsWhenNothingPendingCarriesIt() {
        let s = Store(inMemory: true)
        let a = s.addItem(title: "uno", in: .inbox)
        s.addTag(a, "recados")
        #expect(s.allTags == ["recados"])
        s.toggleComplete(a)
        #expect(s.allTags.isEmpty)
    }
}

/// La hora del día: lo único de Pauta que mira el reloj y no el calendario.
@MainActor
struct TimeOfDayTests {
    private func recargar(_ s: Store, _ id: UUID) -> Item? { s.items.first { $0.id == id } }

    @Test func anHourWithoutADayIsScheduledForToday() {
        let s = Store(inMemory: true)
        let a = s.addItem(title: "pastilla", in: .inbox)
        s.setTime(a, to: 9 * 60)
        #expect(recargar(s, a.id)?.day == Calendar.current.startOfDay(for: .now))
        #expect(s.items(for: .today).map(\.title) == ["pastilla"])
    }

    /// Quitar el día se lleva la hora: «a las nueve» sin día no dice cuándo.
    @Test func removingTheDayRemovesTheHour() {
        let s = Store(inMemory: true)
        let a = s.addItem(title: "pastilla", in: .today)
        s.setTime(a, to: 9 * 60)
        s.schedule(a, to: nil)
        #expect(recargar(s, a.id)?.timeOfDay == nil)
    }

    @Test func parkingAlsoRemovesIt() {
        let s = Store(inMemory: true)
        let a = s.addItem(title: "pastilla", in: .today)
        s.setTime(a, to: 9 * 60)
        s.park(a)
        #expect(recargar(s, a.id)?.timeOfDay == nil)
    }

    @Test func theExactMomentIsTheDayPlusTheHour() {
        let s = Store(inMemory: true)
        let a = s.addItem(title: "pastilla", in: .today)
        s.setTime(a, to: 9 * 60 + 30)
        let momento = recargar(s, a.id)?.scheduledAt
        let partes = Calendar.current.dateComponents([.hour, .minute], from: momento!)
        #expect(partes.hour == 9)
        #expect(partes.minute == 30)
    }

    @Test func hoursOutsideTheDayAreClamped() {
        let s = Store(inMemory: true)
        let a = s.addItem(title: "x", in: .today)
        s.setTime(a, to: 5000)
        #expect(recargar(s, a.id)?.timeOfDay == 24 * 60 - 1)
        s.setTime(a, to: -30)
        #expect(recargar(s, a.id)?.timeOfDay == 0)
    }

    /// En Hoy, lo que tiene hora va primero y por hora; lo demás conserva el
    /// orden manual debajo. Una hora no es una preferencia que se pueda
    /// reordenar: son las nueve o no lo son.
    @Test func timedTasksLeadTheDayInOrderOfTheClock() {
        let s = Store(inMemory: true)
        let suelta1 = s.addItem(title: "suelta 1", in: .today)
        let tarde = s.addItem(title: "tarde", in: .today)
        s.addItem(title: "suelta 2", in: .today)
        let pronto = s.addItem(title: "pronto", in: .today)
        s.setTime(tarde, to: 18 * 60)
        s.setTime(pronto, to: 9 * 60)

        #expect(s.items(for: .today).map(\.title)
                == ["pronto", "tarde", "suelta 1", "suelta 2"])
        // Y el orden manual de las que no tienen hora se sigue respetando.
        s.place(suelta1, before: nil, in: .today)
        #expect(s.items(for: .today).map(\.title)
                == ["pronto", "tarde", "suelta 2", "suelta 1"])
    }

    /// Sin horas de por medio nada cambia: el orden manual sigue mandando.
    @Test func withoutHoursNothingChanges() {
        let s = Store(inMemory: true)
        s.addItem(title: "a", in: .today)
        let b = s.addItem(title: "b", in: .today)
        s.addItem(title: "c", in: .today)
        s.place(b, before: s.items(for: .today)[0], in: .today)
        #expect(s.items(for: .today).map(\.title) == ["b", "a", "c"])
    }

    /// Lo que hace útil una repetitiva: «todos los días a las nueve». Sin
    /// heredarla, la segunda vuelta ya no tendría hora.
    @Test func theNextOccurrenceKeepsTheHour() {
        let s = Store(inMemory: true)
        let a = s.addItem(title: "pastilla", in: .today)
        s.setTime(a, to: 9 * 60)
        s.setRecurrence(a, to: .diaria)
        s.toggleComplete(a)

        let siguiente = s.items.first { !$0.isCompleted && $0.title == "pastilla" }
        #expect(siguiente?.timeOfDay == 9 * 60)
        #expect(siguiente?.day == Calendar.current.startOfDay(
            for: Calendar.current.date(byAdding: .day, value: 1, to: .now)!))
    }

    /// Las etiquetas y los pasos también vuelven, y los pasos sin marcar: la
    /// lista es la de esta vuelta, no la de la anterior ya hecha.
    @Test func theNextOccurrenceKeepsTagsAndResetsTheChecklist() {
        let s = Store(inMemory: true)
        let a = s.addItem(title: "revisar", in: .today)
        s.addTag(a, "trabajo")
        s.addStep(to: a, title: "uno")
        s.addStep(to: a, title: "dos")
        let paso = s.items.first { $0.id == a.id }!.checklist[0]
        s.toggleStep(a, paso.id)
        s.setRecurrence(a, to: .semanal)
        s.toggleComplete(a)

        let siguiente = s.items.first { !$0.isCompleted && $0.title == "revisar" }
        #expect(siguiente?.tags == ["trabajo"])
        #expect(siguiente?.checklist.map(\.title) == ["uno", "dos"])
        #expect(siguiente?.checklistDone == 0)
    }

    @Test func theHourSurvivesAReload() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PautaHora-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let s = Store(root: root)
        let a = s.addItem(title: "pastilla", in: .today)
        s.setTime(a, to: 9 * 60 + 30)
        #expect(Store(root: root).items.first { $0.id == a.id }?.timeOfDay == 9 * 60 + 30)
    }
}

/// Qué tareas merecen aviso. El envío en sí lo hace el sistema; lo que se puede
/// fijar aquí es la selección.
@MainActor
struct AvisoTests {
    private let ahora = Date(timeIntervalSince1970: 1_700_000_000)

    private func conHora(_ s: Store, _ titulo: String, _ dias: Int, _ minutos: Int) -> Item {
        let a = s.addItem(title: titulo, in: .inbox)
        s.schedule(a, to: Calendar.current.date(byAdding: .day, value: dias, to: .now))
        s.setTime(a, to: minutos)
        return a
    }

    @Test func onlyTimedFutureAndOpenTasksAreScheduled() {
        let s = Store(inMemory: true)
        conHora(s, "mañana", 1, 9 * 60)
        conHora(s, "ayer", -1, 9 * 60)
        let hecha = conHora(s, "hecha", 1, 10 * 60)
        s.toggleComplete(hecha)
        s.addItem(title: "sin hora", in: .today)

        let elegidas = s.items.filter { $0.deletedAt == nil && !$0.isCompleted }
            .filter { ($0.scheduledAt ?? .distantPast) > .now }
            .map(\.title)
        #expect(elegidas == ["mañana"])
    }

    /// Una tarea completada con repetición deja una sucesora, y es la sucesora
    /// la que tiene que avisar: la hecha ya no.
    @Test func theSuccessorIsTheOneThatWarns() {
        let s = Store(inMemory: true)
        let a = conHora(s, "pastilla", 0, 23 * 60 + 59)
        s.setRecurrence(a, to: .diaria)
        s.toggleComplete(a)

        let pendientes = s.items.filter { !$0.isCompleted && $0.scheduledAt != nil }
        #expect(pendientes.count == 1)
        #expect(pendientes[0].timeOfDay == 23 * 60 + 59)
        #expect(pendientes[0].id != a.id)
    }

    /// Fuera de un `.app` no hay centro de notificaciones, y pedirlo revienta el
    /// proceso. Este test corre justo ahí, así que fija que la guarda existe.
    @Test func withoutABundleItDoesNothingAndDoesNotCrash() async {
        let s = Store(inMemory: true)
        conHora(s, "pastilla", 1, 9 * 60)
        await Avisos.reschedule(s.items)
        #expect(await Avisos.pending().isEmpty)
    }

    /// El sistema descarta lo que pase de 64 avisos por app, así que el tope se
    /// aplica aquí y sobre los más cercanos.
    @Test func theCapKeepsTheNearestOnes() {
        let s = Store(inMemory: true)
        for i in 1...80 { conHora(s, "t\(i)", i, 9 * 60) }
        let ordenadas = s.items
            .compactMap { item -> (String, Date)? in
                guard let cuando = item.scheduledAt, cuando > .now else { return nil }
                return (item.title, cuando)
            }
            .sorted { $0.1 < $1.1 }
            .prefix(Avisos.tope)
        #expect(ordenadas.count == 60)
        #expect(ordenadas.first?.0 == "t1")
        #expect(ordenadas.last?.0 == "t60")
    }
}
