import XCTest

final class SettingsUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private func open(_ title: String) -> XCUIApplication {
        let app = XCUIApplication(); app.launchArguments = ["--ui-testing"]; app.launch()
        let settings = app.buttons["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 15)); settings.tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 8)); search.tap(); search.typeText(title)
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", title)).firstMatch.tap()
        return app
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
    func testAppearanceControlsAreActionable() {
        let app = open("Appearance")
        let glass = app.switches["Glass styling"]
        XCTAssertTrue(glass.waitForExistence(timeout: 5)); let before = glass.value as? String
        glass.tap(); XCTAssertNotEqual(glass.value as? String, before)
        capture(app, "Settings-Appearance-functional-controls")
    }
    func testSourcesOptInIsExplicit() {
        let app = open("Sources")
        let source = app.switches["sources.saavn"]
        if !source.isHittable { app.swipeUp() }
        XCTAssertTrue(source.waitForExistence(timeout: 5)); XCTAssertEqual(source.value as? String, "0")
        source.tap(); XCTAssertEqual(source.value as? String, "1")
        capture(app, "Settings-Sources-explicit-opt-in")
    }
    func testDownloadsSettingsOpenRealManager() {
        let app = open("Downloads")
        let wifi = app.switches["Wi-Fi only downloads"]
        XCTAssertTrue(wifi.waitForExistence(timeout: 5))
        app.buttons["Manage downloads"].tap()
        XCTAssertTrue(app.staticTexts["Available offline"].waitForExistence(timeout: 5))
        capture(app, "Settings-Downloads-real-manager-empty-fixture")
    }
}
