import Cocoa
import SwiftUI
import Combine

@MainActor
public final class MorphController: NSObject {
    public let model: NotchModel
    public private(set) var panel: NotchPanel!
    private var hostingView: PassthroughHostingView<MorphIslandView>!
    private var collapseWorkItem: DispatchWorkItem?
    private var cancellables = Set<AnyCancellable>()
    private var globalMonitor: Any?
    private var localMonitor: Any?
    
    public init(model: NotchModel = NotchModel()) {
        self.model = model
        super.init()
        setupPanel()
        setupObservers()
        setupMouseMonitors()
    }
    
    private func targetScreen() -> NSScreen {
        return NSScreen.screens.first(where: { $0.auxiliaryTopLeftArea != nil }) ?? NSScreen.main ?? NSScreen.screens[0]
    }
    
    private func setupPanel() {
        let screen = targetScreen()
        model.detectScreenNotch()
        
        let width = model.currentWidth
        let height = model.currentHeight
        let x = screen.frame.midX - (width / 2)
        let y = screen.frame.maxY - height
        let initialFrame = NSRect(x: x, y: y, width: width, height: height)
        
        self.panel = NotchPanel(contentRect: initialFrame)
        
        let islandView = MorphIslandView(
            model: model,
            onMouseEnter: { [weak self] in
                self?.handleMouseEnter()
            },
            onMouseExit: { [weak self] in
                self?.handleMouseExit()
            }
        )
        
        self.hostingView = PassthroughHostingView(rootView: islandView)
        self.hostingView.onMouseEnter = { [weak self] in
            self?.handleMouseEnter()
        }
        self.hostingView.onMouseExit = { [weak self] in
            self?.handleMouseExit()
        }
        
        self.hostingView.getActiveBounds = { [weak self] in
            guard let self = self else { return .zero }
            let w = self.model.currentWidth
            let h = self.model.currentHeight
            let bounds = self.hostingView.bounds
            return NSRect(
                x: (bounds.width - w) / 2,
                y: bounds.height - h,
                width: w,
                height: h
            )
        }
        
        self.panel.contentView = hostingView
        self.panel.orderFrontRegardless()
    }
    
    private func setupObservers() {
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.handleScreenChange()
                }
            }
            .store(in: &cancellables)
        
        // Listen to programmatic expand/collapse changes from model
        model.$isExpanded
            .dropFirst()
            .sink { [weak self] expanded in
                guard let self = self else { return }
                if expanded {
                    self.expandPanel()
                } else if !self.model.isPinned {
                    self.scheduleWindowShrink()
                }
            }
            .store(in: &cancellables)
        
        // Listen to external/scriptable distributed notifications
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleToggleExpandNotification(_:)),
            name: NSNotification.Name("com.morph.toggleExpand"),
            object: nil
        )
        
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleTogglePinNotification(_:)),
            name: NSNotification.Name("com.morph.togglePin"),
            object: nil
        )
    }
    
    @objc private func handleToggleExpandNotification(_ notification: Notification) {
        if model.isExpanded {
            model.isPinned = false
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                model.isExpanded = false
            }
            scheduleWindowShrink()
        } else {
            handleMouseEnter()
        }
    }
    
    @objc private func handleTogglePinNotification(_ notification: Notification) {
        model.togglePin()
    }
    
    private func setupMouseMonitors() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkMousePosition(NSEvent.mouseLocation)
            }
        }
        
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            self?.checkMousePosition(NSEvent.mouseLocation)
            return event
        }
    }
    
    public func checkMousePosition(_ mouseLoc: NSPoint) {
        let screen = targetScreen()
        
        if model.isExpanded {
            let w = model.expandedWidth
            let h = model.expandedHeight
            let minX = screen.frame.midX - (w / 2)
            let maxX = screen.frame.midX + (w / 2)
            let minY = screen.frame.maxY - h - 12
            let maxY = screen.frame.maxY + 5
            
            let isInside = (mouseLoc.x >= minX && mouseLoc.x <= maxX && mouseLoc.y >= minY && mouseLoc.y <= maxY)
            if !isInside && !model.isPinned {
                handleMouseExit()
            } else if isInside {
                collapseWorkItem?.cancel()
                collapseWorkItem = nil
            }
        } else {
            let w = model.currentWidth
            let h = model.currentHeight
            let minX = screen.frame.midX - (w / 2)
            let maxX = screen.frame.midX + (w / 2)
            let minY = screen.frame.maxY - h - 4
            let maxY = screen.frame.maxY + 2
            
            if mouseLoc.x >= minX && mouseLoc.x <= maxX && mouseLoc.y >= minY && mouseLoc.y <= maxY {
                handleMouseEnter()
            }
        }
    }
    
    public func handleMouseEnter() {
        collapseWorkItem?.cancel()
        collapseWorkItem = nil
        model.isHovered = true
        
        if !model.isExpanded {
            expandPanel()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                self.model.isExpanded = true
            }
        }
    }
    
    public func handleMouseExit() {
        model.isHovered = false
        guard !model.isPinned else { return }
        
        collapseWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            guard !self.model.isPinned && !self.model.isHovered else { return }
            
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                self.model.isExpanded = false
            }
            
            self.scheduleWindowShrink()
        }
        self.collapseWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: workItem)
    }
    
    private func expandPanel() {
        let screen = targetScreen()
        let w = model.expandedWidth
        let h = model.expandedHeight
        panel.updatePosition(screen: screen, width: w, height: h, animate: false)
    }
    
    private func scheduleWindowShrink() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) { [weak self] in
            guard let self = self else { return }
            guard !self.model.isExpanded else { return }
            self.resizePanelToRestingState()
        }
    }
    
    private func resizePanelToRestingState() {
        let screen = targetScreen()
        let w = model.currentWidth
        let h = model.currentHeight
        panel.updatePosition(screen: screen, width: w, height: h, animate: false)
    }
    
    private func handleScreenChange() {
        model.detectScreenNotch()
        let screen = targetScreen()
        let w = model.currentWidth
        let h = model.currentHeight
        panel.updatePosition(screen: screen, width: w, height: h, animate: false)
    }
}
