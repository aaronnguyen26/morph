import Cocoa
import SwiftUI
import Combine

public enum SnippetType: String, Codable, CaseIterable, Sendable {
    case shellCommand
    case json
    case secretToken
    case sourceCode
    case url
    case generic
    
    public var iconName: String {
        switch self {
        case .shellCommand: return "terminal.fill"
        case .json: return "curlybraces"
        case .secretToken: return "key.fill"
        case .sourceCode: return "chevron.left.forwardslash.chevron.right"
        case .url: return "link"
        case .generic: return "doc.text"
        }
    }
}

public struct DevSnippet: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var content: String
    public var type: SnippetType
    public let detectedAt: Date
    public var metadata: [String: String]
    
    public init(
        id: UUID = UUID(),
        content: String,
        type: SnippetType? = nil,
        detectedAt: Date = Date(),
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.content = content
        self.detectedAt = detectedAt
        self.metadata = metadata
        self.type = type ?? DevSnippetClipboardModel.classify(content)
    }
}

@MainActor
public final class DevSnippetClipboardModel: ObservableObject {
    @Published public var snippets: [DevSnippet] = []
    @Published public var lastCopiedMessage: String?
    @Published public var showToast: Bool = false
    @Published public var toastMessage: String = ""
    
    public let maxSnippets: Int
    private var lastPasteboardChangeCount: Int
    private var pasteboardCancellable: AnyCancellable?
    
    private static var isTestingEnvironment: Bool {
        return ProcessInfo.processInfo.processName.contains("xctest") ||
            ProcessInfo.processInfo.arguments.contains(where: { $0.contains("xctest") }) ||
            ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
            ProcessInfo.processInfo.environment["XCTestBundlePath"] != nil ||
            NSClassFromString("XCTestCase") != nil
    }
    
    public var latestSnippet: DevSnippet? {
        snippets.first
    }
    
    public init(maxSnippets: Int = 10) {
        self.maxSnippets = maxSnippets
        self.lastPasteboardChangeCount = NSPasteboard.general.changeCount
        
        if !Self.isTestingEnvironment {
            startPasteboardMonitoring()
        }
    }
    
    @discardableResult
    public func ingest(text: String, source: String = "manual") -> DevSnippet? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        // Don't duplicate the immediate previous snippet
        if let first = snippets.first, first.content == trimmed {
            return first
        }
        
        let type = Self.classify(trimmed)
        let snippet = DevSnippet(content: trimmed, type: type, metadata: ["source": source])
        
        snippets.insert(snippet, at: 0)
        if snippets.count > maxSnippets {
            snippets.removeLast(snippets.count - maxSnippets)
        }
        
        self.showToast = true
        self.toastMessage = "Copied \(type.rawValue)"
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            self?.showToast = false
        }
        
        return snippet
    }
    
    public func removeSnippet(id: UUID) {
        snippets.removeAll { $0.id == id }
    }
    
    public func clearAll() {
        snippets.removeAll()
    }
    
    public func copyToPasteboard(snippet: DevSnippet) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(snippet.content, forType: .string)
        self.lastPasteboardChangeCount = pasteboard.changeCount
        self.lastCopiedMessage = "Copied \(snippet.type.rawValue)"
        self.showToast = true
        self.toastMessage = "Copied \(snippet.type.rawValue)"
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            self?.showToast = false
        }
    }
    
    // MARK: - Classification
    
    nonisolated public static func classify(_ raw: String) -> SnippetType {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return .generic }
        
        // 1. Secret token detection
        if isSecretToken(text) {
            return .secretToken
        }
        
        // 2. JSON detection
        if isJSON(text) {
            return .json
        }
        
        // 3. URL detection
        if isURL(text) {
            return .url
        }
        
        // 4. Shell command detection
        if isShellCommand(text) {
            return .shellCommand
        }
        
        // 5. Source code detection
        if isSourceCode(text) {
            return .sourceCode
        }
        
        return .generic
    }
    
    nonisolated private static func isSecretToken(_ text: String) -> Bool {
        // Known token prefixes & patterns
        let patterns = [
            #"^(sk-[a-zA-Z0-9_\-]{20,})"#,                  // OpenAI / Stripe secret
            #"^(pk_[a-zA-Z0-9_\-]{20,})"#,                  // Stripe publishable
            #"^(ghp_[a-zA-Z0-9]{30,})"#,                    // GitHub Personal Token
            #"^(gho_[a-zA-Z0-9]{30,})"#,                    // GitHub OAuth
            #"^(glpat-[a-zA-Z0-9_\-]{20,})"#,              // GitLab Personal Access Token
            #"^(xox[baprs]-[0-9a-zA-Z\-]{20,})"#,           // Slack Token
            #"^(AKIA[0-9A-Z]{16})"#,                        // AWS Access Key ID
            #"^(eyJ[a-zA-Z0-9_-]{10,}\.eyJ[a-zA-Z0-9_-]{10,})"#, // JWT format
            #"(?i)(api[_-]?key|secret[_-]?token|bearer)\s*[:=]\s*['"]?[a-zA-Z0-9_\-]{16,}['"]?"#
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)) != nil {
                return true
            }
        }
        
        return false
    }
    
    nonisolated private static func isJSON(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (trimmed.hasPrefix("{") && trimmed.hasSuffix("}")) ||
              (trimmed.hasPrefix("[") && trimmed.hasSuffix("]")) else {
            return false
        }
        guard let data = trimmed.data(using: .utf8) else { return false }
        return (try? JSONSerialization.jsonObject(with: data, options: [])) != nil
    }
    
    nonisolated private static func isURL(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.contains(" ") || trimmed.contains("\n") { return false }
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") || trimmed.hasPrefix("git@") {
            return true
        }
        if let url = URL(string: trimmed), url.scheme != nil, url.host != nil {
            return true
        }
        return false
    }
    
    nonisolated private static func isShellCommand(_ text: String) -> Bool {
        let lines = text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }
        guard let firstLine = lines.first, !firstLine.isEmpty else { return false }
        
        if firstLine.hasPrefix("$ ") || firstLine.hasPrefix("# ") || firstLine.hasPrefix("> ") {
            return true
        }
        
        let shellPrefixes = [
            "git ", "npm ", "pnpm ", "yarn ", "bun ", "brew ", "curl ", "wget ",
            "docker ", "kubectl ", "cargo ", "swift ", "ssh ", "cd ", "mkdir ",
            "touch ", "rm ", "cp ", "mv ", "cat ", "grep ", "find ", "chmod ",
            "chown ", "sudo ", "export ", "source ", "echo ", "kill ", "ps "
        ]
        
        if shellPrefixes.contains(where: { firstLine.hasPrefix($0) }) {
            return true
        }
        
        if text.contains(" | ") && (text.contains("grep") || text.contains("awk") || text.contains("sed") || text.contains("xargs")) {
            return true
        }
        
        return false
    }
    
    nonisolated private static func isSourceCode(_ text: String) -> Bool {
        let codeKeywords = [
            "import ", "export ", "func ", "function ", "def ", "class ", "struct ",
            "enum ", "protocol ", "interface ", "var ", "let ", "const ", "return ",
            "public ", "private ", "protected ", "override ", "final ", "async ", "await ",
            "fn ", "pub fn ", "package ", "namespace ", "#include ", "console.log"
        ]
        
        var matches = 0
        for kw in codeKeywords {
            if text.contains(kw) {
                matches += 1
                if matches >= 2 { return true }
            }
        }
        
        // Single match with braces or parentheses
        if matches >= 1 && (text.contains("{") && text.contains("}")) {
            return true
        }
        
        return false
    }
    
    // MARK: - Formatting Utilities
    
    nonisolated public static func formatJSON(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
              let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted, .sortedKeys]),
              let formatted = String(data: prettyData, encoding: .utf8) else {
            return nil
        }
        return formatted
    }
    
    nonisolated public static func stripBackticks(_ raw: String) -> String {
        var str = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Strip multi-line markdown fences: ```swift ... ``` or ``` ... ```
        if str.hasPrefix("```") {
            let lines = str.components(separatedBy: .newlines)
            if lines.count >= 2 {
                var strippedLines = lines
                // Remove first line (e.g. ```swift)
                strippedLines.removeFirst()
                // Remove last line if ```
                if let last = strippedLines.last, last.trimmingCharacters(in: .whitespaces) == "```" {
                    strippedLines.removeLast()
                }
                str = strippedLines.joined(separator: "\n")
            }
        }
        
        // Strip inline backticks: `code`
        if str.hasPrefix("`") && str.hasSuffix("`") && str.count >= 2 {
            str = String(str.dropFirst().dropLast())
        }
        
        return str.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    nonisolated public static func maskSensitive(_ raw: String) -> String {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count > 8 else {
            return String(repeating: "•", count: max(text.count, 4))
        }
        
        let prefix = text.prefix(4)
        let suffix = text.suffix(4)
        return "\(prefix)••••••••\(suffix)"
    }
    
    // MARK: - Pasteboard Polling
    
    private func startPasteboardMonitoring() {
        pasteboardCancellable = Timer.publish(every: 1.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkPasteboard()
            }
    }
    
    public func checkPasteboard() {
        let pasteboard = NSPasteboard.general
        let currentCount = pasteboard.changeCount
        guard currentCount != lastPasteboardChangeCount else { return }
        lastPasteboardChangeCount = currentCount
        
        if let text = pasteboard.string(forType: .string) {
            ingest(text: text, source: "pasteboard")
        }
    }
}
