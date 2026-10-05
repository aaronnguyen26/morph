import Cocoa
import SwiftUI
import Combine

@MainActor
public final class ScratchpadModel: ObservableObject {
    @Published public var text: String = "" {
        didSet {
            updateCounts()
            persistText()
        }
    }
    
    @Published public var wordCount: Int = 0
    @Published public var charCount: Int = 0
    @Published public var canUndoClear: Bool = false
    @Published public var showCopiedAlert: Bool = false
    
    private var cachedClearedText: String? = nil
    private var undoTimer: AnyCancellable?
    private let kStorageKey = "MorphScratchpadContent"
    
    public init() {
        loadPersistedText()
        updateCounts()
    }
    
    public func copyAll() {
        guard !text.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        showCopiedAlert = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.showCopiedAlert = false
        }
    }
    
    public func clear() {
        guard !text.isEmpty else { return }
        cachedClearedText = text
        canUndoClear = true
        text = ""
        
        undoTimer?.cancel()
        undoTimer = Timer.publish(every: 2.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.canUndoClear = false
                self?.cachedClearedText = nil
                self?.undoTimer?.cancel()
                self?.undoTimer = nil
            }
    }
    
    public func undoClear() {
        guard canUndoClear, let cached = cachedClearedText else { return }
        text = cached
        canUndoClear = false
        cachedClearedText = nil
        undoTimer?.cancel()
        undoTimer = nil
    }
    
    private func updateCounts() {
        charCount = text.count
        let words = text.split { $0.isWhitespace || $0.isNewline }
        wordCount = words.count
    }
    
    private func persistText() {
        UserDefaults.standard.set(text, forKey: kStorageKey)
        
        let currentText = self.text
        DispatchQueue.global(qos: .utility).async {
            let fileManager = FileManager.default
            guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
            let morphDir = appSupport.appendingPathComponent("Morph", isDirectory: true)
            do {
                if !fileManager.fileExists(atPath: morphDir.path) {
                    try fileManager.createDirectory(at: morphDir, withIntermediateDirectories: true)
                }
                let fileURL = morphDir.appendingPathComponent("scratchpad.json")
                let dict: [String: Any] = ["content": currentText, "timestamp": Date().timeIntervalSince1970]
                let data = try JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted])
                try data.write(to: fileURL, options: .atomic)
            } catch {
                // Ignore backup failure
            }
        }
    }
    
    private func loadPersistedText() {
        if let saved = UserDefaults.standard.string(forKey: kStorageKey) {
            self.text = saved
            return
        }
        
        let fileManager = FileManager.default
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        let fileURL = appSupport.appendingPathComponent("Morph/scratchpad.json")
        if let data = try? Data(contentsOf: fileURL),
           let content = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let textContent = content["content"] as? String {
            self.text = textContent
        }
    }
}
