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

@Test
func widgetSelectionBuildsExpectedDeepLinksAndTitles() {
    #expect(PlainWidgetSelection.inbox.title == "Inbox")
    #expect(PlainWidgetSelection.today.deepLinkURLString == "plain://today")
    #expect(PlainWidgetSelection.overdue.deepLinkURLString == "plain://overdue")
    #expect(PlainWidgetSelection.done.deepLinkURLString == "plain://done")
    #expect(PlainWidgetSelection.project("Client Work").title == "+Client Work")
    #expect(PlainWidgetSelection.project("Client Work").deepLinkURLString == "plain://project/Client%20Work")
    #expect(PlainWidgetSelection.context("Phone Calls").title == "@Phone Calls")
    #expect(PlainWidgetSelection.context("Phone Calls").deepLinkURLString == "plain://context/Phone%20Calls")
}

@Test
func widgetSnapshotFactorySanitizesPreviewTasksAndUsesSelectionMapping() {
    let generatedAt = Date(timeIntervalSince1970: 1_717_000_000)
    let snapshot = PlainWidgetSnapshotFactory.make(
        generatedAt: generatedAt,
        sourceDescription: "todo.txt",
        selection: .context("Home Office"),
        inboxCount: 5,
        todayCount: 2,
        overdueCount: 1,
        doneCount: 9,
        previewTasks: ["  First task  ", "", "\n", "Second task", "Third task", "Fourth task"]
    )

    #expect(snapshot.generatedAt == generatedAt)
    #expect(snapshot.selectionTitle == "@Home Office")
    #expect(snapshot.deepLinkURL == "plain://context/Home%20Office")
    #expect(snapshot.previewTasks == ["First task", "Second task", "Third task"])
}
