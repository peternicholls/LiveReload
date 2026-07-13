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

    func testReloadLoopUIScenarioContractIsComplete() {
        XCTAssertEqual(Set(reloadLoopUIScenarios.map(\.stateIdentifier)), [
            "monitoring.stopped",
            "monitoring.starting",
            "monitoring.watching",
            "monitoring.recovering",
            "monitoring.failed",
            "server.starting",
            "server.listening",
            "server.port-conflict",
            "server.no-clients",
            "server.clients",
        ])
        XCTAssertEqual(reloadLoopUIScenarios.map(\.launchArgument).count, Set(reloadLoopUIScenarios.map(\.launchArgument)).count)
        XCTAssertTrue(reloadLoopUIScenarios.contains { $0.actionIdentifier == "reload.manual" })
        XCTAssertTrue(reloadLoopUIScenarios.contains { $0.expectedValue == "2 compatible browsers connected" })
    }

    @MainActor
    func testReloadLoopStatesActionsAndClientCountAreExpectedFailuresUntilUIComposition() {
        for scenario in reloadLoopUIScenarios {
            XCTContext.runActivity(named: scenario.name) { _ in
                let app = application(["--ui-testing-seeded", scenario.launchArgument])
                app.launch()

                // T015/T029 will implement these deterministic launch fixtures and
                // replace each expected failure with state text, keyboard action,
                // client-count, and preservation assertions. The identifiers come
                // directly from contracts/ui-states.md; action identifiers are the
                // reserved UI-test seam for the corresponding safe next action.
                XCTExpectFailure("Deferred to T015/T029: \(scenario.name) UI fixture is not composed yet") {
                    let state = identified(scenario.stateIdentifier, in: app)
                    XCTAssertTrue(state.waitForExistence(timeout: 0.5), scenario.safeMeaning)
                    if let expectedValue = scenario.expectedValue {
                        XCTAssertEqual(state.value as? String, expectedValue)
                    }
                    if let actionIdentifier = scenario.actionIdentifier {
                        let action = identified(actionIdentifier, in: app)
                        XCTAssertTrue(action.exists)
                        XCTAssertTrue(action.isEnabled)
                    }
                }

                app.terminate()
            }
        }
    }
}

private struct ReloadLoopUIScenario {
    let name: String
    let launchArgument: String
    let stateIdentifier: String
    let actionIdentifier: String?
    let expectedValue: String?
    let safeMeaning: String
}

private let reloadLoopUIScenarios: [ReloadLoopUIScenario] = [
    .init(name: "Stopped monitoring", launchArgument: "--ui-testing-monitoring-stopped", stateIdentifier: "monitoring.stopped", actionIdentifier: "monitoring.start", expectedValue: nil, safeMeaning: "The project is not observing files and offers Start Monitoring"),
    .init(name: "Starting monitoring", launchArgument: "--ui-testing-monitoring-starting", stateIdentifier: "monitoring.starting", actionIdentifier: "monitoring.stop", expectedValue: nil, safeMeaning: "LiveReload is preparing access and observation"),
    .init(name: "Watching", launchArgument: "--ui-testing-monitoring-watching", stateIdentifier: "monitoring.watching", actionIdentifier: "monitoring.stop", expectedValue: nil, safeMeaning: "Supported changes can trigger reloads"),
    .init(name: "Recovering", launchArgument: "--ui-testing-monitoring-recovering", stateIdentifier: "monitoring.recovering", actionIdentifier: "monitoring.retry", expectedValue: nil, safeMeaning: "Configuration is preserved and recovery is actionable"),
    .init(name: "Failed monitoring", launchArgument: "--ui-testing-monitoring-failed", stateIdentifier: "monitoring.failed", actionIdentifier: "monitoring.retry", expectedValue: nil, safeMeaning: "A safe failure reason and retry action are visible"),
    .init(name: "Server starting", launchArgument: "--ui-testing-server-starting", stateIdentifier: "server.starting", actionIdentifier: nil, expectedValue: nil, safeMeaning: "The local browser endpoint is preparing"),
    .init(name: "Server ready without clients", launchArgument: "--ui-testing-server-listening", stateIdentifier: "server.listening", actionIdentifier: nil, expectedValue: nil, safeMeaning: "The loopback endpoint is ready"),
    .init(name: "Port conflict", launchArgument: "--ui-testing-server-port-conflict", stateIdentifier: "server.port-conflict", actionIdentifier: "server.retry", expectedValue: nil, safeMeaning: "Monitoring remains intact and retry is actionable"),
    .init(name: "No compatible clients", launchArgument: "--ui-testing-server-no-clients", stateIdentifier: "server.no-clients", actionIdentifier: nil, expectedValue: "0 compatible browsers connected", safeMeaning: "The user is prompted to connect a compatible browser"),
    .init(name: "Connected clients and manual reload", launchArgument: "--ui-testing-server-two-clients", stateIdentifier: "server.clients", actionIdentifier: "reload.manual", expectedValue: "2 compatible browsers connected", safeMeaning: "The client count and manual reload action are visible"),
]
