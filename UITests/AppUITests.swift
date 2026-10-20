import XCTest

final class AppUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    func testLocalPlaybackAndFavorite() {
        let app = XCUIApplication(); app.launchArguments = ["--ui-testing"]; app.launch()
        let song = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Test Tone")).firstMatch
        XCTAssertTrue(song.waitForExistence(timeout: 15)); song.tap()
        let pause = app.buttons["Pause"].firstMatch
        XCTAssertTrue(pause.waitForExistence(timeout: 15))
        app.buttons["Now playing: Test Tone"].tap()
        let favorite = app.buttons["Toggle favorite"]
        XCTAssertTrue(favorite.waitForExistence(timeout: 5)); favorite.tap()
        app.buttons["Close player"].tap()
        app.buttons["Library"].tap()
        XCTAssertTrue(app.staticTexts["Liked songs · 1"].waitForExistence(timeout: 5) || app.buttons["Liked songs · 1"].exists)
    }
    func testSearchAndSettings() {
        let app = XCUIApplication(); app.launchArguments = ["--ui-testing"]; app.launch()
        app.buttons["Search music"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5)); search.tap(); search.typeText("Test Tone")
        XCTAssertTrue(app.staticTexts["Test Tone"].firstMatch.waitForExistence(timeout: 5))
    }
}
