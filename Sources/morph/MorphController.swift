import Cocoa
import SwiftUI
import Combine

@MainActor
public final class MorphController: NSObject {
    public let model: NotchModel
    public private(set) var panel: NotchPanel!
    private var hostingView: PassthroughHostingView<MorphIslandView>!
    public private(set) var collapseWorkItem: DispatchWorkItem?
    private var shrinkWorkItem: DispatchWorkItem?
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
        self.hostingView.isExpanded = { [weak self] in
            self?.model.isExpanded ?? false
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
        
        self.hostingView.onDraggingEntered = { [weak self] sender in
            guard let self = self else { return [] }
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                    self.model.dropShelf.isDraggingOverNotch = true
                }
            }
            return .copy
        }
        
        self.hostingView.onDraggingUpdated = { _ in
            return .copy
        }
        
        self.hostingView.onDraggingExited = { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                    self.model.dropShelf.isDraggingOverNotch = false
                }
            }
        }
        
        self.hostingView.onPerformDragOperation = { [weak self] sender in
            guard let self = self else { return false }
            let pasteboard = sender.draggingPasteboard
            guard let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], !urls.isEmpty else {
                Task { @MainActor [weak self] in
                    self?.model.dropShelf.isDraggingOverNotch = false
                }
                return false
            }
            
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                    self.model.dropShelf.isDraggingOverNotch = false
                    self.model.dropShelf.stageFiles(urls: urls)
                    self.model.openContextualFeature(.dropShelf)
                }
            }
            return true
        }
        
        self.panel.contentView = hostingView
        self.panel.onKeyEquivalent = { event in
            ShortcutManager.shared.handleKeyEvent(event)
        }
        if !MorphEnvironment.isTestingEnvironment {
            self.panel.orderFrontRegardless()
        }
    }
    
    private func setupObservers() {
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.handleScreenChange()
                }
            }
            .store(in: &cancellables)
        
        // Auto-sync calendar whenever the user returns to Morph from an external app (e.g. Chrome Google sign-in)
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    self.model.calendar.syncWithSystemCalendar()
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
            
        // Observe any submodel state changes to dynamically resize the compact notch window
        model.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self, !self.model.isExpanded else { return }
                self.resizePanelToRestingState()
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
        
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleSelectTabNotification(_:)),
            name: NSNotification.Name("com.morph.selectTab"),
            object: nil
        )
        
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleToggleTimerNotification(_:)),
            name: NSNotification.Name("com.morph.toggleTimer"),
            object: nil
        )
        
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleToggleMediaNotification(_:)),
            name: NSNotification.Name("com.morph.toggleMedia"),
            object: nil
        )
        
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleTogglePinNoteNotification(_:)),
            name: NSNotification.Name("com.morph.togglePinNote"),
            object: nil
        )
        
        // Contextual IPC Observers (Listen on both Distributed and Default for testability)
        let ipcNames = [
            "com.morph.dropShelf.stage": #selector(handleStageFileNotification(_:))
        ]
        
        for (name, selector) in ipcNames {
            DistributedNotificationCenter.default().addObserver(
                self,
                selector: selector,
                name: NSNotification.Name(name),
                object: nil
            )
            NotificationCenter.default.addObserver(
                self,
                selector: selector,
                name: NSNotification.Name(name),
                object: nil
            )
        }
    }
    
    @objc private func handleSelectTabNotification(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let tabRaw = notification.userInfo?["tab"] as? String else { return }
            switch tabRaw.lowercased() {
            case "profile": self.model.openFeature(.profile)
            case "home": self.model.returnToHome()
            case "timer", "focus": self.model.openFeature(.timer)
            case "music": self.model.openFeature(.music)
            case "notes": self.model.openFeature(.notes)
            case "calendar": self.model.openFeature(.calendar)
            default: break
            }
        }
    }
    
    @objc private func handleToggleExpandNotification(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.model.isExpanded {
                self.model.isPinned = false
                withAnimation(.spring(response: 0.30, dampingFraction: 0.86)) {
                    self.model.isExpanded = false
                }
                self.scheduleWindowShrink()
            } else {
                self.handleMouseEnter()
            }
        }
    }
    
    @objc private func handleTogglePinNotification(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            self?.model.togglePin()
        }
    }
    
    @objc private func handleToggleTimerNotification(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            self?.model.pomodoro.toggle()
        }
    }
    
    @objc private func handleToggleMediaNotification(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            self?.model.media.togglePlay()
        }
    }
    
    @objc private func handleTogglePinNoteNotification(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            self?.model.isNotePinnedToNotch.toggle()
        }
    }
    
    @objc private func handleStageFileNotification(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let path = notification.userInfo?["path"] as? String {
                let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
                self.model.dropShelf.stageFile(url: url)
            }
        }
    }
    
    private func setupMouseMonitors() {
        guard !MorphEnvironment.isTestingEnvironment else { return }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkMousePosition(NSEvent.mouseLocation)
            }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.checkMousePosition(NSEvent.mouseLocation)
            }
            return event
        }
    }
    
    public func activeUIRect() -> NSRect {
        let screen = targetScreen()
        let w = model.isExpanded ? model.expandedWidth : model.currentWidth
        let h = model.isExpanded ? model.expandedHeight : model.currentHeight
        let x = screen.frame.midX - (w / 2)
        let y = screen.frame.maxY - h
        return NSRect(x: x, y: y, width: w, height: h)
    }
    
    public func isMouseInsideMorphUI(_ mouseLoc: NSPoint) -> Bool {
        let baseRect = activeUIRect()
        let hPadding: CGFloat = model.isExpanded ? 10 : 8
        let bottomPadding: CGFloat = model.isExpanded ? 12 : 8
        let topPadding: CGFloat = 6
        
        let sensitiveRect = NSRect(
            x: baseRect.origin.x - hPadding,
            y: baseRect.origin.y - bottomPadding,
            width: baseRect.width + (hPadding * 2),
            height: baseRect.height + bottomPadding + topPadding
        )
        return sensitiveRect.contains(mouseLoc)
    }
    
    public func checkMousePosition(_ mouseLoc: NSPoint) {
        let isInside = isMouseInsideMorphUI(mouseLoc)
        
        if isInside {
            collapseWorkItem?.cancel()
            collapseWorkItem = nil
            if !model.isExpanded {
                handleMouseEnter()
            } else {
                model.isHovered = true
            }
        } else {
            if model.isExpanded && !model.isPinned && !model.calendar.isAddingEvent && !model.dropShelf.isDraggingOut && !model.dropShelf.isHeldOpen {
                if collapseWorkItem == nil {
                    handleMouseExit()
                }
            } else if !model.isExpanded {
                model.isHovered = false
            }
        }
    }
    
    public func handleMouseEnter() {
        collapseWorkItem?.cancel()
        collapseWorkItem = nil
        shrinkWorkItem?.cancel()
        shrinkWorkItem = nil
        
        guard !model.isHovered || !model.isExpanded else { return }
        model.isHovered = true
        
        if !model.isExpanded {
            model.syncExpandedFeatureWithActiveContext()
            expandPanel()
            // Fluid Apple Dynamic Island expansion spring: swift organic attack with natural settle
            withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                self.model.isExpanded = true
            }
            if !MorphEnvironment.isTestingEnvironment {
                panel.makeKey()
            }
        }
    }
    
    public func handleMouseExit() {
        guard !model.isPinned && !model.calendar.isAddingEvent && !model.dropShelf.isDraggingOut && !model.dropShelf.isHeldOpen else { return }
        
        collapseWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            guard !self.model.isPinned && !self.model.calendar.isAddingEvent && !self.model.dropShelf.isDraggingOut && !self.model.dropShelf.isHeldOpen else { return }
            
            // Sensitive verification: Is cursor still outside Morph's UI space?
            let currentMouse = NSEvent.mouseLocation
            if self.isMouseInsideMorphUI(currentMouse) {
                self.model.isHovered = true
                self.collapseWorkItem = nil
                return
            }
            
            self.model.isHovered = false
            // Crisp, zero-clutter collapse spring: quick, controlled retraction without bouncing or stutter
            withAnimation(.spring(response: 0.30, dampingFraction: 0.86)) {
                self.model.isExpanded = false
            }
            self.scheduleWindowShrink()
            self.collapseWorkItem = nil
        }
        self.collapseWorkItem = workItem
        // 250ms intention buffer prevents jittery accidental dismissals while keeping UI immediate
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: workItem)
    }
    
    private func expandPanel() {
        let screen = targetScreen()
        let w = model.expandedWidth
        let h = model.expandedHeight
        panel.updatePosition(screen: screen, width: w, height: h, animate: false)
    }
    
    private func scheduleWindowShrink() {
        shrinkWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            guard !self.model.isExpanded else { return }
            self.resizePanelToRestingState()
            self.shrinkWorkItem = nil
        }
        self.shrinkWorkItem = workItem
        // Exactly synchronized with the 300ms retraction curve + 40ms buffer
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.34, execute: workItem)
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
    
    /// Tears down observers, monitors, and explicitly orders out the panel
    public func teardown() {
        collapseWorkItem?.cancel()
        collapseWorkItem = nil
        shrinkWorkItem?.cancel()
        shrinkWorkItem = nil
        cancellables.removeAll()
        if let gm = globalMonitor {
            NSEvent.removeMonitor(gm)
            globalMonitor = nil
        }
        if let lm = localMonitor {
            NSEvent.removeMonitor(lm)
            localMonitor = nil
        }
        DistributedNotificationCenter.default().removeObserver(self)
        panel?.orderOut(nil)
    }
}
