import Foundation

public final class CoordinatedTodoStore: NSObject, NSFilePresenter {
    public typealias SnapshotHandler = @Sendable (Result<TodoFileSnapshot, Error>) -> Void

    public let presentedItemURL: URL?
    public let presentedItemOperationQueue: OperationQueue

    public var onSnapshotChange: SnapshotHandler?

    public private(set) var lastLoadedSnapshot: TodoFileSnapshot?
    public private(set) var lastKnownModificationDate: Date?

    private let fileManager: FileManager

    public init(url: URL, fileManager: FileManager = .default) {
        self.presentedItemURL = url
        self.fileManager = fileManager
        self.presentedItemOperationQueue = {
            let queue = OperationQueue()
            queue.name = "Plain.CoordinatedTodoStore"
            queue.maxConcurrentOperationCount = 1
            return queue
        }()
    }

    deinit {
        stopMonitoring()
    }

    public func startMonitoring() {
        NSFileCoordinator.addFilePresenter(self)
    }

    public func stopMonitoring() {
        NSFileCoordinator.removeFilePresenter(self)
    }

    public func load() throws -> TodoFileSnapshot {
        guard let url = presentedItemURL else {
            throw CocoaError(.fileNoSuchFile)
        }

        var coordinatedError: NSError?
        var loadedSnapshot: TodoFileSnapshot?
        var loadError: Error?

        let coordinator = NSFileCoordinator(filePresenter: self)
        coordinator.coordinate(readingItemAt: url, options: [], error: &coordinatedError) { coordinatedURL in
            do {
                loadedSnapshot = try TodoSnapshotLoader.load(from: coordinatedURL)
                lastKnownModificationDate = try modificationDate(for: coordinatedURL)
            } catch {
                loadError = error
            }
        }

        if let coordinatedError {
            throw coordinatedError
        }

        if let loadError {
            throw loadError
        }

        guard let loadedSnapshot else {
            throw CocoaError(.fileReadUnknown)
        }

        lastLoadedSnapshot = loadedSnapshot
        return loadedSnapshot
    }

    public func reload() {
        publishReloadResult()
    }

    @discardableResult
    public func appendTask(rawText: String) throws -> WriteTransaction {
        try performWrite { snapshot in
            TaskMutation.append(rawText: rawText, to: snapshot)
        }
    }

    @discardableResult
    public func toggleCompletion(at lineIndex: Int, completionDate: TodoDate) throws -> WriteTransaction {
        try performWrite { snapshot in
            try TaskMutation.toggleCompletion(at: lineIndex, in: snapshot, completionDate: completionDate)
        }
    }

    @discardableResult
    public func setPriority(_ priority: Character?, at lineIndex: Int) throws -> WriteTransaction {
        try performWrite { snapshot in
            try TaskMutation.setPriority(priority, at: lineIndex, in: snapshot)
        }
    }

    @discardableResult
    public func deleteTask(at lineIndex: Int) throws -> WriteTransaction {
        try performWrite { snapshot in
            try TaskMutation.deleteLine(at: lineIndex, in: snapshot)
        }
    }

    @discardableResult
    public func toggleCompletion(lineIdentity: LineIdentity, completionDate: TodoDate) throws -> WriteTransaction {
        try performWrite { snapshot in
            guard let lineIndex = snapshot.lineIndex(for: lineIdentity) else {
                throw TaskMutationError.lineIndexOutOfBounds
            }

            return try TaskMutation.toggleCompletion(at: lineIndex, in: snapshot, completionDate: completionDate)
        }
    }

    @discardableResult
    public func setPriority(_ priority: Character?, lineIdentity: LineIdentity) throws -> WriteTransaction {
        try performWrite { snapshot in
            guard let lineIndex = snapshot.lineIndex(for: lineIdentity) else {
                throw TaskMutationError.lineIndexOutOfBounds
            }

            return try TaskMutation.setPriority(priority, at: lineIndex, in: snapshot)
        }
    }

    @discardableResult
    public func deleteTask(lineIdentity: LineIdentity) throws -> WriteTransaction {
        try performWrite { snapshot in
            guard let lineIndex = snapshot.lineIndex(for: lineIdentity) else {
                throw TaskMutationError.lineIndexOutOfBounds
            }

            return try TaskMutation.deleteLine(at: lineIndex, in: snapshot)
        }
    }

    @discardableResult
    public func replaceLine(rawText: String, lineIdentity: LineIdentity) throws -> WriteTransaction {
        try performWrite { snapshot in
            guard let lineIndex = snapshot.lineIndex(for: lineIdentity) else {
                throw TaskMutationError.lineIndexOutOfBounds
            }

            return try TaskMutation.replaceLine(with: rawText, at: lineIndex, in: snapshot)
        }
    }

    public func presentedItemDidChange() {
        publishReloadResult()
    }

    private func publishReloadResult() {
        do {
            let snapshot = try load()
            onSnapshotChange?(.success(snapshot))
        } catch {
            onSnapshotChange?(.failure(error))
        }
    }

    private func performWrite(
        _ mutation: (TodoFileSnapshot) throws -> TodoFileSnapshot
    ) throws -> WriteTransaction {
        guard let url = presentedItemURL else {
            throw CocoaError(.fileNoSuchFile)
        }

        var coordinatedError: NSError?
        var transaction: WriteTransaction?
        var writeError: Error?

        let coordinator = NSFileCoordinator(filePresenter: self)
        coordinator.coordinate(readingItemAt: url, options: [], writingItemAt: url, options: .forReplacing, error: &coordinatedError) { readURL, writeURL in
            do {
                let originalSnapshot = try TodoSnapshotLoader.load(from: readURL)
                let updatedSnapshot = try mutation(originalSnapshot)
                let serializedText = TodoSerializer.serialize(updatedSnapshot)
                try write(serializedText, to: writeURL)

                lastLoadedSnapshot = updatedSnapshot
                lastKnownModificationDate = try modificationDate(for: writeURL)
                transaction = WriteTransaction(
                    originalSnapshot: originalSnapshot,
                    updatedSnapshot: updatedSnapshot,
                    serializedText: serializedText
                )
            } catch {
                writeError = error
            }
        }

        if let coordinatedError {
            throw coordinatedError
        }

        if let writeError {
            throw writeError
        }

        guard let transaction else {
            throw CocoaError(.fileWriteUnknown)
        }

        onSnapshotChange?(.success(transaction.updatedSnapshot))
        return transaction
    }

    private func write(_ text: String, to url: URL) throws {
        let temporaryURL = url.deletingLastPathComponent()
            .appendingPathComponent(".plain-\(UUID().uuidString).tmp")

        do {
            try text.write(to: temporaryURL, atomically: false, encoding: .utf8)

            if fileManager.fileExists(atPath: url.path) {
                _ = try fileManager.replaceItemAt(url, withItemAt: temporaryURL)
            } else {
                try fileManager.moveItem(at: temporaryURL, to: url)
            }
        } catch {
            try? fileManager.removeItem(at: temporaryURL)
            throw error
        }
    }

    private func modificationDate(for url: URL) throws -> Date? {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        return attributes[.modificationDate] as? Date
    }
}