import Cocoa
import SwiftUI
import Combine

@MainActor
public final class MorphController: NSObject {
    public private(set) static weak var shared: MorphController?
    
    public let model: NotchModel
    public private(set) var panel: NotchPanel!
    public private(set) var hostingView: PassthroughHostingView<MorphIslandView>!
    public private(set) var collapseWorkItem: DispatchWorkItem?
    public private(set) var hoverIntentWorkItem: DispatchWorkItem?
    public var hoverDwellDelay: TimeInterval = MorphEnvironment.isTestingEnvironment ? 0.0 : 0.32
    public private(set) var dwellEntryLocation: NSPoint?
    public private(set) var dwellStartTime: TimeInterval = 0
    private var shrinkWorkItem: DispatchWorkItem?
    private var lastMousePoint: NSPoint?
    private var lastMouseTimestamp: TimeInterval = 0
    private var lastClickTimestamp: TimeInterval = 0
    public private(set) var lastUnderlyingInteractionTimestamp: TimeInterval = 0
    public private(set) var isExplicitlyDismissed: Bool = false
    public private(set) var lastDismissalTimestamp: TimeInterval = 0
    private var cancellables = Set<AnyCancellable>()
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var clickMonitor: Any?
    private var keyMonitor: Any?
    private var scrollMonitor: Any?
    private var appSwitchObserver: NSObjectProtocol?
    private var mousePollTimer: Timer?
    
    public init(model: NotchModel? = nil) {
        self.model = model ?? NotchModel()
        super.init()
        Self.shared = self
        setupPanel()
        setupObservers()
        setupMouseMonitors()
    }
    
    private var currentTargetScreen: NSScreen?
    
    public func targetScreen() -> NSScreen {
        // Morph UI is strictly kept anchored under the physical notch of the user's primary/laptop screen.
        // It never renders or jumps to external/bigger displays.
        return NSScreen.screens.first(where: { $0.auxiliaryTopLeftArea != nil }) ?? NSScreen.main ?? NSScreen.screens[0]
    }
    
    private func setupPanel() {
        let screen = targetScreen()
        self.currentTargetScreen = screen
        model.detectScreenNotch(for: screen)
        
        let width = model.currentWidth
        let height = model.currentHeight
        let x = floor(screen.frame.midX - (width / 2))
        let topBarHeight = max(screen.safeAreaInsets.top, screen.frame.maxY - screen.visibleFrame.maxY)
        let topClearance: CGFloat = 14.0
        let y = floor(screen.frame.maxY - topBarHeight - topClearance - height)
        let initialFrame = NSRect(x: x, y: y, width: width, height: height)
        
        self.panel = NotchPanel(contentRect: initialFrame)
        if !MorphEnvironment.isTestingEnvironment {
            // Click-through by default while collapsed so background browser tabs are 100% clickable
            self.panel.ignoresMouseEvents = true
        }
        
        let islandView = MorphIslandView(
            model: model,
            onMouseEnter: { [weak self] in
                self?.checkMousePosition(NSEvent.mouseLocation)
            },
            onMouseExit: { [weak self] in
                self?.handleMouseExit()
            }
        )
        
        self.hostingView = PassthroughHostingView(rootView: islandView)
        self.hostingView.onMouseEnter = { [weak self] in
            self?.checkMousePosition(NSEvent.mouseLocation)
        }
        self.hostingView.onMouseMove = { [weak self] point in
            self?.checkMousePosition(point)
        }
        self.hostingView.onMouseExit = { [weak self] in
            self?.handleMouseExit()
        }
        self.hostingView.isExpanded = { [weak self] in
            guard let self = self else { return false }
            return self.model.isExpanded || self.model.isSpotlightBarActive || self.model.isCompactActive || self.model.isEditingTimerInPill || self.model.isTimerPopupActive || self.model.islandState != .resting || (self.model.isGlassIslandEnabled && self.model.glassIslandState != .idle)
        }
        
        self.hostingView.getActiveBounds = { [weak self] in
            guard let self = self else { return .zero }
            let w = self.model.currentWidth
            let h = self.model.currentHeight
            let bounds = self.hostingView.bounds
            let originX = max(0, (bounds.width - w) / 2)
            let originY = max(0, bounds.height - h)
            let width = min(bounds.width, max(w, bounds.width))
            let height = min(bounds.height, max(h, bounds.height))
            return NSRect(
                x: originX,
                y: originY,
                width: width,
                height: height
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
            YouTubeMusicEngine.shared.attachToHostingView(self.hostingView)
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
        
        // Auto-sync calendar (Google) and YouTube Music whenever the user returns to Morph from an external app (e.g. browser sign-in)
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    self.model.calendar.syncWithGoogle()
                    if !self.model.media.isSignedIn {
                        YouTubeMusicEngine.shared.syncSessionFromBrowser()
                    }
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
            
        // Observe spotlight typing bar and timer popup state changes to dynamically resize the panel
        Publishers.Merge(
            model.$isTimerPopupActive.map { _ in () },
            model.$isSpotlightBarActive.map { _ in () }
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in
            guard let self = self else { return }
            if self.model.currentWidth >= self.panel.frame.width {
                self.updatePanelGeometry(animate: false)
            } else {
                self.scheduleWindowShrink()
            }
        }
        .store(in: &cancellables)
            
        // Explicitly observe formTracker detection state to guarantee immediate panel resizing
        model.formTracker.$isFormDetected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] detected in
                guard let self = self else { return }
                NSLog("[MORPH-FORM] $isFormDetected sink: detected=%d, isExpanded=%d, currentWidth=%.1f, compactHUDMode=%@", detected ? 1 : 0, self.model.isExpanded ? 1 : 0, self.model.currentWidth, self.model.compactHUDMode.rawValue)
                guard !self.model.isExpanded else { return }
                self.resizePanelToRestingState()
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
        
        // 1. High-frequency 50ms (20Hz) active mouse location poller.
        // Direct main thread read from macOS WindowServer via RunLoop.common.
        // Guarantees immediate, rock-solid hover detection across all windows and displays,
        // completely bypassing macOS background event monitor throttling.
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            MainActor.assumeIsolated {
                self.checkMousePosition(NSEvent.mouseLocation)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.mousePollTimer = timer
        
        // 2. Global event monitor for mouse moves and drags
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged]) { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.async { [weak self] in
                self?.checkMousePosition(NSEvent.mouseLocation)
            }
        }
        
        // 3. Local event monitor for inside-window movements
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged]) { [weak self] event in
            guard let self = self else { return event }
            self.checkMousePosition(NSEvent.mouseLocation)
            return event
        }
        
        // 4. Universal platform click & drag monitor: detects mouse down & drag events in ANY underlying application
        // (code editors, terminal windows, web browsers, design tools, document suites, Finder, etc.)
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [
            .leftMouseDown, .rightMouseDown, .otherMouseDown,
            .leftMouseDragged, .rightMouseDragged, .otherMouseDragged
        ]) { [weak self] _ in
            guard let self = self else { return }
            let mouseLoc = NSEvent.mouseLocation
            if self.isMouseInsideMorphUI(mouseLoc) {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    if self.isExplicitlyDismissed { return }
                    self.panel?.ignoresMouseEvents = false
                    if self.model.islandState == .resting {
                        self.handleMouseEnter()
                    }
                }
            } else {
                DispatchQueue.main.async { [weak self] in
                    self?.registerUnderlyingAppInteraction()
                }
            }
        }
        
        // 5. Universal platform keystroke monitor: detects active typing in ANY underlying application
        keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.async { [weak self] in
                self?.registerUnderlyingAppInteraction()
            }
        }
        
        // 6. Universal platform scroll monitor: detects trackpad/mousewheel scrolling in ANY underlying application
        scrollMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.scrollWheel]) { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.async { [weak self] in
                self?.registerUnderlyingAppInteraction()
            }
        }
        
        // 7. Universal workspace application activation observer: detects Cmd+Tab or clicking windows
        appSwitchObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                self?.registerUnderlyingAppInteraction()
            }
        }
    }
    
    /// Records user interaction with ANY underlying application on macOS, immediately cancelling
    /// any pending hover dwell expansion and enforcing a cooldown buffer.
    public func registerUnderlyingAppInteraction() {
        if !model.isExpanded {
            hoverIntentWorkItem?.cancel()
            hoverIntentWorkItem = nil
            let now = ProcessInfo.processInfo.systemUptime
            lastUnderlyingInteractionTimestamp = now
            lastClickTimestamp = now
        }
    }
    
    public func dismissToStealth() {
        isExplicitlyDismissed = true
        lastDismissalTimestamp = ProcessInfo.processInfo.systemUptime
        hoverIntentWorkItem?.cancel()
        hoverIntentWorkItem = nil
        collapseWorkItem?.cancel()
        collapseWorkItem = nil
        shrinkWorkItem?.cancel()
        shrinkWorkItem = nil
        
        // Immediately ignore mouse events so no stray events at the old 'X' coordinate are captured
        panel?.ignoresMouseEvents = true
        
        withAnimation(MorphUniversalAnimation.stealthRetraction) {
            model.resetTransientStateOnCollapse()
        }
        scheduleWindowShrink()
    }
    
    public func activeUIRect() -> NSRect {
        let screen = targetScreen()
        let w = model.currentWidth
        let h = model.currentHeight
        let x = floor(screen.frame.midX - (w / 2))
        let topBarHeight = max(screen.safeAreaInsets.top, screen.frame.maxY - screen.visibleFrame.maxY)
        let topClearance: CGFloat = 14.0
        let y = floor(screen.frame.maxY - topBarHeight - topClearance - h)
        return NSRect(x: x, y: y, width: w, height: h)
    }
    
    public func isMouseInsideMorphUI(_ mouseLoc: NSPoint) -> Bool {
        let baseRect = activeUIRect()
        let isExtended = (model.isGlassIslandEnabled && model.glassIslandState != .idle) ||
            ((model.interactionMode == .spotlightBar)
            ? (model.isSpotlightBarActive || model.isTimerPopupActive || model.isExpanded)
            : model.isExpanded)
        let hPadding: CGFloat = isExtended ? 16 : (model.isCompactActive ? 14 : 0)
        let bottomPadding: CGFloat = isExtended ? 16 : (model.isCompactActive ? 12 : 0)
        let topPadding: CGFloat = isExtended ? 10 : 0
        
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
        let now = ProcessInfo.processInfo.systemUptime
        
        // Calculate cursor velocity to distinguish fast sweeps to browser tabs from intentional hovering
        var velocity: CGFloat = 0
        if let lastPt = lastMousePoint, lastMouseTimestamp > 0 {
            let dt = now - lastMouseTimestamp
            if dt > 0.001 {
                let dist = hypot(mouseLoc.x - lastPt.x, mouseLoc.y - lastPt.y)
                velocity = dist / CGFloat(dt)
            }
        }
        lastMousePoint = mouseLoc
        lastMouseTimestamp = now
        
        let isMorphOpen = (model.isGlassIslandEnabled && model.glassIslandState != .idle) ||
            ((model.interactionMode == .spotlightBar)
            ? (model.isSpotlightBarActive || model.isTimerPopupActive || model.isExpanded)
            : model.isExpanded)
        
        if isInside {
            collapseWorkItem?.cancel()
            collapseWorkItem = nil
            panel?.ignoresMouseEvents = shouldIgnoreMouseEvents
            
            if isExplicitlyDismissed {
                if now - lastDismissalTimestamp > 1.2 {
                    isExplicitlyDismissed = false
                } else {
                    hoverIntentWorkItem?.cancel()
                    hoverIntentWorkItem = nil
                    return
                }
            }
            
            if !isMorphOpen {
                // If user interacted recently (< 450ms ago) in ANY background application
                // (clicks, drags, typing, scrolling, app switches), they are actively working
                // in their underlying workspace — suppress hover expansion!
                let timeSinceInteraction = max(now - lastUnderlyingInteractionTimestamp, now - lastClickTimestamp)
                if timeSinceInteraction < 0.45 {
                    hoverIntentWorkItem?.cancel()
                    hoverIntentWorkItem = nil
                    dwellEntryLocation = mouseLoc
                    dwellStartTime = now
                    if !MorphEnvironment.isTestingEnvironment {
                        panel?.ignoresMouseEvents = true
                    }
                    return
                }
                
                // Point 2: Differentiate Pass-By Motion from Intentional Opening:
                // If velocity > 35 pt/s, cursor is traveling/scrolling across the screen (pass-by)
                if velocity > 35 {
                    hoverIntentWorkItem?.cancel()
                    hoverIntentWorkItem = nil
                    dwellEntryLocation = mouseLoc
                    dwellStartTime = now
                    if !MorphEnvironment.isTestingEnvironment {
                        panel?.ignoresMouseEvents = true
                    }
                    return
                }
                
                // Check displacement from entry point
                if let entry = dwellEntryLocation {
                    let displacement = hypot(mouseLoc.x - entry.x, mouseLoc.y - entry.y)
                    if displacement > 8 {
                        // Cursor moved across the notch area (pass-by sweep/scroll)
                        hoverIntentWorkItem?.cancel()
                        hoverIntentWorkItem = nil
                        dwellEntryLocation = mouseLoc
                        dwellStartTime = now
                        if !MorphEnvironment.isTestingEnvironment {
                            panel?.ignoresMouseEvents = true
                        }
                        return
                    }
                } else {
                    dwellEntryLocation = mouseLoc
                    dwellStartTime = now
                }
                
                if hoverDwellDelay <= 0 {
                    handleMouseEnter()
                    return
                }
                
                // Intentional Hover Dwell: require hoverDwellDelay stationary pause over the island before expanding
                if hoverIntentWorkItem == nil {
                    let entry = mouseLoc
                    let workItem = DispatchWorkItem { [weak self] in
                        guard let self = self else { return }
                        let currentLoc = MorphEnvironment.isTestingEnvironment ? (self.lastMousePoint ?? entry) : NSEvent.mouseLocation
                        let finalDisplacement = hypot(currentLoc.x - entry.x, currentLoc.y - entry.y)
                        if self.isMouseInsideMorphUI(currentLoc) && finalDisplacement <= 10 {
                            self.handleMouseEnter()
                        }
                        self.hoverIntentWorkItem = nil
                    }
                    self.hoverIntentWorkItem = workItem
                    DispatchQueue.main.asyncAfter(deadline: .now() + hoverDwellDelay, execute: workItem)
                }
            } else {
                model.isHovered = true
            }
        } else {
            hoverIntentWorkItem?.cancel()
            hoverIntentWorkItem = nil
            dwellEntryLocation = nil
            dwellStartTime = 0
            
            if now - lastDismissalTimestamp > 0.8 {
                isExplicitlyDismissed = false
            }
            
            if isMorphOpen && !model.isPinned && !model.isCommandBarPresented && !model.calendar.isAddingEvent && !model.dropShelf.isDraggingOut && !model.dropShelf.isHeldOpen {
                if collapseWorkItem == nil {
                    handleMouseExit()
                }
            } else if !isMorphOpen {
                model.isHovered = false
                panel?.ignoresMouseEvents = shouldIgnoreMouseEvents
            }
        }
    }
    
    public func handleMouseEnter() {
        if isExplicitlyDismissed {
            let now = ProcessInfo.processInfo.systemUptime
            if now - lastDismissalTimestamp < 0.8 {
                return
            }
            isExplicitlyDismissed = false
        }
        
        hoverIntentWorkItem?.cancel()
        hoverIntentWorkItem = nil
        collapseWorkItem?.cancel()
        collapseWorkItem = nil
        shrinkWorkItem?.cancel()
        shrinkWorkItem = nil
        
        model.isHovered = true
        panel?.ignoresMouseEvents = false
        
        if model.isGlassIslandEnabled {
            if model.glassIslandState == .idle {
                model.glassPromptText = ""
                withAnimation(MorphUniversalAnimation.stateExpansion) {
                    model.setGlassIslandState(.prompt)
                }
                expandPanel()
                panel?.ignoresMouseEvents = false
                if !MorphEnvironment.isTestingEnvironment {
                    NSApp.activate(ignoringOtherApps: true)
                    panel.makeKeyAndOrderFront(nil)
                }
            }
            return
        }
        
        if model.interactionMode == .spotlightBar && !model.isCompactActive {
            // Fresh spotlight query on intentional open (Point 3)
            model.spotlightQuery = ""
            withAnimation(MorphUniversalAnimation.stateElongation) {
                model.isSpotlightBarActive = true
            }
            expandPanel()
            panel?.ignoresMouseEvents = false
            if !MorphEnvironment.isTestingEnvironment {
                NSApp.activate(ignoringOtherApps: true)
                panel.makeKeyAndOrderFront(nil)
            }
        } else {
            guard !model.isExpanded else {
                model.isHovered = true
                return
            }
            if !model.isCompactActive {
                model.syncExpandedFeatureWithActiveContext()
                withAnimation(MorphUniversalAnimation.stateExpansion) {
                    self.model.isExpanded = true
                }
                expandPanel()
                panel?.ignoresMouseEvents = false
                if !MorphEnvironment.isTestingEnvironment {
                    panel.makeKey()
                }
            }
        }
    }
    
    public func handleMouseExit() {
        if model.isGlassIslandEnabled && (model.isGlassIslandPinned || !model.glassPromptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
            return
        }
        guard !model.isPinned && !model.isCommandBarPresented && !model.calendar.isAddingEvent && !model.dropShelf.isDraggingOut && !model.dropShelf.isHeldOpen else { return }
        if model.isTimerPopupActive || model.isEditingTimerInPill { return }
        if !MorphEnvironment.isTestingEnvironment && isMouseInsideMorphUI(NSEvent.mouseLocation) {
            model.isHovered = true
            return
        }
        
        collapseWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            if self.model.isGlassIslandEnabled && (self.model.isGlassIslandPinned || !self.model.glassPromptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                self.collapseWorkItem = nil
                return
            }
            guard !self.model.isPinned && !self.model.isCommandBarPresented && !self.model.calendar.isAddingEvent && !self.model.dropShelf.isDraggingOut && !self.model.dropShelf.isHeldOpen else { return }
            if self.model.isTimerPopupActive || self.model.isEditingTimerInPill { return }
            
            // Sensitive verification: Is cursor still outside Morph's UI space?
            let currentMouse = NSEvent.mouseLocation
            if self.isMouseInsideMorphUI(currentMouse) {
                self.model.isHovered = true
                self.collapseWorkItem = nil
                return
            }
            
            self.model.isHovered = false
            withAnimation(MorphUniversalAnimation.stealthRetraction) {
                self.model.resetTransientStateOnCollapse()
            }
            self.scheduleWindowShrink()
            self.collapseWorkItem = nil
        }
        self.collapseWorkItem = workItem
        let delay: Double = model.isGlassIslandEnabled ? 0.52 : 0.25
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }
    
    public var shouldIgnoreMouseEvents: Bool {
        if model.isGlassIslandEnabled && model.glassIslandState != .idle {
            return false
        }
        let isResting = (model.islandState == .resting && model.compactHUDMode == .none && !model.isHovered && !model.isSpotlightBarActive)
        return isResting
    }
    
    public func updatePanelGeometry(animate: Bool = true) {
        let screen = targetScreen()
        let w = model.currentWidth.rounded()
        let h = model.currentHeight.rounded()
        panel.updatePosition(screen: screen, width: w, height: h, animate: animate)
        panel.ignoresMouseEvents = shouldIgnoreMouseEvents
    }
    
    public func expandPanel() {
        updatePanelGeometry(animate: false)
    }
    
    public func scheduleWindowShrink() {
        shrinkWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            guard !self.model.isExpanded && !self.model.isSpotlightBarActive && !self.model.isTimerPopupActive && (!self.model.isGlassIslandEnabled || self.model.glassIslandState == .idle) else { return }
            self.applyRestingPanelGeometry()
            self.shrinkWorkItem = nil
        }
        self.shrinkWorkItem = workItem
        // Exactly synchronized with the 260ms retraction curve + 20ms buffer
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28, execute: workItem)
    }
    
    private func resizePanelToRestingState() {
        guard !model.isExpanded && !model.isSpotlightBarActive && !model.isTimerPopupActive else {
            updatePanelGeometry(animate: false)
            return
        }
        let w = model.currentWidth.rounded()
        if w < panel.frame.width && !model.isExpanded {
            // Shrinking: give retraction spring buffer so shrinking wings don't get clipped
            scheduleWindowShrink()
        } else {
            applyRestingPanelGeometry()
        }
    }
    
    public func applyRestingPanelGeometry() {
        let screen = targetScreen()
        let w = model.currentWidth.rounded()
        let h = model.currentHeight.rounded()
        panel.updatePosition(screen: screen, width: w, height: h, animate: false)
        panel.ignoresMouseEvents = shouldIgnoreMouseEvents
    }
    
    private func handleScreenChange() {
        let screen = targetScreen()
        currentTargetScreen = screen
        model.detectScreenNotch(for: screen)
        let w = model.currentWidth
        let h = model.currentHeight
        panel.updatePosition(screen: screen, width: w, height: h, animate: false)
    }
    
    /// Tears down observers, monitors, and explicitly orders out the panel
    public func teardown() {
        hoverIntentWorkItem?.cancel()
        hoverIntentWorkItem = nil
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
        if let cm = clickMonitor {
            NSEvent.removeMonitor(cm)
            clickMonitor = nil
        }
        if let km = keyMonitor {
            NSEvent.removeMonitor(km)
            keyMonitor = nil
        }
        if let sm = scrollMonitor {
            NSEvent.removeMonitor(sm)
            scrollMonitor = nil
        }
        if let aso = appSwitchObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(aso)
            appSwitchObserver = nil
        }
        mousePollTimer?.invalidate()
        mousePollTimer = nil
        DistributedNotificationCenter.default().removeObserver(self)
        panel?.orderOut(nil)
    }
}
