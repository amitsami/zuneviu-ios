import XCTest

final class LiveCatalogUITests: XCTestCase {
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    private func dismissSheet(_ app: XCUIApplication, title: String) {
        let bar = app.navigationBars[title]
        XCTAssertTrue(bar.waitForExistence(timeout: 8))
        bar.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.96)))
    }
    func testRealSaavnSearchAndPlaybackUI() throws {
        let app = XCUIApplication(); app.launchArguments = ["--live-ui-testing"]; app.launch()
        let settings = app.buttons["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 20)); settings.tap()
        let settingsSearch = app.searchFields.firstMatch
        XCTAssertTrue(settingsSearch.waitForExistence(timeout: 10)); settingsSearch.tap(); settingsSearch.typeText("Sources")
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Sources")).firstMatch.tap()
        let source = app.switches["sources.saavn"]
        XCTAssertTrue(source.waitForExistence(timeout: 8))
        if !source.isHittable { app.swipeUp() }
        let sourceHittable = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isHittable == true"), object: source)
        XCTAssertEqual(XCTWaiter.wait(for: [sourceHittable], timeout: 5), .completed)
        if source.value as? String != "1" {
            source.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5))
                .withOffset(CGVector(dx: source.frame.width - 58, dy: 0)).tap()
        }
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "1"), object: source)
        XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 5), .completed)
        dismissSheet(app, title: "Sources")
        let searchMusic = app.buttons["Search music"]
        let visible = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isHittable == true"), object: searchMusic)
        XCTAssertEqual(XCTWaiter.wait(for: [visible], timeout: 8), .completed); searchMusic.tap()
        let selector = app.segmentedControls["search.source"]
        XCTAssertTrue(selector.waitForExistence(timeout: 8)); selector.buttons["JioSaavn"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 8)); search.tap(); search.typeText("Tum Hi Ho")
        let result = app.buttons.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "Tum Hi Ho", "Arijit")).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 45), "Real source recording never appeared in Search")
        capture(app, "Real-JioSaavn-source-search-not-a-fixture")
        result.tap()
        // iOS 26 keeps searchable active with its bar above the keyboard;
        // the navigation title is absent until the native search close action.
        let closeSearch = app.buttons["close"]
        if closeSearch.exists && closeSearch.isHittable { closeSearch.tap() }
        dismissSheet(app, title: "Search")
        let nowPlaying = app.buttons["Now playing: Tum Hi Ho"]
        XCTAssertTrue(nowPlaying.waitForExistence(timeout: 12)); nowPlaying.tap()
        XCTAssertTrue(app.buttons["player.transport"].waitForExistence(timeout: 50), "Native real-source playback did not reach playing")
        XCTAssertTrue(app.staticTexts["Playing from JioSaavn"].exists)
        let advancing = app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "0:(0[2-9]|[1-5][0-9])")).firstMatch
        XCTAssertTrue(advancing.waitForExistence(timeout: 15), "Real playback position did not advance in UI")
        capture(app, "Real-JioSaavn-Now-Playing-native-AVPlayer")
        let transport = app.buttons["player.transport"]
        for control in [transport, app.scrollViews.buttons["Next track"], app.scrollViews.buttons["Previous track"], app.scrollViews.buttons["Track options"]] {
            XCTAssertTrue(control.isHittable)
            XCTAssertGreaterThanOrEqual(control.frame.minX, app.frame.minX)
            XCTAssertLessThanOrEqual(control.frame.maxX, app.frame.maxX)
        }
        XCTAssertEqual(transport.label, "Pause")
        transport.tap()
        let paused = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "Play"), object: transport)
        XCTAssertEqual(XCTWaiter.wait(for: [paused], timeout: 5), .completed)
    }

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
