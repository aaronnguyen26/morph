import Cocoa
import SwiftUI
import Combine

/// Comprehensive Keyboard Shortcut Manager for Morph
/// Implements standard macOS Cmd (⌘) shortcuts for navigation, window control,
/// feature actions (Timer, Music, Notes, Profile), text editing, and global hotkeys.
@MainActor
public final class ShortcutManager: NSObject {
    public static let shared = ShortcutManager()
    
    public weak var model: NotchModel?
    public weak var controller: MorphController?
    
    private var localKeyMonitor: Any?
    private var globalKeyMonitor: Any?
    private var cancellables = Set<AnyCancellable>()
    
    // Status feedback for shortcut triggers
    @Published public var lastTriggeredShortcut: String?
    
    public override init() {
        super.init()
    }
    
    public func configure(model: NotchModel, controller: MorphController) {
        self.model = model
        self.controller = controller
        
        setupMainMenu()
        setupKeyboardMonitors()
    }
    
    public func removeMonitors() {
        if let local = localKeyMonitor {
            NSEvent.removeMonitor(local)
            localKeyMonitor = nil
        }
        if let global = globalKeyMonitor {
            NSEvent.removeMonitor(global)
            globalKeyMonitor = nil
        }
    }
    
    // MARK: - AppKit Native Main Menu Integration
    public func setupMainMenu() {
        let mainMenu = NSMenu(title: "MorphMainMenu")
        
        // 1. Application Menu (Morph)
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu(title: "Morph")
        appMenu.addItem(withTitle: "About Morph", action: #selector(showAbout), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        
        let prefsItem = NSMenuItem(title: "Preferences / Profile...", action: #selector(openPreferences), keyEquivalent: ",")
        prefsItem.target = self
        appMenu.addItem(prefsItem)
        
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Hide Morph", action: #selector(hideApp), keyEquivalent: "h").target = self
        let hideOthers = NSMenuItem(title: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthers)
        appMenu.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        
        appMenu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "Quit Morph", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        appMenu.addItem(quitItem)
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)
        
        // 2. Edit Menu (Standard macOS Text Editing & Clipboard)
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: NSSelectorFromString("undo:"), keyEquivalent: "z")
        let redoItem = NSMenuItem(title: "Redo", action: NSSelectorFromString("redo:"), keyEquivalent: "Z")
        redoItem.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(redoItem)
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: NSSelectorFromString("cut:"), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: NSSelectorFromString("copy:"), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: NSSelectorFromString("paste:"), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: NSSelectorFromString("selectAll:"), keyEquivalent: "a")
        editMenu.addItem(NSMenuItem.separator())
        
        let newNoteItem = NSMenuItem(title: "New Note / Clear", action: #selector(newNote), keyEquivalent: "n")
        newNoteItem.target = self
        editMenu.addItem(newNoteItem)
        
        let saveNoteItem = NSMenuItem(title: "Save Note", action: #selector(saveNote), keyEquivalent: "s")
        saveNoteItem.target = self
        editMenu.addItem(saveNoteItem)
        
        let copyAllItem = NSMenuItem(title: "Copy All Notes to Clipboard", action: #selector(copyAllNotes), keyEquivalent: "C")
        copyAllItem.keyEquivalentModifierMask = [.command, .shift]
        copyAllItem.target = self
        editMenu.addItem(copyAllItem)
        
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)
        
        // 3. Navigate Menu (Tabs & Views)
        let navMenuItem = NSMenuItem()
        let navMenu = NSMenu(title: "Navigate")
        
        let navHomeItem = NSMenuItem(title: "Home", action: #selector(navHome), keyEquivalent: "1")
        navHomeItem.target = self
        navMenu.addItem(navHomeItem)
        
        let navFocusItem = NSMenuItem(title: "Focus Timer", action: #selector(navFocus), keyEquivalent: "2")
        navFocusItem.target = self
        navMenu.addItem(navFocusItem)
        
        let navMusicItem = NSMenuItem(title: "Music Player", action: #selector(navMusic), keyEquivalent: "3")
        navMusicItem.target = self
        navMenu.addItem(navMusicItem)
        
        let navNotesItem = NSMenuItem(title: "Scratchpad Notes", action: #selector(navNotes), keyEquivalent: "4")
        navNotesItem.target = self
        navMenu.addItem(navNotesItem)
        
        let navProfileItem = NSMenuItem(title: "Profile & Settings", action: #selector(navProfile), keyEquivalent: "5")
        navProfileItem.target = self
        navMenu.addItem(navProfileItem)
        
        navMenu.addItem(NSMenuItem.separator())
        let navBackItem = NSMenuItem(title: "Back to Home", action: #selector(navBack), keyEquivalent: "[")
        navBackItem.target = self
        navMenu.addItem(navBackItem)
        
        navMenuItem.submenu = navMenu
        mainMenu.addItem(navMenuItem)
        
        // 4. Controls Menu (Playback & Timer)
        let controlsMenuItem = NSMenuItem()
        let controlsMenu = NSMenu(title: "Controls")
        
        let playPauseItem = NSMenuItem(title: "Play / Pause Music", action: #selector(togglePlayPause), keyEquivalent: "\r")
        playPauseItem.target = self
        controlsMenu.addItem(playPauseItem)
        
        let nextTrackItem = NSMenuItem(title: "Next Track", action: #selector(nextTrack), keyEquivalent: "]")
        nextTrackItem.target = self
        controlsMenu.addItem(nextTrackItem)
        
        let prevTrackItem = NSMenuItem(title: "Previous Track", action: #selector(prevTrack), keyEquivalent: "[")
        prevTrackItem.target = self
        controlsMenu.addItem(prevTrackItem)
        
        let volUpItem = NSMenuItem(title: "Volume Up", action: #selector(volUp), keyEquivalent: String(utf16CodeUnits: [unichar(NSUpArrowFunctionKey)], count: 1))
        volUpItem.target = self
        controlsMenu.addItem(volUpItem)
        
        let volDownItem = NSMenuItem(title: "Volume Down", action: #selector(volDown), keyEquivalent: String(utf16CodeUnits: [unichar(NSDownArrowFunctionKey)], count: 1))
        volDownItem.target = self
        controlsMenu.addItem(volDownItem)
        
        let likeItem = NSMenuItem(title: "Like / Favorite Track", action: #selector(toggleLike), keyEquivalent: "l")
        likeItem.target = self
        controlsMenu.addItem(likeItem)
        
        let muteItem = NSMenuItem(title: "Mute / Unmute", action: #selector(toggleMute), keyEquivalent: "u")
        muteItem.target = self
        controlsMenu.addItem(muteItem)
        
        controlsMenu.addItem(NSMenuItem.separator())
        
        let timerToggleItem = NSMenuItem(title: "Start / Pause Focus Timer", action: #selector(toggleTimer), keyEquivalent: "t")
        timerToggleItem.target = self
        controlsMenu.addItem(timerToggleItem)
        
        let timerResetItem = NSMenuItem(title: "Reset Focus Timer", action: #selector(resetTimer), keyEquivalent: "R")
        timerResetItem.keyEquivalentModifierMask = [.command, .shift]
        timerResetItem.target = self
        controlsMenu.addItem(timerResetItem)
        
        controlsMenuItem.submenu = controlsMenu
        mainMenu.addItem(controlsMenuItem)
        
        // 5. Window Menu (Morph Island Sizing & Pinning)
        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        
        let closeItem = NSMenuItem(title: "Close / Collapse Island", action: #selector(closeOrCollapse), keyEquivalent: "w")
        closeItem.target = self
        windowMenu.addItem(closeItem)
        
        let minItem = NSMenuItem(title: "Minimize to Notch", action: #selector(minimizeToNotch), keyEquivalent: "m")
        minItem.target = self
        windowMenu.addItem(minItem)
        
        let pinItem = NSMenuItem(title: "Pin Island Open", action: #selector(togglePin), keyEquivalent: "p")
        pinItem.target = self
        windowMenu.addItem(pinItem)
        
        let refreshItem = NSMenuItem(title: "Sync Profile & Refresh", action: #selector(refreshProfile), keyEquivalent: "r")
        refreshItem.target = self
        windowMenu.addItem(refreshItem)
        
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)
        
        NSApplication.shared.mainMenu = mainMenu
    }
    
    // MARK: - Key Event Monitors
    private func setupKeyboardMonitors() {
        // Local Monitor: Captures key events directed to Morph
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self = self else { return event }
            if self.handleKeyEvent(event) {
                return nil // Event consumed
            }
            return event
        }
        
        // Global Monitor: Captures global hotkeys from anywhere on macOS
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self = self else { return }
            self.handleGlobalKeyEvent(event)
        }
    }
    
    // MARK: - Direct Key Handling (Local & Panel Key Equivalent)
    @discardableResult
    public func handleKeyEvent(_ event: NSEvent) -> Bool {
        guard let model = model else { return false }
        
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let isCmd = flags.contains(.command)
        let isShift = flags.contains(.shift)
        let isOpt = flags.contains(.option)
        let isCtrl = flags.contains(.control)
        
        // Check if user is typing in a text field or text editor
        let isEditingText: Bool = {
            if let responder = NSApp.keyWindow?.firstResponder {
                return responder is NSTextView || responder is NSTextField
            }
            return false
        }()
        
        // 1. Global / Window toggles with Cmd+Option
        if isCmd && isOpt {
            switch event.charactersIgnoringModifiers?.lowercased() {
            case "m":
                toggleExpand()
                return true
            case "p":
                togglePin()
                return true
            case " ":
                togglePlayPause()
                return true
            case "t":
                toggleTimer()
                return true
            default:
                break
            }
        }
        
        // 2. Escape: Collapse island if expanded, or return to home
        if event.keyCode == 53 { // Escape
            if model.isExpanded {
                if model.selectedTab != .home {
                    model.returnToHome()
                } else {
                    collapseIsland()
                }
                return true
            }
            return false
        }
        
        // 3. Command shortcuts
        if isCmd && !isCtrl {
            // Text editing bypass: Allow standard Cmd+A, C, X, V, Z in active text fields
            if isEditingText && !isShift && !isOpt {
                let char = event.charactersIgnoringModifiers?.lowercased() ?? ""
                if ["a", "c", "x", "v", "z"].contains(char) {
                    return false // Let system text responder handle it natively
                }
            }
            
            // Cmd + Shift shortcuts
            if isShift {
                switch event.charactersIgnoringModifiers?.lowercased() {
                case "c":
                    copyAllNotes()
                    return true
                case "r":
                    resetTimer()
                    return true
                case "s":
                    skipTimer()
                    return true
                case "p":
                    togglePinNoteToNotch()
                    return true
                case "z":
                    // Redo will be handled by responder or edit menu
                    return false
                default:
                    break
                }
            }
            
            // Standard single Cmd shortcuts
            let char = event.charactersIgnoringModifiers?.lowercased() ?? ""
            
            switch char {
            // Tab Navigation
            case "1", "0":
                navHome()
                return true
            case "2":
                navFocus()
                return true
            case "3":
                navMusic()
                return true
            case "4":
                navNotes()
                return true
            case "5":
                navProfile()
                return true
            case ",":
                openPreferences()
                return true
            case "[":
                if model.selectedTab == .music {
                    prevTrack()
                } else {
                    navBack()
                }
                return true
            case "]":
                nextTrack()
                return true
                
            // Window & App Management
            case "w":
                closeOrCollapse()
                return true
            case "m":
                minimizeToNotch()
                return true
            case "p":
                togglePin()
                return true
            case "r":
                refreshProfile()
                return true
            case "h":
                hideApp()
                return true
            case "q":
                quitApp()
                return true
                
            // Notes & Features
            case "n":
                newNote()
                return true
            case "s":
                saveNote()
                return true
            case "l":
                toggleLike()
                return true
            case "u":
                toggleMute()
                return true
                
            // Enter / Return (keyCode 36): Contextual play/pause or timer
            case "\r":
                if model.selectedTab == .timer {
                    toggleTimer()
                } else if model.selectedTab == .music {
                    togglePlayPause()
                } else {
                    // Default home action: toggle timer if idle, or toggle music
                    togglePlayPause()
                }
                return true
                
            default:
                // Arrow navigation
                switch event.keyCode {
                case 126: // Up Arrow
                    volUp()
                    return true
                case 125: // Down Arrow
                    volDown()
                    return true
                case 124: // Right Arrow
                    nextTrack()
                    return true
                case 123: // Left Arrow
                    prevTrack()
                    return true
                default:
                    break
                }
            }
        }
        
        return false
    }
    
    // MARK: - Global Key Handling
    private func handleGlobalKeyEvent(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let isCmd = flags.contains(.command)
        let isOpt = flags.contains(.option)
        
        if isCmd && isOpt {
            switch event.charactersIgnoringModifiers?.lowercased() {
            case "m":
                Task { @MainActor in
                    self.toggleExpand()
                }
            case "p":
                Task { @MainActor in
                    self.togglePin()
                }
            case " ":
                Task { @MainActor in
                    self.togglePlayPause()
                }
            case "t":
                Task { @MainActor in
                    self.toggleTimer()
                }
            default:
                break
            }
        }
    }
    
    // MARK: - Action Selectors
    @objc public func showAbout() {
        NSApplication.shared.orderFrontStandardAboutPanel(nil)
    }
    
    @objc public func openPreferences() {
        guard let model = model else { return }
        model.openFeature(.profile)
        ensurePanelKey()
        lastTriggeredShortcut = "⌘, Profile"
    }
    
    @objc public func hideApp() {
        collapseIsland()
        lastTriggeredShortcut = "⌘H Hide"
    }
    
    @objc public func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    // Navigation
    @objc public func navHome() {
        guard let model = model else { return }
        model.openFeature(.home)
        ensurePanelKey()
        lastTriggeredShortcut = "⌘1 Home"
    }
    
    @objc public func navFocus() {
        guard let model = model else { return }
        model.openFeature(.timer)
        ensurePanelKey()
        lastTriggeredShortcut = "⌘2 Focus"
    }
    
    @objc public func navMusic() {
        guard let model = model else { return }
        model.openFeature(.music)
        ensurePanelKey()
        lastTriggeredShortcut = "⌘3 Music"
    }
    
    @objc public func navNotes() {
        guard let model = model else { return }
        model.openFeature(.notes)
        ensurePanelKey()
        lastTriggeredShortcut = "⌘4 Notes"
    }
    
    @objc public func navProfile() {
        guard let model = model else { return }
        model.openFeature(.profile)
        ensurePanelKey()
        lastTriggeredShortcut = "⌘5 Profile"
    }
    
    @objc public func navBack() {
        guard let model = model else { return }
        if model.selectedTab != .home {
            model.returnToHome()
            lastTriggeredShortcut = "⌘[ Back"
        } else {
            collapseIsland()
        }
    }
    
    // Window Management
    @objc public func closeOrCollapse() {
        guard let model = model else { return }
        if model.isExpanded {
            if model.selectedTab != .home {
                model.returnToHome()
            } else {
                collapseIsland()
            }
            lastTriggeredShortcut = "⌘W Close"
        }
    }
    
    @objc public func minimizeToNotch() {
        collapseIsland()
        lastTriggeredShortcut = "⌘M Minimize"
    }
    
    @objc public func togglePin() {
        guard let model = model else { return }
        model.togglePin()
        ensurePanelKey()
        lastTriggeredShortcut = model.isPinned ? "⌘P Pinned" : "⌘P Unpinned"
    }
    
    @objc public func toggleExpand() {
        guard let model = model, let controller = controller else { return }
        if model.isExpanded {
            collapseIsland()
        } else {
            controller.handleMouseEnter()
            ensurePanelKey()
        }
        lastTriggeredShortcut = "⌘⌥M Expand"
    }
    
    @objc public func refreshProfile() {
        guard let model = model else { return }
        Task {
            await model.supabase.fetchProfile()
        }
        lastTriggeredShortcut = "⌘R Synced"
    }
    
    // Playback Controls
    @objc public func togglePlayPause() {
        guard let model = model else { return }
        model.media.togglePlay()
        lastTriggeredShortcut = model.media.isPlaying ? "⌘⏎ Playing" : "⌘⏎ Paused"
    }
    
    @objc public func nextTrack() {
        guard let model = model else { return }
        model.media.nextTrack()
        lastTriggeredShortcut = "⌘] Next"
    }
    
    @objc public func prevTrack() {
        guard let model = model else { return }
        model.media.previousTrack()
        lastTriggeredShortcut = "⌘[ Previous"
    }
    
    @objc public func volUp() {
        guard let model = model else { return }
        let newVol = min(1.0, model.media.volume + 0.1)
        model.media.setVolume(newVol)
        lastTriggeredShortcut = "⌘↑ Vol \(Int(newVol * 100))%"
    }
    
    @objc public func volDown() {
        guard let model = model else { return }
        let newVol = max(0.0, model.media.volume - 0.1)
        model.media.setVolume(newVol)
        lastTriggeredShortcut = "⌘↓ Vol \(Int(newVol * 100))%"
    }
    
    @objc public func toggleLike() {
        guard let model = model else { return }
        model.media.toggleLike()
        lastTriggeredShortcut = model.media.isLiked ? "⌘L Liked" : "⌘L Unliked"
    }
    
    @objc public func toggleMute() {
        guard let model = model else { return }
        model.media.toggleMute()
        lastTriggeredShortcut = model.media.isMuted ? "⌘U Muted" : "⌘U Unmuted"
    }
    
    // Timer Controls
    @objc public func toggleTimer() {
        guard let model = model else { return }
        model.pomodoro.toggle()
        lastTriggeredShortcut = model.pomodoro.isRunning ? "⌘⏎ Timer Started" : "⌘⏎ Timer Paused"
    }
    
    @objc public func resetTimer() {
        guard let model = model else { return }
        model.pomodoro.reset()
        lastTriggeredShortcut = "⌘⇧R Reset Timer"
    }
    
    @objc public func skipTimer() {
        guard let model = model else { return }
        switch model.pomodoro.mode {
        case .work:
            model.pomodoro.switchMode(.shortBreak)
        case .shortBreak:
            model.pomodoro.switchMode(.work)
        case .longBreak:
            model.pomodoro.switchMode(.work)
        }
        lastTriggeredShortcut = "⌘⇧S Skip Session"
    }
    
    // Notes Controls
    @objc public func newNote() {
        guard let model = model else { return }
        model.scratchpad.clear()
        lastTriggeredShortcut = "⌘N New Note"
    }
    
    @objc public func saveNote() {
        // Notes auto-persist, but trigger explicit visual flash/feedback
        lastTriggeredShortcut = "⌘S Note Saved"
    }
    
    @objc public func copyAllNotes() {
        guard let model = model else { return }
        model.scratchpad.copyAll()
        lastTriggeredShortcut = "⌘⇧C Copied Notes"
    }
    
    @objc public func togglePinNoteToNotch() {
        guard let model = model else { return }
        model.isNotePinnedToNotch.toggle()
        lastTriggeredShortcut = model.isNotePinnedToNotch ? "⌘⇧P Note Pinned" : "⌘⇧P Note Unpinned"
    }
    
    // Helper to collapse
    private func collapseIsland() {
        guard let model = model, let controller = controller else { return }
        model.isPinned = false
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            model.isExpanded = false
        }
        controller.handleMouseExit()
    }
    
    // Helper to ensure NotchPanel is key window for keyboard events
    public func ensurePanelKey() {
        guard let controller = controller else { return }
        controller.panel.makeKey()
    }
}
