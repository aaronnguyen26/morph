import Cocoa
import SwiftUI
import Combine

public enum DevTaskStatus: String, Codable, Equatable, Sendable {
    case running
    case succeeded
    case failed
    case cancelled
}

public struct DevTask: Identifiable, Equatable, Sendable {
    public let id: String
    public var title: String
    public var command: String
    public var startedAt: Date
    public var endedAt: Date?
    public var status: DevTaskStatus
    public var progress: Double?
    public var statusMessage: String?
    public var exitCode: Int32?
    
    public init(
        id: String = UUID().uuidString,
        title: String,
        command: String = "",
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        status: DevTaskStatus = .running,
        progress: Double? = nil,
        statusMessage: String? = nil,
        exitCode: Int32? = nil
    ) {
        self.id = id
        self.title = title
        self.command = command
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.status = status
        self.progress = progress
        self.statusMessage = statusMessage
        self.exitCode = exitCode
    }
}

@MainActor
public final class DevAgentMonitorModel: ObservableObject {
    @Published public var currentTask: DevTask?
    @Published public var stdoutLines: [String] = []
    @Published public var progress: Double = 0.0 // 0.0 to 1.0
    @Published public var statusMessage: String = "Idle"
    @Published public var isTaskActive: Bool = false
    
    public let maxCapacity: Int
    private var connectedPipes = [Pipe]()
    
    public var fullStdoutText: String {
        stdoutLines.joined(separator: "\n")
    }
    
    public var lastStdoutLine: String? {
        stdoutLines.last
    }
    
    public init(maxCapacity: Int = 100) {
        self.maxCapacity = max(maxCapacity, 1)
    }
    
    // MARK: - Task Lifecycle
    
    @discardableResult
    public func startTask(id: String = UUID().uuidString, title: String, command: String = "") -> DevTask {
        clearOutput()
        let task = DevTask(id: id, title: title, command: command, status: .running, progress: 0.0, statusMessage: "Running...")
        self.currentTask = task
        self.isTaskActive = true
        self.progress = 0.0
        self.statusMessage = "Starting: \(title)"
        return task
    }
    
    public func appendLine(_ rawLine: String) {
        let clean = Self.stripANSI(from: rawLine)
        let trimmed = clean.trimmingCharacters(in: .newlines)
        guard !trimmed.isEmpty else { return }
        
        stdoutLines.append(trimmed)
        if stdoutLines.count > maxCapacity {
            stdoutLines.removeFirst(stdoutLines.count - maxCapacity)
        }
        
        // Auto-detect percentage or progress if not manually set
        if let detectedProgress = Self.detectProgressPercentage(in: trimmed) {
            self.progress = detectedProgress
            self.currentTask?.progress = detectedProgress
        }
        
        self.statusMessage = trimmed
        self.currentTask?.statusMessage = trimmed
    }
    
    public func appendOutput(_ text: String) {
        let clean = Self.stripANSI(from: text)
        let lines = clean.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                appendLine(trimmed)
            }
        }
    }
    
    public func updateProgress(_ newProgress: Double, message: String? = nil) {
        let clamped = min(max(newProgress, 0.0), 1.0)
        self.progress = clamped
        self.currentTask?.progress = clamped
        
        if let msg = message {
            self.statusMessage = msg
            self.currentTask?.statusMessage = msg
        }
    }
    
    public func completeTask(isSuccess: Bool, exitCode: Int32 = 0, message: String? = nil) {
        let finalStatus: DevTaskStatus = isSuccess ? .succeeded : .failed
        let finalMessage = message ?? (isSuccess ? "Task completed successfully" : "Task failed with exit code \(exitCode)")
        
        if var task = currentTask {
            task.endedAt = Date()
            task.status = finalStatus
            task.exitCode = exitCode
            task.progress = isSuccess ? 1.0 : task.progress
            task.statusMessage = finalMessage
            self.currentTask = task
        }
        
        self.progress = isSuccess ? 1.0 : progress
        self.statusMessage = finalMessage
        self.isTaskActive = false
        
        // Retain completion state briefly, then return notch to idle
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard let self = self, !self.isTaskActive else { return }
            self.currentTask = nil
            self.statusMessage = "Idle"
        }
    }
    
    public func cancelTask() {
        if var task = currentTask {
            task.endedAt = Date()
            task.status = .cancelled
            task.statusMessage = "Task cancelled"
            self.currentTask = task
        }
        self.statusMessage = "Cancelled"
        self.isTaskActive = false
    }
    
    public func clearOutput() {
        stdoutLines.removeAll()
    }
    
    // MARK: - Pipe Monitoring
    
    public func connectPipe(_ pipe: Pipe) {
        connectedPipes.append(pipe)
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let str = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor [weak self] in
                self?.appendOutput(str)
            }
        }
    }
    
    public func disconnectPipes() {
        for pipe in connectedPipes {
            pipe.fileHandleForReading.readabilityHandler = nil
        }
        connectedPipes.removeAll()
    }
    
    // MARK: - Utilities
    
    nonisolated public static func stripANSI(from string: String) -> String {
        // Regex matches standard ANSI escape code sequences: \x1b[ ... letter, \x1b( ...
        let pattern = #"\x1b\[[0-9;?]*[ -/]*[@-~]|\x1b\([ -/]*[@-~]|\r"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return string
        }
        let range = NSRange(location: 0, length: string.utf16.count)
        return regex.stringByReplacingMatches(in: string, options: [], range: range, withTemplate: "")
    }
    
    nonisolated public static func detectProgressPercentage(in line: String) -> Double? {
        // Match percentages like "45%" or " 80 %"
        let percentPattern = #"(\d{1,3})\s*%"#
        if let regex = try? NSRegularExpression(pattern: percentPattern, options: []),
           let match = regex.firstMatch(in: line, options: [], range: NSRange(location: 0, length: line.utf16.count)),
           match.numberOfRanges > 1,
           let percentRange = Range(match.range(at: 1), in: line),
           let val = Double(line[percentRange]), val >= 0 && val <= 100 {
            return val / 100.0
        }
        
        // Match fractions like "[3/10]" or "step 5/20"
        let fractionPattern = #"\[?(\d+)\s*\/\s*(\d+)\]?"#
        if let regex = try? NSRegularExpression(pattern: fractionPattern, options: []),
           let match = regex.firstMatch(in: line, options: [], range: NSRange(location: 0, length: line.utf16.count)),
           match.numberOfRanges > 2,
           let currRange = Range(match.range(at: 1), in: line),
           let totalRange = Range(match.range(at: 2), in: line),
           let current = Double(line[currRange]),
           let total = Double(line[totalRange]),
           total > 0 && current <= total {
            return current / total
        }
        
        return nil
    }
}
