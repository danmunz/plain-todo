import Testing
@testable import PlainCore

@Test
func emptyFileFixtureParsesToEmptySnapshot() throws {
    let text = try FixtureLoader.text(named: "empty")

    let snapshot = TodoParser.parse(text)

    #expect(snapshot == .empty)
    #expect(TodoSerializer.serialize(snapshot) == text)
}

@Test
func simpleTasksExposeTodoTxtFields() throws {
    let text = try FixtureLoader.text(named: "simple")

    let snapshot = TodoParser.parse(text)

    #expect(snapshot.lines.count == 3)
    #expect(snapshot.hasTrailingNewline)
    #expect(snapshot.preferredLineEnding == .lf)
    #expect(snapshot.containsMixedLineEndings == false)

    let firstTask = try #require(snapshot.lines[0].task)
    #expect(firstTask.isCompleted == false)
    #expect(firstTask.priority == "A")
    #expect(firstTask.creationDate == TodoDate(rawValue: "2026-05-22"))
    #expect(firstTask.projects == ["taxes"])
    #expect(firstTask.contexts == ["phone"])
    #expect(firstTask.metadata == [TodoKeyValue(key: "due", value: "2026-05-29")])

    let secondTask = try #require(snapshot.lines[1].task)
    #expect(secondTask.isCompleted)
    #expect(secondTask.priority == nil)
    #expect(secondTask.completionDate == TodoDate(rawValue: "2026-05-24"))
    #expect(secondTask.creationDate == TodoDate(rawValue: "2026-05-23"))
    #expect(secondTask.projects == ["taxes"])
    #expect(secondTask.contexts == ["desk"])
    #expect(secondTask.metadata == [TodoKeyValue(key: "rec", value: "1w")])

    let thirdTask = try #require(snapshot.lines[2].task)
    #expect(thirdTask.body == "Schedule dentist @phone +health wait:2026-06-01")
    #expect(thirdTask.projects == ["health"])
    #expect(thirdTask.contexts == ["phone"])
    #expect(thirdTask.metadata == [TodoKeyValue(key: "wait", value: "2026-06-01")])
}

@Test
func malformedLineIsPreservedAsOpaque() throws {
    let text = try FixtureLoader.text(named: "malformed")

    let snapshot = TodoParser.parse(text)

    #expect(snapshot.lines.count == 2)
    #expect(snapshot.lines[0].task == nil)

    switch snapshot.lines[0].kind {
    case .opaque:
        #expect(snapshot.lines[0].rawText == "x 2026-05-24 (A) Broken completed priority ordering @oops +parser")
    default:
        Issue.record("Expected the malformed line to remain opaque")
    }

    #expect(TodoSerializer.serialize(snapshot) == text)
}

@Test
func mixedLineEndingsAreDetectedAndRoundTrip() {
    let text = "(A) Call accountant +taxes @phone\r\nReview parser bootstrap +plain @work\r\nMalformed prefix? x (A) maybe\nCapture receipt @errands +home\r"

    let snapshot = TodoParser.parse(text)

    #expect(snapshot.lines.count == 4)
    #expect(snapshot.hasTrailingNewline)
    #expect(snapshot.containsMixedLineEndings)
    #expect(snapshot.preferredLineEnding == .crlf)
    #expect(TodoSerializer.serialize(snapshot) == text)
}

@Test
func roundTripSerializationPreservesFixtureBytes() throws {
    for fixtureName in ["simple", "malformed", "roundtrip"] {
        let text = try FixtureLoader.text(named: fixtureName)
        let snapshot = TodoParser.parse(text)
        #expect(
            TodoSerializer.serialize(snapshot) == text,
            "Round-trip mismatch for fixture \(fixtureName)"
        )
    }
}