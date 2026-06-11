import XCTest

@MainActor
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

    override func setUp() async throws {
        continueAfterFailure = false

        let tempDir = FileManager.default.temporaryDirectory
        tempFileURL = tempDir.appendingPathComponent("plain-uitest-\(UUID().uuidString).txt")
        let fixture = """
        (A) Call accountant @phone +taxes due:2026-06-15
        (B) Review pull request @work +plain
        Buy groceries @errands
        x 2026-06-01 2026-05-30 Old completed task +done
        """
        try fixture.write(to: tempFileURL, atomically: true, encoding: .utf8)

        app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--todo-file", tempFileURL.path]
        app.launch()
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempFileURL)
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

        let fieldValue = addField.value as? String ?? ""
        XCTAssertTrue(fieldValue.isEmpty, "Add field should clear after submission")
    }

    // MARK: - Keyboard Navigation
    func testArrowKeyNavigation() {
        let window = app.windows.firstMatch
        guard window.waitForExistence(timeout: 3) else {
            XCTFail("Window not found")
            return
        }

        window.typeKey(.downArrow, modifierFlags: [])
        window.typeKey(.downArrow, modifierFlags: [])
        window.typeKey("j", modifierFlags: [])
        window.typeKey("k", modifierFlags: [])
    }

    // MARK: - Complete Task
    func testCompleteTaskViaKeyboard() {
        let window = app.windows.firstMatch
        guard window.waitForExistence(timeout: 3) else {
            XCTFail("Window not found")
            return
        }

        window.typeKey(.downArrow, modifierFlags: [])
        window.typeKey(.return, modifierFlags: [.shift, .command])
    }

    // MARK: - Delete Task
    func testDeleteTaskViaKeyboard() {
        let window = app.windows.firstMatch
        guard window.waitForExistence(timeout: 3) else {
            XCTFail("Window not found")
            return
        }

        window.typeKey(.downArrow, modifierFlags: [])
        window.typeKey(.delete, modifierFlags: .command)
    }

    // MARK: - Inline Edit
    func testInlineEditViaKeyboard() {
        let window = app.windows.firstMatch
        guard window.waitForExistence(timeout: 3) else {
            XCTFail("Window not found")
            return
        }

        window.typeKey(.downArrow, modifierFlags: [])
        window.typeKey(.return, modifierFlags: [])
        window.typeText(" edited")
        window.typeKey(.return, modifierFlags: [])
    }

    // MARK: - Inline Edit Cancel
    func testInlineEditCancelViaEscape() {
        let window = app.windows.firstMatch
        guard window.waitForExistence(timeout: 3) else {
            XCTFail("Window not found")
            return
        }

        window.typeKey(.downArrow, modifierFlags: [])
        window.typeKey(.return, modifierFlags: [])
        window.typeText("DISCARD THIS")
        window.typeKey(.escape, modifierFlags: [])
    }

    // MARK: - Undo After Complete
    func testUndoAfterComplete() {
        let window = app.windows.firstMatch
        guard window.waitForExistence(timeout: 3) else {
            XCTFail("Window not found")
            return
        }

        window.typeKey(.downArrow, modifierFlags: [])
        window.typeKey(.return, modifierFlags: [.shift, .command])
        window.typeKey("z", modifierFlags: .command)
    }

    // MARK: - Priority Change
    func testReprioritizeViaKeyboard() {
        let window = app.windows.firstMatch
        guard window.waitForExistence(timeout: 3) else {
            XCTFail("Window not found")
            return
        }

        window.typeKey(.downArrow, modifierFlags: [])
        window.typeKey("2", modifierFlags: .command)
        window.typeKey("1", modifierFlags: .command)
        window.typeKey("0", modifierFlags: .command)
    }

    // MARK: - Search Overlay
    func testSearchOverlayViaKeyboard() {
        let window = app.windows.firstMatch
        guard window.waitForExistence(timeout: 3) else {
            XCTFail("Window not found")
            return
        }

        window.typeKey("f", modifierFlags: .command)
        window.typeText("accountant")
        window.typeKey(.escape, modifierFlags: [])
    }

    // MARK: - Multi-Select
    func testMultiSelectViaKeyboard() {
        let window = app.windows.firstMatch
        guard window.waitForExistence(timeout: 3) else {
            XCTFail("Window not found")
            return
        }

        window.typeKey(.downArrow, modifierFlags: [])
        window.typeKey(.downArrow, modifierFlags: .shift)
        window.typeKey(.downArrow, modifierFlags: .shift)
        window.typeKey("a", modifierFlags: .command)
    }

    // MARK: - Keyboard Reorder
    func testReorderViaKeyboard() {
        let window = app.windows.firstMatch
        guard window.waitForExistence(timeout: 3) else {
            XCTFail("Window not found")
            return
        }

        window.typeKey(.downArrow, modifierFlags: [])
        window.typeKey(.downArrow, modifierFlags: [])
        window.typeKey(.upArrow, modifierFlags: [.option, .command])
        window.typeKey(.downArrow, modifierFlags: [.option, .command])
    }
}
