import Foundation
import AppKit
@preconcurrency import CoreServices
import UniformTypeIdentifiers

// MARK: - Found File Model

public struct MorphFoundFile: Identifiable, Equatable, Hashable, Sendable {
    public enum MatchKind: Int, Comparable, Sendable {
        case pathMatch = 1
        case substringName = 2
        case wordMatch = 3
        case prefixName = 4
        case exactName = 5
        case directPath = 6

        public static func < (lhs: MatchKind, rhs: MatchKind) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    public let id: String
    public let url: URL
    public let path: String
    public let name: String
    public let displayPath: String
    public let parentFolderName: String
    public let pathExtension: String
    public let fileSizeBytes: Int64?
    public let modifiedDate: Date?
    public let lastUsedDate: Date?
    public let contentTypeIdentifier: String?
    public let isDirectory: Bool
    public let isApplication: Bool
    public let matchKind: MatchKind
    public let relevanceScore: Double

    public init(
        url: URL,
        name: String? = nil,
        displayPath: String? = nil,
        fileSizeBytes: Int64? = nil,
        modifiedDate: Date? = nil,
        lastUsedDate: Date? = nil,
        contentTypeIdentifier: String? = nil,
        isDirectory: Bool = false,
        isApplication: Bool? = nil,
        matchKind: MatchKind = .prefixName,
        relevanceScore: Double = 0
    ) {
        let canonical = SpotlightSmartFinderProvider.normalizeFileURL(url)
        let resolvedPath = canonical.path
        let resolvedName = (name?.isEmpty == false ? name! : canonical.lastPathComponent)
        let ext = canonical.pathExtension
        let appFlag = isApplication ?? (ext.lowercased() == "app")
        let parentURL = canonical.deletingLastPathComponent()
        let shortenedParent = displayPath ?? SpotlightSmartFinderProvider.shortenHomePath(parentURL.path)

        self.id = resolvedPath
        self.url = canonical
        self.path = resolvedPath
        self.name = resolvedName
        self.displayPath = shortenedParent
        self.parentFolderName = parentURL.lastPathComponent
        self.pathExtension = ext
        self.fileSizeBytes = fileSizeBytes
        self.modifiedDate = modifiedDate
        self.lastUsedDate = lastUsedDate
        self.contentTypeIdentifier = contentTypeIdentifier
        self.isDirectory = isDirectory
        self.isApplication = appFlag
        self.matchKind = matchKind
        self.relevanceScore = relevanceScore
    }

    public var badgeExtension: String {
        if isApplication { return "APP" }
        if isDirectory { return "FOLDER" }
        let ext = pathExtension.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if ext.count > 6 {
            return String(ext.prefix(6))
        }
        return ext
    }

    public var formattedSize: String? {
        guard !isDirectory, !isApplication, let bytes = fileSizeBytes, bytes >= 0 else {
            return nil
        }
        return SmartFinderFormatters.shared.formatByteCount(bytes)
    }

    public var formattedModifiedDate: String? {
        guard let date = lastUsedDate ?? modifiedDate else { return nil }
        return SmartFinderFormatters.shared.formatModifiedDate(date)
    }

    public var metadataSummary: String {
        var parts: [String] = [displayPath]
        if let size = formattedSize {
            parts.append(size)
        }
        if let dateStr = formattedModifiedDate {
            parts.append(dateStr)
        }
        return parts.joined(separator: "  ·  ")
    }

    public var fallbackSymbolName: String {
        if isApplication { return "app.dashed" }
        if isDirectory { return "folder.fill" }
        switch pathExtension.lowercased() {
        case "pdf":
            return "doc.richtext.fill"
        case "png", "jpg", "jpeg", "heic", "webp", "gif", "svg", "tiff":
            return "photo.fill"
        case "mp4", "mov", "mkv", "avi", "m4v":
            return "film.fill"
        case "mp3", "wav", "m4a", "flac", "aac":
            return "waveform"
        case "zip", "tar", "gz", "dmg", "pkg", "7z", "rar":
            return "archivebox.fill"
        case "swift", "py", "js", "ts", "tsx", "jsx", "rs", "go", "c", "cpp", "h", "java", "kt", "json", "yaml", "yml", "toml", "sh", "zsh":
            return "chevron.left.forwardslash.chevron.right"
        case "md", "txt", "rtf", "doc", "docx", "pages":
            return "doc.text.fill"
        case "xls", "xlsx", "csv", "numbers":
            return "tablecells.fill"
        case "ppt", "pptx", "key":
            return "rectangle.stack.fill"
        default:
            return "doc.fill"
        }
    }
}

private final class SmartFinderFormatters: @unchecked Sendable {
    static let shared = SmartFinderFormatters()

    private let lock = NSLock()
    private let byteCountFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter
    }()

    private let relativeDateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    private let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    func formatByteCount(_ bytes: Int64) -> String {
        lock.lock()
        defer { lock.unlock() }
        return byteCountFormatter.string(fromByteCount: bytes)
    }

    func formatModifiedDate(_ date: Date) -> String {
        let now = Date()
        let interval = now.timeIntervalSince(date)
        if interval >= 0 && interval < 60 {
            return "Just now"
        }
        lock.lock()
        defer { lock.unlock() }
        if interval >= 0 && interval < 7 * 86400 {
            return relativeDateFormatter.localizedString(for: date, relativeTo: now)
        }
        return shortDateFormatter.string(from: date)
    }
}

// MARK: - Search Provider Protocol

public protocol MorphFileSearchProviding: Sendable {
    func search(
        query: String,
        limit: Int,
        onPartialResults: (@Sendable ([MorphFoundFile]) -> Void)?
    ) async throws -> [MorphFoundFile]
}

public extension MorphFileSearchProviding {
    func search(query: String, limit: Int = 20) async throws -> [MorphFoundFile] {
        try await search(query: query, limit: limit, onPartialResults: nil)
    }
}

// MARK: - Query Parsing & Spotlight Escaping

public enum SmartFinderQueryParser {
    public struct ParsedQuery: Equatable, Sendable {
        public let rawQuery: String
        public let searchTermsText: String
        public let tokens: [String]
        public let isExplicitFileSearch: Bool
        public let isPathQuery: Bool
        public let shouldTriggerLiveSearch: Bool
    }

    private static let explicitPrefixes = [
        "find file ",
        "find files ",
        "search file ",
        "search files ",
        "locate file ",
        "open file ",
        "reveal file ",
        "find ",
        "search ",
        "locate "
    ]

    private static let conversationalQuestionPrefixes = [
        "what ",
        "what's ",
        "whats ",
        "who ",
        "who's ",
        "why ",
        "how ",
        "when ",
        "where ",
        "where's ",
        "wheres ",
        "explain ",
        "summarize ",
        "translate ",
        "calculate ",
        "define ",
        "tell me ",
        "can you ",
        "could you "
    ]

    public static func parse(_ raw: String) -> ParsedQuery {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return ParsedQuery(
                rawQuery: "",
                searchTermsText: "",
                tokens: [],
                isExplicitFileSearch: false,
                isPathQuery: false,
                shouldTriggerLiveSearch: false
            )
        }

        let isPath = trimmed.hasPrefix("/") || trimmed == "~" || trimmed.hasPrefix("~/")
        let lower = trimmed.lowercased()

        var stripped = trimmed
        var explicitVerb = isPath
        if !isPath {
            for prefix in explicitPrefixes where lower.hasPrefix(prefix) {
                let candidate = String(trimmed.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                if !candidate.isEmpty {
                    stripped = candidate
                    explicitVerb = true
                    break
                }
            }
        }

        let tokens = stripped
            .components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let isQuestion = !isPath && !explicitVerb && (
            trimmed.contains("?") ||
            conversationalQuestionPrefixes.contains(where: { lower.hasPrefix($0) })
        )

        let meetsLength = isPath || stripped.count >= 2
        let shouldTrigger = meetsLength && !isQuestion && (!tokens.isEmpty || isPath)

        return ParsedQuery(
            rawQuery: trimmed,
            searchTermsText: stripped,
            tokens: tokens,
            isExplicitFileSearch: explicitVerb,
            isPathQuery: isPath,
            shouldTriggerLiveSearch: shouldTrigger
        )
    }

    /// Escapes a user token for safe inclusion inside a double-quoted Spotlight `MDQuery` literal.
    public static func escapeSpotlightLiteral(_ raw: String) -> String {
        var result = ""
        result.reserveCapacity(raw.count + 4)
        for scalar in raw.unicodeScalars {
            if CharacterSet.controlCharacters.contains(scalar) {
                continue
            }
            switch scalar {
            case "\\":
                result.append("\\\\")
            case "\"":
                result.append("\\\"")
            case "*":
                result.append("\\*")
            case "?":
                result.append("\\?")
            default:
                result.unicodeScalars.append(scalar)
            }
        }
        return result
    }

    /// Builds a safe computer-wide Spotlight `MDQuery` expression for prefix/word or substring matching.
    public static func buildSpotlightPredicate(
        tokens: [String],
        substringMode: Bool,
        includeSystemAndLibrary: Bool = false
    ) -> String? {
        let escapedTokens = tokens
            .map { escapeSpotlightLiteral($0) }
            .filter { !$0.isEmpty }
        guard !escapedTokens.isEmpty else { return nil }

        let termClauses: [String] = escapedTokens.map { token in
            if substringMode {
                return "(kMDItemDisplayName == \"*\(token)*\"cd || kMDItemFSName == \"*\(token)*\"cd)"
            } else {
                return "(kMDItemDisplayName == \"\(token)*\"cdw || kMDItemFSName == \"\(token)*\"cdw)"
            }
        }

        var fullClauses = termClauses
        if !includeSystemAndLibrary {
            fullClauses.append("kMDItemPath != \"/System/Library/*\"")
            fullClauses.append("kMDItemPath != \"/Library/*\"")
        }
        return fullClauses.joined(separator: " && ")
    }
}

// MARK: - Computer-Wide Spotlight + Shallow Fast-Cache Provider

public final class SpotlightSmartFinderProvider: MorphFileSearchProviding, @unchecked Sendable {
    public static let shared = SpotlightSmartFinderProvider()

    private struct ShallowEntry: Sendable {
        let url: URL
        let name: String
        let lowerName: String
        let lowerStem: String
        let isDirectory: Bool
        let isApplication: Bool
        let fileSizeBytes: Int64?
        let modifiedDate: Date?
    }

    private let cacheLock = NSLock()
    private var shallowEntries: [ShallowEntry] = []
    private var lastShallowRefresh: Date = .distantPast
    private var isRefreshingShallow = false
    private let shallowTTL: TimeInterval = 20.0

    public init() {}

    public func search(
        query: String,
        limit: Int = 20,
        onPartialResults: (@Sendable ([MorphFoundFile]) -> Void)? = nil
    ) async throws -> [MorphFoundFile] {
        let parsed = SmartFinderQueryParser.parse(query)
        guard parsed.shouldTriggerLiveSearch else { return [] }
        let effectiveLimit = max(1, min(limit, 50))

        // 0. Direct path navigation (/... or ~/...)
        if parsed.isPathQuery {
            let pathMatches = searchDirectPath(parsed.rawQuery, limit: effectiveLimit)
            if !pathMatches.isEmpty {
                onPartialResults?(pathMatches)
            }
            return pathMatches
        }

        let overallDeadline = Date().addingTimeInterval(2.4)
        let explicitSystemQuery = isExplicitSystemOrLibraryQuery(parsed.searchTermsText)
        let aggregator = SearchResultAggregator(limit: effectiveLimit)

        // 1. Instant shallow index for Applications + top-level Desktop/Downloads/Documents (<10ms)
        ensureShallowCacheFresh(blockingIfEmpty: true)
        let instantMatches = searchShallowCache(parsed: parsed, limit: effectiveLimit)
        if !instantMatches.isEmpty {
            let ranked = aggregator.mergeAndRank(instantMatches)
            onPartialResults?(ranked)
        }

        try Task.checkCancellation()

        // 2A. Computer-wide Spotlight indexed prefix/word search (kMDQueryScopeComputer)
        if let prefixPredicate = SmartFinderQueryParser.buildSpotlightPredicate(
            tokens: parsed.tokens,
            substringMode: false,
            includeSystemAndLibrary: explicitSystemQuery
        ) {
            let stageAMatches = await executeComputerWideSpotlightQuery(
                predicateString: prefixPredicate,
                parsed: parsed,
                explicitSystemQuery: explicitSystemQuery,
                targetCleanCount: max(effectiveLimit * 2, 40),
                timeout: 1.05,
                onBatch: { batch in
                    let ranked = aggregator.mergeAndRank(batch)
                    if !ranked.isEmpty {
                        onPartialResults?(ranked)
                    }
                }
            )
            _ = aggregator.mergeAndRank(stageAMatches)
        }

        try Task.checkCancellation()

        // 2B. Computer-wide Spotlight substring fallback for mid-word/camelCase matches (e.g. "Controller")
        let remainingBudget = overallDeadline.timeIntervalSinceNow
        let canRunSubstring = parsed.searchTermsText.count >= 3 &&
            aggregator.count < min(effectiveLimit, 8) &&
            remainingBudget > 0.25
        if canRunSubstring,
           let substringPredicate = SmartFinderQueryParser.buildSpotlightPredicate(
               tokens: parsed.tokens,
               substringMode: true,
               includeSystemAndLibrary: explicitSystemQuery
           ) {
            let stageBMatches = await executeComputerWideSpotlightQuery(
                predicateString: substringPredicate,
                parsed: parsed,
                explicitSystemQuery: explicitSystemQuery,
                targetCleanCount: max(effectiveLimit * 2, 35),
                timeout: min(1.15, remainingBudget),
                onBatch: { batch in
                    let ranked = aggregator.mergeAndRank(batch)
                    if !ranked.isEmpty {
                        onPartialResults?(ranked)
                    }
                }
            )
            _ = aggregator.mergeAndRank(stageBMatches)
        }

        try Task.checkCancellation()
        return aggregator.mergeAndRank([])
    }

    private final class SearchResultAggregator: @unchecked Sendable {
        private let lock = NSLock()
        private let limit: Int
        private var itemsByPath: [String: MorphFoundFile] = [:]

        init(limit: Int) {
            self.limit = limit
        }

        var count: Int {
            lock.lock()
            defer { lock.unlock() }
            return itemsByPath.count
        }

        func mergeAndRank(_ incoming: [MorphFoundFile]) -> [MorphFoundFile] {
            lock.lock()
            for item in incoming {
                if let existing = itemsByPath[item.id] {
                    if item.relevanceScore > existing.relevanceScore {
                        itemsByPath[item.id] = item
                    }
                } else {
                    itemsByPath[item.id] = item
                }
            }
            let snapshot = Array(itemsByPath.values)
            lock.unlock()

            return snapshot
                .sorted { lhs, rhs in
                    if lhs.relevanceScore != rhs.relevanceScore {
                        return lhs.relevanceScore > rhs.relevanceScore
                    }
                    if lhs.name.count != rhs.name.count {
                        return lhs.name.count < rhs.name.count
                    }
                    return lhs.path.localizedStandardCompare(rhs.path) == .orderedAscending
                }
                .prefix(limit)
                .map { $0 }
        }
    }

    // MARK: - Path Normalization & Filtering

    public static func fastStripDataVolumePrefix(_ rawPath: String) -> String {
        let dataVolumePrefix = "/System/Volumes/Data/"
        if rawPath.hasPrefix(dataVolumePrefix) {
            return "/" + String(rawPath.dropFirst(dataVolumePrefix.count))
        }
        return rawPath
    }

    public static func normalizeFileURL(_ url: URL) -> URL {
        let standardized = url.standardizedFileURL
        let rawPath = standardized.path
        let stripped = fastStripDataVolumePrefix(rawPath)
        if stripped != rawPath && FileManager.default.fileExists(atPath: stripped) {
            return URL(fileURLWithPath: stripped).standardizedFileURL
        }
        return standardized
    }

    public static func shortenHomePath(_ path: String) -> String {
        let home = NSHomeDirectory()
        if path == home {
            return "~"
        }
        if path.hasPrefix(home + "/") {
            return "~" + String(path.dropFirst(home.count))
        }
        return path
    }

    func isExplicitSystemOrLibraryQuery(_ query: String) -> Bool {
        let lower = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if lower == ".git" { return true }
        let explicitMarkers = [
            "/system", "/library", "~/library", "library/", "/caches",
            "/.git", ".git/", "node_modules", "deriveddata", "group containers"
        ]
        return explicitMarkers.contains(where: { lower.contains($0) })
    }

    public static func isNoisePath(_ path: String, explicitlyRequested: Bool = false) -> Bool {
        if explicitlyRequested { return false }
        let lower = fastStripDataVolumePrefix(path).lowercased()

        let blockedPrefixes = [
            "/system/library/",
            "/library/",
            "/system/volumes/preboot/",
            "/system/volumes/vm/",
            "/system/volumes/update/",
            "/usr/share/",
            "/private/var/",
            "/private/tmp/",
            "/var/",
            "/tmp/",
            "/cores/"
        ]
        if blockedPrefixes.contains(where: { lower.hasPrefix($0) }) {
            return true
        }

        let blockedSegments = [
            "/.git/",
            "/node_modules/",
            "/.build/",
            "/deriveddata/",
            "/.trash/",
            "/__pycache__/",
            "/.swiftpm/",
            "/pods/",
            "/.venv/"
        ]
        if blockedSegments.contains(where: { lower.contains($0) }) {
            return true
        }

        let blockedLeafFolders = [
            "/.git",
            "/node_modules",
            "/.build",
            "/deriveddata",
            "/.trash",
            "/__pycache__",
            "/.swiftpm",
            "/.venv"
        ]
        if blockedLeafFolders.contains(where: { lower.hasSuffix($0) }) {
            return true
        }

        // Exclude internal ~/Library app caches & containers while keeping iCloud Drive & CloudStorage
        let homeLibrary = (NSHomeDirectory() + "/library/").lowercased()
        if lower.hasPrefix(homeLibrary) {
            let allowedSubtrees = [
                homeLibrary + "mobile documents/",
                homeLibrary + "cloudstorage/"
            ]
            if !allowedSubtrees.contains(where: { lower.hasPrefix($0) }) {
                return true
            }
        }

        return false
    }

    // MARK: - Direct Path Search (/... or ~/...)

    private func searchDirectPath(_ rawPath: String, limit: Int) -> [MorphFoundFile] {
        let expanded = (rawPath as NSString).expandingTildeInPath
        let fm = FileManager.default
        let explicitSystemQuery = isExplicitSystemOrLibraryQuery(rawPath)
        var results: [MorphFoundFile] = []

        var isDir: ObjCBool = false
        if fm.fileExists(atPath: expanded, isDirectory: &isDir) {
            let exactURL = Self.normalizeFileURL(URL(fileURLWithPath: expanded))
            if let exactItem = makeFoundFile(from: exactURL, parsed: SmartFinderQueryParser.parse(rawPath), forcedMatchKind: .directPath) {
                results.append(exactItem)
            }
            if isDir.boolValue,
               let rawChildren = try? fm.contentsOfDirectory(
                at: exactURL,
                includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey, .contentTypeKey],
                options: [.skipsHiddenFiles]
               ) {
                let sortedChildren = rawChildren
                    .filter { !Self.isNoisePath($0.path, explicitlyRequested: explicitSystemQuery) }
                    .sorted {
                        $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
                    }
                for child in sortedChildren.prefix(max(0, limit - results.count)) {
                    if let item = makeFoundFile(from: child, parsed: SmartFinderQueryParser.parse(rawPath), forcedMatchKind: .pathMatch) {
                        results.append(item)
                    }
                }
            }
            return Array(results.prefix(limit))
        }

        // Partial path prefix (e.g. ~/Downloads/cs2)
        let partialURL = URL(fileURLWithPath: expanded)
        let parentURL = partialURL.deletingLastPathComponent()
        let prefix = partialURL.lastPathComponent.lowercased()
        guard !prefix.isEmpty,
              let siblings = try? fm.contentsOfDirectory(
                at: parentURL,
                includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey, .contentTypeKey],
                options: [.skipsHiddenFiles]
              ) else {
            return []
        }

        let parsed = SmartFinderQueryParser.parse(prefix)
        let matchingSiblings = siblings
            .filter {
                $0.lastPathComponent.lowercased().hasPrefix(prefix) &&
                !Self.isNoisePath($0.path, explicitlyRequested: explicitSystemQuery)
            }
            .sorted {
                $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
            }
        for sibling in matchingSiblings.prefix(limit) {
            if let item = makeFoundFile(from: sibling, parsed: parsed, forcedMatchKind: .prefixName) {
                results.append(item)
            }
        }
        return results
    }

    // MARK: - Shallow Instant Cache

    private func ensureShallowCacheFresh(blockingIfEmpty: Bool) {
        cacheLock.lock()
        let isEmpty = shallowEntries.isEmpty
        let isStale = Date().timeIntervalSince(lastShallowRefresh) > shallowTTL
        let alreadyRefreshing = isRefreshingShallow
        if (isEmpty || isStale) && !alreadyRefreshing {
            isRefreshingShallow = true
        } else {
            cacheLock.unlock()
            return
        }
        cacheLock.unlock()

        if isEmpty && blockingIfEmpty {
            rebuildShallowCache()
        } else {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.rebuildShallowCache()
            }
        }
    }

    private func rebuildShallowCache() {
        let fm = FileManager.default
        let home = NSHomeDirectory()
        let roots: [(path: String, recurseOneLevel: Bool)] = [
            ("/Applications", true),
            ("/System/Applications", true),
            (home + "/Applications", true),
            (home + "/Desktop", false),
            (home + "/Downloads", false),
            (home + "/Documents", false)
        ]

        let keys: [URLResourceKey] = [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey]
        var built: [ShallowEntry] = []
        built.reserveCapacity(400)

        func collect(from dirURL: URL, depth: Int) {
            guard let items = try? fm.contentsOfDirectory(
                at: dirURL,
                includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles]
            ) else { return }

            for itemURL in items {
                let normalized = Self.normalizeFileURL(itemURL)
                let vals = try? normalized.resourceValues(forKeys: Set(keys))
                let isDir = vals?.isDirectory ?? false
                let isApp = normalized.pathExtension.lowercased() == "app"
                let name = normalized.lastPathComponent
                let stem = normalized.deletingPathExtension().lastPathComponent
                let size = vals?.fileSize.map { Int64($0) }
                let mod = vals?.contentModificationDate

                built.append(
                    ShallowEntry(
                        url: normalized,
                        name: name,
                        lowerName: name.lowercased(),
                        lowerStem: stem.lowercased(),
                        isDirectory: isDir && !isApp,
                        isApplication: isApp,
                        fileSizeBytes: size,
                        modifiedDate: mod
                    )
                )

                if depth > 0 && isDir && !isApp {
                    collect(from: normalized, depth: depth - 1)
                }
            }
        }

        for root in roots {
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: root.path, isDirectory: &isDir), isDir.boolValue {
                collect(from: URL(fileURLWithPath: root.path), depth: root.recurseOneLevel ? 1 : 0)
            }
        }

        cacheLock.lock()
        self.shallowEntries = built
        self.lastShallowRefresh = Date()
        self.isRefreshingShallow = false
        cacheLock.unlock()
    }

    private func searchShallowCache(parsed: SmartFinderQueryParser.ParsedQuery, limit: Int) -> [MorphFoundFile] {
        cacheLock.lock()
        let snapshot = shallowEntries
        cacheLock.unlock()

        guard !snapshot.isEmpty, !parsed.tokens.isEmpty else { return [] }
        let lowerTokens = parsed.tokens.map { $0.lowercased() }

        var matches: [MorphFoundFile] = []
        for entry in snapshot {
            let allMatch = lowerTokens.allSatisfy { token in
                entry.lowerName.contains(token)
            }
            guard allMatch else { continue }

            let matchKind = classifyMatchKind(name: entry.name, path: entry.url.path, parsed: parsed)
            let score = computeRelevanceScore(
                name: entry.name,
                path: entry.url.path,
                isApplication: entry.isApplication,
                isDirectory: entry.isDirectory,
                modifiedDate: entry.modifiedDate,
                lastUsedDate: nil,
                matchKind: matchKind,
                parsed: parsed
            )
            matches.append(
                MorphFoundFile(
                    url: entry.url,
                    name: entry.name,
                    fileSizeBytes: entry.fileSizeBytes,
                    modifiedDate: entry.modifiedDate,
                    isDirectory: entry.isDirectory,
                    isApplication: entry.isApplication,
                    matchKind: matchKind,
                    relevanceScore: score
                )
            )
        }

        return matches
            .sorted { $0.relevanceScore > $1.relevanceScore }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: - Computer-Wide Async Spotlight Query (MDQuery)

    private final class ActiveMDQuerySession: @unchecked Sendable {
        let mdQuery: MDQuery
        let queue: DispatchQueue
        private let lock = NSLock()
        private var hasResumed = false
        private var hasStartedQuery = false
        private var processedRawIndex = 0
        private var collectedClean: [MorphFoundFile] = []
        private var progressObserver: NSObjectProtocol?
        private var finishObserver: NSObjectProtocol?
        private var continuation: CheckedContinuation<[MorphFoundFile], Never>?

        init(mdQuery: MDQuery, queue: DispatchQueue) {
            self.mdQuery = mdQuery
            self.queue = queue
        }

        var isCancelledOrFinished: Bool {
            lock.lock()
            defer { lock.unlock() }
            return hasResumed
        }

        @discardableResult
        func installObserversIfActive(
            onProgress: @escaping @Sendable () -> Void,
            onFinish: @escaping @Sendable () -> Void
        ) -> Bool {
            let center = NotificationCenter.default
            let pObs = center.addObserver(
                forName: NSNotification.Name(kMDQueryProgressNotification as String),
                object: mdQuery,
                queue: nil
            ) { _ in
                onProgress()
            }
            let fObs = center.addObserver(
                forName: NSNotification.Name(kMDQueryDidFinishNotification as String),
                object: mdQuery,
                queue: nil
            ) { _ in
                onFinish()
            }
            lock.lock()
            if hasResumed {
                lock.unlock()
                center.removeObserver(pObs)
                center.removeObserver(fObs)
                return false
            }
            self.progressObserver = pObs
            self.finishObserver = fObs
            lock.unlock()
            return true
        }

        func markQueryStartedIfActive() -> Bool {
            lock.lock()
            defer { lock.unlock() }
            if hasResumed {
                return false
            }
            hasStartedQuery = true
            return true
        }

        func beginDrainWindow(targetCleanCount: Int) -> (isActive: Bool, startIndex: Int, remainingNeeded: Int) {
            lock.lock()
            defer { lock.unlock() }
            if hasResumed {
                return (false, 0, 0)
            }
            return (true, processedRawIndex, max(0, targetCleanCount - collectedClean.count))
        }

        func commitBatch(_ items: [MorphFoundFile], nextRawIndex: Int, targetCleanCount: Int) -> (shouldEmit: Bool, reachedEnough: Bool) {
            lock.lock()
            defer { lock.unlock() }
            processedRawIndex = max(processedRawIndex, nextRawIndex)
            if hasResumed {
                return (false, true)
            }
            if !items.isEmpty {
                collectedClean.append(contentsOf: items)
            }
            return (!items.isEmpty, collectedClean.count >= targetCleanCount)
        }

        func installContinuation(_ continuation: CheckedContinuation<[MorphFoundFile], Never>) {
            lock.lock()
            let alreadyFinished = hasResumed
            if !alreadyFinished {
                self.continuation = continuation
            }
            lock.unlock()
            if alreadyFinished {
                continuation.resume(returning: [])
            }
        }

        func finishAndResumeIfNeeded() {
            lock.lock()
            if hasResumed {
                lock.unlock()
                return
            }
            hasResumed = true
            let shouldStop = hasStartedQuery
            hasStartedQuery = false
            let finalResults = collectedClean
            let cont = continuation
            let pObs = progressObserver
            let fObs = finishObserver
            continuation = nil
            progressObserver = nil
            finishObserver = nil
            lock.unlock()

            if let pObs { NotificationCenter.default.removeObserver(pObs) }
            if let fObs { NotificationCenter.default.removeObserver(fObs) }
            if shouldStop {
                let q = mdQuery
                queue.async {
                    MDQueryStop(q)
                }
            }
            cont?.resume(returning: finalResults)
        }
    }

    private func executeComputerWideSpotlightQuery(
        predicateString: String,
        parsed: SmartFinderQueryParser.ParsedQuery,
        explicitSystemQuery: Bool,
        targetCleanCount: Int,
        timeout: TimeInterval,
        onBatch: @escaping @Sendable ([MorphFoundFile]) -> Void
    ) async -> [MorphFoundFile] {
        guard !Task.isCancelled,
              let mdQuery = MDQueryCreate(kCFAllocatorDefault, predicateString as CFString, nil, nil) else {
            return []
        }

        MDQuerySetSearchScope(mdQuery, [kMDQueryScopeComputer as String] as CFArray, 0)
        MDQuerySetMaxCount(mdQuery, 450)

        let queryQueue = DispatchQueue(label: "com.morph.smartfinder.mdquery.\(UUID().uuidString)", qos: .userInitiated)
        MDQuerySetDispatchQueue(mdQuery, queryQueue)

        let session = ActiveMDQuerySession(mdQuery: mdQuery, queue: queryQueue)
        let deadline = Date().addingTimeInterval(timeout)

        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                session.installContinuation(continuation)
                if session.isCancelledOrFinished {
                    return
                }

                let drainNewResults: @Sendable () -> Void = {
                    if session.isCancelledOrFinished || Date() >= deadline {
                        session.finishAndResumeIfNeeded()
                        return
                    }
                    let window = session.beginDrainWindow(targetCleanCount: targetCleanCount)
                    guard window.isActive else { return }
                    if window.remainingNeeded <= 0 {
                        session.finishAndResumeIfNeeded()
                        return
                    }

                    let totalCount = MDQueryGetResultCount(session.mdQuery)
                    guard totalCount > window.startIndex else { return }

                    var newCleanItems: [MorphFoundFile] = []
                    newCleanItems.reserveCapacity(min(window.remainingNeeded, 40))
                    var lastProcessedIndex = window.startIndex

                    for idx in window.startIndex..<totalCount {
                        if session.isCancelledOrFinished || Date() >= deadline {
                            break
                        }
                        lastProcessedIndex = idx + 1
                        guard let rawPtr = MDQueryGetResultAtIndex(session.mdQuery, idx) else { continue }
                        let mdItem = Unmanaged<MDItem>.fromOpaque(rawPtr).takeUnretainedValue()
                        guard let rawPath = MDItemCopyAttribute(mdItem, kMDItemPath) as? String, !rawPath.isEmpty else {
                            continue
                        }
                        // Fast noise filter before hitting FileManager/normalization or reading 7 extra MDItem attributes
                        let fastStripped = Self.fastStripDataVolumePrefix(rawPath)
                        if Self.isNoisePath(fastStripped, explicitlyRequested: explicitSystemQuery) {
                            continue
                        }
                        let normalizedURL = Self.normalizeFileURL(URL(fileURLWithPath: rawPath))
                        if Self.isNoisePath(normalizedURL.path, explicitlyRequested: explicitSystemQuery) {
                            continue
                        }

                        if let found = self.makeFoundFileFromMDItem(mdItem, url: normalizedURL, parsed: parsed) {
                            newCleanItems.append(found)
                            if newCleanItems.count >= window.remainingNeeded {
                                break
                            }
                        }
                    }

                    let commit = session.commitBatch(
                        newCleanItems,
                        nextRawIndex: lastProcessedIndex,
                        targetCleanCount: targetCleanCount
                    )

                    if commit.shouldEmit && !session.isCancelledOrFinished {
                        onBatch(newCleanItems)
                    }
                    if commit.reachedEnough || session.isCancelledOrFinished || Date() >= deadline {
                        session.finishAndResumeIfNeeded()
                    }
                }

                guard session.installObserversIfActive(
                    onProgress: {
                        drainNewResults()
                    },
                    onFinish: {
                        drainNewResults()
                        session.finishAndResumeIfNeeded()
                    }
                ) else {
                    return
                }

                // Independent hard-deadline watchdog off the serial queryQueue so Spotlight stalls cannot hang it
                DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + timeout) {
                    session.finishAndResumeIfNeeded()
                }

                queryQueue.async {
                    guard session.markQueryStartedIfActive() else {
                        session.finishAndResumeIfNeeded()
                        return
                    }
                    let started = MDQueryExecute(session.mdQuery, CFOptionFlags(kMDQueryWantsUpdates.rawValue))
                    if !started {
                        session.finishAndResumeIfNeeded()
                    }
                }
            }
        } onCancel: {
            session.finishAndResumeIfNeeded()
        }
    }

    // MARK: - Item Construction & Ranking

    private func makeFoundFileFromMDItem(
        _ mdItem: MDItem,
        url: URL,
        parsed: SmartFinderQueryParser.ParsedQuery
    ) -> MorphFoundFile? {
        let fsName = MDItemCopyAttribute(mdItem, kMDItemFSName) as? String
        let displayName = MDItemCopyAttribute(mdItem, kMDItemDisplayName) as? String
        let chosenName = (fsName?.isEmpty == false ? fsName : displayName) ?? url.lastPathComponent

        let sizeNumber = MDItemCopyAttribute(mdItem, kMDItemFSSize) as? NSNumber
        let modDate = MDItemCopyAttribute(mdItem, kMDItemContentModificationDate) as? Date
        let usedDate = MDItemCopyAttribute(mdItem, kMDItemLastUsedDate) as? Date
        let contentType = MDItemCopyAttribute(mdItem, kMDItemContentType) as? String
        let contentTree = MDItemCopyAttribute(mdItem, kMDItemContentTypeTree) as? [String]

        let isApp = url.pathExtension.lowercased() == "app" || contentType == UTType.applicationBundle.identifier
        let isFolder = !isApp && (
            contentType == UTType.folder.identifier ||
            (contentTree?.contains(UTType.folder.identifier) == true && contentType != UTType.package.identifier)
        )

        let matchKind = classifyMatchKind(name: chosenName, path: url.path, parsed: parsed)
        let score = computeRelevanceScore(
            name: chosenName,
            path: url.path,
            isApplication: isApp,
            isDirectory: isFolder,
            modifiedDate: modDate,
            lastUsedDate: usedDate,
            matchKind: matchKind,
            parsed: parsed
        )

        return MorphFoundFile(
            url: url,
            name: chosenName,
            fileSizeBytes: sizeNumber?.int64Value,
            modifiedDate: modDate,
            lastUsedDate: usedDate,
            contentTypeIdentifier: contentType,
            isDirectory: isFolder,
            isApplication: isApp,
            matchKind: matchKind,
            relevanceScore: score
        )
    }

    private func makeFoundFile(
        from rawURL: URL,
        parsed: SmartFinderQueryParser.ParsedQuery,
        forcedMatchKind: MorphFoundFile.MatchKind? = nil
    ) -> MorphFoundFile? {
        let url = Self.normalizeFileURL(rawURL)
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey, .contentTypeKey]
        let vals = try? url.resourceValues(forKeys: keys)
        let isApp = url.pathExtension.lowercased() == "app"
        let isDir = !isApp && (vals?.isDirectory ?? false)
        let name = url.lastPathComponent
        let matchKind = forcedMatchKind ?? classifyMatchKind(name: name, path: url.path, parsed: parsed)
        let score = computeRelevanceScore(
            name: name,
            path: url.path,
            isApplication: isApp,
            isDirectory: isDir,
            modifiedDate: vals?.contentModificationDate,
            lastUsedDate: nil,
            matchKind: matchKind,
            parsed: parsed
        )
        return MorphFoundFile(
            url: url,
            name: name,
            fileSizeBytes: vals?.fileSize.map { Int64($0) },
            modifiedDate: vals?.contentModificationDate,
            contentTypeIdentifier: vals?.contentType?.identifier,
            isDirectory: isDir,
            isApplication: isApp,
            matchKind: matchKind,
            relevanceScore: score
        )
    }

    public func classifyMatchKind(
        name: String,
        path: String,
        parsed: SmartFinderQueryParser.ParsedQuery
    ) -> MorphFoundFile.MatchKind {
        let lowerQuery = parsed.searchTermsText.lowercased()
        let lowerName = name.lowercased()
        let lowerStem = (name as NSString).deletingPathExtension.lowercased()

        if lowerName == lowerQuery || lowerStem == lowerQuery {
            return .exactName
        }
        if lowerName.hasPrefix(lowerQuery) || lowerStem.hasPrefix(lowerQuery) {
            return .prefixName
        }

        let nameWords = lowerName
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        if parsed.tokens.allSatisfy({ token in
            let lt = token.lowercased()
            return nameWords.contains(where: { $0.hasPrefix(lt) })
        }) {
            return .wordMatch
        }

        if parsed.tokens.allSatisfy({ lowerName.contains($0.lowercased()) }) {
            return .substringName
        }
        return .pathMatch
    }

    public func computeRelevanceScore(
        name: String,
        path: String,
        isApplication: Bool,
        isDirectory: Bool,
        modifiedDate: Date?,
        lastUsedDate: Date?,
        matchKind: MorphFoundFile.MatchKind,
        parsed: SmartFinderQueryParser.ParsedQuery
    ) -> Double {
        var score: Double = 0

        switch matchKind {
        case .directPath:
            score += 1200
        case .exactName:
            score += 1000
        case .prefixName:
            score += 680
        case .wordMatch:
            score += 480
        case .substringName:
            score += 310
        case .pathMatch:
            score += 120
        }

        // Boost prime user-facing locations
        let home = NSHomeDirectory()
        if isApplication && (path.hasPrefix("/Applications/") || path.hasPrefix("/System/Applications/") || path.hasPrefix(home + "/Applications/")) {
            score += 200
        } else if path.hasPrefix(home + "/Desktop/") || path.hasPrefix(home + "/Downloads/") || path.hasPrefix(home + "/Documents/") {
            score += 150
        } else if path.hasPrefix(home + "/Library/Mobile Documents/") || path.hasPrefix(home + "/Library/CloudStorage/") {
            score += 110
        } else if path.hasPrefix(home + "/") {
            score += 70
        }

        // Recency signal (prefer recently opened or modified files)
        if let recent = lastUsedDate ?? modifiedDate {
            let age = max(0, Date().timeIntervalSince(recent))
            if age < 86400 {
                score += 120
            } else if age < 7 * 86400 {
                score += 80
            } else if age < 30 * 86400 {
                score += 40
            } else if age < 180 * 86400 {
                score += 15
            }
        }

        // Prefer concise, top-level filenames over deeply nested artifacts
        let depth = path.split(separator: "/").count
        score -= Double(min(depth, 20)) * 2.0
        score -= Double(min(name.count, 80)) * 0.25

        return score
    }
}

// MARK: - Cached File Icon Provider

@MainActor
public final class SmartFinderIconCache {
    public static let shared = SmartFinderIconCache()

    private let cache = NSCache<NSString, NSImage>()

    private init() {
        cache.countLimit = 250
    }

    public func icon(for file: MorphFoundFile) -> NSImage {
        let key = file.id as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }
        let img = NSWorkspace.shared.icon(forFile: file.path)
        img.size = NSSize(width: 32, height: 32)
        cache.setObject(img, forKey: key)
        return img
    }
}
