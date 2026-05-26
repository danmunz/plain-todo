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