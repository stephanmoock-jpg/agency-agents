import XCTest

/// F01 + F02: Einstufung durchklicken, ersten Satz loggen, Power steigt. Start mit -uiTesting (In-Memory-Store).
final class CoreLoopUITests: XCTestCase {
    func testOnboardingThenFirstLog() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-skipPaywall"]
        app.launch()

        app.buttons["Einstufung starten"].tap()
        // 12 Fragen: jeweils "Nichts davon"
        for _ in 0..<12 { app.buttons["Nichts davon / weiß nicht"].firstMatch.tap() }
        app.buttons["Weiter"].tap()

        XCTAssertTrue(app.staticTexts["Grad 1"].waitForExistence(timeout: 5))
        let logButton = app.buttons.matching(NSPredicate(format: "label ENDSWITH ' loggen'")).firstMatch
        XCTAssertTrue(logButton.waitForExistence(timeout: 3))
        logButton.tap()                                        // Tap 1
        app.buttons["Speichern"].tap()                         // Tap 2  (Ziel: <= 4 Taps)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Power +'")).firstMatch
            .waitForExistence(timeout: 3))
    }
}
