import Foundation

public final class CoordinatedTodoStore: NSObject, NSFilePresenter {
    public typealias SnapshotHandler = @Sendable (Result<TodoFileSnapshot, Error>) -> Void
    public typealias ExternalChangeHandler = @Sendable (ExternalChange) -> Void

    public enum ExternalChange: Sendable, Equatable {
        case todo
        case archive
    }

    public let presentedItemURL: URL?
    public let presentedItemOperationQueue: OperationQueue

    public var onSnapshotChange: SnapshotHandler?
    public var onExternalChange: ExternalChangeHandler?
    public var createBackupBeforeWrite = false

    public private(set) var lastLoadedSnapshot: TodoFileSnapshot?
    public private(set) var lastLoadedArchiveSnapshot: TodoFileSnapshot?
    public private(set) var lastKnownModificationDate: Date?
    public private(set) var lastKnownArchiveModificationDate: Date?

    private let fileManager: FileManager
    private var archivePresenter: ArchiveFilePresenter?

    public var archiveURL: URL? {
        presentedItemURL?.deletingLastPathComponent().appendingPathComponent("done.txt")
    }

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
        if archivePresenter == nil {
            archivePresenter = ArchiveFilePresenter(store: self)
        }

        NSFileCoordinator.addFilePresenter(self)
        if let archivePresenter {
            NSFileCoordinator.addFilePresenter(archivePresenter)
        }
    }

    public func stopMonitoring() {
        NSFileCoordinator.removeFilePresenter(self)
        if let archivePresenter {
            NSFileCoordinator.removeFilePresenter(archivePresenter)
        }
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

    public func reloadAll() throws -> (todo: TodoFileSnapshot, archive: TodoFileSnapshot) {
        let todoSnapshot = try load()
        let archiveSnapshot = try loadArchiveSnapshot()
        return (todoSnapshot, archiveSnapshot)
    }

    public func loadArchiveSnapshot() throws -> TodoFileSnapshot {
        guard let archiveURL else {
            throw CocoaError(.fileNoSuchFile)
        }

        let preferredLineEnding = lastLoadedSnapshot?.preferredLineEnding ?? .lf
        let archiveSnapshot = try loadSnapshotIfPresent(from: archiveURL, fallbackLineEnding: preferredLineEnding)
        lastLoadedArchiveSnapshot = archiveSnapshot
        lastKnownArchiveModificationDate = try modificationDateIfPresent(for: archiveURL)
        return archiveSnapshot
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
    public func moveLine(lineIdentity: LineIdentity, by offset: Int) throws -> WriteTransaction {
        try performWrite { snapshot in
            guard let lineIndex = snapshot.lineIndex(for: lineIdentity) else {
                throw TaskMutationError.lineIndexOutOfBounds
            }

            let destinationIndex = lineIndex + offset
            return try TaskMutation.moveLine(at: lineIndex, to: destinationIndex, in: snapshot)
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

    @discardableResult
    public func write(snapshot: TodoFileSnapshot) throws -> WriteTransaction {
        try performWrite { currentSnapshot in
            snapshot
        }
    }

    @discardableResult
    public func archiveCompletedTasks() throws -> ArchiveTransaction {
        try performArchiveWrite { todoSnapshot, doneSnapshot in
            try TaskMutation.archiveCompletedTasks(from: todoSnapshot, into: doneSnapshot)
        }
    }

    @discardableResult
    public func completeAndArchive(lineIdentity: LineIdentity, completionDate: TodoDate) throws -> ArchiveTransaction {
        try performArchiveWrite { todoSnapshot, doneSnapshot in
            guard let lineIndex = todoSnapshot.lineIndex(for: lineIdentity) else {
                throw TaskMutationError.lineIndexOutOfBounds
            }

            return try TaskMutation.completeAndArchive(
                at: lineIndex,
                in: todoSnapshot,
                into: doneSnapshot,
                completionDate: completionDate
            )
        }
    }

    @discardableResult
    public func write(todoSnapshot: TodoFileSnapshot, doneSnapshot: TodoFileSnapshot) throws -> ArchiveTransaction {
        try performArchiveWrite { _, _ in
            ArchiveMutationResult(
                updatedTodoSnapshot: todoSnapshot,
                updatedDoneSnapshot: doneSnapshot,
                archivedTaskCount: 0
            )
        }
    }

    public func presentedItemDidChange() {
        guard hasObservedExternalChange(at: presentedItemURL, previousModificationDate: lastKnownModificationDate) else {
            return
        }

        lastKnownModificationDate = try? modificationDateIfPresent(for: presentedItemURL)
        onExternalChange?(.todo)
        publishReloadResult()
    }

    public func archivePresentedItemDidChange() {
        guard hasObservedExternalChange(at: archiveURL, previousModificationDate: lastKnownArchiveModificationDate) else {
            return
        }

        lastKnownArchiveModificationDate = try? modificationDateIfPresent(for: archiveURL)
        onExternalChange?(.archive)
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

    private func performArchiveWrite(
        _ mutation: (TodoFileSnapshot, TodoFileSnapshot) throws -> ArchiveMutationResult
    ) throws -> ArchiveTransaction {
        guard let url = presentedItemURL, let archiveURL else {
            throw CocoaError(.fileNoSuchFile)
        }

        var coordinatedError: NSError?
        var transaction: ArchiveTransaction?
        var writeError: Error?

        let coordinator = NSFileCoordinator(filePresenter: self)
        coordinator.coordinate(
            writingItemAt: url,
            options: .forReplacing,
            writingItemAt: archiveURL,
            options: .forReplacing,
            error: &coordinatedError
        ) { todoURL, doneURL in
            do {
                let originalTodoSnapshot = try TodoSnapshotLoader.load(from: todoURL)
                let originalDoneSnapshot = try loadSnapshotIfPresent(
                    from: doneURL,
                    fallbackLineEnding: originalTodoSnapshot.preferredLineEnding
                )
                let mutationResult = try mutation(originalTodoSnapshot, originalDoneSnapshot)
                let serializedTodoText = TodoSerializer.serialize(mutationResult.updatedTodoSnapshot)
                let serializedDoneText = TodoSerializer.serialize(mutationResult.updatedDoneSnapshot)

                try writePair(
                    serializedTodoText,
                    to: todoURL,
                    and: serializedDoneText,
                    to: doneURL,
                    originalDoneFileExists: fileManager.fileExists(atPath: doneURL.path)
                )

                lastLoadedSnapshot = mutationResult.updatedTodoSnapshot
                lastLoadedArchiveSnapshot = mutationResult.updatedDoneSnapshot
                lastKnownModificationDate = try modificationDate(for: todoURL)
                lastKnownArchiveModificationDate = try modificationDateIfPresent(for: doneURL)
                transaction = ArchiveTransaction(
                    originalTodoSnapshot: originalTodoSnapshot,
                    updatedTodoSnapshot: mutationResult.updatedTodoSnapshot,
                    serializedTodoText: serializedTodoText,
                    originalDoneSnapshot: originalDoneSnapshot,
                    updatedDoneSnapshot: mutationResult.updatedDoneSnapshot,
                    serializedDoneText: serializedDoneText,
                    archivedTaskCount: mutationResult.archivedTaskCount
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

        onSnapshotChange?(.success(transaction.updatedTodoSnapshot))
        return transaction
    }

    private func write(_ text: String, to url: URL) throws {
        if createBackupBeforeWrite && fileManager.fileExists(atPath: url.path) {
            let bakURL = url.appendingPathExtension("bak")
            try? fileManager.removeItem(at: bakURL)
            try? fileManager.copyItem(at: url, to: bakURL)
        }

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

    private func writePair(
        _ todoText: String,
        to todoURL: URL,
        and doneText: String,
        to doneURL: URL,
        originalDoneFileExists: Bool
    ) throws {
        let temporaryTodoURL = temporaryURL(for: todoURL)
        let temporaryDoneURL = temporaryURL(for: doneURL)
        let todoBackupURL = todoURL.deletingLastPathComponent().appendingPathComponent(".plain-\(UUID().uuidString).todo.bak")
        let doneBackupURL = doneURL.deletingLastPathComponent().appendingPathComponent(".plain-\(UUID().uuidString).done.bak")
        var wroteTodo = false

        do {
            try todoText.write(to: temporaryTodoURL, atomically: false, encoding: .utf8)
            try doneText.write(to: temporaryDoneURL, atomically: false, encoding: .utf8)

            if fileManager.fileExists(atPath: todoURL.path) {
                _ = try fileManager.replaceItemAt(
                    todoURL,
                    withItemAt: temporaryTodoURL,
                    backupItemName: todoBackupURL.lastPathComponent,
                    options: []
                )
            } else {
                try fileManager.moveItem(at: temporaryTodoURL, to: todoURL)
            }
            wroteTodo = true

            if fileManager.fileExists(atPath: doneURL.path) {
                _ = try fileManager.replaceItemAt(
                    doneURL,
                    withItemAt: temporaryDoneURL,
                    backupItemName: doneBackupURL.lastPathComponent,
                    options: []
                )
            } else {
                try fileManager.moveItem(at: temporaryDoneURL, to: doneURL)
            }

            try? fileManager.removeItem(at: todoBackupURL)
            try? fileManager.removeItem(at: doneBackupURL)
        } catch {
            try? fileManager.removeItem(at: temporaryTodoURL)
            try? fileManager.removeItem(at: temporaryDoneURL)

            if wroteTodo,
               fileManager.fileExists(atPath: todoBackupURL.path)
            {
                if fileManager.fileExists(atPath: todoURL.path) {
                    _ = try? fileManager.replaceItemAt(todoURL, withItemAt: todoBackupURL)
                } else {
                    try? fileManager.moveItem(at: todoBackupURL, to: todoURL)
                }
            }

            if fileManager.fileExists(atPath: doneBackupURL.path) {
                if fileManager.fileExists(atPath: doneURL.path) {
                    _ = try? fileManager.replaceItemAt(doneURL, withItemAt: doneBackupURL)
                } else {
                    try? fileManager.moveItem(at: doneBackupURL, to: doneURL)
                }
            } else if !originalDoneFileExists, fileManager.fileExists(atPath: doneURL.path) {
                try? fileManager.removeItem(at: doneURL)
            }

            throw error
        }
    }

    private func temporaryURL(for url: URL) -> URL {
        url.deletingLastPathComponent()
            .appendingPathComponent(".plain-\(UUID().uuidString).tmp")
    }

    private func loadSnapshotIfPresent(from url: URL, fallbackLineEnding: LineEnding) throws -> TodoFileSnapshot {
        guard fileManager.fileExists(atPath: url.path) else {
            return TodoFileSnapshot(
                lines: [],
                preferredLineEnding: fallbackLineEnding,
                containsMixedLineEndings: false,
                hasTrailingNewline: false
            )
        }

        return try TodoSnapshotLoader.load(from: url)
    }

    private func modificationDate(for url: URL) throws -> Date? {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        return attributes[.modificationDate] as? Date
    }

    private func modificationDateIfPresent(for url: URL?) throws -> Date? {
        guard let url else {
            return nil
        }

        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }

        return try modificationDate(for: url)
    }

    private func hasObservedExternalChange(at url: URL?, previousModificationDate: Date?) -> Bool {
        let currentModificationDate = try? modificationDateIfPresent(for: url)
        return currentModificationDate != previousModificationDate
    }
}

private final class ArchiveFilePresenter: NSObject, NSFilePresenter {
    weak var store: CoordinatedTodoStore?

    init(store: CoordinatedTodoStore) {
        self.store = store
    }

    var presentedItemURL: URL? {
        store?.archiveURL
    }

    var presentedItemOperationQueue: OperationQueue {
        store?.presentedItemOperationQueue ?? OperationQueue.main
    }

    func presentedItemDidChange() {
        store?.archivePresentedItemDidChange()
    }
}