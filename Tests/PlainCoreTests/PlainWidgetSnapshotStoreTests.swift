import Foundation
import Testing
@testable import PlainCore

@Test
func widgetSnapshotStoreRoundTripsSnapshotData() throws {
    let suiteName = "PlainWidgetSnapshotStoreTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let snapshot = PlainWidgetSnapshot(
        generatedAt: Date(timeIntervalSince1970: 1_716_000_000),
        sourceDescription: "todo.txt",
        selectionTitle: "Today",
        deepLinkURL: "plain://today",
        inboxCount: 12,
        todayCount: 3,
        overdueCount: 1,
        doneCount: 22,
        previewTasks: ["Pay invoice", "Call plumber"]
    )

    PlainWidgetSnapshotStore.save(snapshot, defaults: defaults)
    let reloadedSnapshot = try #require(PlainWidgetSnapshotStore.load(defaults: defaults))

    #expect(reloadedSnapshot == snapshot)
}

@Test
func widgetSnapshotStoreClearRemovesPersistedSnapshot() throws {
    let suiteName = "PlainWidgetSnapshotStoreClearTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    defer { defaults.removePersistentDomain(forName: suiteName) }

    PlainWidgetSnapshotStore.save(.placeholder, defaults: defaults)
    #expect(PlainWidgetSnapshotStore.load(defaults: defaults) != nil)

    PlainWidgetSnapshotStore.clear(defaults: defaults)
    #expect(PlainWidgetSnapshotStore.load(defaults: defaults) == nil)
}
