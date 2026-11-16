import XCTest

final class AITranslatorUITests: XCTestCase {
    func testAppLaunchesToAuthOrHome() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
    }
}
