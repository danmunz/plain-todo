import Foundation

public struct ArchiveTransaction: Sendable {
    public let originalTodoSnapshot: TodoFileSnapshot
    public let updatedTodoSnapshot: TodoFileSnapshot
    public let serializedTodoText: String
    public let originalDoneSnapshot: TodoFileSnapshot
    public let updatedDoneSnapshot: TodoFileSnapshot
    public let serializedDoneText: String
    public let archivedTaskCount: Int

    public init(
        originalTodoSnapshot: TodoFileSnapshot,
        updatedTodoSnapshot: TodoFileSnapshot,
        serializedTodoText: String,
        originalDoneSnapshot: TodoFileSnapshot,
        updatedDoneSnapshot: TodoFileSnapshot,
        serializedDoneText: String,
        archivedTaskCount: Int
    ) {
        self.originalTodoSnapshot = originalTodoSnapshot
        self.updatedTodoSnapshot = updatedTodoSnapshot
        self.serializedTodoText = serializedTodoText
        self.originalDoneSnapshot = originalDoneSnapshot
        self.updatedDoneSnapshot = updatedDoneSnapshot
        self.serializedDoneText = serializedDoneText
        self.archivedTaskCount = archivedTaskCount
    }
}