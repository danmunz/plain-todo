import Foundation
import Testing
@testable import PlainCore

@Test
func coordinatedStoreLoadsSnapshotFromDisk() throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let fileURL = temporaryDirectory.appendingPathComponent("todo.txt")
    let text = "(A) Call accountant @phone +taxes due:2026-05-29\n"
    try text.write(to: fileURL, atomically: true, encoding: .utf8)

    let store = CoordinatedTodoStore(url: fileURL)
    let snapshot = try store.load()

    #expect(snapshot.lines.count == 1)
    #expect(snapshot.tasks.count == 1)
    #expect(store.lastLoadedSnapshot == snapshot)
    #expect(store.lastKnownModificationDate != nil)
}

@Test
func coordinatedStorePublishesReloadedSnapshotWhenItemChanges() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let fileURL = temporaryDirectory.appendingPathComponent("todo.txt")
    try "Call accountant @phone +taxes\n".write(to: fileURL, atomically: true, encoding: .utf8)

    let store = CoordinatedTodoStore(url: fileURL)
    _ = try store.load()

    await confirmation("store publishes reloaded snapshot", expectedCount: 1) { confirmation in
        store.onSnapshotChange = { result in
            guard case let .success(snapshot) = result else {
                return
            }

            if snapshot.lines.count == 2 {
                confirmation()
            }
        }

        try? "Call accountant @phone +taxes\nReview parser bootstrap +plain @work\n"
            .write(to: fileURL, atomically: true, encoding: .utf8)
        store.presentedItemDidChange()
    }
}

@Test
func coordinatedStoreAppendWritesThroughSinglePersistencePath() throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let fileURL = temporaryDirectory.appendingPathComponent("todo.txt")
    let originalText = "(A) Call accountant @phone +taxes due:2026-05-29\n"
    try originalText.write(to: fileURL, atomically: true, encoding: .utf8)

    let store = CoordinatedTodoStore(url: fileURL)
    let transaction = try store.appendTask(rawText: "Review travel receipts @desk +finance")
    let diskText = try String(contentsOf: fileURL, encoding: .utf8)

    #expect(transaction.originalSnapshot.lines.count == 1)
    #expect(transaction.updatedSnapshot.lines.count == 2)
    #expect(diskText == transaction.serializedText)
    #expect(diskText.hasPrefix(originalText))
}

@Test
func coordinatedStoreDeleteLeavesFileUnchangedOnInvalidTarget() throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let fileURL = temporaryDirectory.appendingPathComponent("todo.txt")
    let originalText = "Call accountant @phone +taxes\n"
    try originalText.write(to: fileURL, atomically: true, encoding: .utf8)

    let store = CoordinatedTodoStore(url: fileURL)

    #expect(throws: TaskMutationError.lineIndexOutOfBounds) {
        try store.deleteTask(at: 3)
    }

    let diskText = try String(contentsOf: fileURL, encoding: .utf8)
    #expect(diskText == originalText)
}

@Test
func coordinatedStoreCanReplaceLineByStableIdentity() throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let fileURL = temporaryDirectory.appendingPathComponent("todo.txt")
    let originalText = "Call accountant @phone +taxes\nReview parser bootstrap +plain @work\n"
    try originalText.write(to: fileURL, atomically: true, encoding: .utf8)

    let store = CoordinatedTodoStore(url: fileURL)
    let snapshot = try store.load()
    let identity = snapshot.lines[1].identity

    let transaction = try store.replaceLine(
        rawText: "(A) Review parser bootstrap +plain @work due:2026-05-30",
        lineIdentity: identity
    )

    let diskText = try String(contentsOf: fileURL, encoding: .utf8)
    #expect(diskText == transaction.serializedText)
    #expect(diskText.contains("(A) Review parser bootstrap +plain @work due:2026-05-30"))
}

@Test
func coordinatedStorePublishesArchiveExternalChangeEvents() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let todoURL = temporaryDirectory.appendingPathComponent("todo.txt")
    let doneURL = temporaryDirectory.appendingPathComponent("done.txt")
    try "Review parser bootstrap +plain @work\n".write(to: todoURL, atomically: true, encoding: .utf8)
    try "x 2026-05-20 Close sprint +plain\n".write(to: doneURL, atomically: true, encoding: .utf8)

    let store = CoordinatedTodoStore(url: todoURL)
    _ = try store.load()
    _ = try store.loadArchiveSnapshot()

    await confirmation("store publishes archive external change", expectedCount: 1) { confirmation in
        store.onExternalChange = { change in
            if change == .archive {
                confirmation()
            }
        }

        try? "x 2026-05-20 Close sprint +plain\nx 2026-05-25 File taxes +finance\n"
            .write(to: doneURL, atomically: true, encoding: .utf8)
        store.archivePresentedItemDidChange()
    }
}

@Test
func coordinatedStoreArchivesCompletedTasksIntoDoneFile() throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let todoURL = temporaryDirectory.appendingPathComponent("todo.txt")
    let doneURL = temporaryDirectory.appendingPathComponent("done.txt")
    try "Review parser bootstrap +plain @work\nx 2026-05-25 File taxes +finance\n".write(to: todoURL, atomically: true, encoding: .utf8)
    try "x 2026-05-20 Close sprint +plain\n".write(to: doneURL, atomically: true, encoding: .utf8)

    let store = CoordinatedTodoStore(url: todoURL)
    let transaction = try store.archiveCompletedTasks()

    let todoText = try String(contentsOf: todoURL, encoding: .utf8)
    let doneText = try String(contentsOf: doneURL, encoding: .utf8)

    #expect(transaction.archivedTaskCount == 1)
    #expect(todoText == transaction.serializedTodoText)
    #expect(doneText == transaction.serializedDoneText)
    #expect(todoText == "Review parser bootstrap +plain @work\n")
    #expect(doneText.contains("x 2026-05-20 Close sprint +plain"))
    #expect(doneText.contains("x 2026-05-25 File taxes +finance"))
}

@Test
func coordinatedStoreArchiveLeavesFilesUnchangedWhenNothingIsCompleted() throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let todoURL = temporaryDirectory.appendingPathComponent("todo.txt")
    let doneURL = temporaryDirectory.appendingPathComponent("done.txt")
    let originalTodoText = "Review parser bootstrap +plain @work\n"
    let originalDoneText = "x 2026-05-20 Close sprint +plain\n"
    try originalTodoText.write(to: todoURL, atomically: true, encoding: .utf8)
    try originalDoneText.write(to: doneURL, atomically: true, encoding: .utf8)

    let store = CoordinatedTodoStore(url: todoURL)

    #expect(throws: TaskMutationError.noCompletedTasksToArchive) {
        try store.archiveCompletedTasks()
    }

    let todoText = try String(contentsOf: todoURL, encoding: .utf8)
    let doneText = try String(contentsOf: doneURL, encoding: .utf8)
    #expect(todoText == originalTodoText)
    #expect(doneText == originalDoneText)
}

@Test
func coordinatedStoreCanMoveLineByStableIdentity() throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let fileURL = temporaryDirectory.appendingPathComponent("todo.txt")
    try "Call accountant @phone +taxes\nReview parser bootstrap +plain @work\nSchedule dentist @phone +health\n".write(to: fileURL, atomically: true, encoding: .utf8)

    let store = CoordinatedTodoStore(url: fileURL)
    let snapshot = try store.load()
    let identity = snapshot.lines[0].identity

    let transaction = try store.moveLine(lineIdentity: identity, by: 1)
    let diskText = try String(contentsOf: fileURL, encoding: .utf8)

    #expect(diskText == transaction.serializedText)
    #expect(diskText == "Review parser bootstrap +plain @work\nCall accountant @phone +taxes\nSchedule dentist @phone +health\n")
}

@Test
func coordinatedStoreCanCompleteAndArchiveOneTask() throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let todoURL = temporaryDirectory.appendingPathComponent("todo.txt")
    let doneURL = temporaryDirectory.appendingPathComponent("done.txt")
    try "Call accountant @phone +taxes\nReview parser bootstrap +plain @work\n".write(to: todoURL, atomically: true, encoding: .utf8)
    try "x 2026-05-20 Close sprint +plain\n".write(to: doneURL, atomically: true, encoding: .utf8)

    let store = CoordinatedTodoStore(url: todoURL)
    let snapshot = try store.load()
    let identity = snapshot.lines[0].identity

    let transaction = try store.completeAndArchive(
        lineIdentity: identity,
        completionDate: TodoDate(year: 2026, month: 5, day: 25)
    )
    let todoText = try String(contentsOf: todoURL, encoding: .utf8)
    let doneText = try String(contentsOf: doneURL, encoding: .utf8)

    #expect(transaction.archivedTaskCount == 1)
    #expect(todoText == "Review parser bootstrap +plain @work\n")
    #expect(doneText == "x 2026-05-20 Close sprint +plain\nx 2026-05-25 Call accountant @phone +taxes\n")
}