import Cocoa
import SwiftUI
import Combine
import PDFKit

public struct DropShelfItem: Identifiable, Equatable, @unchecked Sendable {
    public let id: UUID
    public let url: URL
    public let name: String
    public let fileSize: Int64
    public let dateAdded: Date
    public let icon: NSImage?
    public let pageCount: Int?
    public let isPDF: Bool
    
    public init(
        id: UUID = UUID(),
        url: URL,
        name: String? = nil,
        fileSize: Int64? = nil,
        dateAdded: Date = Date(),
        icon: NSImage? = nil,
        pageCount: Int? = nil
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
        
        let isPDFFile = url.pathExtension.lowercased() == "pdf"
        self.isPDF = isPDFFile
        
        var resolvedIcon = icon
        var resolvedPageCount = pageCount
        
        if resolvedIcon == nil && isPDFFile {
            if let pdfDoc = PDFDocument(url: url) {
                resolvedPageCount = resolvedPageCount ?? pdfDoc.pageCount
                if let firstPage = pdfDoc.page(at: 0) {
                    resolvedIcon = firstPage.thumbnail(of: CGSize(width: 120, height: 120), for: .cropBox)
                }
            }
        }
        
        self.pageCount = resolvedPageCount
        self.icon = resolvedIcon ?? NSWorkspace.shared.icon(forFile: url.path)
    }
    
    public var formattedSize: String {
        guard fileSize > 0 else { return "0 B" }
        return ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
    
    public var pathExtension: String {
        url.pathExtension.uppercased()
    }
    
    public var subtitle: String {
        if isPDF, let pages = pageCount, pages > 0 {
            return "\(formattedSize) • \(pages) \(pages == 1 ? "pg" : "pgs")"
        }
        return formattedSize
    }
    
    public static func == (lhs: DropShelfItem, rhs: DropShelfItem) -> Bool {
        lhs.id == rhs.id && lhs.url == rhs.url && lhs.fileSize == rhs.fileSize
    }
}

@MainActor
public final class DropShelfModel: ObservableObject {
    @Published public var stagedItems: [DropShelfItem] = []
    @Published public var isDraggingOverNotch: Bool = false
    @Published public var isDraggingOut: Bool = false
    @Published public var activeDraggedItem: DropShelfItem? = nil
    @Published public var lastActionMessage: String?
    
    @Published public var holdShelfOnDrop: Bool
    @Published public var holdFilesAfterDrag: Bool
    @Published public var isHeldOpen: Bool = false
    
    // Callbacks for NotchModel context synchronization
    public var onItemExported: ((DropShelfItem) -> Void)?
    public var onItemRemoved: ((DropShelfItem) -> Void)?
    public var onShelfEmptied: (() -> Void)?
    
    private var globalMouseUpMonitor: Any?
    private var localMouseUpMonitor: Any?
    private var dragPollingTask: Task<Void, Never>?
    private var dragTimeoutTask: Task<Void, Never>?
    
    private static let holdShelfKey = "com.morph.dropshelf.holdShelfOnDrop"
    private static let holdFilesKey = "com.morph.dropshelf.holdFilesAfterDrag"
    
    public var hasItems: Bool {
        !stagedItems.isEmpty
    }
    
    public var count: Int {
        stagedItems.count
    }
    
    public var isHoldModeActive: Bool {
        holdShelfOnDrop || holdFilesAfterDrag
    }
    
    public init(
        items: [DropShelfItem] = [],
        holdShelfOnDrop: Bool? = nil,
        holdFilesAfterDrag: Bool? = nil
    ) {
        self.stagedItems = items
        let defaults = UserDefaults.standard
        self.holdShelfOnDrop = holdShelfOnDrop ?? (defaults.object(forKey: Self.holdShelfKey) as? Bool ?? false)
        self.holdFilesAfterDrag = holdFilesAfterDrag ?? (defaults.object(forKey: Self.holdFilesKey) as? Bool ?? false)
    }
    
    public func toggleHoldMode() {
        let newState = !isHoldModeActive
        holdShelfOnDrop = newState
        holdFilesAfterDrag = newState
        isHeldOpen = newState && hasItems
        UserDefaults.standard.set(newState, forKey: Self.holdShelfKey)
        UserDefaults.standard.set(newState, forKey: Self.holdFilesKey)
        lastActionMessage = newState ? "Hold Mode: ON (Holds shelf & files)" : "Hold Mode: OFF (Transient stash)"
    }
    
    public func setHoldShelfOnDrop(_ enabled: Bool) {
        holdShelfOnDrop = enabled
        UserDefaults.standard.set(enabled, forKey: Self.holdShelfKey)
        if enabled && hasItems {
            isHeldOpen = true
        } else if !enabled {
            isHeldOpen = false
        }
    }
    
    public func setHoldFilesAfterDrag(_ enabled: Bool) {
        holdFilesAfterDrag = enabled
        UserDefaults.standard.set(enabled, forKey: Self.holdFilesKey)
    }
    
    public func releaseHold() {
        isHeldOpen = false
        lastActionMessage = "Shelf hold released"
    }
    
    @discardableResult
    public func stageFile(url: URL) -> DropShelfItem {
        if let existing = stagedItems.first(where: { $0.url == url }) {
            if holdShelfOnDrop {
                isHeldOpen = true
            }
            return existing
        }
        let item = DropShelfItem(url: url)
        stagedItems.append(item)
        lastActionMessage = "Staged: \(item.name)"
        if holdShelfOnDrop {
            isHeldOpen = true
        }
        return item
    }
    
    public func stageFiles(urls: [URL]) {
        for url in urls {
            stageFile(url: url)
        }
    }
    
    public func removeItem(id: UUID) {
        let removed = stagedItems.first(where: { $0.id == id })
        stagedItems.removeAll { $0.id == id }
        if stagedItems.isEmpty {
            isHeldOpen = false
            lastActionMessage = "Shelf cleared"
            onShelfEmptied?()
        }
        if let r = removed {
            onItemRemoved?(r)
        }
    }
    
    public func removeItem(at index: Int) {
        guard stagedItems.indices.contains(index) else { return }
        let removed = stagedItems.remove(at: index)
        if stagedItems.isEmpty {
            isHeldOpen = false
            lastActionMessage = "Shelf cleared"
            onShelfEmptied?()
        }
        onItemRemoved?(removed)
    }
    
    public func clearAll() {
        stagedItems.removeAll()
        isHeldOpen = false
        lastActionMessage = "Shelf cleared"
        onShelfEmptied?()
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
    
    // MARK: - Drag Out Management
    
    public func startDragOut(for item: DropShelfItem) {
        self.isDraggingOut = true
        self.activeDraggedItem = item
        self.lastActionMessage = "Dragging \(item.name)..."
        
        setupMouseUpMonitors()
    }
    
    public func endDragOut(successful: Bool = true) {
        guard isDraggingOut else { return }
        self.isDraggingOut = false
        dragPollingTask?.cancel()
        dragPollingTask = nil
        
        if let item = activeDraggedItem {
            if successful {
                if !holdFilesAfterDrag {
                    removeItem(id: item.id)
                    self.lastActionMessage = "Exported: \(item.name)"
                } else {
                    self.lastActionMessage = "Exported: \(item.name) (Held)"
                }
                self.isHeldOpen = false
                onItemExported?(item)
            } else {
                self.lastActionMessage = "Cancelled drag"
            }
        }
        self.activeDraggedItem = nil
        teardownMouseUpMonitors()
    }
    
    private func setupMouseUpMonitors() {
        teardownMouseUpMonitors()
        
        globalMouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.endDragOut(successful: true)
            }
        }
        
        localMouseUpMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.endDragOut(successful: true)
            }
            return event
        }
        
        // Fast polling task to detect mouse button release anywhere across macOS
        dragPollingTask = Task { [weak self] in
            // Brief 80ms delay for the drag session to establish
            try? await Task.sleep(nanoseconds: 80_000_000)
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 50_000_000)
                if NSEvent.pressedMouseButtons & 1 == 0 {
                    await MainActor.run {
                        self?.endDragOut(successful: true)
                    }
                    break
                }
            }
        }
        
        // 15-second safety timer in case drag terminates without mouse-up event delivery
        dragTimeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 15_000_000_000)
            if !Task.isCancelled {
                await MainActor.run {
                    self?.endDragOut(successful: true)
                }
            }
        }
    }
    
    private func teardownMouseUpMonitors() {
        if let g = globalMouseUpMonitor {
            NSEvent.removeMonitor(g)
            globalMouseUpMonitor = nil
        }
        if let l = localMouseUpMonitor {
            NSEvent.removeMonitor(l)
            localMouseUpMonitor = nil
        }
        dragPollingTask?.cancel()
        dragPollingTask = nil
        dragTimeoutTask?.cancel()
        dragTimeoutTask = nil
    }
}
