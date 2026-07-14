import Foundation
import Testing
@testable import LiveReloadCore

@Test func runtimeContractsDoNotEnterThePersistedConfigurationEnvelope() throws {
    let project = try ProjectConfiguration(
        displayName: "Runtime-free persistence",
        folderReference: FolderReference(
            bookmarkData: Data("bookmark".utf8),
            normalizedIdentity: "/tmp/runtime-free",
            displayLabel: "runtime-free"
        )
    )
    let envelope = try ConfigurationEnvelope(
        projects: [project],
        createdAt: Date(timeIntervalSince1970: 1),
        updatedAt: Date(timeIntervalSince1970: 2)
    )
    let data = try JSONEncoder().encode(envelope)
    let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    let projects = try #require(object["projects"] as? [[String: Any]])
    let persistedProject = try #require(projects.first)

    #expect(object["schemaVersion"] as? Int == ConfigurationEnvelope.currentSchemaVersion)
    #expect(persistedProject["monitoringRuntimeState"] == nil)
    #expect(persistedProject["serverState"] == nil)
    #expect(persistedProject["browserSessions"] == nil)
    #expect(persistedProject["changeBatch"] == nil)
}

@Test func currentPhaseOneConfigurationStillDecodesWithRuntimeContractsPresentInTheModule() throws {
    let data = Data(
        #"{"schemaVersion":1,"projects":[],"createdAt":"2026-07-13T00:00:00Z","updatedAt":"2026-07-13T00:00:00Z"}"#.utf8
    )
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    let decoded = try decoder.decode(ConfigurationEnvelope.self, from: data)

    #expect(decoded.schemaVersion == 1)
    #expect(decoded.projects.isEmpty)
}
