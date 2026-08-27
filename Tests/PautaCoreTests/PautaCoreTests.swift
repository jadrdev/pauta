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
