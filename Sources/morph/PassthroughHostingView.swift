import Cocoa
import SwiftUI

public final class PassthroughHostingView<Content: View>: NSHostingView<Content> {
    public var onMouseEnter: (() -> Void)?
    public var onMouseExit: (() -> Void)?
    public var getActiveBounds: (() -> NSRect)?
    
    private var trackingArea: NSTrackingArea?
    
    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let area = trackingArea {
            removeTrackingArea(area)
        }
        let options: NSTrackingArea.Options = [
            .mouseEnteredAndExited,
            .mouseMoved,
            .activeAlways,
            .inVisibleRect
        ]
        let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(area)
        self.trackingArea = area
    }
    
    public override func mouseEntered(with event: NSEvent) {
        onMouseEnter?()
        super.mouseEntered(with: event)
    }
    
    public override func mouseExited(with event: NSEvent) {
        onMouseExit?()
        super.mouseExited(with: event)
    }
    
    public override func hitTest(_ point: NSPoint) -> NSView? {
        if let activeBounds = getActiveBounds?() {
            if !activeBounds.contains(point) {
                return nil
            }
        }
        return super.hitTest(point)
    }
}
