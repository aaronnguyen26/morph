import Cocoa
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: MorphController?
    private var menuBarManager: MenuBarManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set as accessory so it doesn't show in the Dock and seamlessly overlays the notch
        NSApplication.shared.setActivationPolicy(.accessory)
        
        let model = NotchModel()
        let controller = MorphController(model: model)
        self.controller = controller
        self.menuBarManager = MenuBarManager(model: model, controller: controller)
        
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
