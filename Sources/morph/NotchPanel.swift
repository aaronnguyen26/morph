import Cocoa

public final class NotchPanel: NSPanel {
    public init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless],
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
        self.becomesKeyOnlyIfNeeded = false
        self.hidesOnDeactivate = false
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.standardWindowButton(.closeButton)?.isHidden = true
        self.standardWindowButton(.miniaturizeButton)?.isHidden = true
        self.standardWindowButton(.zoomButton)?.isHidden = true
        self.registerForDraggedTypes([.fileURL, .URL, .string])
        
        // Dynamic Island default: click-through while resting/idle
        self.ignoresMouseEvents = true
        
        if MorphEnvironment.isTestingEnvironment {
            self.alphaValue = 0.0
        }
    }
    
    public override func orderFrontRegardless() {
        guard !MorphEnvironment.isTestingEnvironment else { return }
        super.orderFrontRegardless()
    }
    
    public override func orderFront(_ sender: Any?) {
        guard !MorphEnvironment.isTestingEnvironment else { return }
        super.orderFront(sender)
    }
    
    public override func makeKeyAndOrderFront(_ sender: Any?) {
        guard !MorphEnvironment.isTestingEnvironment else { return }
        NSApp.activate(ignoringOtherApps: true)
        super.makeKeyAndOrderFront(sender)
    }
    
    public override func makeKey() {
        guard !MorphEnvironment.isTestingEnvironment else { return }
        NSApp.activate(ignoringOtherApps: true)
        super.makeKey()
    }
    
    public override func order(_ place: NSWindow.OrderingMode, relativeTo otherWin: Int) {
        guard !MorphEnvironment.isTestingEnvironment else { return }
        super.order(place, relativeTo: otherWin)
    }
    
    public override var canBecomeKey: Bool {
        return true
    }
    
    public override var acceptsFirstResponder: Bool {
        return true
    }
    
    public override var canBecomeMain: Bool {
        return false
    }
    
    public var onKeyEquivalent: ((NSEvent) -> Bool)?
    
    public var onDraggingEntered: ((NSDraggingInfo) -> NSDragOperation)?
    public var onDraggingUpdated: ((NSDraggingInfo) -> NSDragOperation)?
    public var onDraggingExited: ((NSDraggingInfo) -> Void)?
    public var onPerformDragOperation: ((NSDraggingInfo) -> Bool)?
    
    // MARK: - NSDraggingDestination
    public func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if let custom = onDraggingEntered?(sender) {
            return custom
        }
        return .copy
    }
    
    public func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        if let custom = onDraggingUpdated?(sender) {
            return custom
        }
        return .copy
    }
    
    public func draggingExited(_ sender: NSDraggingInfo?) {
        if let sender = sender {
            onDraggingExited?(sender)
        }
    }
    
    public func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        if let custom = onPerformDragOperation?(sender) {
            return custom
        }
        return false
    }
    
    public override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if let handled = onKeyEquivalent?(event), handled {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
    
    public func updatePosition(screen: NSScreen, width: CGFloat, height: CGFloat, animate: Bool = false) {
        let x = floor(screen.frame.midX - (width / 2))
        let topBarHeight = max(screen.safeAreaInsets.top, screen.frame.maxY - screen.visibleFrame.maxY)
        let topClearance: CGFloat = 14.0
        let y = floor(screen.frame.maxY - topBarHeight - topClearance - height)
        let newFrame = NSRect(x: x, y: y, width: width.rounded(), height: height.rounded())
        
        if self.frame != newFrame {
            if animate && self.isVisible && !MorphEnvironment.isTestingEnvironment {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.32
                    context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    context.allowsImplicitAnimation = true
                    self.animator().setFrame(newFrame, display: false)
                }
            } else {
                self.setFrame(newFrame, display: false)
            }
            if !MorphEnvironment.isTestingEnvironment {
                self.orderFrontRegardless()
            }
        } else if !MorphEnvironment.isTestingEnvironment && !self.isVisible {
            self.orderFrontRegardless()
        }
    }
}
