import Foundation

public enum TodoParser {
    public static func parse(_ text: String) -> TodoFileSnapshot {
        guard !text.isEmpty else {
            return .empty
        }

        let splitLines = splitPreservingLineEndings(in: text)
        let endings = splitLines.compactMap(\.lineEnding)
        let preferredLineEnding = dominantLineEnding(from: endings) ?? .lf
        let containsMixedLineEndings = Set(endings).count > 1
        let hasTrailingNewline = splitLines.last?.lineEnding != nil

        let lines = splitLines.enumerated().map { index, splitLine in
            parseLine(splitLine.rawText, lineNumber: index, originalLineEnding: splitLine.lineEnding)
        }

        return TodoFileSnapshot(
            lines: lines,
            preferredLineEnding: preferredLineEnding,
            containsMixedLineEndings: containsMixedLineEndings,
            hasTrailingNewline: hasTrailingNewline
        )
    }

    public static func parseLine(_ rawText: String, lineNumber: Int, originalLineEnding: LineEnding? = nil) -> TodoLine {
        TodoLine(
            identity: LineIdentity(lineNumber: lineNumber, rawText: rawText),
            rawText: rawText,
            originalLineEnding: originalLineEnding,
            kind: classify(rawText: rawText)
        )
    }

    private struct SplitLine {
        let rawText: String
        let lineEnding: LineEnding?
    }

    private static func splitPreservingLineEndings(in text: String) -> [SplitLine] {
        var lines: [SplitLine] = []
        let scalars = text.unicodeScalars
        var lineStart = scalars.startIndex
        var index = scalars.startIndex

        while index < scalars.endIndex {
            let scalar = scalars[index]

            if scalar == "\n" {
                lines.append(
                    SplitLine(
                        rawText: String(String.UnicodeScalarView(scalars[lineStart..<index])),
                        lineEnding: .lf
                    )
                )
                index = scalars.index(after: index)
                lineStart = index
                continue
            }

            if scalar == "\r" {
                let nextIndex = scalars.index(after: index)
                if nextIndex < scalars.endIndex, scalars[nextIndex] == "\n" {
                    lines.append(
                        SplitLine(
                            rawText: String(String.UnicodeScalarView(scalars[lineStart..<index])),
                            lineEnding: .crlf
                        )
                    )
                    index = scalars.index(after: nextIndex)
                } else {
                    lines.append(
                        SplitLine(
                            rawText: String(String.UnicodeScalarView(scalars[lineStart..<index])),
                            lineEnding: .cr
                        )
                    )
                    index = nextIndex
                }
                lineStart = index
                continue
            }

            index = scalars.index(after: index)
        }

        if lineStart < scalars.endIndex {
            lines.append(
                SplitLine(
                    rawText: String(String.UnicodeScalarView(scalars[lineStart..<scalars.endIndex])),
                    lineEnding: nil
                )
            )
        }

        return lines
    }

    private static func dominantLineEnding(from endings: [LineEnding]) -> LineEnding? {
        guard !endings.isEmpty else {
            return nil
        }

        var counts: [LineEnding: Int] = [:]
        for ending in endings {
            counts[ending, default: 0] += 1
        }

        return LineEnding.allCases.max { left, right in
            let leftCount = counts[left, default: 0]
            let rightCount = counts[right, default: 0]
            if leftCount == rightCount {
                return firstIndex(of: left, in: endings) ?? .max > firstIndex(of: right, in: endings) ?? .max
            }
            return leftCount < rightCount
        }
    }

    private static func firstIndex(of ending: LineEnding, in endings: [LineEnding]) -> Int? {
        endings.firstIndex(of: ending)
    }

    private static func classify(rawText: String) -> TodoLine.Kind {
        if rawText.isEmpty {
            return .blank
        }

        guard let task = parseTask(from: rawText) else {
            return .opaque
        }

        return .task(task)
    }

    private static func parseTask(from rawText: String) -> TodoTask? {
        let tokens = rawText.split(whereSeparator: \ .isWhitespace).map(String.init)
        guard !tokens.isEmpty else {
            return nil
        }

        var index = 0
        var isCompleted = false
        var completionDate: TodoDate?
        var creationDate: TodoDate?
        var priority: Character?

        if tokens[index] == "x" {
            isCompleted = true
            index += 1

            if index < tokens.count, let parsedCompletionDate = TodoDate(rawValue: tokens[index]) {
                completionDate = parsedCompletionDate
                index += 1
            }

            if index < tokens.count, parsePriority(tokens[index]) != nil {
                return nil
            }

            if index < tokens.count, let parsedCreationDate = TodoDate(rawValue: tokens[index]) {
                creationDate = parsedCreationDate
                index += 1
            }

            if index < tokens.count, parsePriority(tokens[index]) != nil {
                return nil
            }
        } else {
            if index < tokens.count, let parsedPriority = parsePriority(tokens[index]) {
                priority = parsedPriority
                index += 1
            }

            if index < tokens.count, let parsedCreationDate = TodoDate(rawValue: tokens[index]) {
                creationDate = parsedCreationDate
                index += 1
            }
        }

        let bodyTokens = Array(tokens[index...])
        let body = bodyTokens.joined(separator: " ")
        let extracted = extractMetadata(from: bodyTokens)

        return TodoTask(
            isCompleted: isCompleted,
            priority: priority,
            completionDate: completionDate,
            creationDate: creationDate,
            body: body,
            projects: extracted.projects,
            contexts: extracted.contexts,
            metadata: extracted.metadata
        )
    }

    private static func parsePriority(_ token: String) -> Character? {
        guard token.count == 3,
              token.first == "(",
              token.last == ")"
        else {
            return nil
        }

        let letterIndex = token.index(after: token.startIndex)
        let letter = token[letterIndex]
        guard letter.isASCII, letter >= "A", letter <= "Z" else {
            return nil
        }

        return letter
    }

    private static func extractMetadata(from bodyTokens: [String]) -> (projects: [String], contexts: [String], metadata: [TodoKeyValue]) {
        var projects: [String] = []
        var contexts: [String] = []
        var metadata: [TodoKeyValue] = []

        for token in bodyTokens {
            if token.hasPrefix("+"), token.count > 1 {
                projects.append(String(token.dropFirst()))
            }

            if token.hasPrefix("@"), token.count > 1 {
                contexts.append(String(token.dropFirst()))
            }

            if let separatorIndex = token.firstIndex(of: ":"),
               separatorIndex != token.startIndex,
               token.index(after: separatorIndex) < token.endIndex {
                let key = String(token[..<separatorIndex])
                let value = String(token[token.index(after: separatorIndex)...])
                metadata.append(TodoKeyValue(key: key, value: value))
            }
        }

        return (projects, contexts, metadata)
    }
}