import XCTest

final class OrielUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Phase 1 smoke: app launches to the Oriel start page.
    func testLaunchShowsStartPage() throws {
        let app = XCUIApplication()
        app.launch()

        let brand = app.staticTexts["Oriel"]
        XCTAssertTrue(brand.waitForExistence(timeout: 5))

        let madeBy = app.staticTexts["Made by inveil.net"]
        XCTAssertTrue(madeBy.exists)
    }
}
