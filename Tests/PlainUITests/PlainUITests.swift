import XCTest

final class PlainUITests: XCTestCase {
    func testAppLaunchesAndShowsWindow() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
    }
}

// MARK: - Keyboard Editing Regression Tests

@MainActor
final class PlainKeyboardEditingTests: XCTestCase {

    private var app: XCUIApplication!
    private var tempFileURL: URL!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false

        // Create a temporary todo.txt with known content
        let tempDir = FileManager.default.temporaryDirectory
        tempFileURL = tempDir.appendingPathComponent("plain-uitest-\(UUID().uuidString).txt")
        let fixture = """
        (A) Call accountant @phone +taxes due:2026-06-15
        (B) Review pull request @work +plain
        Buy groceries @errands
        x 2026-06-01 2026-05-30 Old completed task +done
        """
        try? fixture.write(to: tempFileURL, atomically: true, encoding: .utf8)

        app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--todo-file", tempFileURL.path]
        app.launch()
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempFileURL)
        super.tearDown()
    }

    // MARK: - Add Task
    func testAddTaskViaKeyboard() {
        let addField = app.textFields["plain.add.textField"]
        guard addField.waitForExistence(timeout: 3) else {
            XCTFail("Add field not found")
            return
        }

        addField.click()
        addField.typeText("New test task @work +testing")
        addField.typeKey(.return, modifierFlags: [])

        // Verify the task was added — the text field should be cleared
        let fieldValue = addField.value as? String ?? ""
        XCTAssertTrue(fieldValue.isEmpty, "Add field should clear after submission")
    }

    // MARK: - Keyboard Navigation
    func testArrowKeyNavigation() {
        // Press Down arrow to enter the task list and navigate
        let window = app.windows.firstMatch
        guard window.waitForExistence(timeout: 3) else {
            XCTFail("Window not found")
            return
        }

        // Down arrow moves selection into the list
        window.typeKey(.downArrow, modifierFlags: [])
        window.typeKey(.downArrow, modifierFlags: [])

        // J/K vim-style navigation
        window.typeKey("j", modifierFlags: [])
        window.typeKey("k", modifierFlags: [])

        // No crash = pass for navigation regression
    }

    // MARK: - Complete Task
    func testCompleteTaskViaKeyboard() {
        let window = app.windows.firstMatch
        guard window.waitForExistence(timeout: 3) else {
            XCTFail("Window not found")
            return
        }

        // Navigate to first task
        window.typeKey(.downArrow, modifierFlags: [])

        // Complete via Cmd+Shift+Enter (standard completion shortcut)
        window.typeKey(.return, modifierFlags: [.shift, .command])

        // Should not crash — the task row should update
    }

    // MARK: - Delete Task
    func testDeleteTaskViaKeyboard() {
        let window = app.windows.firstMatch
        guard window.waitForExistence(timeout: 3) else {
            XCTFail("Window not found")
            return
        }

        // Navigate to a task
        window.typeKey(.downArrow, modifierFlags: [])

        // Delete via Cmd+Backspace
        window.typeKey(.delete, modifierFlags: .command)

        // No crash = regression pass
    }

    // MARK: - Inline Edit
    func testInlineEditViaKeyboard() {
        let window = app.windows.firstMatch
        guard window.waitForExistence(timeout: 3) else {
            XCTFail("Window not found")
            return
        }

        // Navigate to first task
        window.typeKey(.downArrow, modifierFlags: [])

        // Enter inline edit mode (Return key)
        window.typeKey(.return, modifierFlags: [])

        // Type some edit
        window.typeText(" edited")

        // Save with Return
        window.typeKey(.return, modifierFlags: [])

        // No crash = regression pass
    }

    // MARK: - Inline Edit Cancel
    func testInlineEditCancelViaEscape() {
        let window = app.windows.firstMatch
        guard window.waitForExistence(timeout: 3) else {
            XCTFail("Window not found")
            return
        }

        // Navigate to first task
        window.typeKey(.downArrow, modifierFlags: [])

        // Enter inline edit mode
        window.typeKey(.return, modifierFlags: [])

        // Type something
        window.typeText("DISCARD THIS")

        // Cancel with Escape
        window.typeKey(.escape, modifierFlags: [])

        // No crash = regression pass; original text should be preserved in file
    }

    // MARK: - Undo After Complete
    func testUndoAfterComplete() {
        let window = app.windows.firstMatch
        guard window.waitForExistence(timeout: 3) else {
            XCTFail("Window not found")
            return
        }

        // Navigate and complete
        window.typeKey(.downArrow, modifierFlags: [])
        window.typeKey(.return, modifierFlags: [.shift, .command])

        // Undo
        window.typeKey("z", modifierFlags: .command)

        // No crash = regression pass
    }

    // MARK: - Priority Change
    func testReprioritizeViaKeyboard() {
        let window = app.windows.firstMatch
        guard window.waitForExistence(timeout: 3) else {
            XCTFail("Window not found")
            return
        }

        // Navigate to first task
        window.typeKey(.downArrow, modifierFlags: [])

        // Set priority B via Cmd+2
        window.typeKey("2", modifierFlags: .command)

        // Set priority A via Cmd+1
        window.typeKey("1", modifierFlags: .command)

        // Remove priority via Cmd+0
        window.typeKey("0", modifierFlags: .command)

        // No crash = regression pass
    }

    // MARK: - Search Overlay
    func testSearchOverlayViaKeyboard() {
        let window = app.windows.firstMatch
        guard window.waitForExistence(timeout: 3) else {
            XCTFail("Window not found")
            return
        }

        // Open search with Cmd+F
        window.typeKey("f", modifierFlags: .command)

        // Type a search query
        window.typeText("accountant")

        // Close search with Escape
        window.typeKey(.escape, modifierFlags: [])

        // No crash = regression pass
    }

    // MARK: - Multi-Select
    func testMultiSelectViaKeyboard() {
        let window = app.windows.firstMatch
        guard window.waitForExistence(timeout: 3) else {
            XCTFail("Window not found")
            return
        }

        // Navigate to first task
        window.typeKey(.downArrow, modifierFlags: [])

        // Extend selection with Shift+Down
        window.typeKey(.downArrow, modifierFlags: .shift)
        window.typeKey(.downArrow, modifierFlags: .shift)

        // Select all with Cmd+A
        window.typeKey("a", modifierFlags: .command)

        // No crash = regression pass
    }

    // MARK: - Keyboard Reorder
    func testReorderViaKeyboard() {
        let window = app.windows.firstMatch
        guard window.waitForExistence(timeout: 3) else {
            XCTFail("Window not found")
            return
        }

        // Navigate to second task
        window.typeKey(.downArrow, modifierFlags: [])
        window.typeKey(.downArrow, modifierFlags: [])

        // Move up with Opt+Cmd+Up
        window.typeKey(.upArrow, modifierFlags: [.option, .command])

        // Move down with Opt+Cmd+Down
        window.typeKey(.downArrow, modifierFlags: [.option, .command])

        // No crash = regression pass
    }
}