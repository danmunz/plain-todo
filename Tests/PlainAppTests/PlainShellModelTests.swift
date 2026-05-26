import XCTest
@testable import Plain

@MainActor
final class PlainShellModelTests: XCTestCase {
    private func makePreferencesStore() -> (PreferencesStore, UserDefaults, String) {
        let suiteName = "PlainShellModelTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (PreferencesStore(userDefaults: defaults), defaults, suiteName)
    }

    private func makeSortPreferenceStore() -> (SortPreferenceStore, UserDefaults, String) {
        let suiteName = "PlainShellSortTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (SortPreferenceStore(userDefaults: defaults), defaults, suiteName)
    }

    func testAddTaskRegistersUndoAndRestoresPreviousVisibleRows() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let fileURL = temporaryDirectory.appendingPathComponent("todo.txt")
        try "Call accountant @phone +taxes\n".write(to: fileURL, atomically: true, encoding: .utf8)

        let model = PlainShellModel()
        let undoManager = UndoManager()

        model.open(url: fileURL)
        XCTAssertEqual(model.visibleRows.count, 1)

        model.addTask(rawText: "Review parser bootstrap +plain @work", undoManager: undoManager)
        XCTAssertEqual(model.visibleRows.count, 2)

        undoManager.undo()
        XCTAssertEqual(model.visibleRows.count, 1)
        XCTAssertEqual(model.visibleRows.first?.rawText, "Call accountant @phone +taxes")

        undoManager.redo()
        XCTAssertEqual(model.visibleRows.count, 2)
    }

    func testMoveSelectionTracksVisibleRows() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let fileURL = temporaryDirectory.appendingPathComponent("todo.txt")
        try "Call accountant @phone +taxes\nReview parser bootstrap +plain @work\n".write(to: fileURL, atomically: true, encoding: .utf8)

        let model = PlainShellModel()
        model.open(url: fileURL)

        let firstRow = try XCTUnwrap(model.visibleRows.first)
        XCTAssertEqual(model.selectedRowID, firstRow.id)

        model.moveSelection(by: 1)
        XCTAssertEqual(model.selectedRowID, model.visibleRows.last?.id)

        model.moveSelection(by: -1)
        XCTAssertEqual(model.selectedRowID, firstRow.id)
    }

    func testArchiveBehaviorPreferencePersistsAcrossStoreInstances() {
        let suiteName = "PreferencesStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let firstStore = PreferencesStore(userDefaults: defaults)
        XCTAssertEqual(firstStore.archiveBehavior, .manual)
        firstStore.archiveBehavior = .automatic

        let secondStore = PreferencesStore(userDefaults: defaults)
        XCTAssertEqual(secondStore.archiveBehavior, .automatic)
    }

    func testSortModesReorderInboxRowsWithoutMutatingFileOrder() throws {
        let (sortPreferences, defaults, suiteName) = makeSortPreferenceStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let todoURL = temporaryDirectory.appendingPathComponent("todo.txt")
        try "(B) 2026-05-10 beta item\n2026-05-20 alpha item\n(A) 2026-05-01 zeta item\ngamma item\n".write(to: todoURL, atomically: true, encoding: .utf8)

        let model = PlainShellModel(sortPreferences: sortPreferences)
        model.open(url: todoURL)

        XCTAssertEqual(model.visibleRows.map(\.rawText), [
            "(B) 2026-05-10 beta item",
            "2026-05-20 alpha item",
            "(A) 2026-05-01 zeta item",
            "gamma item"
        ])

        model.setSortMode(.priority)
        XCTAssertEqual(model.visibleRows.map(\.rawText), [
            "(A) 2026-05-01 zeta item",
            "(B) 2026-05-10 beta item",
            "2026-05-20 alpha item",
            "gamma item"
        ])

        model.setSortMode(.creationDate)
        XCTAssertEqual(model.visibleRows.map(\.rawText), [
            "2026-05-20 alpha item",
            "(B) 2026-05-10 beta item",
            "(A) 2026-05-01 zeta item",
            "gamma item"
        ])

        model.setSortMode(.alphabetical)
        XCTAssertEqual(model.visibleRows.map(\.rawText), [
            "2026-05-20 alpha item",
            "(B) 2026-05-10 beta item",
            "gamma item",
            "(A) 2026-05-01 zeta item"
        ])

        XCTAssertEqual(try String(contentsOf: todoURL, encoding: .utf8), "(B) 2026-05-10 beta item\n2026-05-20 alpha item\n(A) 2026-05-01 zeta item\ngamma item\n")
    }

    func testSortModeMemoryIsIndependentPerSidebarSelection() throws {
        let (sortPreferences, defaults, suiteName) = makeSortPreferenceStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let todoURL = temporaryDirectory.appendingPathComponent("todo.txt")
        try "Call accountant +finance\nReview parser +plain @work\n".write(to: todoURL, atomically: true, encoding: .utf8)

        let model = PlainShellModel(sortPreferences: sortPreferences)
        model.open(url: todoURL)

        model.setSortMode(.priority)
        model.selection = .project("plain")
        XCTAssertEqual(model.sortMode, .fileOrder)

        model.setSortMode(.alphabetical)
        model.selection = .inbox
        XCTAssertEqual(model.sortMode, .priority)

        model.selection = .project("plain")
        XCTAssertEqual(model.sortMode, .alphabetical)
    }

    func testChangingSortModePreservesSelectedRowIdentity() throws {
        let (sortPreferences, defaults, suiteName) = makeSortPreferenceStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let todoURL = temporaryDirectory.appendingPathComponent("todo.txt")
        try "zeta item\nalpha item\ngamma item\n".write(to: todoURL, atomically: true, encoding: .utf8)

        let model = PlainShellModel(sortPreferences: sortPreferences)
        model.open(url: todoURL)

        let preservedIdentity = try XCTUnwrap(model.visibleRows.last?.id)
        model.selectedRowID = preservedIdentity
        model.setSortMode(.alphabetical)

        XCTAssertEqual(model.selectedRowID, preservedIdentity)
        XCTAssertEqual(model.visibleRows.first(where: { $0.id == preservedIdentity })?.rawText, "gamma item")
    }

    func testSearchFiltersRowsByCaseInsensitiveRawLineSubstring() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let todoURL = temporaryDirectory.appendingPathComponent("todo.txt")
        try "Submit expense report @work\nReview sprint notes @home\nBook dentist appointment\n".write(to: todoURL, atomically: true, encoding: .utf8)

        let model = PlainShellModel()
        model.open(url: todoURL)
        model.setSearchQuery("WORK")

        XCTAssertEqual(model.visibleRows.map(\.rawText), ["Submit expense report @work"])
    }

    func testSearchCombinesWithSidebarSelection() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let todoURL = temporaryDirectory.appendingPathComponent("todo.txt")
        try "Submit expense report @work +ops\nReview hiring plan @work\nBuy printer ink @home +ops\n".write(to: todoURL, atomically: true, encoding: .utf8)

        let model = PlainShellModel()
        model.open(url: todoURL)
        model.selection = .context("work")
        model.setSearchQuery("expense")

        XCTAssertEqual(model.visibleRows.map(\.rawText), ["Submit expense report @work +ops"])
    }

    func testSearchPreservesSelectedRowWhenMatchRemainsVisible() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let todoURL = temporaryDirectory.appendingPathComponent("todo.txt")
        try "alpha task\nbeta task @work\ngamma task @work\n".write(to: todoURL, atomically: true, encoding: .utf8)

        let model = PlainShellModel()
        model.open(url: todoURL)

        let preservedIdentity = try XCTUnwrap(model.visibleRows[2].id)
        model.selectedRowID = preservedIdentity
        model.setSearchQuery("task")

        XCTAssertEqual(model.selectedRowID, preservedIdentity)
    }

    func testSearchFallsBackToFirstVisibleRowWhenSelectionDropsOut() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let todoURL = temporaryDirectory.appendingPathComponent("todo.txt")
        try "alpha task\nbeta task @work\ngamma task @work\n".write(to: todoURL, atomically: true, encoding: .utf8)

        let model = PlainShellModel()
        model.open(url: todoURL)

        let droppedIdentity = try XCTUnwrap(model.visibleRows.first?.id)
        model.selectedRowID = droppedIdentity
        model.setSearchQuery("gamma")

        XCTAssertNotEqual(model.selectedRowID, droppedIdentity)
        XCTAssertEqual(model.visibleRows.map(\.rawText), ["gamma task @work"])
        XCTAssertEqual(model.selectedRowID, model.visibleRows.first?.id)
    }

    func testSearchRemainsAppliedAcrossExternalReload() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let todoURL = temporaryDirectory.appendingPathComponent("todo.txt")
        try "alpha work item\nbeta home item\n".write(to: todoURL, atomically: true, encoding: .utf8)

        let model = PlainShellModel()
        model.open(url: todoURL)
        model.setSearchQuery("work")

        try "gamma work item\ndelta home item\n".write(to: todoURL, atomically: true, encoding: .utf8)
        model.handleTodoFileChangedExternally()

        XCTAssertEqual(model.visibleRows.map(\.rawText), ["gamma work item"])
    }

    func testDoneSelectionIgnoresActiveSortMode() throws {
        let (sortPreferences, defaults, suiteName) = makeSortPreferenceStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let todoURL = temporaryDirectory.appendingPathComponent("todo.txt")
        let doneURL = temporaryDirectory.appendingPathComponent("done.txt")
        try "zeta item\nalpha item\n".write(to: todoURL, atomically: true, encoding: .utf8)
        try "x 2026-05-20 Close sprint +plain\nx 2026-05-25 File taxes +finance\n".write(to: doneURL, atomically: true, encoding: .utf8)

        let model = PlainShellModel(sortPreferences: sortPreferences)
        model.open(url: todoURL)
        model.setSortMode(.alphabetical)
        model.selection = .done

        XCTAssertEqual(model.visibleRows.map(\.rawText), [
            "x 2026-05-25 File taxes +finance",
            "x 2026-05-20 Close sprint +plain"
        ])
    }

    func testRememberedSortModeSurvivesConflictReload() throws {
        let (sortPreferences, defaults, suiteName) = makeSortPreferenceStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let todoURL = temporaryDirectory.appendingPathComponent("todo.txt")
        try "zeta item\nalpha item\n".write(to: todoURL, atomically: true, encoding: .utf8)

        let model = PlainShellModel(sortPreferences: sortPreferences)
        model.open(url: todoURL)
        model.setSortMode(.alphabetical)

        let selectedIdentity = try XCTUnwrap(model.visibleRows.first?.id)
        model.updateDraftState(newTaskText: "", editingRowID: selectedIdentity, editingRawText: "alpha item @edited")

        try "gamma item\nbeta item\n".write(to: todoURL, atomically: true, encoding: .utf8)
        model.handleTodoFileChangedExternally()
        model.reloadAfterConflict()

        XCTAssertEqual(model.sortMode, .alphabetical)
        XCTAssertEqual(model.visibleRows.map(\.rawText), [
            "beta item",
            "gamma item"
        ])
    }

    func testManualArchiveModeLeavesCompletedTaskInTodoFile() throws {
        let (preferences, defaults, suiteName) = makePreferencesStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let todoURL = temporaryDirectory.appendingPathComponent("todo.txt")
        try "Call accountant @phone +taxes\n".write(to: todoURL, atomically: true, encoding: .utf8)

        let model = PlainShellModel(preferences: preferences)
        model.open(url: todoURL)
        let identity = try XCTUnwrap(model.visibleRows.first?.id)

        model.toggleCompletion(lineIdentity: identity, undoManager: nil)

        let todoText = try String(contentsOf: todoURL, encoding: .utf8)
        XCTAssertTrue(todoText.hasPrefix("x "))
        XCTAssertEqual(model.archivableCompletedTaskCount, 1)
        XCTAssertEqual(model.doneCount, 0)
    }

    func testAutomaticArchiveModeMovesCompletedTaskIntoDoneFile() throws {
        let (preferences, defaults, suiteName) = makePreferencesStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        preferences.archiveBehavior = .automatic

        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let todoURL = temporaryDirectory.appendingPathComponent("todo.txt")
        let doneURL = temporaryDirectory.appendingPathComponent("done.txt")
        try "Call accountant @phone +taxes\n".write(to: todoURL, atomically: true, encoding: .utf8)
        try "x 2026-05-20 Close sprint +plain\n".write(to: doneURL, atomically: true, encoding: .utf8)

        let model = PlainShellModel(preferences: preferences)
        model.open(url: todoURL)
        let identity = try XCTUnwrap(model.visibleRows.first?.id)

        model.toggleCompletion(lineIdentity: identity, undoManager: nil)

        XCTAssertTrue(model.visibleRows.isEmpty)
        XCTAssertEqual(model.archivableCompletedTaskCount, 0)
        XCTAssertEqual(model.doneCount, 2)
        XCTAssertEqual(try String(contentsOf: todoURL, encoding: .utf8), "")
        XCTAssertTrue(try String(contentsOf: doneURL, encoding: .utf8).contains("Call accountant @phone +taxes"))
    }

    func testAutomaticArchiveModeSupportsUndoAcrossBothFiles() throws {
        let (preferences, defaults, suiteName) = makePreferencesStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        preferences.archiveBehavior = .automatic

        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let todoURL = temporaryDirectory.appendingPathComponent("todo.txt")
        let doneURL = temporaryDirectory.appendingPathComponent("done.txt")
        try "Call accountant @phone +taxes\n".write(to: todoURL, atomically: true, encoding: .utf8)
        try "x 2026-05-20 Close sprint +plain\n".write(to: doneURL, atomically: true, encoding: .utf8)

        let model = PlainShellModel(preferences: preferences)
        let undoManager = UndoManager()
        model.open(url: todoURL)
        let identity = try XCTUnwrap(model.visibleRows.first?.id)

        model.toggleCompletion(lineIdentity: identity, undoManager: undoManager)
        undoManager.undo()

        XCTAssertEqual(model.visibleRows.map(\.rawText), ["Call accountant @phone +taxes"])
        XCTAssertEqual(model.doneCount, 1)
        XCTAssertEqual(try String(contentsOf: todoURL, encoding: .utf8), "Call accountant @phone +taxes\n")
        XCTAssertEqual(try String(contentsOf: doneURL, encoding: .utf8), "x 2026-05-20 Close sprint +plain\n")
    }

    func testArchiveCompletedMovesTasksIntoDoneFileAndSupportsUndo() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let todoURL = temporaryDirectory.appendingPathComponent("todo.txt")
        let doneURL = temporaryDirectory.appendingPathComponent("done.txt")
        try "Review parser bootstrap +plain @work\nx 2026-05-25 File taxes +finance\n".write(to: todoURL, atomically: true, encoding: .utf8)
        try "x 2026-05-20 Close sprint +plain\n".write(to: doneURL, atomically: true, encoding: .utf8)

        let model = PlainShellModel()
        let undoManager = UndoManager()
        model.open(url: todoURL)

        XCTAssertEqual(model.doneCount, 1)
        XCTAssertEqual(model.archivableCompletedTaskCount, 1)

        model.archiveCompletedTasks(undoManager: undoManager)

        XCTAssertEqual(model.doneCount, 2)
        XCTAssertEqual(model.archivableCompletedTaskCount, 0)
        XCTAssertEqual(model.visibleRows.count, 1)
        XCTAssertEqual(try String(contentsOf: doneURL, encoding: .utf8), "x 2026-05-20 Close sprint +plain\nx 2026-05-25 File taxes +finance\n")

        undoManager.undo()

        XCTAssertEqual(model.doneCount, 1)
        XCTAssertEqual(model.archivableCompletedTaskCount, 1)
        XCTAssertEqual(try String(contentsOf: todoURL, encoding: .utf8), "Review parser bootstrap +plain @work\nx 2026-05-25 File taxes +finance\n")
    }

    func testDoneSelectionShowsArchivedRowsInReverseFileOrder() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let todoURL = temporaryDirectory.appendingPathComponent("todo.txt")
        let doneURL = temporaryDirectory.appendingPathComponent("done.txt")
        try "Review parser bootstrap +plain @work\n".write(to: todoURL, atomically: true, encoding: .utf8)
        try "x 2026-05-20 Close sprint +plain\nx 2026-05-25 File taxes +finance\n".write(to: doneURL, atomically: true, encoding: .utf8)

        let model = PlainShellModel()
        model.open(url: todoURL)
        model.selection = .done

        XCTAssertEqual(model.doneCount, 2)
        XCTAssertEqual(model.visibleRows.map(\.rawText), [
            "x 2026-05-25 File taxes +finance",
            "x 2026-05-20 Close sprint +plain"
        ])
    }

    func testExternalTodoChangeReloadsWhenNoDraftIsActive() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let todoURL = temporaryDirectory.appendingPathComponent("todo.txt")
        try "Call accountant @phone +taxes\n".write(to: todoURL, atomically: true, encoding: .utf8)

        let model = PlainShellModel()
        model.open(url: todoURL)

        try "Call accountant @phone +taxes\nReview parser bootstrap +plain @work\n".write(to: todoURL, atomically: true, encoding: .utf8)
        model.handleTodoFileChangedExternally()

        XCTAssertEqual(model.visibleRows.count, 2)
        XCTAssertFalse(model.hasExternalTodoConflict)
    }

    func testExternalDoneChangeReloadsArchiveCountsWithoutClearingDraft() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let todoURL = temporaryDirectory.appendingPathComponent("todo.txt")
        let doneURL = temporaryDirectory.appendingPathComponent("done.txt")
        try "Call accountant @phone +taxes\n".write(to: todoURL, atomically: true, encoding: .utf8)
        try "x 2026-05-20 Close sprint +plain\n".write(to: doneURL, atomically: true, encoding: .utf8)

        let model = PlainShellModel()
        model.open(url: todoURL)
        model.updateDraftState(newTaskText: "Review parser bootstrap +plain @work", editingRowID: nil, editingRawText: "")

        try "x 2026-05-20 Close sprint +plain\nx 2026-05-25 File taxes +finance\n".write(to: doneURL, atomically: true, encoding: .utf8)
        model.handleDoneFileChangedExternally()

        XCTAssertEqual(model.doneCount, 2)
        XCTAssertFalse(model.hasExternalTodoConflict)
    }

    func testExternalTodoChangeDuringInlineEditSetsConflictState() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let todoURL = temporaryDirectory.appendingPathComponent("todo.txt")
        try "Call accountant @phone +taxes\n".write(to: todoURL, atomically: true, encoding: .utf8)

        let model = PlainShellModel()
        model.open(url: todoURL)
        let selectedIdentity = try XCTUnwrap(model.visibleRows.first?.id)
        model.updateDraftState(newTaskText: "", editingRowID: selectedIdentity, editingRawText: "Call accountant @phone +taxes due:2026-05-29")

        try "Call accountant @phone +taxes +moved\n".write(to: todoURL, atomically: true, encoding: .utf8)
        model.handleTodoFileChangedExternally()

        XCTAssertTrue(model.hasExternalTodoConflict)
        XCTAssertEqual(model.visibleRows.first?.rawText, "Call accountant @phone +taxes")
    }

    func testReloadAfterConflictDiscardsDraftAndAppliesDiskState() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let todoURL = temporaryDirectory.appendingPathComponent("todo.txt")
        try "Call accountant @phone +taxes\n".write(to: todoURL, atomically: true, encoding: .utf8)

        let model = PlainShellModel()
        model.open(url: todoURL)
        let selectedIdentity = try XCTUnwrap(model.visibleRows.first?.id)
        model.updateDraftState(newTaskText: "", editingRowID: selectedIdentity, editingRawText: "Call accountant @phone +taxes due:2026-05-29")

        try "Call accountant @phone +moved\n".write(to: todoURL, atomically: true, encoding: .utf8)
        model.handleTodoFileChangedExternally()
        model.reloadAfterConflict()

        XCTAssertFalse(model.hasExternalTodoConflict)
        XCTAssertEqual(model.visibleRows.first?.rawText, "Call accountant @phone +moved")
    }

    func testKeepMineAfterConflictWritesDraftThroughStore() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let todoURL = temporaryDirectory.appendingPathComponent("todo.txt")
        try "Call accountant @phone +taxes\n".write(to: todoURL, atomically: true, encoding: .utf8)

        let model = PlainShellModel()
        model.open(url: todoURL)
        let selectedIdentity = try XCTUnwrap(model.visibleRows.first?.id)
        model.updateDraftState(newTaskText: "", editingRowID: selectedIdentity, editingRawText: "Call accountant @phone +taxes due:2026-05-29")

        try "Call accountant @phone +moved\n".write(to: todoURL, atomically: true, encoding: .utf8)
        model.handleTodoFileChangedExternally()
        model.keepMineAfterConflict()

        XCTAssertFalse(model.hasExternalTodoConflict)
        XCTAssertEqual(try String(contentsOf: todoURL, encoding: .utf8), "Call accountant @phone +taxes due:2026-05-29\n")
    }

    func testMoveRowReordersTasksAndSupportsUndo() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let todoURL = temporaryDirectory.appendingPathComponent("todo.txt")
        try "Call accountant @phone +taxes\nReview parser bootstrap +plain @work\nSchedule dentist @phone +health\n".write(to: todoURL, atomically: true, encoding: .utf8)

        let model = PlainShellModel()
        let undoManager = UndoManager()
        model.open(url: todoURL)

        let firstIdentity = try XCTUnwrap(model.visibleRows.first?.id)
        model.moveRow(lineIdentity: firstIdentity, by: 1, undoManager: undoManager)

        XCTAssertEqual(model.visibleRows.map(\.rawText), [
            "Review parser bootstrap +plain @work",
            "Call accountant @phone +taxes",
            "Schedule dentist @phone +health"
        ])

        undoManager.undo()

        XCTAssertEqual(model.visibleRows.map(\.rawText), [
            "Call accountant @phone +taxes",
            "Review parser bootstrap +plain @work",
            "Schedule dentist @phone +health"
        ])
    }
}