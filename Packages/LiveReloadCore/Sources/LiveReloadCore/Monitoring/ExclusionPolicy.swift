import Foundation

public enum RelativeProjectPathError: Error, Equatable, Sendable {
    case empty
    case absolute
    case outsideRoot
    case tooLong
}

public struct RelativeProjectPath: Equatable, Hashable, Sendable {
    public let value: String

    public init(_ rawValue: String) throws {
        guard !rawValue.isEmpty else { throw RelativeProjectPathError.empty }
        guard !rawValue.hasPrefix("/") else { throw RelativeProjectPathError.absolute }
        let components = rawValue
            .replacingOccurrences(of: "\\", with: "/")
            .split(separator: "/", omittingEmptySubsequences: true)
        guard !components.isEmpty else { throw RelativeProjectPathError.empty }
        guard !components.contains("..") else { throw RelativeProjectPathError.outsideRoot }
        let normalized = components
            .filter { $0 != "." }
            .joined(separator: "/")
            .precomposedStringWithCanonicalMapping
        guard !normalized.isEmpty else { throw RelativeProjectPathError.empty }
        guard normalized.utf8.count <= ProtocolLimits.maximumRelativePathBytes else {
            throw RelativeProjectPathError.tooLong
        }
        value = normalized
    }

    public init(candidateURL: URL, rootURL: URL) throws {
        let root = rootURL.standardizedFileURL.resolvingSymlinksInPath().path
        let candidate = Self.resolvingExistingPathComponents(candidateURL).path
        let prefix = root.hasSuffix("/") ? root : root + "/"
        guard candidate.hasPrefix(prefix) else { throw RelativeProjectPathError.outsideRoot }
        try self.init(String(candidate.dropFirst(prefix.count)))
    }

    private static func resolvingExistingPathComponents(_ url: URL) -> URL {
        var existing = url.standardizedFileURL
        var missingComponents: [String] = []
        while !FileManager.default.fileExists(atPath: existing.path), existing.path != "/" {
            missingComponents.insert(existing.lastPathComponent, at: 0)
            existing.deleteLastPathComponent()
        }
        return missingComponents.reduce(existing.resolvingSymlinksInPath()) { partial, component in
            partial.appending(path: component)
        }
    }
}

public enum ExclusionPolicyError: Error, Equatable, Sendable {
    case invalidPattern
}

public enum ExclusionReason: Equatable, Sendable {
    case builtIn
    case userRule(Int)
}

public enum ExclusionResult: Equatable, Sendable {
    case included(String)
    case excluded(ExclusionReason)
    case invalidPath
}

public struct ExclusionPolicy: Sendable {
    private static let excludedDirectoryNames: Set<String> = [
        ".git", ".hg", ".svn", "node_modules", "bower_components", "vendor",
        ".build", "build", "dist", "DerivedData", ".swiftpm",
    ]

    private let userRegexes: [String]

    public init(userPatterns: [String] = []) throws {
        userRegexes = try userPatterns.map(Self.regex(for:))
    }

    public init(ignoreRules: [IgnoreRule]) throws {
        try self.init(userPatterns: ignoreRules.map(\.pattern))
    }

    public func evaluate(relativePath rawPath: String) -> ExclusionResult {
        guard let path = try? RelativeProjectPath(rawPath).value else { return .invalidPath }
        let components = path.split(separator: "/").map(String.init)
        let basename = components.last ?? path
        if components.contains(where: Self.excludedDirectoryNames.contains) ||
            basename == ".DS_Store" ||
            basename.hasSuffix("~") ||
            basename.hasSuffix(".tmp") ||
            basename.hasSuffix(".swp") ||
            basename.hasSuffix(".swo") {
            return .excluded(.builtIn)
        }
        for (index, regex) in userRegexes.enumerated() {
            if path.range(of: regex, options: .regularExpression) != nil {
                return .excluded(.userRule(index))
            }
        }
        return .included(path)
    }

    private static func regex(for rawPattern: String) throws -> String {
        let pattern = rawPattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pattern.isEmpty,
              pattern.utf8.count <= IgnoreRule.maximumPatternLength,
              !pattern.hasPrefix("/"),
              !pattern.hasPrefix("!"),
              !pattern.contains("\\"),
              !pattern.contains("***") else {
            throw ExclusionPolicyError.invalidPattern
        }
        let directoryRule = pattern.hasSuffix("/")
        let body = directoryRule ? String(pattern.dropLast()) : pattern
        guard !body.isEmpty else { throw ExclusionPolicyError.invalidPattern }

        var result = "^"
        var cursor = body.startIndex
        while cursor < body.endIndex {
            let character = body[cursor]
            if character == "*" {
                let next = body.index(after: cursor)
                if next < body.endIndex, body[next] == "*" {
                    let afterPair = body.index(after: next)
                    if afterPair < body.endIndex, body[afterPair] == "/" {
                        result += "(?:.*/)?"
                        cursor = body.index(after: afterPair)
                    } else {
                        result += ".*"
                        cursor = afterPair
                    }
                    continue
                }
                result += "[^/]*"
            } else if character == "?" {
                result += "[^/]"
            } else {
                result += NSRegularExpression.escapedPattern(for: String(character))
            }
            cursor = body.index(after: cursor)
        }
        result += directoryRule ? "(?:/.*)?$" : "$"
        do {
            _ = try NSRegularExpression(pattern: result)
        } catch {
            throw ExclusionPolicyError.invalidPattern
        }
        return result
    }
}
