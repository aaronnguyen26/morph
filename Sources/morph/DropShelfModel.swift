import Cocoa
import SwiftUI
import Combine

public struct DropShelfItem: Identifiable, Equatable, @unchecked Sendable {
    public let id: UUID
    public let url: URL
    public let name: String
    public let fileSize: Int64
    public let dateAdded: Date
    public let icon: NSImage?
    
    public init(
        id: UUID = UUID(),
        url: URL,
        name: String? = nil,
        fileSize: Int64? = nil,
        dateAdded: Date = Date(),
        icon: NSImage? = nil
    ) {
        self.id = id
        self.url = url
        self.name = name ?? (url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent)
        self.dateAdded = dateAdded
        
        if let size = fileSize {
            self.fileSize = size
        } else {
            let resources = try? url.resourceValues(forKeys: [.fileSizeKey])
            self.fileSize = Int64(resources?.fileSize ?? 0)
        }
        
        self.icon = icon ?? NSWorkspace.shared.icon(forFile: url.path)
    }
    
    public var formattedSize: String {
        guard fileSize > 0 else { return "0 B" }
        return ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
    
    public var pathExtension: String {
        url.pathExtension.uppercased()
    }
    
    public static func == (lhs: DropShelfItem, rhs: DropShelfItem) -> Bool {
        lhs.id == rhs.id && lhs.url == rhs.url && lhs.fileSize == rhs.fileSize
    }
}

@MainActor
public final class DropShelfModel: ObservableObject {
    @Published public var stagedItems: [DropShelfItem] = []
    @Published public var isDraggingOverNotch: Bool = false
    @Published public var lastActionMessage: String?
    
    public var hasItems: Bool {
        !stagedItems.isEmpty
    }
    
    public var count: Int {
        stagedItems.count
    }
    
    public init(items: [DropShelfItem] = []) {
        self.stagedItems = items
    }
    
    @discardableResult
    public func stageFile(url: URL) -> DropShelfItem {
        if let existing = stagedItems.first(where: { $0.url == url }) {
            return existing
        }
        let item = DropShelfItem(url: url)
        stagedItems.append(item)
        return item
    }
    
    public func stageFiles(urls: [URL]) {
        for url in urls {
            stageFile(url: url)
        }
    }
    
    public func removeItem(id: UUID) {
        stagedItems.removeAll { $0.id == id }
    }
    
    public func removeItem(at index: Int) {
        guard stagedItems.indices.contains(index) else { return }
        stagedItems.remove(at: index)
    }
    
    public func clearAll() {
        stagedItems.removeAll()
    }
    
    public func revealInFinder(item: DropShelfItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
        lastActionMessage = "Revealed in Finder: \(item.name)"
    }
    
    public func copyFilePath(item: DropShelfItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(item.url.path, forType: .string)
        lastActionMessage = "Copied path: \(item.name)"
    }
    
    public func copyAllFilePaths() {
        guard !stagedItems.isEmpty else { return }
        let paths = stagedItems.map { $0.url.path }.joined(separator: "\n")
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(paths, forType: .string)
        lastActionMessage = "Copied \(stagedItems.count) file paths"
    }
    
    public func triggerShareSheet(item: DropShelfItem, from view: NSView? = nil) {
        let picker = NSSharingServicePicker(items: [item.url])
        if let targetView = view ?? NSApp.keyWindow?.contentView {
            picker.show(relativeTo: targetView.bounds, of: targetView, preferredEdge: .minY)
        }
    }
}
