import XCTest

final class LiveReloadAppUITests: XCTestCase {
    private var fixtureRoot: URL!
    private var storeURL: URL!
    private var selectedFolderURL: URL!

    override func setUpWithError() throws {
        continueAfterFailure = false
        fixtureRoot = FileManager.default.temporaryDirectory
            .appending(path: "LiveReloadUITests-\(UUID().uuidString)", directoryHint: .isDirectory)
        storeURL = fixtureRoot.appending(path: "projects.json")
        selectedFolderURL = fixtureRoot.appending(path: "Disposable Project", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: selectedFolderURL, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: fixtureRoot)
    }

    @MainActor
    private func application(_ arguments: [String], folderURL: URL? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments
        app.launchEnvironment["LIVERELOAD_UI_TEST_STORE"] = storeURL.path
        app.launchEnvironment["LIVERELOAD_UI_TEST_FOLDER"] = (folderURL ?? selectedFolderURL).path
        return app
    }

    @MainActor
    private func identified(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    @MainActor
    func testLoadingEmptyAddRelaunchRenameEnableAndFolderPreservingRemoval() throws {
        let app = application(["--ui-testing-empty", "--ui-testing-delay-load"])
        app.launch()
        XCTAssertTrue(identified("state.loading", in: app).waitForExistence(timeout: 2))
        XCTAssertTrue(identified("state.empty", in: app).waitForExistence(timeout: 5))

        app.buttons["empty.add"].click()
        var name = app.textFields["project.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertEqual(name.value as? String, "Disposable Project")

        XCTAssertTrue(FileManager.default.fileExists(atPath: storeURL.path))
        app.terminate()
        app.launchArguments = ["--ui-testing-empty"]
        app.launch()
        name = app.textFields["project.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5), "Persisted project should restore after relaunch")

        name.click()
        name.typeKey("a", modifierFlags: .command)
        name.typeText("Renamed Fixture\n")
        XCTAssertEqual(name.value as? String, "Renamed Fixture")

        let enabled = identified("project.enabled", in: app)
        XCTAssertTrue(enabled.exists)
        enabled.click()

        app.buttons["project.remove"].click()
        let removalSheet = app.sheets.firstMatch
        XCTAssertTrue(removalSheet.waitForExistence(timeout: 2))
        XCTAssertTrue(
            removalSheet.staticTexts.matching(NSPredicate(format: "value CONTAINS 'remain unchanged'")).firstMatch.exists
        )
        let confirm = removalSheet.buttons["Remove Configuration"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 2))
        confirm.click()
        XCTAssertTrue(identified("state.empty", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(FileManager.default.fileExists(atPath: selectedFolderURL.path))
    }

    @MainActor
    func testMissingFolderRepairsWithoutDiscardingIdentityOrSettings() {
        let replacement = fixtureRoot.appending(path: "Replacement Folder", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: replacement, withIntermediateDirectories: true)
        let app = application(["--ui-testing-repair"], folderURL: replacement)
        app.launch()

        let name = app.textFields["project.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertEqual(name.value as? String, "Fixture Project")
        let repair = app.buttons["project.repair"]
        XCTAssertTrue(repair.exists)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "value CONTAINS 'preserved'")).firstMatch.exists)
        repair.click()
        XCTAssertFalse(repair.waitForExistence(timeout: 1))
        XCTAssertEqual(name.value as? String, "Fixture Project")
    }

    @MainActor
    func testCorruptStoreRecoveryExplainsPreservationAndNextAction() throws {
        try FileManager.default.createDirectory(at: fixtureRoot, withIntermediateDirectories: true)
        let app = application(["--ui-testing-empty", "--ui-testing-corrupt"])
        app.launch()

        let alert = app.sheets.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        XCTAssertTrue(alert.staticTexts.matching(NSPredicate(format: "value CONTAINS 'preserved'")).firstMatch.exists)
        XCTAssertTrue(alert.buttons["OK"].exists)
    }

    @MainActor
    func testLongLabelsAndReducedMotionPreserveActions() {
        let app = application(["--ui-testing-long-label"])
        app.launchEnvironment["NSWorkspaceAccessibilityDisplayShouldReduceMotion"] = "1"
        app.launch()

        XCTAssertTrue(app.textFields["project.name"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["project.remove"].exists)
        XCTAssertTrue(identified("project.enabled", in: app).exists)
    }

    @MainActor
    func testFutureStoreShowsWriteProtectedRecoveryState() throws {
        try FileManager.default.createDirectory(at: fixtureRoot, withIntermediateDirectories: true)
        try Data(#"{"schemaVersion":999,"futureShape":true}"#.utf8).write(to: storeURL)
        let app = application(["--ui-testing-empty"])

        app.launch()

        XCTAssertTrue(identified("state.configuration.newer", in: app).waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["empty.add"].exists)
        XCTAssertFalse(app.buttons["project.add"].exists)
    }
}
