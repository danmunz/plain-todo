import Foundation

public enum PlainWidgetConfig {
    public static let appGroupID = "group.com.danmunz.Plain"
    public static let snapshotDefaultsKey = "PlainWidgetSnapshot"
    public static let widgetKind = "PlainOverviewWidget"
}

public struct PlainWidgetSnapshot: Codable, Equatable, Sendable {
    public let generatedAt: Date
    public let sourceDescription: String
    public let selectionTitle: String
    public let deepLinkURL: String
    public let inboxCount: Int
    public let todayCount: Int
    public let overdueCount: Int
    public let doneCount: Int
    public let previewTasks: [String]

    public init(
        generatedAt: Date,
        sourceDescription: String,
        selectionTitle: String,
        deepLinkURL: String,
        inboxCount: Int,
        todayCount: Int,
        overdueCount: Int,
        doneCount: Int,
        previewTasks: [String]
    ) {
        self.generatedAt = generatedAt
        self.sourceDescription = sourceDescription
        self.selectionTitle = selectionTitle
        self.deepLinkURL = deepLinkURL
        self.inboxCount = inboxCount
        self.todayCount = todayCount
        self.overdueCount = overdueCount
        self.doneCount = doneCount
        self.previewTasks = previewTasks
    }

    public static let placeholder = PlainWidgetSnapshot(
        generatedAt: Date(),
        sourceDescription: "Open a todo.txt file in Plain",
        selectionTitle: "Inbox",
        deepLinkURL: "plain://inbox",
        inboxCount: 0,
        todayCount: 0,
        overdueCount: 0,
        doneCount: 0,
        previewTasks: []
    )
}

public enum PlainWidgetSelection: Equatable, Sendable {
    case inbox
    case today
    case overdue
    case done
    case project(String)
    case context(String)

    public var title: String {
        switch self {
        case .inbox:
            return "Inbox"
        case .today:
            return "Today"
        case .overdue:
            return "Overdue"
        case .done:
            return "Done"
        case let .project(project):
            return "+\(project)"
        case let .context(context):
            return "@\(context)"
        }
    }

    public var deepLinkURLString: String {
        switch self {
        case .inbox:
            return "plain://inbox"
        case .today:
            return "plain://today"
        case .overdue:
            return "plain://overdue"
        case .done:
            return "plain://done"
        case let .project(project):
            return "plain://project/\(Self.encodePathSegment(project))"
        case let .context(context):
            return "plain://context/\(Self.encodePathSegment(context))"
        }
    }

    private static func encodePathSegment(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? value
    }
}

public enum PlainWidgetSnapshotFactory {
    public static func make(
        generatedAt: Date = Date(),
        sourceDescription: String,
        selection: PlainWidgetSelection,
        inboxCount: Int,
        todayCount: Int,
        overdueCount: Int,
        doneCount: Int,
        previewTasks: [String]
    ) -> PlainWidgetSnapshot {
        PlainWidgetSnapshot(
            generatedAt: generatedAt,
            sourceDescription: sourceDescription,
            selectionTitle: selection.title,
            deepLinkURL: selection.deepLinkURLString,
            inboxCount: inboxCount,
            todayCount: todayCount,
            overdueCount: overdueCount,
            doneCount: doneCount,
            previewTasks: sanitizedPreviewTasks(previewTasks)
        )
    }

    private static func sanitizedPreviewTasks(_ previewTasks: [String]) -> [String] {
        previewTasks
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(3)
            .map { String($0) }
    }
}

public enum PlainWidgetSnapshotStore {
    public static func load(defaults: UserDefaults? = nil) -> PlainWidgetSnapshot? {
        let resolvedDefaults = defaults ?? UserDefaults(suiteName: PlainWidgetConfig.appGroupID) ?? .standard
        guard let data = resolvedDefaults.data(forKey: PlainWidgetConfig.snapshotDefaultsKey) else {
            return nil
        }

        return try? JSONDecoder().decode(PlainWidgetSnapshot.self, from: data)
    }

    public static func save(
        _ snapshot: PlainWidgetSnapshot,
        defaults: UserDefaults? = nil
    ) {
        let resolvedDefaults = defaults ?? UserDefaults(suiteName: PlainWidgetConfig.appGroupID) ?? .standard
        guard let data = try? JSONEncoder().encode(snapshot) else {
            return
        }

        resolvedDefaults.set(data, forKey: PlainWidgetConfig.snapshotDefaultsKey)
    }

    public static func clear(defaults: UserDefaults? = nil) {
        let resolvedDefaults = defaults ?? UserDefaults(suiteName: PlainWidgetConfig.appGroupID) ?? .standard
        resolvedDefaults.removeObject(forKey: PlainWidgetConfig.snapshotDefaultsKey)
    }
}
