import UIKit
import XCTest

/// Uses the app the way a person does: first launch, typing a day, asking an AI, sending the
/// prompt to Grok and pasting the answer back. Every step saves a screenshot, written to
/// $JOURNEY_DIR when it's set (CI publishes them) and attached to the test result.
final class UserJourneyTests: XCTestCase {
    private var app: XCUIApplication!
    private var step = 0

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication()
    }

    // MARK: Journeys

    func test1_NewUserTypesTheirDay() {
        launch("-fresh")
        snap("first-launch")

        // Onboarding: pick nothing and continue.
        if app.buttons["Continue"].waitForExistence(timeout: 5) {
            app.buttons["Continue"].tap()
        } else if app.buttons["Skip"].exists {
            app.buttons["Skip"].tap()
        }
        XCTAssertTrue(app.buttons["Type a list"].waitForExistence(timeout: 5), "Today should show the ways to log")
        snap("today-empty")

        app.buttons["Type a list"].tap()
        let editor = app.textViews.firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText("""
        Breakfast 3 eggs and toast
        8am coffee with milk
        creatine 5g
        magnesium glycinate 400mg
        lunch chicken salad
        2pm walk 30 min
        felt tired 3/5
        water 2 glasses
        """)
        snap("type-a-list-preview")

        let add = app.navigationBars.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Add'")).firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 3))
        XCTAssertNotEqual(add.label, "Add", "The list should turn into entries before adding")
        add.tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] 'chicken salad'")).firstMatch.waitForExistence(timeout: 5),
                      "Typed lines should appear on Today")
        snap("today-after-list")

        app.swipeUp()
        snap("today-scrolled")

        // Speak and Scan open their own screens; look and back out.
        app.swipeDown()
        addUIInterruptionMonitor(withDescription: "Permissions") { alert in
            for label in ["Allow", "OK", "Allow While Using App"] where alert.buttons[label].exists {
                alert.buttons[label].tap()
                return true
            }
            return false
        }
        if app.buttons["Speak"].exists {
            app.buttons["Speak"].tap()
            sleep(2)
            app.tap()
            snap("speak")
            dismissSheet()
        }
        if app.buttons["Scan label"].exists {
            app.buttons["Scan label"].tap()
            sleep(1)
            snap("scan-label")
            dismissSheet()
        }
    }

    func test2_AskAIAndSendToGrok() {
        launch("-demo")
        app.tabBars.buttons["Ask AI"].tap()
        XCTAssertTrue(app.buttons["Send to AI"].waitForExistence(timeout: 5))
        snap("ask-ai")

        app.buttons["Send to AI"].tap()
        if app.buttons["I Understand"].waitForExistence(timeout: 3) {
            snap("disclaimer")
            app.buttons["I Understand"].tap()
        }
        XCTAssertTrue(app.navigationBars["Send to AI"].waitForExistence(timeout: 5))
        snap("send-sheet")

        let grok = app.buttons.containing(NSPredicate(format: "label CONTAINS 'Grok'")).matching(NSPredicate(format: "label CONTAINS 'opens'")).firstMatch
        if !grok.isHittable { app.swipeUp() }
        XCTAssertTrue(grok.waitForExistence(timeout: 3), "Grok should be listed")
        UIPasteboard.general.string = ""
        grok.tap()

        // Whatever opens (Safari here, the Grok app on a phone that has it), the prompt
        // must be on the clipboard ready to paste.
        let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
        if safari.wait(for: .runningForeground, timeout: 10) {
            sleep(8)
            snap("grok-opened")
        }
        let clip = UIPasteboard.general.string ?? ""
        XCTAssertTrue(clip.contains("Log"), "The prompt should be copied when Grok opens, got: \(clip.prefix(80))")
        XCTAssertGreaterThan(clip.count, 500, "The whole prompt should be copied")

        app.activate()
        XCTAssertTrue(app.staticTexts["Your prompt is copied"].waitForExistence(timeout: 5),
                      "Coming back should show how to paste")
        snap("send-sheet-after-grok")
    }

    func test3_PasteGrokAnswerBack() {
        launch("-demo")
        app.tabBars.buttons["Ask AI"].tap()
        XCTAssertTrue(app.buttons["Send to AI"].waitForExistence(timeout: 5))

        // How Grok, ChatGPT and Claude actually format the numbers block.
        UIPasteboard.general.string = Self.grokStyleAnswer
        let paste = app.buttons["Paste"].firstMatch
        for _ in 0..<6 where !paste.isHittable { app.swipeUp() }
        XCTAssertTrue(paste.isHittable, "Step 4 should have a Paste button")
        paste.tap()
        let saved = app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH 'Saved estimates'")).firstMatch
        XCTAssertTrue(saved.waitForExistence(timeout: 5), "A Grok-style answer should save its daily numbers")
        snap("answer-saved")

        app.tabBars.buttons["History"].tap()
        let trends = app.buttons.containing(NSPredicate(format: "label BEGINSWITH 'Trends'")).firstMatch
        XCTAssertTrue(trends.waitForExistence(timeout: 5))
        snap("history")
        trends.tap()
        sleep(1)
        snap("trends")
        app.swipeUp()
        snap("trends-scrolled")
    }

    func test4_SettingsAndProfile() {
        launch("-demo")
        let settings = app.buttons["Settings"].firstMatch
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        settings.tap()
        sleep(1)
        snap("settings")
        app.swipeUp()
        snap("settings-scrolled")
        dismissSheet()

        app.tabBars.buttons["Ask AI"].tap()
        let profile = app.buttons.containing(NSPredicate(format: "label BEGINSWITH 'My profile'")).firstMatch
        for _ in 0..<4 where !profile.isHittable { app.swipeUp() }
        if profile.isHittable {
            profile.tap()
            sleep(1)
            snap("profile")
        }
    }

    // MARK: Helpers

    static let grokStyleAnswer = """
    Here's a breakdown of your week:

    **Highlights**
    - Protein was low on Tuesday (~70 g).
    - Fiber looks good overall.

    ```
    FUELPRINT-DAILY
    date,calories,protein_g,fiber_g
    \(dateString(-2)),"1,850",112,28
    \(dateString(-1)),2100,135,31
    ```

    *Not medical advice.*
    """

    private static func dateString(_ offset: Int) -> String {
        let date = Calendar.current.date(byAdding: .day, value: offset, to: Date())!
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func launch(_ argument: String) {
        app.launchArguments = [argument, "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
    }

    private func dismissSheet() {
        for label in ["Cancel", "Done", "Close"] where app.navigationBars.buttons[label].exists {
            app.navigationBars.buttons[label].firstMatch.tap()
            return
        }
        app.swipeDown(velocity: .fast)
    }

    private func snap(_ name: String) {
        step += 1
        let shot = XCUIScreen.main.screenshot()
        let label = "\(name)-\(step)"
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = label
        attachment.lifetime = .keepAlways
        add(attachment)

        guard let dir = ProcessInfo.processInfo.environment["JOURNEY_DIR"], !dir.isEmpty else { return }
        // "-[UserJourneyTests test2_AskAIAndSendToGrok]" → "test2_AskAIAndSendToGrok"
        let test = self.name.components(separatedBy: " ").last?.trimmingCharacters(in: CharacterSet(charactersIn: "]")) ?? "test"
        let file = URL(fileURLWithPath: dir).appendingPathComponent(String(format: "%@-%02d-%@.png", test, step, name))
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try? shot.pngRepresentation.write(to: file)
    }
}
