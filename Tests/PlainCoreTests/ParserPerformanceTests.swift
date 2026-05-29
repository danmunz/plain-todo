import Testing
import Foundation
@testable import PlainCore

@Test
func parsingOneThousandLineFileCompletesWithinBudget() throws {
    let lines = (0..<1000).map { i -> String in
        let priority = ["(A) ", "(B) ", "(C) ", ""].randomElement()!
        let date = "2026-05-\(String(format: "%02d", (i % 28) + 1))"
        let project = ["+work", "+home", "+shipping", "+taxes"].randomElement()!
        let context = ["@phone", "@errands", "@computer", "@office"].randomElement()!
        return "\(priority)\(date) Task number \(i) \(project) \(context) due:2026-06-\(String(format: "%02d", (i % 28) + 1))"
    }
    let text = lines.joined(separator: "\n") + "\n"

    let start = CFAbsoluteTimeGetCurrent()
    let snapshot = TodoParser.parse(text)
    let elapsed = CFAbsoluteTimeGetCurrent() - start

    #expect(snapshot.lines.count == 1000)
    #expect(elapsed < 1.0, "Parsing 1000 lines took \(elapsed)s, expected < 1s")
}

@Test
func serializerRoundTripsOneThousandLineFileWithinBudget() throws {
    let lines = (0..<1000).map { i -> String in
        let priority = i % 4 == 0 ? "(A) " : ""
        return "\(priority)2026-05-01 Task \(i) +proj\(i % 10) @ctx\(i % 5)"
    }
    let text = lines.joined(separator: "\n") + "\n"
    let snapshot = TodoParser.parse(text)

    let start = CFAbsoluteTimeGetCurrent()
    let serialized = TodoSerializer.serialize(snapshot)
    let elapsed = CFAbsoluteTimeGetCurrent() - start

    #expect(serialized == text)
    #expect(elapsed < 0.5, "Serializing 1000 lines took \(elapsed)s, expected < 0.5s")
}

@Test
func fiveThousandLineParsePlusMutationStaysResponsive() throws {
    let lines = (0..<5000).map { i -> String in
        "2026-01-01 Large file task \(i) +bulk @test"
    }
    let text = lines.joined(separator: "\n") + "\n"

    let parseStart = CFAbsoluteTimeGetCurrent()
    var snapshot = TodoParser.parse(text)
    let parseElapsed = CFAbsoluteTimeGetCurrent() - parseStart

    #expect(snapshot.lines.count == 5000)
    #expect(parseElapsed < 3.0, "Parsing 5000 lines took \(parseElapsed)s, expected < 3s")

    // Mutation: toggle first task completion
    let firstLine = snapshot.lines[0]
    guard let task = firstLine.task else {
        Issue.record("First line should be a task")
        return
    }

    let mutateStart = CFAbsoluteTimeGetCurrent()
    let transaction = try TaskMutation.toggleCompletion(
        at: 0,
        in: snapshot,
        completionDate: TodoDate(rawValue: "2026-05-28")!
    )
    let mutateElapsed = CFAbsoluteTimeGetCurrent() - mutateStart

    #expect(mutateElapsed < 0.5, "Mutation on 5000-line snapshot took \(mutateElapsed)s, expected < 0.5s")
}
