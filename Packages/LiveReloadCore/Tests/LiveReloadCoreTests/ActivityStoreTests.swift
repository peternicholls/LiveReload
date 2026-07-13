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

@Test func activityRedactsAuthorizationHeaders() {
    let summary = ActivityRedactor.redact(
        "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.payload.signature, "
            + "authorization: basic dXNlcjpwYXNzd29yZA=="
    )

    #expect(!summary.localizedCaseInsensitiveContains("bearer"))
    #expect(!summary.localizedCaseInsensitiveContains("basic"))
    #expect(!summary.contains("eyJhbGciOiJIUzI1NiJ9"))
    #expect(!summary.contains("dXNlcjpwYXNzd29yZA=="))
    #expect(summary.components(separatedBy: "[REDACTED]").count == 3)
}

@Test func activityRedactsCredentialsEmbeddedInURLs() {
    let summary = ActivityRedactor.redact(
        "Connect https://build-user:s3cr3t@example.com/reload?access_token=query-secret; "
            + "fetch https://deployment-token@private.example/status"
    )

    #expect(summary.contains("https://[REDACTED]@example.com"))
    #expect(summary.contains("access_token=[REDACTED]"))
    #expect(!summary.contains("build-user"))
    #expect(!summary.contains("s3cr3t"))
    #expect(!summary.contains("query-secret"))
    #expect(!summary.contains("deployment-token"))
}

@Test func activityRedactsCommonAccessKeyNames() {
    let summary = ActivityRedactor.redact(
        "AWS_ACCESS_KEY_ID=AKIAEXAMPLE AWS_SECRET_ACCESS_KEY: topsecret "
            + "client_secret=oauth-secret auth-token=session-secret"
    )

    #expect(summary.contains("AWS_ACCESS_KEY_ID=[REDACTED]"))
    #expect(summary.contains("AWS_SECRET_ACCESS_KEY=[REDACTED]"))
    #expect(summary.contains("client_secret=[REDACTED]"))
    #expect(summary.contains("auth-token=[REDACTED]"))
    #expect(!summary.contains("AKIAEXAMPLE"))
    #expect(!summary.contains("topsecret"))
    #expect(!summary.contains("oauth-secret"))
    #expect(!summary.contains("session-secret"))
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
