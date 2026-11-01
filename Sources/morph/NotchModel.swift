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
    case calendarAndMedia
    case notesPinned
    case calendarAlert
    case meetingFlight
    case dropShelfActive
    case formTrackerActive
}

public enum MorphInteractionMode: String, CaseIterable, Codable {
    case spotlightBar = "Spotlight Bar (Horizontal Expand + Shrunk Timer Popup)"
    case legacyLargeUI = "Packaged Large UI (640x225 Full Modal with Tabs)"
}

public enum MorphIslandState: String, CaseIterable, Equatable {
    case resting = "Normal Resting (State 1)"
    case spotlightBar = "Horizontal Typing Bar"
    case timerPopup = "Compact Shrunk Timer Popup"
    case extendedPill = "Extended Morph Pill (State 2)"
    case fullExpanded = "Full Big UI (State 3)"
}

public struct MorphTimerQueryParser {
    public struct ParsedTimer: Equatable {
        public let minutes: Int
        public let autoStart: Bool
        
        public init(minutes: Int, autoStart: Bool = false) {
            self.minutes = minutes
            self.autoStart = autoStart
        }
    }
    
    public static func parse(_ text: String) -> ParsedTimer? {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleaned.isEmpty else { return nil }
        
        // 1. Direct number check: "25", "15", "5", "45", "60"
        if let directNumber = Int(cleaned), directNumber > 0 && directNumber <= 180 {
            return ParsedTimer(minutes: directNumber, autoStart: true)
        }
        
        // 2. Pattern matching: e.g. "25m", "25min", "25mins", "25 minutes"
        if let regex = try? NSRegularExpression(pattern: #"^(\d+)\s*(m|min|mins|minutes)?$"#, options: .caseInsensitive) {
            let ns = cleaned as NSString
            if let match = regex.firstMatch(in: cleaned, range: NSRange(location: 0, length: ns.length)) {
                let numStr = ns.substring(with: match.range(at: 1))
                if let mins = Int(numStr), mins > 0 && mins <= 180 {
                    return ParsedTimer(minutes: mins, autoStart: true)
                }
            }
        }
        
        // 3. Break keywords
        if cleaned == "break" || cleaned == "short break" {
            return ParsedTimer(minutes: 5, autoStart: false)
        } else if cleaned == "long break" {
            return ParsedTimer(minutes: 15, autoStart: false)
        }
        
        // 4. Command phrases like "timer 15m", "set timer 30", "focus 45m"
        let timerKeywords = ["timer", "focus", "pomo", "pomodoro", "work", "sprint"]
        for kw in timerKeywords {
            if cleaned.contains(kw) {
                let digits = cleaned.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                if let mins = Int(digits), mins > 0 && mins <= 180 {
                    return ParsedTimer(minutes: mins, autoStart: true)
                }
                return ParsedTimer(minutes: 25, autoStart: false)
            }
        }
        
        return nil
    }
    
    public static func parseMinutes(from text: String) -> Int? {
        return parse(text)?.minutes
    }
}

public struct MorphUniversalAnimation {
    /// State 1 <-> State 2: Asymmetric fluid elongation & contraction
    public static let stateElongation = Animation.spring(response: 0.35, dampingFraction: 0.78)
    
    /// State 2 <-> State 3 or State 1 <-> State 3: Fluid 4-sided squircle modal expansion
    public static let stateExpansion = Animation.spring(response: 0.38, dampingFraction: 0.82)
    
    /// State 3 -> State 2 or State 3 -> State 1: Crisp controlled modal retraction
    public static let stateRetraction = Animation.spring(response: 0.30, dampingFraction: 0.86)
    
    /// Universal tab switching animation inside State 3
    public static let tabSwitch = Animation.spring(response: 0.28, dampingFraction: 0.82)
    
    /// Universal wing entrance / exit for live activity pills
    public static let wingTransition = Animation.spring(response: 0.32, dampingFraction: 0.80)
}

public enum ContextualFeature: String, Identifiable, Equatable {
    case meetingFlight = "Meeting Cockpit"
    case dropShelf = "Drop Shelf"
    case formTracker = "Application Form Tracker"
    
    public var id: String { rawValue }
}

@MainActor
public final class NotchModel: ObservableObject {
    // Apple Dynamic Island & Physical Notch Resting Baseline
    public var idleWidth: CGFloat = 179
    public var idleHeight: CGFloat = 32
    
    // Expanded Island Dimensions (640 width, 225 shortened length)
    public let expandedWidth: CGFloat = 640
    public let expandedHeight: CGFloat = 225
    
    // Spotlight Typing Bar Dimensions (Horizontal Expansion on Hover)
    public let spotlightBarWidth: CGFloat = 520
    public let spotlightBarHeight: CGFloat = 38
    
    // Shrunk Timer Popup Dimensions (Shrunk horizontally, less than typing bar)
    public let timerPopupWidth: CGFloat = 320
    public let timerPopupHeight: CGFloat = 135
    
    @Published public var interactionMode: MorphInteractionMode = .spotlightBar
    @Published public var spotlightQuery: String = ""
    @Published public var isSpotlightBarActive: Bool = false
    @Published public var isTimerPopupActive: Bool = false
    @Published public var requestedTimerMinutes: Int = 25
    
    @Published public var isExpanded: Bool = false
    @Published public var isHovered: Bool = false
    @Published public var isPinned: Bool = false
    @Published public var isCommandBarPresented: Bool = false
    @Published public var selectedTab: MorphTab = .home
    @Published public var activeContextFeature: ContextualFeature? = nil
    @Published public var latestTabBeforeContextualFeature: MorphTab? = nil
    @Published public var lastUsedFeatureTab: MorphTab? = nil
    
    // Sub-models for the features
    public let pomodoro: PomodoroModel
    public let media: MediaControllerModel
    public let scratchpad: ScratchpadModel
    public let calendar: CalendarModel
    public let supabase: SupabaseService
    public let dropShelf: DropShelfModel
    public let meetingController: MeetingFlightControllerModel
    public let formTracker: ApplicationFormModel
    public let theme: MorphTheme = .shared
    
    @Published public var hasPhysicalNotch: Bool = false
    @Published public var screenName: String = "Main Display"
    
    private var cancellables = Set<AnyCancellable>()
    
    public init(
        pomodoro: PomodoroModel? = nil,
        media: MediaControllerModel? = nil,
        scratchpad: ScratchpadModel? = nil,
        calendar: CalendarModel? = nil,
        supabase: SupabaseService? = nil,
        dropShelf: DropShelfModel? = nil,
        meetingController: MeetingFlightControllerModel? = nil,
        formTracker: ApplicationFormModel? = nil
    ) {
        self.pomodoro = pomodoro ?? PomodoroModel()
        self.media = media ?? MediaControllerModel()
        self.scratchpad = scratchpad ?? ScratchpadModel()
        self.calendar = calendar ?? CalendarModel()
        self.supabase = supabase ?? .shared
        self.dropShelf = dropShelf ?? DropShelfModel()
        self.meetingController = meetingController ?? MeetingFlightControllerModel()
        self.formTracker = formTracker ?? ApplicationFormModel()
        
        detectScreenNotch()
        observeSubmodels()
        checkInitialLaunchStep()
    }
    
    private var isTesting: Bool {
        return MorphEnvironment.isTestingEnvironment
    }
    
    /// Ensures that profile sign-in is the first step whenever someone opens the app unauthenticated,
    /// and auto-propagates the user email to Google Calendar to prevent double sign-in.
    public func checkInitialLaunchStep(forceLaunchCheck: Bool = false) {
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "com.morph.has_completed_profile_onboarding")
        let isAuthenticated = supabase.currentUser.isAuthenticated
        
        // Auto-propagate user email to Google Calendar & Form Tracker immediately
        if isAuthenticated {
            calendar.configureUser(email: supabase.currentUser.email)
            formTracker.setRecipientEmail(supabase.currentUser.email)
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
            formTracker.setRecipientEmail(supabase.currentUser.email)
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
            formTracker.setRecipientEmail(profile.email)
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
        
        // Priority 2: Meeting Flight (Strictly context-aware: only when Google Meet or Zoom is active or detected)
        if meetingController.isMeetingActiveOrDetected {
            return .meetingFlight
        }
        
        // Priority 3: Form Tracker (Strictly context-aware: active when an application form is detected on screen)
        if formTracker.isFormDetected {
            return .formTrackerActive
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
        } else if musicPlaying && calendarAlert {
            return .calendarAndMedia
        } else if calendarAlert {
            return .calendarAlert
        } else if musicPlaying {
            return .mediaOnly
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
        case .dualActive, .calendarAndMedia:
            return max(idleWidth + 320, 520)
        case .notesPinned:
            return max(idleWidth + 200, 400)
        case .calendarAlert:
            return max(idleWidth + 280, 480)
        case .meetingFlight:
            return max(idleWidth + 280, 480)
        case .dropShelfActive:
            return max(idleWidth + 240, 440)
        case .formTrackerActive:
            return max(idleWidth + 280, 480)
        }
    }
    
    // Independent compact heights tailored to each feature
    public var compactHeight: CGFloat {
        switch compactHUDMode {
        case .notesPinned:
            return max(idleHeight + 24, 56)
        case .none, .pomodoroOnly, .mediaOnly, .dualActive, .calendarAndMedia, .calendarAlert,
             .meetingFlight, .dropShelfActive, .formTrackerActive:
            return idleHeight
        }
    }
    
    public var currentWidth: CGFloat {
        switch islandState {
        case .spotlightBar:
            return spotlightBarWidth
        case .timerPopup:
            return timerPopupWidth
        case .fullExpanded:
            return expandedWidth
        case .extendedPill:
            return compactWidth
        case .resting:
            return idleWidth
        }
    }
    
    public var currentHeight: CGFloat {
        switch islandState {
        case .spotlightBar:
            return spotlightBarHeight
        case .timerPopup:
            return timerPopupHeight
        case .fullExpanded:
            return expandedHeight
        case .extendedPill:
            return compactHeight
        case .resting:
            return idleHeight
        }
    }
    
    /// The universal operational state of Morph
    public var islandState: MorphIslandState {
        if isTimerPopupActive {
            return .timerPopup
        }
        if isExpanded {
            return .fullExpanded
        }
        switch interactionMode {
        case .spotlightBar:
            if isHovered || isSpotlightBarActive {
                return .spotlightBar
            } else if isCompactActive {
                return .extendedPill
            } else {
                return .resting
            }
        case .legacyLargeUI:
            if isCompactActive {
                return .extendedPill
            } else {
                return .resting
            }
        }
    }
    
    public func handleSpotlightQueryChanged(_ query: String) {
        self.spotlightQuery = query
        if let parsed = MorphTimerQueryParser.parse(query) {
            triggerTimerPopup(minutes: parsed.minutes, autoStart: parsed.autoStart)
        }
    }
    
    public func handleSpotlightSubmit() {
        if let parsed = MorphTimerQueryParser.parse(spotlightQuery) {
            triggerTimerPopup(minutes: parsed.minutes, autoStart: true)
        } else {
            triggerTimerPopup(minutes: 25, autoStart: true)
        }
    }
    
    public func triggerTimerPopup(minutes: Int, autoStart: Bool = false) {
        self.requestedTimerMinutes = minutes
        self.pomodoro.setCustomDuration(minutes: minutes, saveAsPreference: false)
        if autoStart {
            self.pomodoro.start()
        }
        withAnimation(MorphUniversalAnimation.stateExpansion) {
            self.isTimerPopupActive = true
            self.isSpotlightBarActive = false
        }
    }
    
    public func dismissTimerPopup() {
        withAnimation(MorphUniversalAnimation.stateRetraction) {
            self.isTimerPopupActive = false
            self.spotlightQuery = ""
            if !self.isHovered {
                self.isSpotlightBarActive = false
            }
        }
    }
    
    public func resetSpotlightBar() {
        withAnimation(MorphUniversalAnimation.stateRetraction) {
            self.spotlightQuery = ""
            self.isTimerPopupActive = false
            self.isSpotlightBarActive = false
            self.isHovered = false
        }
    }
    
    public func detectScreenNotch(for targetScreen: NSScreen? = nil) {
        guard let screen = targetScreen ?? NSScreen.screens.first(where: { $0.auxiliaryTopLeftArea != nil }) ?? NSScreen.main else {
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
        formTracker.objectWillChange.sink { triggerChange() }.store(in: &cancellables)
        theme.objectWillChange.sink { triggerChange() }.store(in: &cancellables)
        $isNotePinnedToNotch.sink { _ in triggerChange() }.store(in: &cancellables)
        $isCommandBarPresented.sink { _ in triggerChange() }.store(in: &cancellables)
        
        // Track the latest feature tab used by the user
        $selectedTab
            .sink { [weak self] tab in
                if tab != .home {
                    self?.lastUsedFeatureTab = tab
                }
            }
            .store(in: &cancellables)
            
        // When a file is taken out of Drop Shelf, context-awarely close the tool and restore context
        dropShelf.onItemExported = { [weak self] item in
            self?.closeDropShelfAndRestoreContext()
        }
        
        // When Drop Shelf is emptied (e.g. via xmark or clear), close and restore context
        dropShelf.onShelfEmptied = { [weak self] in
            if self?.activeContextFeature == .dropShelf {
                self?.closeDropShelfAndRestoreContext()
            }
        }
        
        // Sync CalendarModel events into MeetingFlightControllerModel
        meetingController.updateFromCalendar(events: calendar.events)
        calendar.$events
            .sink { [weak self] events in
                self?.meetingController.updateFromCalendar(events: events)
            }
            .store(in: &cancellables)
        
        // Hook up GoogleCalendarEngine to direct in-app meeting taking
        calendar.engine.onOpenMeet = { [weak self] url in
            guard let self = self else { return false }
            let started = self.meetingController.engine.startCall(url: url, title: "Meeting Call", scratchpadModel: self.scratchpad)
            if started {
                if self.media.isPlaying {
                    self.media.pause()
                }
                self.meetingController.startCall(title: "Meeting Call")
            }
            return started
        }
        
        // Restore context when an in-app meeting call ends
        meetingController.engine.onCallEnded = { [weak self] in
            guard let self = self else { return }
            if self.activeContextFeature == .meetingFlight {
                self.closeDropShelfAndRestoreContext()
            }
        }
        
        // Auto-surface Meeting Flight when Google Meet or Zoom is detected, and auto-dismiss when closed
        meetingController.$isMeetingActiveOrDetected
            .dropFirst()
            .sink { [weak self] detected in
                guard let self = self else { return }
                if detected {
                    if self.media.isPlaying {
                        self.media.pause()
                    }
                    if self.isExpanded && (self.selectedTab == .home || self.activeContextFeature == nil) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                            self.activeContextFeature = .meetingFlight
                        }
                    }
                } else {
                    if self.activeContextFeature == .meetingFlight {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                            self.activeContextFeature = nil
                            self.selectedTab = .home
                        }
                    }
                }
            }
            .store(in: &cancellables)
        
        // Restore context when an application form session ends
        formTracker.onFormClosed = { [weak self] in
            guard let self = self else { return }
            if self.activeContextFeature == .formTracker {
                self.closeDropShelfAndRestoreContext()
            }
        }
        
        // Auto-surface Form Tracker when a form is detected while island is expanded on Home
        formTracker.$isFormDetected
            .dropFirst()
            .sink { [weak self] detected in
                guard let self = self else { return }
                if detected && self.isExpanded && (self.selectedTab == .home || self.activeContextFeature == nil) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                        self.activeContextFeature = .formTracker
                    }
                }
            }
            .store(in: &cancellables)
        
        pomodoro.$completedSessionsCount
            .dropFirst()
            .sink { [weak self] _ in
                guard let self = self else { return }
                let minutes = max(1, Int(self.pomodoro.totalDuration / 60))
                Task { [weak self] in
                    await self?.supabase.recordFocusSession(minutes: minutes, mode: "focus", label: "Focus Session")
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
                    self.formTracker.setRecipientEmail(clean)
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
        case .calendarAndMedia:
            // Calendar is primary when alert is firing, music controls remain active in background
            selectedTab = .calendar
            activeContextFeature = nil
        case .notesPinned:
            selectedTab = .notes
            activeContextFeature = nil
        case .calendarAlert:
            selectedTab = .calendar
            activeContextFeature = nil
        case .meetingFlight:
            if meetingController.isMeetingActiveOrDetected {
                activeContextFeature = .meetingFlight
            } else {
                activeContextFeature = nil
                selectedTab = .home
            }
        case .dropShelfActive:
            activeContextFeature = .dropShelf
        case .formTrackerActive:
            activeContextFeature = .formTracker
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
    
    public func toggleTheme() {
        theme.toggleTheme()
    }
    
    public func togglePin() {
        isPinned.toggle()
        MorphHaptics.levelChange()
        if isPinned {
            if !isExpanded {
                syncExpandedFeatureWithActiveContext()
            }
            isExpanded = true
        }
    }
    
    public func toggleCommandBar() {
        withAnimation(.spring(response: 0.26, dampingFraction: 0.84)) {
            if !isExpanded {
                isExpanded = true
                isCommandBarPresented = true
            } else {
                isCommandBarPresented.toggle()
            }
        }
        MorphHaptics.levelChange()
    }
    
    public func cycleTab(forward: Bool) {
        let allTabs = MorphTab.allCases
        guard let currentIndex = allTabs.firstIndex(of: selectedTab) else { return }
        let nextIndex = forward
            ? (currentIndex + 1) % allTabs.count
            : (currentIndex - 1 + allTabs.count) % allTabs.count
        openFeature(allTabs[nextIndex])
    }
    
    public func openFeature(_ tab: MorphTab) {
        MorphHaptics.levelChange()
        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
            selectedTab = tab
            if tab != .home {
                lastUsedFeatureTab = tab
            }
            activeContextFeature = nil
            isCommandBarPresented = false
            isExpanded = true
        }
    }
    
    public func returnToHome() {
        dropShelf.isHeldOpen = false
        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
            selectedTab = .home
            activeContextFeature = nil
            isCommandBarPresented = false
        }
    }
    
    public func openContextualFeature(_ feature: ContextualFeature) {
        if activeContextFeature == nil {
            latestTabBeforeContextualFeature = selectedTab
            if selectedTab != .home {
                lastUsedFeatureTab = selectedTab
            }
        }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
            activeContextFeature = feature
            isExpanded = true
        }
    }
    
    public func closeContextualFeature() {
        dropShelf.isHeldOpen = false
        withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
            activeContextFeature = nil
            selectedTab = .home
        }
    }
    
    public func closeDropShelfAndRestoreContext() {
        dropShelf.isHeldOpen = false
        
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            activeContextFeature = nil
            
            // 1. Live Contextual Awareness Priority:
            if meetingController.isMeetingActiveOrDetected {
                activeContextFeature = .meetingFlight
                return
            }
            
            if formTracker.isFormDetected {
                activeContextFeature = .formTracker
                return
            }
            
            if media.isPlaying {
                selectedTab = .music
                return
            }
            
            if pomodoro.isRunning {
                selectedTab = .timer
                return
            }
            
            if isNotePinnedToNotch {
                selectedTab = .notes
                return
            }
            
            if calendar.showNotchAlert {
                selectedTab = .calendar
                return
            }
            
            // 2. Latest Feature Used / Home Page Check:
            if let prevTab = latestTabBeforeContextualFeature {
                selectedTab = prevTab
            } else if let lastUsed = lastUsedFeatureTab {
                selectedTab = lastUsed
            } else {
                selectedTab = .home
            }
            latestTabBeforeContextualFeature = nil
        }
    }
}
