import Cocoa

public final class NotchPanel: NSPanel {
    public init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.level = .popUpMenu
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        self.isMovable = false
        self.isMovableByWindowBackground = false
        self.acceptsMouseMovedEvents = true
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.standardWindowButton(.closeButton)?.isHidden = true
        self.standardWindowButton(.miniaturizeButton)?.isHidden = true
        self.standardWindowButton(.zoomButton)?.isHidden = true
    }
    
    public override var canBecomeKey: Bool {
        return true
    }
    
    public override var canBecomeMain: Bool {
        return false
    }
    
    public var onKeyEquivalent: ((NSEvent) -> Bool)?
    
    public override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if let handled = onKeyEquivalent?(event), handled {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
    
    public func updatePosition(screen: NSScreen, width: CGFloat, height: CGFloat, animate: Bool = false) {
        let x = screen.frame.midX - (width / 2)
        let y = screen.frame.maxY - height
        let newFrame = NSRect(x: x, y: y, width: width, height: height)
        
        self.setFrame(newFrame, display: true, animate: animate)
    }
}
