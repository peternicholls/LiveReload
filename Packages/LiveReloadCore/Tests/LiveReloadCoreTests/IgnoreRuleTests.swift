import Foundation
import Testing
@testable import LiveReloadCore

@Suite("Reload-loop exclusion policy")
struct IgnoreRuleTests {
    @Test("built-in repository, dependency, output, and temporary paths are excluded", arguments: [
        ".git/HEAD",
        ".svn/entries",
        "node_modules/pkg/index.js",
        ".build/debug/App",
        "build/output.js",
        "dist/site.css",
        "Sources/.index.html.swp",
        "notes.tmp",
        "file~",
    ])
    func builtInExclusions(path: String) throws {
        let policy = try ExclusionPolicy()
        #expect(policy.evaluate(relativePath: path) == .excluded(.builtIn))
    }

    @Test("hidden source paths remain eligible")
    func hiddenSourceFiles() throws {
        let policy = try ExclusionPolicy()
        #expect(policy.evaluate(relativePath: ".env.example") == .included(".env.example"))
        #expect(policy.evaluate(relativePath: ".well-known/site") == .included(".well-known/site"))
    }

    @Test("user globs support rooted segments, recursive matches, question marks, and directories")
    func userRules() throws {
        let policy = try ExclusionPolicy(userPatterns: [
            "generated/",
            "assets/**/*.map",
            "cache/file?.json",
        ])

        #expect(policy.evaluate(relativePath: "generated/client/app.js") == .excluded(.userRule(0)))
        #expect(policy.evaluate(relativePath: "assets/map/app.map") == .excluded(.userRule(1)))
        #expect(policy.evaluate(relativePath: "assets/a/b/app.map") == .excluded(.userRule(1)))
        #expect(policy.evaluate(relativePath: "cache/file1.json") == .excluded(.userRule(2)))
        #expect(policy.evaluate(relativePath: "cache/file10.json") == .included("cache/file10.json"))
    }

    @Test("normalization is stable and rejects paths outside the project root")
    func pathNormalization() throws {
        let root = URL(fileURLWithPath: "/tmp/ReloadRoot", isDirectory: true)
        #expect(try RelativeProjectPath(candidateURL: root.appending(path: "café//index.html"), rootURL: root).value == "café/index.html".precomposedStringWithCanonicalMapping)
        #expect(throws: RelativeProjectPathError.self) {
            try RelativeProjectPath(candidateURL: URL(fileURLWithPath: "/tmp/Other/private.html"), rootURL: root)
        }
        #expect(throws: RelativeProjectPathError.self) {
            try RelativeProjectPath("../outside.html")
        }
    }

    @Test("symlink escape is rejected")
    func symlinkEscape() throws {
        let temporary = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let root = temporary.appending(path: "root", directoryHint: .isDirectory)
        let outside = temporary.appending(path: "outside", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: root.appending(path: "escape"), withDestinationURL: outside)
        defer { try? FileManager.default.removeItem(at: temporary) }

        #expect(throws: RelativeProjectPathError.self) {
            try RelativeProjectPath(candidateURL: root.appending(path: "escape/private.html"), rootURL: root)
        }
    }

    @Test("negation, escaping, absolute paths, and malformed recursive tokens are rejected", arguments: [
        "!keep.js", "foo\\bar", "/absolute", "foo/***/bar", "",
    ])
    func invalidPatterns(pattern: String) {
        #expect(throws: ExclusionPolicyError.self) {
            try ExclusionPolicy(userPatterns: [pattern])
        }
    }
}
