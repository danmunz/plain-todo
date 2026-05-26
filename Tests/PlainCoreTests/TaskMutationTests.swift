import Testing
@testable import PlainCore

@Test
func appendTaskAddsANewParsedLineWithoutChangingExistingPrefix() throws {
    let originalText = try FixtureLoader.text(named: "simple")
    let snapshot = TodoParser.parse(originalText)

    let updatedSnapshot = TaskMutation.append(
        rawText: "Review travel receipts @desk +finance due:2026-06-01",
        to: snapshot
    )

    #expect(updatedSnapshot.lines.count == snapshot.lines.count + 1)

    let serialized = TodoSerializer.serialize(updatedSnapshot)
    #expect(serialized.hasPrefix(originalText))
    #expect(serialized.contains("Review travel receipts @desk +finance due:2026-06-01"))

    let appendedTask = try #require(updatedSnapshot.lines.last?.task)
    #expect(appendedTask.projects == ["finance"])
    #expect(appendedTask.contexts == ["desk"])
    #expect(appendedTask.metadata == [TodoKeyValue(key: "due", value: "2026-06-01")])
}

@Test
func toggleCompletionRewritesOnlyTheTargetTaskLine() throws {
    let originalText = try FixtureLoader.text(named: "simple")
    let snapshot = TodoParser.parse(originalText)

    let updatedSnapshot = try TaskMutation.toggleCompletion(
        at: 0,
        in: snapshot,
        completionDate: TodoDate(year: 2026, month: 5, day: 25)
    )

    let updatedTask = try #require(updatedSnapshot.lines[0].task)
    #expect(updatedTask.isCompleted)
    #expect(updatedTask.priority == nil)
    #expect(updatedTask.completionDate == TodoDate(year: 2026, month: 5, day: 25))
    #expect(updatedTask.creationDate == TodoDate(rawValue: "2026-05-22"))
    #expect(updatedSnapshot.lines[1].rawText == snapshot.lines[1].rawText)
    #expect(updatedSnapshot.lines[2].rawText == snapshot.lines[2].rawText)
}

@Test
func setPriorityUpdatesTaskAndCanClearIt() throws {
    let originalText = try FixtureLoader.text(named: "simple")
    let snapshot = TodoParser.parse(originalText)

    let prioritized = try TaskMutation.setPriority("B", at: 2, in: snapshot)
    let prioritizedTask = try #require(prioritized.lines[2].task)
    #expect(prioritizedTask.priority == "B")
    #expect(prioritized.lines[0].rawText == snapshot.lines[0].rawText)

    let cleared = try TaskMutation.setPriority(nil, at: 2, in: prioritized)
    let clearedTask = try #require(cleared.lines[2].task)
    #expect(clearedTask.priority == nil)
}

@Test
func settingPriorityOnCompletedTaskFails() throws {
    let originalText = try FixtureLoader.text(named: "simple")
    let snapshot = TodoParser.parse(originalText)

    #expect(throws: TaskMutationError.completedTaskCannotHavePriority) {
        try TaskMutation.setPriority("A", at: 1, in: snapshot)
    }
}

@Test
func deleteLineRemovesOnlyTheRequestedLine() throws {
    let originalText = try FixtureLoader.text(named: "simple")
    let snapshot = TodoParser.parse(originalText)

    let updatedSnapshot = try TaskMutation.deleteLine(at: 1, in: snapshot)

    #expect(updatedSnapshot.lines.count == 2)
    #expect(updatedSnapshot.lines[0].rawText == snapshot.lines[0].rawText)
    #expect(updatedSnapshot.lines[1].rawText == snapshot.lines[2].rawText)
}

@Test
func replacingLineRefreshesIdentityAndKeepsNeighborsStable() throws {
    let originalText = try FixtureLoader.text(named: "simple")
    let snapshot = TodoParser.parse(originalText)
    let originalIdentity = snapshot.lines[2].identity

    let updatedSnapshot = try TaskMutation.replaceLine(
        with: "(B) Schedule dentist @phone +health wait:2026-06-02",
        at: 2,
        in: snapshot
    )

    #expect(updatedSnapshot.lines[0].identity == snapshot.lines[0].identity)
    #expect(updatedSnapshot.lines[1].identity == snapshot.lines[1].identity)
    #expect(updatedSnapshot.lines[2].identity != originalIdentity)
    let updatedTask = try #require(updatedSnapshot.lines[2].task)
    #expect(updatedTask.priority == "B")
    #expect(updatedTask.metadata == [TodoKeyValue(key: "wait", value: "2026-06-02")])
}

@Test
func archiveCompletedTasksMovesOnlyCompletedLinesIntoDoneSnapshot() throws {
    let todoSnapshot = TodoParser.parse(
        "Review receipts @desk\n"
        + "x 2026-05-25 File taxes +finance\n"
        + "x 2026-05-24 Send invoice +client\n"
    )
    let doneSnapshot = TodoParser.parse("x 2026-05-20 Close sprint +plain\n")

    let result = try TaskMutation.archiveCompletedTasks(from: todoSnapshot, into: doneSnapshot)

    #expect(result.archivedTaskCount == 2)
    #expect(result.updatedTodoSnapshot.tasks.count == 1)
    #expect(result.updatedTodoSnapshot.tasks.allSatisfy { !$0.isCompleted })
    #expect(result.updatedDoneSnapshot.tasks.count == 3)
    #expect(result.updatedDoneSnapshot.lines.last?.rawText == "x 2026-05-24 Send invoice +client")
}

@Test
func movingLineReordersOnlyTheRequestedLine() throws {
    let snapshot = TodoParser.parse(
        "Call accountant @phone +taxes\n"
        + "Review parser bootstrap +plain @work\n"
        + "Schedule dentist @phone +health\n"
    )

    let updatedSnapshot = try TaskMutation.moveLine(at: 0, to: 2, in: snapshot)

    #expect(updatedSnapshot.lines.map(\.rawText) == [
        "Review parser bootstrap +plain @work",
        "Schedule dentist @phone +health",
        "Call accountant @phone +taxes"
    ])
}

@Test
func completeAndArchiveMovesOnlyTheTargetTaskIntoDoneSnapshot() throws {
    let todoSnapshot = TodoParser.parse(
        "Call accountant @phone +taxes\n"
        + "Review parser bootstrap +plain @work\n"
    )
    let doneSnapshot = TodoParser.parse("x 2026-05-20 Close sprint +plain\n")

    let result = try TaskMutation.completeAndArchive(
        at: 0,
        in: todoSnapshot,
        into: doneSnapshot,
        completionDate: TodoDate(year: 2026, month: 5, day: 25)
    )

    #expect(result.archivedTaskCount == 1)
    #expect(result.updatedTodoSnapshot.lines.map(\.rawText) == ["Review parser bootstrap +plain @work"])
    #expect(result.updatedDoneSnapshot.lines.last?.rawText == "x 2026-05-25 Call accountant @phone +taxes")
}