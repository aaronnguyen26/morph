import Cocoa
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: MorphController?
    private var menuBarManager: MenuBarManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set as accessory so it doesn't show in the Dock and seamlessly overlays the notch
        NSApplication.shared.setActivationPolicy(.accessory)
        
        // Check accessibility permissions safely without repeated nagging prompts
        if !MorphEnvironment.isTestingEnvironment {
            if !AXIsProcessTrusted() {
                let promptedKey = "Morph_HasPromptedAccessibility"
                if !UserDefaults.standard.bool(forKey: promptedKey) {
                    UserDefaults.standard.set(true, forKey: promptedKey)
                    let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
                    _ = AXIsProcessTrustedWithOptions(options)
                }
            }
        }
        
        let model = NotchModel()
        let controller = MorphController(model: model)
        self.controller = controller
        self.menuBarManager = MenuBarManager(model: model, controller: controller)
        ShortcutManager.shared.configure(model: model, controller: controller)
        
        print("Morph launched successfully. Tracking notch at: \(model.idleWidth) x \(model.idleHeight) pt")
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        print("Morph terminating.")
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
