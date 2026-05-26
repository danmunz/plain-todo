import Foundation

public enum LineEnding: String, CaseIterable, Equatable, Sendable {
    case lf = "\n"
    case crlf = "\r\n"
    case cr = "\r"
}

public struct TodoDate: Equatable, Hashable, Sendable, CustomStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int

    public init?(rawValue: String) {
        let segments = rawValue.split(separator: "-", omittingEmptySubsequences: false)
        guard segments.count == 3,
              let year = Int(segments[0]),
              let month = Int(segments[1]),
              let day = Int(segments[2])
        else {
            return nil
        }

        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.year = year
        components.month = month
        components.day = day

        guard components.date != nil else {
            return nil
        }

        self.year = year
        self.month = month
        self.day = day
    }

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    public var description: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }
}

public struct TodoKeyValue: Equatable, Hashable, Sendable {
    public let key: String
    public let value: String

    public init(key: String, value: String) {
        self.key = key
        self.value = value
    }
}

public struct LineIdentity: Hashable, Sendable, CustomStringConvertible {
    public let lineNumber: Int
    public let contentHash: Int

    public init(lineNumber: Int, rawText: String) {
        var hasher = Hasher()
        hasher.combine(rawText)
        self.lineNumber = lineNumber
        self.contentHash = hasher.finalize()
    }

    public var description: String {
        "\(lineNumber):\(contentHash)"
    }
}

public struct TodoTask: Equatable, Sendable {
    public let isCompleted: Bool
    public let priority: Character?
    public let completionDate: TodoDate?
    public let creationDate: TodoDate?
    public let body: String
    public let projects: [String]
    public let contexts: [String]
    public let metadata: [TodoKeyValue]

    public init(
        isCompleted: Bool,
        priority: Character?,
        completionDate: TodoDate?,
        creationDate: TodoDate?,
        body: String,
        projects: [String],
        contexts: [String],
        metadata: [TodoKeyValue]
    ) {
        self.isCompleted = isCompleted
        self.priority = priority
        self.completionDate = completionDate
        self.creationDate = creationDate
        self.body = body
        self.projects = projects
        self.contexts = contexts
        self.metadata = metadata
    }
}

public extension TodoTask {
    public func renderedRawText() -> String {
        var tokens: [String] = []

        if isCompleted {
            tokens.append("x")

            if let completionDate {
                tokens.append(completionDate.description)
            }

            if let creationDate {
                tokens.append(creationDate.description)
            }
        } else {
            if let priority {
                tokens.append("(\(priority))")
            }

            if let creationDate {
                tokens.append(creationDate.description)
            }
        }

        if !body.isEmpty {
            tokens.append(body)
        }

        return tokens.joined(separator: " ")
    }
}

public struct TodoLine: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case blank
        case task(TodoTask)
        case opaque
    }

    public let identity: LineIdentity
    public let rawText: String
    public let originalLineEnding: LineEnding?
    public let kind: Kind

    public init(identity: LineIdentity, rawText: String, originalLineEnding: LineEnding?, kind: Kind) {
        self.identity = identity
        self.rawText = rawText
        self.originalLineEnding = originalLineEnding
        self.kind = kind
    }

    public var task: TodoTask? {
        guard case let .task(task) = kind else {
            return nil
        }

        return task
    }
}

public struct TodoFileSnapshot: Equatable, Sendable {
    public let lines: [TodoLine]
    public let preferredLineEnding: LineEnding
    public let containsMixedLineEndings: Bool
    public let hasTrailingNewline: Bool

    public init(
        lines: [TodoLine],
        preferredLineEnding: LineEnding,
        containsMixedLineEndings: Bool,
        hasTrailingNewline: Bool
    ) {
        self.lines = lines
        self.preferredLineEnding = preferredLineEnding
        self.containsMixedLineEndings = containsMixedLineEndings
        self.hasTrailingNewline = hasTrailingNewline
    }

    public static let empty = TodoFileSnapshot(
        lines: [],
        preferredLineEnding: .lf,
        containsMixedLineEndings: false,
        hasTrailingNewline: false
    )

    public var tasks: [TodoTask] {
        lines.compactMap(\.task)
    }

    public func lineIndex(for identity: LineIdentity) -> Int? {
        lines.firstIndex { $0.identity == identity }
    }
}