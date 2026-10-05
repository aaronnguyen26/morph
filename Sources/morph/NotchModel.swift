import SwiftUI
import Combine

public enum MorphTab: String, CaseIterable, Identifiable {
    case home = "Home"
    case timer = "Focus"
    case music = "Music"
    case notes = "Notes"
    case profile = "Profile"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .home: return "square.grid.2x2.fill"
        case .timer: return "timer"
        case .music: return "play.circle.fill"
        case .notes: return "note.text"
        case .profile: return "person.crop.circle"
        }
    }
    
    public var shortcutLabel: String {
        switch self {
        case .home: return "⌘1"
        case .timer: return "⌘2"
        case .music: return "⌘3"
        case .notes: return "⌘4"
        case .profile: return "⌘5"
        }
    }
}

public enum CompactHUDMode: String, Equatable {
    case none
    case pomodoroOnly
    case mediaOnly
    case dualActive
    case notesPinned
}

@MainActor
public final class NotchModel: ObservableObject {
    // Exact Hardware Notch Baseline
    public var idleWidth: CGFloat = 179
    public var idleHeight: CGFloat = 32
    
    // Expanded Island Dimensions (640 width, 225 shortened length)
    public let expandedWidth: CGFloat = 640
    public let expandedHeight: CGFloat = 225
    
    @Published public var isExpanded: Bool = false
    @Published public var isHovered: Bool = false
    @Published public var isPinned: Bool = false
    @Published public var selectedTab: MorphTab = .home
    
    // Sub-models for the features
    public let pomodoro: PomodoroModel
    public let media: MediaControllerModel
    public let scratchpad: ScratchpadModel
    public let supabase: SupabaseService
    
    @Published public var hasPhysicalNotch: Bool = false
    @Published public var screenName: String = "Main Display"
    
    private var cancellables = Set<AnyCancellable>()
    
    public init(
        pomodoro: PomodoroModel = PomodoroModel(),
        media: MediaControllerModel = MediaControllerModel(),
        scratchpad: ScratchpadModel = ScratchpadModel(),
        supabase: SupabaseService = .shared
    ) {
        self.pomodoro = pomodoro
        self.media = media
        self.scratchpad = scratchpad
        self.supabase = supabase
        
        detectScreenNotch()
        observeSubmodels()
    }
    
    @Published public var isNotePinnedToNotch: Bool = false
    
    public var hasActiveNotes: Bool {
        !scratchpad.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    public var compactHUDMode: CompactHUDMode {
        let timerRunning = pomodoro.isRunning
        let musicPlaying = media.isPlaying
        
        if timerRunning && musicPlaying {
            return .dualActive
        } else if timerRunning {
            return .pomodoroOnly
        } else if musicPlaying {
            return .mediaOnly
        } else if isNotePinnedToNotch {
            return .notesPinned
        } else {
            return .none
        }
    }
    
    public var isCompactActive: Bool {
        compactHUDMode != .none
    }
    
    // Independent compact widths tailored to each feature:
    // Sized generously to guarantee zero content touches or sits behind the camera notch
    public var compactWidth: CGFloat {
        switch compactHUDMode {
        case .none:
            return idleWidth
        case .pomodoroOnly:
            return max(idleWidth + 240, 440)
        case .mediaOnly:
            return max(idleWidth + 260, 460)
        case .dualActive:
            return max(idleWidth + 320, 520)
        case .notesPinned:
            return max(idleWidth + 200, 400)
        }
    }
    
    // Independent compact heights tailored to each feature
    public var compactHeight: CGFloat {
        switch compactHUDMode {
        case .notesPinned:
            return max(idleHeight + 24, 56)
        case .none, .pomodoroOnly, .mediaOnly, .dualActive:
            return idleHeight
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
        // Trigger UI refresh when submodel playback/timer/note/supabase state changes
        Publishers.MergeMany(
            pomodoro.$isRunning.map { _ in () }.eraseToAnyPublisher(),
            pomodoro.$timeRemaining.map { _ in () }.eraseToAnyPublisher(),
            pomodoro.$mode.map { _ in () }.eraseToAnyPublisher(),
            media.$isPlaying.map { _ in () }.eraseToAnyPublisher(),
            media.$currentTime.map { _ in () }.eraseToAnyPublisher(),
            media.$visualizerBars.map { _ in () }.eraseToAnyPublisher(),
            media.$trackTitle.map { _ in () }.eraseToAnyPublisher(),
            $isNotePinnedToNotch.map { _ in () }.eraseToAnyPublisher(),
            scratchpad.$text.map { _ in () }.eraseToAnyPublisher(),
            supabase.$currentUser.map { _ in () }.eraseToAnyPublisher()
        )
        .sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        .store(in: &cancellables)
        
        pomodoro.$completedSessionsCount
            .dropFirst()
            .sink { [weak self] _ in
                Task { [weak self] in
                    await self?.supabase.recordFocusSession(minutes: 25)
                }
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
