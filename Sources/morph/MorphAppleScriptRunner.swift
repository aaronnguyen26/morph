import Foundation

/// Process-isolated, thread-safe AppleScript runner backed by `/usr/bin/osascript`.
///
/// Using an out-of-process runner completely avoids Apple OpenScripting (`NSAppleScript` /
/// `TASLexer`) global state corruption and `SIGSEGV` crashes when browser/form scripts execute
/// concurrently across background queues, while enforcing bounded timeouts so hung target apps
/// cannot wedge caller threads.
public enum MorphAppleScriptRunner {
    private final class OutputBuffer: @unchecked Sendable {
        private let lock = NSLock()
        private var data = Data()
        
        func set(_ newData: Data) {
            lock.lock()
            data = newData
            lock.unlock()
        }
        
        func get() -> Data {
            lock.lock()
            let copy = data
            lock.unlock()
            return copy
        }
    }
    
    @discardableResult
    public static func run(
        _ source: String,
        timeout: TimeInterval = 3.0,
        executablePath: String = "/usr/bin/osascript",
        argumentsPrefix: [String] = ["-e"]
    ) -> String? {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: executablePath)
        proc.arguments = argumentsPrefix + [source]
        
        let outPipe = Pipe()
        let errPipe = Pipe()
        proc.standardOutput = outPipe
        proc.standardError = errPipe
        
        let semaphore = DispatchSemaphore(value: 0)
        proc.terminationHandler = { _ in
            semaphore.signal()
        }
        
        do {
            try proc.run()
        } catch {
            return nil
        }
        
        let buffer = OutputBuffer()
        let readGroup = DispatchGroup()
        
        readGroup.enter()
        DispatchQueue.global(qos: .utility).async {
            let data = outPipe.fileHandleForReading.readDataToEndOfFile()
            buffer.set(data)
            readGroup.leave()
        }
        
        readGroup.enter()
        DispatchQueue.global(qos: .utility).async {
            _ = errPipe.fileHandleForReading.readDataToEndOfFile()
            readGroup.leave()
        }
        
        let waitResult = semaphore.wait(timeout: .now() + max(0.05, timeout))
        if waitResult == .timedOut {
            if proc.isRunning {
                proc.terminate()
            }
            return nil
        }
        
        _ = readGroup.wait(timeout: .now() + 0.5)
        guard proc.terminationStatus == 0 else {
            return nil
        }
        
        let captured = buffer.get()
        guard let str = String(data: captured, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !str.isEmpty else {
            return nil
        }
        return str
    }
    
    public static func runBoolean(_ source: String, timeout: TimeInterval = 3.0) -> Bool {
        guard let result = run(source, timeout: timeout)?.lowercased() else {
            return false
        }
        return result == "true" || result == "1" || result == "yes"
    }
}
