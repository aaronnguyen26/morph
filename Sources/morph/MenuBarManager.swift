import Cocoa
import SwiftUI
import Combine

@MainActor
public final class MenuBarManager: NSObject {
    private var statusItem: NSStatusItem!
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
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "sparkle", accessibilityDescription: "Morph")
            button.imagePosition = .imageLeft
            button.toolTip = "Morph Notch Control"
        }
        
        rebuildMenu()
    }
    
    private func observeModel() {
        Publishers.Merge3(
            model.$isExpanded.map { _ in () },
            model.$isPinned.map { _ in () },
            model.$selectedAccent.map { _ in () }
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
        let titleItem = NSMenuItem(title: "Morph — Notch Assistant", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        
        let screenInfo = NSMenuItem(
            title: "\(model.hasPhysicalNotch ? "MacBook Notch" : "Simulated Notch"): \(Int(model.notchWidth)) × \(Int(model.notchHeight)) pt",
            action: nil,
            keyEquivalent: ""
        )
        screenInfo.isEnabled = false
        menu.addItem(screenInfo)
        
        menu.addItem(NSMenuItem.separator())
        
        // Toggle Expand
        let expandItem = NSMenuItem(
            title: model.isExpanded ? "Collapse Notch Window" : "Expand Notch Window",
            action: #selector(toggleExpand),
            keyEquivalent: "m"
        )
        expandItem.keyEquivalentModifierMask = [.command, .control]
        expandItem.target = self
        menu.addItem(expandItem)
        
        // Toggle Pin
        let pinItem = NSMenuItem(
            title: model.isPinned ? "Unpin Window (Allow Auto-Collapse)" : "Pin Window Open",
            action: #selector(togglePin),
            keyEquivalent: "p"
        )
        pinItem.keyEquivalentModifierMask = [.command, .control]
        pinItem.target = self
        menu.addItem(pinItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Accent Color Submenu
        let themesMenu = NSMenu()
        for theme in AccentTheme.allCases {
            let item = NSMenuItem(title: theme.rawValue, action: #selector(selectTheme(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = theme
            item.state = (model.selectedAccent == theme) ? .on : .off
            themesMenu.addItem(item)
        }
        let themesParent = NSMenuItem(title: "Accent Theme", action: nil, keyEquivalent: "")
        themesParent.submenu = themesMenu
        menu.addItem(themesParent)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit
        let quitItem = NSMenuItem(title: "Quit Morph", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem.menu = menu
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
    
    @objc private func selectTheme(_ sender: NSMenuItem) {
        if let theme = sender.representedObject as? AccentTheme {
            model.selectedAccent = theme
        }
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
