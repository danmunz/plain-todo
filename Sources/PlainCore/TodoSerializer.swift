import Foundation

public enum TodoSerializer {
    public static func serialize(_ snapshot: TodoFileSnapshot) -> String {
        snapshot.lines.enumerated().map { index, line in
            let lineEnding = line.originalLineEnding ?? fallbackLineEnding(for: snapshot, lineIndex: index)
            return line.rawText + (lineEnding?.rawValue ?? "")
        }
        .joined()
    }

    private static func fallbackLineEnding(for snapshot: TodoFileSnapshot, lineIndex: Int) -> LineEnding? {
        let isLastLine = lineIndex == snapshot.lines.count - 1
        if isLastLine {
            return snapshot.hasTrailingNewline ? snapshot.preferredLineEnding : nil
        }

        return snapshot.preferredLineEnding
    }
}