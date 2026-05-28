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
