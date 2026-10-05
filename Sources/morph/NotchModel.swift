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

@MainActor
public final class NotchModel: ObservableObject {
    // Exact Hardware Notch Baseline
    public var idleWidth: CGFloat = 179
    public var idleHeight: CGFloat = 32
    
    // Expanded Island Dimensions (640 x 300 pt)
    public let expandedWidth: CGFloat = 640
    public let expandedHeight: CGFloat = 300
    
    @Published public var isExpanded: Bool = false
    @Published public var isHovered: Bool = false
    @Published public var isPinned: Bool = false
    @Published public var selectedTab: MorphTab = .home
    
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
    
    public var isCompactActive: Bool {
        pomodoro.isRunning || media.isPlaying
    }
    
    public var compactHeight: CGFloat {
        max(idleHeight + 16, 48)
    }
    
    // Compact notch width when activity is running on the notch itself.
    // Gives generous left & right wings (90-100 pt each) outside the physical notch
    // so active timers and music visualizers are 100% visible to the user!
    public var compactWidth: CGFloat {
        if pomodoro.isRunning && media.isPlaying {
            return idleWidth + 200 // 100 pt left wing for timer, 100 pt right wing for equalizer
        } else if pomodoro.isRunning {
            return idleWidth + 180 // 90 pt left/right wings
        } else if media.isPlaying {
            return idleWidth + 180 // 90 pt left/right wings
        } else {
            return idleWidth
        }
    }
    
    public var currentWidth: CGFloat {
        if isExpanded {
            return expandedWidth
        } else if isCompactActive {
            return compactWidth
        } else {
            return idleWidth
        }
    }
    
    public var currentHeight: CGFloat {
        if isExpanded {
            return expandedHeight
        } else if isCompactActive {
            return compactHeight
        } else {
            return idleHeight
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
        // Trigger UI refresh when submodel playback/timer state changes
        Publishers.Merge(
            pomodoro.$isRunning.map { _ in () },
            media.$isPlaying.map { _ in () }
        )
        .sink { [weak self] _ in
            self?.objectWillChange.send()
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
