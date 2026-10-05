import SwiftUI
import Combine

public enum MorphTab: String, CaseIterable, Identifiable {
    case home = "Home"
    case timer = "Focus"
    case music = "Music"
    case notes = "Notes"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .home: return "square.grid.2x2.fill"
        case .timer: return "timer"
        case .music: return "play.circle.fill"
        case .notes: return "note.text"
        }
    }
}

public enum AccentTheme: String, CaseIterable, Identifiable {
    case emerald = "Emerald"
    case cyan = "Cyan"
    case violet = "Violet"
    case amber = "Amber"
    case monochrome = "Silver"
    
    public var id: String { rawValue }
    
    public var color: Color {
        switch self {
        case .emerald: return Color(red: 0.20, green: 0.90, blue: 0.55)
        case .cyan: return Color(red: 0.15, green: 0.85, blue: 1.0)
        case .violet: return Color(red: 0.65, green: 0.40, blue: 1.0)
        case .amber: return Color(red: 1.0, green: 0.65, blue: 0.20)
        case .monochrome: return Color(white: 0.85)
        }
    }
}

@MainActor
public final class NotchModel: ObservableObject {
    // Exact Hardware Notch Baseline (Flush when idle)
    public var idleWidth: CGFloat = 179
    public var idleHeight: CGFloat = 32
    
    // Expanded Island Dimensions
    public let expandedWidth: CGFloat = 460
    public let expandedHeight: CGFloat = 175
    
    @Published public var isExpanded: Bool = false
    @Published public var isHovered: Bool = false
    @Published public var isPinned: Bool = false
    @Published public var selectedTab: MorphTab = .home
    @Published public var selectedAccent: AccentTheme = .emerald
    
    // Sub-models for the 3 features
    public let pomodoro: PomodoroModel
    public let media: MediaControllerModel
    public let scratchpad: ScratchpadModel
    
    @Published public var hasPhysicalNotch: Bool = false
    @Published public var screenName: String = "Main Display"
    
    private var cancellables = Set<AnyCancellable>()
    
    public init(
        pomodoro: PomodoroModel = PomodoroModel(),
        media: MediaControllerModel = MediaControllerModel(),
        scratchpad: ScratchpadModel = ScratchpadModel()
    ) {
        self.pomodoro = pomodoro
        self.media = media
        self.scratchpad = scratchpad
        
        detectScreenNotch()
        observeSubmodels()
    }
    
    // Width and Height strictly adapt: Flush notch when resting, expanded island when active
    public var currentWidth: CGFloat {
        isExpanded ? expandedWidth : idleWidth
    }
    
    public var currentHeight: CGFloat {
        isExpanded ? expandedHeight : idleHeight
    }
    
    public func detectScreenNotch() {
        guard let screen = NSScreen.screens.first(where: { $0.auxiliaryTopLeftArea != nil }) ?? NSScreen.main else {
            return
        }
        
        self.screenName = screen.localizedName
        
        if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            let width = right.minX - left.maxX
            let height = screen.frame.height - left.minY
            self.idleWidth = max(width, 160)
            self.idleHeight = max(height, 28)
            self.hasPhysicalNotch = true
        } else {
            self.idleWidth = 179
            self.idleHeight = screen.safeAreaInsets.top > 0 ? screen.safeAreaInsets.top : 32
            self.hasPhysicalNotch = false
        }
    }
    
    private func observeSubmodels() {
        // When Pomodoro finishes, trigger an emerald completion pulse
        pomodoro.$isCompleted
            .filter { $0 }
            .sink { [weak self] _ in
                self?.selectedAccent = .emerald
            }
            .store(in: &cancellables)
    }
    
    public func toggleExpand() {
        isExpanded.toggle()
        if isExpanded && selectedTab != .home {
            // Keep current tab or default to home if desired
        }
    }
    
    public func togglePin() {
        isPinned.toggle()
        if isPinned {
            isExpanded = true
        }
    }
    
    public func openFeature(_ tab: MorphTab) {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
            selectedTab = tab
            isExpanded = true
        }
    }
    
    public func returnToHome() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
            selectedTab = .home
        }
    }
}
