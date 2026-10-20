import XCTest

final class LiveCatalogUITests: XCTestCase {
    func testRealOnlineSearchUI() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--live-ui-testing"]
        app.launch()
        let searchButton = app.buttons["Search music"]
        XCTAssertTrue(searchButton.waitForExistence(timeout: 20)); searchButton.tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 10)); search.tap(); search.typeText("The Weeknd Starboy")
        let result = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Starboy")).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 45), "Real online search results never appeared")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Real online search results — not playback proof"
        screenshot.lifetime = .keepAlways; add(screenshot)
    }
}
