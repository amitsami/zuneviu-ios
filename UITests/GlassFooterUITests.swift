import XCTest
import UIKit

final class GlassFooterUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication(); app.launchArguments = ["--ui-testing"] + extra; app.launch(); return app
    }
    private func verifyLayout(_ app: XCUIApplication) {
        let home = app.buttons["dock.tab.home"], explore = app.buttons["dock.tab.explore"]
        let library = app.buttons["dock.tab.library"], search = app.buttons["dock.search"]
        XCTAssertTrue(home.waitForExistence(timeout: 15))
        for control in [home, explore, library, search] {
            XCTAssertTrue(control.isHittable)
            XCTAssertGreaterThanOrEqual(control.frame.width, 44)
            XCTAssertGreaterThanOrEqual(control.frame.height, 44)
            XCTAssertGreaterThanOrEqual(control.frame.minX, app.frame.minX + 8)
            XCTAssertLessThanOrEqual(control.frame.maxX, app.frame.maxX - 8)
        }
        XCTAssertGreaterThan(search.frame.minX - library.frame.maxX, 4, "Search must be a separate floating capsule")
        let bottomGap = app.frame.maxY - search.frame.maxY
        XCTAssertGreaterThanOrEqual(bottomGap, 6, "Footer must not collide with bottom edge/home indicator")
        XCTAssertLessThanOrEqual(bottomGap, 40, "Footer should sit low, not on a tall opaque bottom slab")
        XCTAssertEqual(home.frame.midY, search.frame.midY, accuracy: 2)
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    func testFooterGeometryAndEveryNavigationAction() {
        let app = launch(); verifyLayout(app)
        let brand = app.staticTexts["brand.name"]
        XCTAssertTrue(brand.waitForExistence(timeout: 5))
        let expectedWidth = ("Zunéviu" as NSString).size(withAttributes: [.font: UIFont.systemFont(ofSize: 21, weight: .semibold)]).width
        XCTAssertGreaterThanOrEqual(brand.frame.width, expectedWidth - 1, "Brand must retain its complete intrinsic text width")
        capture(app, "Glass-01-Home-local-fixture")
        app.buttons["dock.tab.explore"].tap()
        XCTAssertTrue(app.buttons["dock.tab.explore"].isSelected)
        capture(app, "Glass-02-Explore-local-fixture")
        app.buttons["dock.tab.library"].tap()
        XCTAssertTrue(app.buttons["dock.tab.library"].isSelected)
        capture(app, "Glass-03-Library-local-fixture")
        app.buttons["dock.tab.home"].tap()
        XCTAssertTrue(app.buttons["dock.tab.home"].isSelected)
        app.buttons["dock.search"].tap()
        XCTAssertTrue(app.searchFields.firstMatch.waitForExistence(timeout: 5))
    }
    func testMiniPlayerDoesNotOverlapFloatingTabs() {
        let app = launch()
        let song = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Test Tone")).firstMatch
        XCTAssertTrue(song.waitForExistence(timeout: 15)); song.tap()
        let mini = app.buttons["Now playing: Test Tone"]
        XCTAssertTrue(mini.waitForExistence(timeout: 10)); verifyLayout(app)
        let home = app.buttons["dock.tab.home"]
        XCTAssertLessThan(mini.frame.maxY, home.frame.minY - 4)
        capture(app, "Glass-04-MiniPlayer-local-audio-fixture")
        app.buttons["Now playing: Test Tone"].tap()
        XCTAssertTrue(app.buttons["Close player"].waitForExistence(timeout: 5))
        let transport = app.buttons["player.transport"]
        XCTAssertTrue(transport.waitForExistence(timeout: 5))
        for control in [transport, app.buttons["Next track"], app.buttons["Previous track"], app.buttons["Track options"]] {
            XCTAssertTrue(control.isHittable)
            XCTAssertGreaterThanOrEqual(control.frame.minX, app.frame.minX)
            XCTAssertLessThanOrEqual(control.frame.maxX, app.frame.maxX)
        }
        capture(app, "Glass-Player-width-and-transport-regression")
        app.buttons["Close player"].tap()
    }
    func testReducedMotionTransparencyAndLargeTextRemainUsable() {
        let app = launch(["--reduce-motion", "--reduce-transparency", "--large-type"])
        verifyLayout(app)
        capture(app, "Glass-05-Accessibility-large-text-solid-fallback")
        app.buttons["dock.tab.library"].tap()
        XCTAssertTrue(app.buttons["dock.tab.library"].isSelected)
        app.buttons["dock.search"].tap()
        XCTAssertTrue(app.searchFields.firstMatch.waitForExistence(timeout: 5))
    }
    func testPlaylistCreationSheetWorksWithLegacyCompatibleControls() {
        let app = launch()
        app.buttons["dock.tab.library"].tap()
        let create = app.buttons["New playlist"]
        XCTAssertTrue(create.waitForExistence(timeout: 5)); create.tap()
        let field = app.textFields["playlist.name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap(); field.typeText("Compatibility playlist")
        app.buttons["Create"].tap()
        XCTAssertTrue(app.staticTexts["Compatibility playlist"].waitForExistence(timeout: 5))
    }
    func testScrollInteractionMetrics() {
        let app = launch()
        XCTAssertTrue(app.buttons["dock.tab.home"].waitForExistence(timeout: 15))
        let options = XCTMeasureOptions(); options.iterationCount = 3
        // Reports actual CPU/memory/wall time for this interaction. No claimed
        // FPS or percentage improvement is inferred without a before baseline.
        measure(metrics: [XCTClockMetric(), XCTCPUMetric(application: app), XCTMemoryMetric(application: app)], options: options) {
            app.swipeUp(velocity: .fast); app.swipeDown(velocity: .fast)
        }
        verifyLayout(app)
    }
}
