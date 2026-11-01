import Cocoa
import SwiftUI
import Combine

@MainActor
public final class MenuBarManager: NSObject {
    private var statusItem: NSStatusItem?
    private let model: NotchModel
    private let controller: MorphController
    private var cancellables = Set<AnyCancellable>()
    
    public init(model: NotchModel, controller: MorphController) {
        self.model = model
        self.controller = controller
        super.init()
        setupStatusItem()
        observeModel()
    }
    
    private func setupStatusItem() {
        guard !MorphEnvironment.isTestingEnvironment else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.statusItem = item
        
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "sparkle", accessibilityDescription: "Morph")
            button.imagePosition = .imageLeft
            button.toolTip = "Morph Productivity Notch"
        }
        
        rebuildMenu()
    }
    
    private func observeModel() {
        Publishers.Merge6(
            model.$isExpanded.map { _ in () },
            model.$isPinned.map { _ in () },
            model.$selectedTab.map { _ in () },
            model.pomodoro.$isRunning.map { _ in () },
            model.theme.$mode.map { _ in () },
            model.$interactionMode.map { _ in () }
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] in
            self?.rebuildMenu()
        }
        .store(in: &cancellables)
    }
    
    public func rebuildMenu() {
        let menu = NSMenu()
        
        // Title Header
        let titleItem = NSMenuItem(title: "Morph — Everyday Productivity", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        
        let screenInfo = NSMenuItem(
            title: "Hardware Baseline: \(Int(model.idleWidth)) × \(Int(model.idleHeight)) pt",
            action: nil,
            keyEquivalent: ""
        )
        screenInfo.isEnabled = false
        menu.addItem(screenInfo)
        
        menu.addItem(NSMenuItem.separator())
        
        // Toggle Expand
        let expandItem = NSMenuItem(
            title: model.isExpanded ? "Collapse Notch Island" : "Expand Notch Island",
            action: #selector(toggleExpand),
            keyEquivalent: "m"
        )
        expandItem.keyEquivalentModifierMask = [.command, .option]
        expandItem.target = self
        menu.addItem(expandItem)
        
        // Toggle Pin
        let pinItem = NSMenuItem(
            title: model.isPinned ? "Unpin Island (Allow Auto-Collapse)" : "Pin Island Open",
            action: #selector(togglePin),
            keyEquivalent: "p"
        )
        pinItem.keyEquivalentModifierMask = [.command, .option]
        pinItem.target = self
        menu.addItem(pinItem)
        
        // Mode Submenu
        let modeSubmenu = NSMenu()
        for mode in MorphInteractionMode.allCases {
            let isSelected = (mode == model.interactionMode)
            let item = NSMenuItem(
                title: "\(mode.rawValue) \(isSelected ? "✓" : "")",
                action: #selector(selectInteractionMode(_:)),
                keyEquivalent: ""
            )
            item.representedObject = mode
            item.target = self
            modeSubmenu.addItem(item)
        }
        let modeMenuItem = NSMenuItem(title: "Interaction Mode", action: nil, keyEquivalent: "")
        modeMenuItem.submenu = modeSubmenu
        menu.addItem(modeMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Suite Submenu 1: Pomodoro
        let pomodoroItem = NSMenuItem(
            title: "Focus Timer: \(model.pomodoro.isRunning ? "Running (\(model.pomodoro.formattedTime))" : "Paused")",
            action: #selector(togglePomodoro),
            keyEquivalent: ""
        )
        pomodoroItem.target = self
        menu.addItem(pomodoroItem)
        
        // Suite Submenu 2: Media
        let mediaItem = NSMenuItem(
            title: "Music: \(model.media.isPlaying ? "Playing (\(model.media.trackTitle))" : "Paused")",
            action: #selector(toggleMedia),
            keyEquivalent: ""
        )
        mediaItem.target = self
        menu.addItem(mediaItem)
        
        // Suite Submenu 3: Copy Scratchpad
        let notesItem = NSMenuItem(
            title: "Copy Scratchpad Notes",
            action: #selector(copyNotes),
            keyEquivalent: "c"
        )
        notesItem.keyEquivalentModifierMask = [.command, .shift]
        notesItem.target = self
        menu.addItem(notesItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Appearance / Theme Submenu
        let themeSubmenu = NSMenu()
        for tMode in MorphThemeMode.allCases {
            let item = NSMenuItem(
                title: "\(tMode.rawValue) \(tMode == model.theme.mode ? "✓" : "")",
                action: #selector(selectThemeMode(_:)),
                keyEquivalent: ""
            )
            item.representedObject = tMode
            item.target = self
            themeSubmenu.addItem(item)
        }
        let themeItem = NSMenuItem(title: "Appearance (\(model.theme.mode.rawValue))", action: nil, keyEquivalent: "")
        themeItem.submenu = themeSubmenu
        menu.addItem(themeItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit
        let quitItem = NSMenuItem(title: "Quit Morph", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
    }
    
    public func teardown() {
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }
    
    @objc private func toggleExpand() {
        if model.isExpanded {
            model.isPinned = false
            model.isExpanded = false
        } else {
            controller.handleMouseEnter()
        }
    }
    
    @objc private func togglePin() {
        model.togglePin()
    }
    
    @objc private func togglePomodoro() {
        model.pomodoro.toggle()
    }
    
    @objc private func toggleMedia() {
        model.media.togglePlay()
    }
    
    @objc private func copyNotes() {
        model.scratchpad.copyAll()
    }
    
    @objc private func selectInteractionMode(_ sender: NSMenuItem) {
        if let mode = sender.representedObject as? MorphInteractionMode {
            model.interactionMode = mode
            if mode == .spotlightBar {
                model.isExpanded = false
            } else {
                model.isSpotlightBarActive = false
                model.isTimerPopupActive = false
            }
            controller.updatePanelGeometry()
        }
    }
    
    @objc private func selectThemeMode(_ sender: NSMenuItem) {
        if let mode = sender.representedObject as? MorphThemeMode {
            model.theme.setMode(mode)
        }
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
