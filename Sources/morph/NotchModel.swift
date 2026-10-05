import SwiftUI
import Combine

public enum AccentTheme: String, CaseIterable, Identifiable {
    case cyan = "Cyan"
    case violet = "Violet"
    case emerald = "Emerald"
    case amber = "Amber"
    case monochrome = "Silver"
    
    public var id: String { rawValue }
    
    public var color: Color {
        switch self {
        case .cyan: return Color(red: 0.15, green: 0.85, blue: 1.0)
        case .violet: return Color(red: 0.65, green: 0.40, blue: 1.0)
        case .emerald: return Color(red: 0.20, green: 0.90, blue: 0.55)
        case .amber: return Color(red: 1.0, green: 0.65, blue: 0.20)
        case .monochrome: return Color(white: 0.85)
        }
    }
    
    public var gradient: LinearGradient {
        LinearGradient(
            colors: [color.opacity(0.8), color.opacity(0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

@MainActor
public final class NotchModel: ObservableObject {
    @Published public var isExpanded: Bool = false
    @Published public var isHovered: Bool = false
    @Published public var isPinned: Bool = false
    @Published public var selectedAccent: AccentTheme = .cyan
    @Published public var pulseCounter: Int = 0
    
    @Published public var notchWidth: CGFloat = 180
    @Published public var notchHeight: CGFloat = 32
    @Published public var hasPhysicalNotch: Bool = false
    @Published public var screenName: String = "Main Display"
    
    public let expandedWidth: CGFloat = 520
    public let expandedHeight: CGFloat = 270
    
    public init() {
        detectScreenNotch()
    }
    
    public func detectScreenNotch() {
        guard let screen = NSScreen.screens.first(where: { $0.auxiliaryTopLeftArea != nil }) ?? NSScreen.main else {
            return
        }
        
        self.screenName = screen.localizedName
        
        if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            let width = right.minX - left.maxX
            let height = screen.frame.height - left.minY
            self.notchWidth = max(width, 160)
            self.notchHeight = max(height, 28)
            self.hasPhysicalNotch = true
        } else {
            // Screen without physical notch (fallback simulation)
            self.notchWidth = 180
            self.notchHeight = screen.safeAreaInsets.top > 0 ? screen.safeAreaInsets.top : 32
            self.hasPhysicalNotch = false
        }
    }
    
    public func toggleExpand() {
        isExpanded.toggle()
    }
    
    public func togglePin() {
        isPinned.toggle()
        if isPinned {
            isExpanded = true
        }
    }
    
    public func triggerPulse() {
        pulseCounter += 1
    }
}
