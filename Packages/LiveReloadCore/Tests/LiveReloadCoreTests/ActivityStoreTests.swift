import Foundation
import Testing
@testable import LiveReloadCore

@Test func activityStoreRetainsNewestEvents() async {
    let store = ActivityStore()
    for index in 0...200 {
        await store.append(ActivityEvent(category: .app, severity: .info, summary: "event \(index)"))
    }

    let snapshot = await store.snapshot()
    #expect(snapshot.count == 200)
    #expect(snapshot.first?.summary == "event 1")
    #expect(snapshot.last?.summary == "event 200")
}

@Test func activityRedactsPathsAndSecretsBeforeStorage() async {
    let rawSecret = "token=hunter2"
    let event = ActivityEvent(
        category: .folderAccess,
        severity: .error,
        summary: "Failed /Users/example/Private/project \(rawSecret) " + String(repeating: "x", count: 700)
    )
    let store = ActivityStore()
    await store.append(event)
    let snapshot = await store.snapshot()

    #expect(snapshot[0].summary.contains("[REDACTED_PATH]"))
    #expect(snapshot[0].summary.contains("token=[REDACTED]"))
    #expect(!snapshot[0].summary.contains("hunter2"))
    #expect(snapshot[0].summary.count <= ActivityRedactor.maximumSummaryLength)
}

@Test func activityRedactsArbitraryAbsolutePathsFileURLsAndSpaces() {
    let summary = ActivityRedactor.redact(
        "Open /Applications/Live Reload/My Project.app, read file:///opt/private data/config.json; then /custom/root/file"
    )

    #expect(!summary.contains("Applications"))
    #expect(!summary.contains("Live Reload"))
    #expect(!summary.contains("file:///"))
    #expect(!summary.contains("/opt"))
    #expect(!summary.contains("/custom"))
    #expect(summary.components(separatedBy: "[REDACTED_PATH]").count == 4)
}

@Test func decodedActivityEventsReapplyRedaction() throws {
    let event = ActivityEvent(category: .storage, severity: .error, summary: "safe")
    let encoded = try JSONEncoder().encode(event)
    var object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    object["summary"] = "Read /Applications/Private Folder/data token=hunter2"

    let decoded = try JSONDecoder().decode(
        ActivityEvent.self,
        from: JSONSerialization.data(withJSONObject: object)
    )

    #expect(decoded.summary.contains("[REDACTED_PATH]"))
    #expect(!decoded.summary.contains("Private Folder"))
    #expect(!decoded.summary.contains("hunter2"))
}

@Test func activityCategoryAndSeverityContractsAreFixed() {
    #expect(ActivityCategory.allCases.count == 7)
    #expect(ActivitySeverity.allCases.count == 4)
}
