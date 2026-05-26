import Foundation

public struct WriteTransaction: Sendable {
    public let originalSnapshot: TodoFileSnapshot
    public let updatedSnapshot: TodoFileSnapshot
    public let serializedText: String

    public init(
        originalSnapshot: TodoFileSnapshot,
        updatedSnapshot: TodoFileSnapshot,
        serializedText: String
    ) {
        self.originalSnapshot = originalSnapshot
        self.updatedSnapshot = updatedSnapshot
        self.serializedText = serializedText
    }
}