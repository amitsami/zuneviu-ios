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
        glass.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value != %@", before ?? "1"), object: glass)
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 5), .completed)
        capture(app, "Settings-Appearance-functional-controls")
    }
    func testSourcesOptInIsExplicit() {
        let app = open("Sources")
        let source = app.switches["sources.saavn"]
        if !source.isHittable { app.swipeUp() }
        XCTAssertTrue(source.waitForExistence(timeout: 5)); XCTAssertEqual(source.value as? String, "0")
        source.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "1"), object: source)
        XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 5), .completed)
        capture(app, "Settings-Sources-explicit-opt-in")
    }
    func testDownloadsSettingsOpenRealManager() {
        let app = open("Downloads")
        let wifi = app.switches["Wi-Fi only downloads"]
        XCTAssertTrue(wifi.waitForExistence(timeout: 5))
        app.buttons["Manage downloads"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label ==[c] %@", "Available offline")).firstMatch.waitForExistence(timeout: 5))
        capture(app, "Settings-Downloads-real-manager-empty-fixture")
    }
}
