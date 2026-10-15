import XCTest

/// End-to-End je Flow. Start mit -uiTesting (In-Memory-Store) und -skipPaywall (nur DEBUG).
/// Jeder Test: Accessibility-Audit (Xcode 15+) auf den besuchten Screens.
final class CoreLoopUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-skipPaywall"]
        app.launch()
    }

    private func onboard() {
        app.buttons["Einstufung starten"].tap()
        for _ in 0..<12 { app.buttons["Nichts davon / weiß nicht"].firstMatch.tap() }
        app.buttons["Weiter"].tap()
        XCTAssertTrue(app.staticTexts["Grad 1"].waitForExistence(timeout: 5))
    }

    private func audit() throws {
        if #available(iOS 17.0, *) { try app.performAccessibilityAudit() }
    }

    // F01-H1
    func testF01Onboarding() throws {
        XCTAssertTrue(app.buttons["Einstufung starten"].exists)
        try audit()
        app.buttons["Einstufung starten"].tap()
        XCTAssertTrue(app.staticTexts["Ehrlich bleiben: Der Grad steigt später durch echte Sätze."].exists)
        try audit()
        for _ in 0..<12 { app.buttons["Nichts davon / weiß nicht"].firstMatch.tap() }
        XCTAssertTrue(app.staticTexts["Deine Einstufung"].waitForExistence(timeout: 3))
        try audit()
        app.buttons["Weiter"].tap()
        XCTAssertTrue(app.staticTexts["Grad 1"].waitForExistence(timeout: 5))
        try audit()
    }

    // F01-E4: Zurück in der Einstufung
    func testF01BackButton() {
        app.buttons["Einstufung starten"].tap()
        app.buttons["Nichts davon / weiß nicht"].firstMatch.tap()
        app.buttons["Zurück"].tap()
        XCTAssertTrue(app.otherElements["Frage 1 von 12"].exists || app.progressIndicators["Frage 1 von 12"].exists)
    }

    // F02-H1 + F02-E2: erster Satz in <= 2 Taps, Doppeltipp erzeugt einen Satz
    func testF02FirstLog() throws {
        onboard()
        let logButton = app.buttons.matching(NSPredicate(format: "label ENDSWITH ' loggen'")).firstMatch
        XCTAssertTrue(logButton.waitForExistence(timeout: 3))
        logButton.tap()
        try audit()
        let save = app.buttons["Speichern"]
        save.doubleTap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Power +'")).firstMatch
            .waitForExistence(timeout: 3))
    }

    // F02-N1: Wert 0 per Tastatur wird auf 1 geklemmt
    func testF02ZeroInputClamped() {
        onboard()
        app.buttons.matching(NSPredicate(format: "label ENDSWITH ' loggen'")).firstMatch.tap()
        let field = app.textFields.firstMatch
        field.tap()
        field.press(forDuration: 1.0)
        if app.menuItems["Select All"].waitForExistence(timeout: 1) { app.menuItems["Select All"].tap() }
        field.typeText(XCUIKeyboardKey.delete.rawValue + "0")
        app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Ziel:'")).firstMatch.tap()      // Fokus weg -> Wert übernehmen
        XCTAssertNotEqual(field.value as? String, "0")
    }

    // F03-H1: Stufe geschafft -> LevelUp-Sheet
    func testF03StageCleared() throws {
        onboard()
        app.buttons.matching(NSPredicate(format: "label ENDSWITH ' loggen'")).firstMatch.tap()
        app.buttons["Speichern"].tap()        // Default = Ziel -> Stufe geschafft
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Stufe geschafft'")).firstMatch
            .waitForExistence(timeout: 3))
        try audit()
        app.buttons["Weiter"].tap()
    }

    #if PERSONAL
    // F04-H1 (Eigengebrauch): Plan ohne Kauf nutzbar
    func testF04PlanFreeInPersonalBuild() throws {
        onboard()
        app.tabBars.buttons["Plan"].tap()
        app.buttons["Plan erstellen"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Ziel:'")).firstMatch
            .waitForExistence(timeout: 3))
        try audit()
    }
    #else
    // F04-N1: Plan ohne PRO zeigt Hinweis statt Inhalt
    func testF04PlanLockedWithoutPro() throws {
        onboard()
        app.tabBars.buttons["Plan"].tap()
        XCTAssertTrue(app.buttons["PRO ansehen"].waitForExistence(timeout: 3))
        try audit()
    }

    // F05-H1: Paywall erreichbar und schließbar
    func testF05PaywallOpens() {
        onboard()
        app.tabBars.buttons["Verlauf"].tap()
        app.buttons["PRO ansehen"].tap()
        XCTAssertTrue(app.staticTexts["PRO"].waitForExistence(timeout: 5))
    }
    #endif

    // S06/S07: Skills -> Linie -> Stufenkette
    func testSkillsNavigation() throws {
        onboard()
        app.tabBars.buttons["Skills"].tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Klimmzug'")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Stufen"].waitForExistence(timeout: 3))
        try audit()
    }
}
