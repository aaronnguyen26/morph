import SwiftUI
import Combine

public enum MorphTab: String, CaseIterable, Identifiable {
    case home = "Home"
    case timer = "Focus"
    case music = "Music"
    case notes = "Notes"
    case calendar = "Calendar"
    case profile = "Profile"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .home: return "square.grid.2x2.fill"
        case .timer: return "timer"
        case .music: return "play.circle.fill"
        case .notes: return "note.text"
        case .calendar: return "calendar"
        case .profile: return "person.crop.circle"
        }
    }
    
    public var shortcutLabel: String {
        switch self {
        case .home: return "⌘1"
        case .timer: return "⌘2"
        case .music: return "⌘3"
        case .notes: return "⌘4"
        case .calendar: return "⌘6"
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
    case calendarAlert
    case meetingFlight
    case dropShelfActive
}

public enum ContextualFeature: String, Identifiable, Equatable {
    case meetingFlight = "Meeting Cockpit"
    case dropShelf = "Drop Shelf"
    
    public var id: String { rawValue }
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
    @Published public var activeContextFeature: ContextualFeature? = nil
    
    // Sub-models for the features
    public let pomodoro: PomodoroModel
    public let media: MediaControllerModel
    public let scratchpad: ScratchpadModel
    public let calendar: CalendarModel
    public let supabase: SupabaseService
    public let dropShelf: DropShelfModel
    public let meetingController: MeetingFlightControllerModel
    
    @Published public var hasPhysicalNotch: Bool = false
    @Published public var screenName: String = "Main Display"
    
    private var cancellables = Set<AnyCancellable>()
    
    public init(
        pomodoro: PomodoroModel = PomodoroModel(),
        media: MediaControllerModel = MediaControllerModel(),
        scratchpad: ScratchpadModel = ScratchpadModel(),
        calendar: CalendarModel = CalendarModel(),
        supabase: SupabaseService = .shared,
        dropShelf: DropShelfModel = DropShelfModel(),
        meetingController: MeetingFlightControllerModel = MeetingFlightControllerModel()
    ) {
        self.pomodoro = pomodoro
        self.media = media
        self.scratchpad = scratchpad
        self.calendar = calendar
        self.supabase = supabase
        self.dropShelf = dropShelf
        self.meetingController = meetingController
        
        detectScreenNotch()
        observeSubmodels()
        checkInitialLaunchStep()
    }
    
    private var isTesting: Bool {
        return ProcessInfo.processInfo.processName.contains("xctest") ||
            ProcessInfo.processInfo.arguments.contains(where: { $0.contains("xctest") }) ||
            ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
            ProcessInfo.processInfo.environment["XCTestBundlePath"] != nil ||
            NSClassFromString("XCTestCase") != nil
    }
    
    /// Ensures that profile sign-in is the first step whenever someone opens the app unauthenticated,
    /// and auto-propagates the user email to Google Calendar to prevent double sign-in.
    public func checkInitialLaunchStep(forceLaunchCheck: Bool = false) {
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "com.morph.has_completed_profile_onboarding")
        let isAuthenticated = supabase.currentUser.isAuthenticated
        
        // Auto-propagate user email to Google Calendar immediately
        if isAuthenticated {
            calendar.configureUser(email: supabase.currentUser.email)
        }
        
        // Guard against automatically mutating test state unless explicitly requested
        if isTesting && !forceLaunchCheck {
            return
        }
        
        // If profile sign-in hasn't been completed yet, route to profile tab as first step
        if !hasCompletedOnboarding || !isAuthenticated {
            self.selectedTab = .profile
            self.isExpanded = true
        }
    }

    
    public func completeProfileSignIn() {
        UserDefaults.standard.set(true, forKey: "com.morph.has_completed_profile_onboarding")
        if supabase.currentUser.isAuthenticated {
            calendar.configureUser(email: supabase.currentUser.email)
        }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
            self.selectedTab = .home
        }
    }
    
    public func signOutProfile() {
        UserDefaults.standard.set(false, forKey: "com.morph.has_completed_profile_onboarding")
        supabase.signOut()
        calendar.clearUser()
        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
            self.selectedTab = .profile
            self.isExpanded = true
        }
    }
    
    public func signInProfile(
        username: String,
        password: String,
        firstName: String? = nil,
        lastName: String? = nil,
        role: String? = nil,
        avatarImageBase64: String? = nil
    ) async -> Bool {
        let (profile, isFirstTime) = await supabase.signIn(
            username: username,
            password: password,
            firstName: firstName,
            lastName: lastName,
            role: role,
            avatarImageBase64: avatarImageBase64
        )
        if profile.isAuthenticated {
            calendar.configureUser(email: profile.email)
        }
        return isFirstTime
    }
    
    // Convenience overload
    public func signInProfile(email: String, firstName: String? = nil, lastName: String? = nil, role: String? = nil) async {
        _ = await signInProfile(
            username: email,
            password: "password123",
            firstName: firstName,
            lastName: lastName,
            role: role,
            avatarImageBase64: nil
        )
        await MainActor.run {
            self.completeProfileSignIn()
        }
    }

    
    @Published public var isNotePinnedToNotch: Bool = false
    
    public var hasActiveNotes: Bool {
        !scratchpad.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    public var compactHUDMode: CompactHUDMode {
        if dropShelf.isDraggingOverNotch || dropShelf.isDraggingOut || dropShelf.isHeldOpen {
            return .dropShelfActive
        }
        
        if meetingController.isInCall || meetingController.isPreMeetingWindow {
            return .meetingFlight
        }
        
        if isNotePinnedToNotch {
            return .notesPinned
        }
        
        let timerRunning = pomodoro.isRunning
        let musicPlaying = media.isPlaying
        let calendarAlert = calendar.showNotchAlert
        
        if timerRunning && musicPlaying {
            return .dualActive
        } else if timerRunning {
            return .pomodoroOnly
        } else if musicPlaying {
            return .mediaOnly
        } else if calendarAlert {
            return .calendarAlert
        } else if dropShelf.hasItems {
            return .dropShelfActive
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
        case .calendarAlert:
            return max(idleWidth + 280, 480)
        case .meetingFlight:
            return max(idleWidth + 280, 480)
        case .dropShelfActive:
            return max(idleWidth + 240, 440)
        }
    }
    
    // Independent compact heights tailored to each feature
    public var compactHeight: CGFloat {
        switch compactHUDMode {
        case .notesPinned:
            return max(idleHeight + 24, 56)
        case .none, .pomodoroOnly, .mediaOnly, .dualActive, .calendarAlert,
             .meetingFlight, .dropShelfActive:
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
        // Break up observation sinks so Swift compiler can type-check effortlessly
        let triggerChange: () -> Void = { [weak self] in
            self?.objectWillChange.send()
        }
        
        pomodoro.objectWillChange.sink { triggerChange() }.store(in: &cancellables)
        media.objectWillChange.sink { triggerChange() }.store(in: &cancellables)
        scratchpad.objectWillChange.sink { triggerChange() }.store(in: &cancellables)
        calendar.objectWillChange.sink { triggerChange() }.store(in: &cancellables)
        supabase.objectWillChange.sink { triggerChange() }.store(in: &cancellables)
        dropShelf.objectWillChange.sink { triggerChange() }.store(in: &cancellables)
        meetingController.objectWillChange.sink { triggerChange() }.store(in: &cancellables)
        $isNotePinnedToNotch.sink { _ in triggerChange() }.store(in: &cancellables)
        
        // Sync CalendarModel events into MeetingFlightControllerModel
        meetingController.updateFromCalendar(events: calendar.events)
        calendar.$events
            .sink { [weak self] events in
                self?.meetingController.updateFromCalendar(events: events)
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
            
        // Whenever currentUser email updates, propagate to Google Calendar automatically
        supabase.$currentUser
            .map(\.email)
            .removeDuplicates()
            .sink { [weak self] email in
                guard let self = self else { return }
                let clean = email.trimmingCharacters(in: .whitespacesAndNewlines)
                if !clean.isEmpty && clean.contains("@") {
                    self.calendar.configureUser(email: clean)
                }
            }
            .store(in: &cancellables)
    }
    
    /// Synchronizes the displayed feature/tab with whatever active feature is showing in the collapsed HUD
    public func syncExpandedFeatureWithActiveContext() {
        switch compactHUDMode {
        case .pomodoroOnly:
            selectedTab = .timer
            activeContextFeature = nil
        case .mediaOnly:
            selectedTab = .music
            activeContextFeature = nil
        case .dualActive:
            // Dual active displays both timer and media. Focus is primary if running, otherwise music
            if pomodoro.isRunning {
                selectedTab = .timer
            } else {
                selectedTab = .music
            }
            activeContextFeature = nil
        case .notesPinned:
            selectedTab = .notes
            activeContextFeature = nil
        case .calendarAlert:
            selectedTab = .calendar
            activeContextFeature = nil
        case .meetingFlight:
            activeContextFeature = .meetingFlight
        case .dropShelfActive:
            activeContextFeature = .dropShelf
        case .none:
            // Remain on current tab or home
            break
        }
    }
    
    public func toggleExpand() {
        if !isExpanded {
            syncExpandedFeatureWithActiveContext()
        }
        isExpanded.toggle()
    }
    
    public func togglePin() {
        isPinned.toggle()
        if isPinned {
            if !isExpanded {
                syncExpandedFeatureWithActiveContext()
            }
            isExpanded = true
        }
    }
    
    public func openFeature(_ tab: MorphTab) {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
            selectedTab = tab
            activeContextFeature = nil
            isExpanded = true
        }
    }
    
    public func returnToHome() {
        dropShelf.isHeldOpen = false
        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
            selectedTab = .home
            activeContextFeature = nil
        }
    }
    
    public func openContextualFeature(_ feature: ContextualFeature) {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
            activeContextFeature = feature
            isExpanded = true
        }
    }
    
    public func closeContextualFeature() {
        dropShelf.isHeldOpen = false
        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
            activeContextFeature = nil
        }
    }
}
