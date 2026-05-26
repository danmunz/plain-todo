import Foundation

public enum TaskMutationError: Error, Equatable, Sendable {
    case lineIndexOutOfBounds
    case lineIsNotTask
    case completedTaskCannotHavePriority
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