import SwiftUI
import Combine

public enum MorphTab: String, CaseIterable, Identifiable {
    case timer = "Focus"
    case music = "Music"
    case notes = "Notes"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .timer: return "timer"
        case .music: return "play.circle.fill"
        case .notes: return "note.text"
        }
    }
}

public enum MorphDisplayState {
    case idle       // 179 x 32 pt (flush notch cutout)
    case pill       // 300 x 44 pt (ambient resting state with wings)
    case expanded   // 440 x 140 pt (3:1 horizontal suite)
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
    // PRD Exact Dimensions
    public var idleWidth: CGFloat = 179
    public var idleHeight: CGFloat = 32
    public let pillWidth: CGFloat = 300
    public let pillHeight: CGFloat = 44
    public let expandedWidth: CGFloat = 440
    public let expandedHeight: CGFloat = 140
    
    @Published public var isExpanded: Bool = false
    @Published public var isHovered: Bool = false
    @Published public var isPinned: Bool = false
    @Published public var selectedTab: MorphTab = .timer
    @Published public var selectedAccent: AccentTheme = .emerald
    @Published public var alwaysShowPill: Bool = true
    
    // Sub-models
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
    
    public var currentDisplayState: MorphDisplayState {
        if isExpanded {
            return .expanded
        }
        if alwaysShowPill || pomodoro.isRunning || media.isPlaying {
            return .pill
        }
        return .idle
    }
    
    public var currentWidth: CGFloat {
        switch currentDisplayState {
        case .idle: return idleWidth
        case .pill: return pillWidth
        case .expanded: return expandedWidth
        }
    }
    
    public var currentHeight: CGFloat {
        switch currentDisplayState {
        case .idle: return idleHeight
        case .pill: return pillHeight
        case .expanded: return expandedHeight
        }
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
    }
    
    public func togglePin() {
        isPinned.toggle()
        if isPinned {
            isExpanded = true
        }
    }
}
