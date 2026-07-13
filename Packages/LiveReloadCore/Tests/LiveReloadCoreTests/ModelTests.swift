import Foundation
import Testing
@testable import LiveReloadCore

private func reference(_ identity: String = "/tmp/project") throws -> FolderReference {
    try FolderReference(
        bookmarkData: Data("bookmark".utf8),
        normalizedIdentity: identity,
        displayLabel: identity
    )
}

@Test func coreLoadsWithoutUIFrameworks() {
    #expect(LiveReloadCoreVersion.schemaVersion == ConfigurationEnvelope.currentSchemaVersion)
}

@Test func configurationRoundTripsWithStableIdentity() throws {
    let id = UUID()
    let project = try ProjectConfiguration(id: id, displayName: " Example ", folderReference: reference())
    let envelope = try ConfigurationEnvelope(projects: [project])
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    let decoded = try decoder.decode(ConfigurationEnvelope.self, from: encoder.encode(envelope))

    #expect(decoded.projects.first?.id == id)
    #expect(decoded.projects.first?.displayName == "Example")
    #expect(decoded.projects.first?.monitoringState == .disabled)
    #expect(decoded.projects.first?.buildConfiguration == BuildConfiguration())
}

@Test func invalidAndFutureEnvelopesAreRejected() throws {
    #expect(throws: ConfigurationError.invalidSchemaVersion(0)) {
        try ConfigurationEnvelope(schemaVersion: 0)
    }
    #expect(throws: ConfigurationError.unsupportedFutureVersion(2)) {
        try ConfigurationEnvelope(schemaVersion: 2)
    }

    let first = try ProjectConfiguration(displayName: "One", folderReference: reference())
    let second = try ProjectConfiguration(displayName: "Two", folderReference: reference())
    #expect(throws: ConfigurationError.duplicateFolderIdentity) {
        try ConfigurationEnvelope(projects: [first, second])
    }
}

@Test func modelInvariantsRejectUnsafeValues() throws {
    #expect(throws: ModelValidationError.emptyDisplayName) {
        try ProjectConfiguration(displayName: "   ", folderReference: reference())
    }
    #expect(throws: ModelValidationError.displayNameTooLong) {
        try ProjectConfiguration(displayName: String(repeating: "x", count: 121), folderReference: reference())
    }
    #expect(throws: ModelValidationError.invalidIgnoreRule) {
        try IgnoreRule(pattern: "")
    }
    #expect(throws: ModelValidationError.invalidBookmarkData) {
        try FolderReference(bookmarkData: Data(), normalizedIdentity: "/tmp/project", displayLabel: "project")
    }
}

@Test func decodingReappliesAllNestedModelInvariants() throws {
    let invalidFolder = #"{"bookmarkData":"","normalizedIdentity":"","displayLabel":"/Users/private/secret"}"#
    #expect(throws: (any Error).self) {
        _ = try JSONDecoder().decode(FolderReference.self, from: Data(invalidFolder.utf8))
    }

    let invalidRule = #"{"pattern":"   "}"#
    #expect(throws: (any Error).self) {
        _ = try JSONDecoder().decode(IgnoreRule.self, from: Data(invalidRule.utf8))
    }

    let oversizedBuild = #"{"placeholderName":"\#(String(repeating: "x", count: 81))"}"#
    #expect(throws: (any Error).self) {
        _ = try JSONDecoder().decode(BuildConfiguration.self, from: Data(oversizedBuild.utf8))
    }

    let validProject = try ProjectConfiguration(displayName: "Project", folderReference: reference())
    let encoder = JSONEncoder()
    var object = try #require(JSONSerialization.jsonObject(with: encoder.encode(validProject)) as? [String: Any])
    object["displayName"] = "   "
    let invalidProject = try JSONSerialization.data(withJSONObject: object)
    #expect(throws: (any Error).self) {
        _ = try JSONDecoder().decode(ProjectConfiguration.self, from: invalidProject)
    }
}
