import Cocoa
import SwiftUI

public final class PassthroughHostingView<Content: View>: NSHostingView<Content> {
    public var onMouseEnter: (() -> Void)?
    public var onMouseExit: (() -> Void)?
    public var getActiveBounds: (() -> NSRect)?
    public var isExpanded: (() -> Bool)?
    
    public var onDraggingEntered: ((NSDraggingInfo) -> NSDragOperation)?
    public var onDraggingUpdated: ((NSDraggingInfo) -> NSDragOperation)?
    public var onDraggingExited: ((NSDraggingInfo) -> Void)?
    public var onPerformDragOperation: ((NSDraggingInfo) -> Bool)?
    
    private var trackingArea: NSTrackingArea?
    private var isMouseInside: Bool = false
    
    @MainActor required public init(rootView: Content) {
        super.init(rootView: rootView)
        registerForDraggedTypes([.fileURL, .URL, .string])
    }
    
    @MainActor required dynamic public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        registerForDraggedTypes([.fileURL, .URL, .string])
    }
    
    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let area = trackingArea {
            removeTrackingArea(area)
        }
        let options: NSTrackingArea.Options = [
            .mouseEnteredAndExited,
            .activeAlways,
            .inVisibleRect
        ]
        let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(area)
        self.trackingArea = area
    }
    
    public override func mouseEntered(with event: NSEvent) {
        if !isMouseInside {
            isMouseInside = true
            onMouseEnter?()
        }
        super.mouseEntered(with: event)
    }
    
    public override func mouseExited(with event: NSEvent) {
        if isMouseInside {
            isMouseInside = false
            onMouseExit?()
        }
        super.mouseExited(with: event)
    }
    
    public override func hitTest(_ point: NSPoint) -> NSView? {
        if let expanded = isExpanded?(), expanded {
            return super.hitTest(point)
        }
        if let activeBounds = getActiveBounds?() {
            if !activeBounds.contains(point) {
                return nil
            }
        }
        return super.hitTest(point)
    }
    
    // MARK: - NSDraggingDestination
    
    public override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if let custom = onDraggingEntered?(sender) {
            return custom
        }
        return super.draggingEntered(sender)
    }
    
    public override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        if let custom = onDraggingUpdated?(sender) {
            return custom
        }
        return super.draggingUpdated(sender)
    }
    
    public override func draggingExited(_ sender: NSDraggingInfo?) {
        if let sender = sender {
            onDraggingExited?(sender)
        }
        super.draggingExited(sender)
    }
    
    public override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        if let custom = onPerformDragOperation?(sender) {
            return custom
        }
        return super.performDragOperation(sender)
    }
}
