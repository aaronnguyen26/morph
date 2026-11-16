import AppKit
import SwiftUI

/// NSMenuItem subclass that executes a closure when selected, avoiding complex selector wiring.
public final class ClosureMenuItem: NSMenuItem {
    private let actionClosure: () -> Void
    
    public init(title: String, image: NSImage? = nil, isChecked: Bool = false, isEnabled: Bool = true, action: @escaping () -> Void = {}) {
        self.actionClosure = action
        super.init(title: title, action: isEnabled ? #selector(trigger) : nil, keyEquivalent: "")
        self.target = self
        self.image = image
        self.isEnabled = isEnabled
        if isChecked {
            self.state = .on
        }
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func trigger() {
        actionClosure()
    }
}

public extension NSImage {
    /// Returns a rounded circular thumbnail of the image for use in menu items and avatars.
    func circularThumbnail(size: CGFloat = 16) -> NSImage {
        let targetSize = NSSize(width: size, height: size)
        let roundImage = NSImage(size: targetSize)
        roundImage.lockFocus()
        let rect = NSRect(origin: .zero, size: targetSize)
        let path = NSBezierPath(ovalIn: rect)
        path.addClip()
        self.draw(in: rect, from: NSRect(origin: .zero, size: self.size), operation: .sourceOver, fraction: 1.0)
        roundImage.unlockFocus()
        return roundImage
    }
}

/// Native macOS menu presenter for YouTube Music profiles, guaranteeing zero chevron or popup arrow artifacts.
@MainActor
public enum YouTubeMusicProfileMenuPresenter {
    public static func show(for media: MediaControllerModel, at location: NSPoint? = nil) {
        let menu = NSMenu(title: "YouTube Music Profiles")
        
        let headerItem = ClosureMenuItem(title: "YouTube Music Account", isEnabled: false)
        menu.addItem(headerItem)
        
        for p in media.profiles {
            let isCurrent = (p.id == media.activeProfile?.id)
            let title = p.displayName.isEmpty ? p.email : "\(p.displayName) (\(p.email))"
            let item = ClosureMenuItem(title: title, isChecked: isCurrent) {
                media.switchProfile(to: p)
            }
            if let img = p.avatarImage {
                item.image = img.circularThumbnail(size: 16)
            }
            menu.addItem(item)
        }
        
        let detected = YTMProfileManager.shared.detectAvailableBrowserProfiles()
        let unimported = detected.filter { det in
            !media.profiles.contains(where: { $0.email.lowercased() == det.email.lowercased() })
        }
        if !unimported.isEmpty {
            menu.addItem(NSMenuItem.separator())
            let importHeader = ClosureMenuItem(title: "Import from Chrome", isEnabled: false)
            menu.addItem(importHeader)
            
            for item in unimported {
                let menuItem = ClosureMenuItem(title: "Import \(item.name) (\(item.email))") {
                    media.importBrowserProfile(email: item.email, displayName: item.name)
                }
                if let path = item.avatarLocalPath, let img = NSImage(contentsOfFile: path) {
                    menuItem.image = img.circularThumbnail(size: 16)
                }
                menu.addItem(menuItem)
            }
        }
        
        menu.addItem(NSMenuItem.separator())
        
        let addItem = ClosureMenuItem(title: "Add YouTube Music Profile...") {
            media.addNewProfile()
        }
        menu.addItem(addItem)
        
        if media.isSignedIn {
            let signOutItem = ClosureMenuItem(title: "Sign Out of YouTube Music") {
                media.signOut()
            }
            menu.addItem(signOutItem)
        } else {
            let signInItem = ClosureMenuItem(title: "Sign In to YouTube Music...") {
                media.openSignIn()
            }
            menu.addItem(signInItem)
        }
        
        let targetLocation = location ?? NSEvent.mouseLocation
        menu.popUp(positioning: nil, at: targetLocation, in: nil)
    }
}
