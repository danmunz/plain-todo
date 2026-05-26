import Foundation

public enum TaskMutationError: Error, Equatable, Sendable {
    case lineIndexOutOfBounds
    case lineIsNotTask
    case completedTaskCannotHavePriority
    case noCompletedTasksToArchive
    case taskAlreadyCompleted
}

public struct ArchiveMutationResult: Equatable, Sendable {
    public let updatedTodoSnapshot: TodoFileSnapshot
    public let updatedDoneSnapshot: TodoFileSnapshot
    public let archivedTaskCount: Int

    public init(
        updatedTodoSnapshot: TodoFileSnapshot,
        updatedDoneSnapshot: TodoFileSnapshot,
        archivedTaskCount: Int
    ) {
        self.updatedTodoSnapshot = updatedTodoSnapshot
        self.updatedDoneSnapshot = updatedDoneSnapshot
        self.archivedTaskCount = archivedTaskCount
    }
}

public enum TaskMutation {
    public static func append(rawText: String, to snapshot: TodoFileSnapshot) -> TodoFileSnapshot {
        var lines = snapshot.lines
        let appendedLineEnding: LineEnding? = snapshot.hasTrailingNewline ? snapshot.preferredLineEnding : nil
        lines.append(TodoParser.parseLine(rawText, lineNumber: lines.count, originalLineEnding: appendedLineEnding))

        return TodoFileSnapshot(
            lines: lines,
            preferredLineEnding: snapshot.preferredLineEnding,
            containsMixedLineEndings: snapshot.containsMixedLineEndings,
            hasTrailingNewline: snapshot.hasTrailingNewline
        )
    }

    public static func toggleCompletion(
        at lineIndex: Int,
        in snapshot: TodoFileSnapshot,
        completionDate: TodoDate
    ) throws -> TodoFileSnapshot {
        let line = try line(at: lineIndex, in: snapshot)
        let task = try task(from: line)

        let updatedTask = TodoTask(
            isCompleted: !task.isCompleted,
            priority: nil,
            completionDate: task.isCompleted ? nil : completionDate,
            creationDate: task.creationDate,
            body: task.body,
            projects: task.projects,
            contexts: task.contexts,
            metadata: task.metadata
        )

        return replacingLine(
            at: lineIndex,
            in: snapshot,
            with: updatedTask.renderedRawText(),
            originalLineEnding: line.originalLineEnding
        )
    }

    public static func replaceLine(
        with rawText: String,
        at lineIndex: Int,
        in snapshot: TodoFileSnapshot
    ) throws -> TodoFileSnapshot {
        let line = try line(at: lineIndex, in: snapshot)

        return replacingLine(
            at: lineIndex,
            in: snapshot,
            with: rawText,
            originalLineEnding: line.originalLineEnding
        )
    }

    public static func setPriority(
        _ priority: Character?,
        at lineIndex: Int,
        in snapshot: TodoFileSnapshot
    ) throws -> TodoFileSnapshot {
        let line = try line(at: lineIndex, in: snapshot)
        let task = try task(from: line)

        if task.isCompleted, priority != nil {
            throw TaskMutationError.completedTaskCannotHavePriority
        }

        let updatedTask = TodoTask(
            isCompleted: task.isCompleted,
            priority: priority,
            completionDate: task.completionDate,
            creationDate: task.creationDate,
            body: task.body,
            projects: task.projects,
            contexts: task.contexts,
            metadata: task.metadata
        )

        return replacingLine(
            at: lineIndex,
            in: snapshot,
            with: updatedTask.renderedRawText(),
            originalLineEnding: line.originalLineEnding
        )
    }

    public static func deleteLine(at lineIndex: Int, in snapshot: TodoFileSnapshot) throws -> TodoFileSnapshot {
        _ = try line(at: lineIndex, in: snapshot)

        var lines = snapshot.lines
        lines.remove(at: lineIndex)

        return TodoFileSnapshot(
            lines: lines,
            preferredLineEnding: snapshot.preferredLineEnding,
            containsMixedLineEndings: snapshot.containsMixedLineEndings,
            hasTrailingNewline: snapshot.hasTrailingNewline && !lines.isEmpty
        )
    }

    public static func moveLine(
        at lineIndex: Int,
        to destinationIndex: Int,
        in snapshot: TodoFileSnapshot
    ) throws -> TodoFileSnapshot {
        _ = try line(at: lineIndex, in: snapshot)
        guard snapshot.lines.indices.contains(destinationIndex) else {
            throw TaskMutationError.lineIndexOutOfBounds
        }

        guard lineIndex != destinationIndex else {
            return snapshot
        }

        var lines = snapshot.lines
        let line = lines.remove(at: lineIndex)
        lines.insert(line, at: destinationIndex)

        return TodoFileSnapshot(
            lines: lines,
            preferredLineEnding: snapshot.preferredLineEnding,
            containsMixedLineEndings: snapshot.containsMixedLineEndings,
            hasTrailingNewline: snapshot.hasTrailingNewline
        )
    }

    public static func archiveCompletedTasks(
        from todoSnapshot: TodoFileSnapshot,
        into doneSnapshot: TodoFileSnapshot
    ) throws -> ArchiveMutationResult {
        let completedLines = todoSnapshot.lines.compactMap { line -> String? in
            guard let task = line.task, task.isCompleted else {
                return nil
            }

            return line.rawText
        }

        guard !completedLines.isEmpty else {
            throw TaskMutationError.noCompletedTasksToArchive
        }

        let updatedTodoLines = todoSnapshot.lines.filter { line in
            guard let task = line.task else {
                return true
            }

            return !task.isCompleted
        }

        let updatedTodoSnapshot = TodoFileSnapshot(
            lines: updatedTodoLines,
            preferredLineEnding: todoSnapshot.preferredLineEnding,
            containsMixedLineEndings: todoSnapshot.containsMixedLineEndings,
            hasTrailingNewline: todoSnapshot.hasTrailingNewline && !updatedTodoLines.isEmpty
        )

        var updatedDoneSnapshot = doneSnapshot
        for completedLine in completedLines {
            updatedDoneSnapshot = append(rawText: completedLine, to: updatedDoneSnapshot)
        }

        return ArchiveMutationResult(
            updatedTodoSnapshot: updatedTodoSnapshot,
            updatedDoneSnapshot: updatedDoneSnapshot,
            archivedTaskCount: completedLines.count
        )
    }

    public static func completeAndArchive(
        at lineIndex: Int,
        in todoSnapshot: TodoFileSnapshot,
        into doneSnapshot: TodoFileSnapshot,
        completionDate: TodoDate
    ) throws -> ArchiveMutationResult {
        let line = try line(at: lineIndex, in: todoSnapshot)
        let task = try task(from: line)
        guard !task.isCompleted else {
            throw TaskMutationError.taskAlreadyCompleted
        }

        let completedTask = TodoTask(
            isCompleted: true,
            priority: nil,
            completionDate: completionDate,
            creationDate: task.creationDate,
            body: task.body,
            projects: task.projects,
            contexts: task.contexts,
            metadata: task.metadata
        )

        var updatedTodoLines = todoSnapshot.lines
        updatedTodoLines.remove(at: lineIndex)
        let updatedTodoSnapshot = TodoFileSnapshot(
            lines: updatedTodoLines,
            preferredLineEnding: todoSnapshot.preferredLineEnding,
            containsMixedLineEndings: todoSnapshot.containsMixedLineEndings,
            hasTrailingNewline: todoSnapshot.hasTrailingNewline && !updatedTodoLines.isEmpty
        )

        let updatedDoneSnapshot = append(rawText: completedTask.renderedRawText(), to: doneSnapshot)
        return ArchiveMutationResult(
            updatedTodoSnapshot: updatedTodoSnapshot,
            updatedDoneSnapshot: updatedDoneSnapshot,
            archivedTaskCount: 1
        )
    }

    private static func line(at lineIndex: Int, in snapshot: TodoFileSnapshot) throws -> TodoLine {
        guard snapshot.lines.indices.contains(lineIndex) else {
            throw TaskMutationError.lineIndexOutOfBounds
        }

        return snapshot.lines[lineIndex]
    }

    private static func task(from line: TodoLine) throws -> TodoTask {
        guard let task = line.task else {
            throw TaskMutationError.lineIsNotTask
        }

        return task
    }

    private static func replacingLine(
        at lineIndex: Int,
        in snapshot: TodoFileSnapshot,
        with rawText: String,
        originalLineEnding: LineEnding?
    ) -> TodoFileSnapshot {
        var lines = snapshot.lines
        lines[lineIndex] = TodoParser.parseLine(rawText, lineNumber: lineIndex, originalLineEnding: originalLineEnding)

        return TodoFileSnapshot(
            lines: lines,
            preferredLineEnding: snapshot.preferredLineEnding,
            containsMixedLineEndings: snapshot.containsMixedLineEndings,
            hasTrailingNewline: snapshot.hasTrailingNewline
        )
    }
}