import XCTest

final class PlainUITests: XCTestCase {
    @MainActor
    func testAppLaunchesAndShowsWindow() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
    }
}