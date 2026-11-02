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

public enum MorphBackgroundTaskPillState: Equatable {
    case none
    case calendar(title: String, timeText: String, meetLink: String?, fullEvent: CalendarEvent?)
    case timer(title: String, minutes: Int)
    case media(trackTitle: String, artist: String)
    case note(previewText: String)
    case directAnswer(text: String, icon: String)
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
        public let title: String
        
        public init(minutes: Int, autoStart: Bool = true, title: String = "Focus Session") {
            self.minutes = minutes
            self.autoStart = autoStart
            self.title = title
        }
    }
    
    public static func parse(_ text: String) -> ParsedTimer? {
        let raw = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }
        let lower = raw.lowercased()
        
        // Break keywords check
        if lower == "break" || lower == "short break" {
            return ParsedTimer(minutes: 5, autoStart: true, title: "Short Break")
        } else if lower == "long break" {
            return ParsedTimer(minutes: 15, autoStart: true, title: "Long Break")
        }
        
        var extractedMinutes: Int? = nil
        var textWithoutTime = raw
        
        // Natural verbal hour/fraction checks:
        if lower.contains("an hour and a half") || lower.contains("hour and a half") || lower.contains("one and a half hours") || lower.contains("1.5 hours") {
            extractedMinutes = 90
            textWithoutTime = textWithoutTime.replacingOccurrences(of: "(?i)an hour and a half", with: "", options: .regularExpression)
            textWithoutTime = textWithoutTime.replacingOccurrences(of: "(?i)hour and a half", with: "", options: .regularExpression)
            textWithoutTime = textWithoutTime.replacingOccurrences(of: "(?i)one and a half hours", with: "", options: .regularExpression)
            textWithoutTime = textWithoutTime.replacingOccurrences(of: "(?i)1.5 hours", with: "", options: .regularExpression)
        } else if lower.contains("half an hour") || lower.contains("half hour") {
            extractedMinutes = 30
            textWithoutTime = textWithoutTime.replacingOccurrences(of: "(?i)half an hour", with: "", options: .regularExpression)
            textWithoutTime = textWithoutTime.replacingOccurrences(of: "(?i)half hour", with: "", options: .regularExpression)
        } else if lower.contains("quarter of an hour") || lower.contains("quarter hour") {
            extractedMinutes = 15
            textWithoutTime = textWithoutTime.replacingOccurrences(of: "(?i)quarter of an hour", with: "", options: .regularExpression)
            textWithoutTime = textWithoutTime.replacingOccurrences(of: "(?i)quarter hour", with: "", options: .regularExpression)
        } else if lower.contains("two hours") || lower.contains("2 hours") {
            extractedMinutes = 120
            textWithoutTime = textWithoutTime.replacingOccurrences(of: "(?i)two hours", with: "", options: .regularExpression)
            textWithoutTime = textWithoutTime.replacingOccurrences(of: "(?i)2 hours", with: "", options: .regularExpression)
        } else if lower.contains("an hour") || lower.contains("one hour") {
            extractedMinutes = 60
            textWithoutTime = textWithoutTime.replacingOccurrences(of: "(?i)an hour", with: "", options: .regularExpression)
            textWithoutTime = textWithoutTime.replacingOccurrences(of: "(?i)one hour", with: "", options: .regularExpression)
        }
        
        // 1. Check for hour patterns: e.g. "1h 30m", "1.5h", "2h", "1 hr", "1 hour"
        if let hourRegex = try? NSRegularExpression(pattern: #"(?i)(\d+(?:\.\d+)?)\s*(?:h|hrs?|hours?)(?:\s*(\d+)\s*(?:m|mins?|minutes?))?"#) {
            let ns = raw as NSString
            if let match = hourRegex.firstMatch(in: raw, range: NSRange(location: 0, length: ns.length)) {
                let hourStr = ns.substring(with: match.range(at: 1))
                let hours = Double(hourStr) ?? 1.0
                var mins = Int(hours * 60)
                if match.numberOfRanges > 2 && match.range(at: 2).location != NSNotFound {
                    let extraMinsStr = ns.substring(with: match.range(at: 2))
                    mins += Int(extraMinsStr) ?? 0
                }
                extractedMinutes = min(180, max(1, mins))
                textWithoutTime = hourRegex.stringByReplacingMatches(in: textWithoutTime, range: NSRange(location: 0, length: (textWithoutTime as NSString).length), withTemplate: "")
            }
        }
        
        // 2. Check for minute patterns: e.g. "45m", "25min", "50 mins", "30 minutes"
        if extractedMinutes == nil {
            if let minRegex = try? NSRegularExpression(pattern: #"(?i)(\d+)\s*(?:m|mins?|minutes?)\b"#) {
                let ns = textWithoutTime as NSString
                if let match = minRegex.firstMatch(in: textWithoutTime, range: NSRange(location: 0, length: ns.length)) {
                    let numStr = ns.substring(with: match.range(at: 1))
                    if let mins = Int(numStr), mins > 0 {
                        extractedMinutes = min(180, mins)
                        textWithoutTime = minRegex.stringByReplacingMatches(in: textWithoutTime, range: NSRange(location: 0, length: ns.length), withTemplate: "")
                    }
                }
            }
        }
        
        // 3. Check for standalone numbers e.g. "Focus 45" or "15"
        // Standalone numbers without "m/min" units are ONLY treated as timer duration
        // if the query contains an explicit timer keyword OR consists purely of digits
        let timerKeywords = ["timer", "focus", "pomo", "pomodoro", "sprint", "break", "deep work", "countdown"]
        let hasIntentKeyword = timerKeywords.contains { lower.contains($0) }
        let isPureDigits = Int(raw.trimmingCharacters(in: .whitespaces)) != nil
        
        if extractedMinutes == nil && (hasIntentKeyword || isPureDigits) {
            if let digitRegex = try? NSRegularExpression(pattern: #"\b(\d+)\b"#) {
                let ns = textWithoutTime as NSString
                if let match = digitRegex.firstMatch(in: textWithoutTime, range: NSRange(location: 0, length: ns.length)) {
                    let numStr = ns.substring(with: match.range(at: 1))
                    if let mins = Int(numStr), mins > 0 && mins <= 180 {
                        extractedMinutes = mins
                        textWithoutTime = digitRegex.stringByReplacingMatches(in: textWithoutTime, range: NSRange(location: 0, length: ns.length), withTemplate: "")
                    }
                }
            }
        }
        
        // If neither valid timer numbers nor intent keywords found, return nil (e.g. "reading response #4", "play music")
        if extractedMinutes == nil && !hasIntentKeyword {
            return nil
        }
        
        // 4. Clean up remaining text to form the personalized title
        var cleanedTitle = textWithoutTime
            .replacingOccurrences(of: "(?i)^(set a|set|start a|start|run a|run|create a|create|give me a|give me|need a|i need a|put a|put on a|put on|put)\\s+", with: "", options: .regularExpression)
            .replacingOccurrences(of: "(?i)\\b(for|in)\\b", with: "", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
        
        if ["timer", "focus", "focus timer", "pomodoro", "pomo"].contains(cleanedTitle.lowercased()) {
            cleanedTitle = ""
        }
        if cleanedTitle.lowercased().contains("break") || cleanedTitle.lowercased().contains("rest") {
            cleanedTitle = "Break"
        }
        
        let finalMinutes = extractedMinutes ?? 25
        
        if cleanedTitle.isEmpty {
            cleanedTitle = (finalMinutes == 25) ? "Focus Session" : "\(finalMinutes)m Focus"
        } else {
            cleanedTitle = cleanedTitle.capitalized
        }
        
        return ParsedTimer(minutes: finalMinutes, autoStart: true, title: cleanedTitle)
    }
    
    public static func parseMinutes(from text: String) -> Int? {
        return parse(text)?.minutes
    }
}

public struct MorphUniversalAnimation {
    /// State 1 <-> State 2: Asymmetric fluid elongation & contraction
    public static let stateElongation = Animation.spring(response: 0.32, dampingFraction: 0.96)
    
    /// State 2 <-> State 3 or State 1 <-> State 3: Fluid 4-sided squircle modal expansion
    public static let stateExpansion = Animation.spring(response: 0.34, dampingFraction: 0.96)
    
    /// State 3 -> State 2 or State 3 -> State 1: Crisp controlled modal retraction (critically damped: zero bounce)
    public static let stateRetraction = Animation.spring(response: 0.28, dampingFraction: 1.0)
    
    /// Stealth mode retraction: crisp, smooth, 100% non-bouncing critically damped spring
    public static let stealthRetraction = Animation.spring(response: 0.26, dampingFraction: 1.0)
    
    /// Universal tab switching animation inside State 3
    public static let tabSwitch = Animation.spring(response: 0.28, dampingFraction: 0.90)
    
    /// Universal wing entrance / exit for live activity pills
    public static let wingTransition = Animation.spring(response: 0.30, dampingFraction: 0.90)
}

public enum ContextualFeature: String, Identifiable, Equatable {
    case meetingFlight = "Meeting Cockpit"
    case dropShelf = "Drop Shelf"
    case formTracker = "Application Form Tracker"
    
    public var id: String { rawValue }
}

public struct MorphAIResponse: Equatable, Identifiable {
    public let id: UUID
    public let query: String
    public let title: String
    public let category: String
    public let icon: String
    public let summary: String
    public let detailedContent: String
    public let keyPoints: [String]
    public let suggestedActions: [String]
    public let timestamp: Date
    
    public init(
        id: UUID = UUID(),
        query: String,
        title: String,
        category: String = "AI Intelligence",
        icon: String = "sparkles",
        summary: String,
        detailedContent: String,
        keyPoints: [String] = [],
        suggestedActions: [String] = [],
        timestamp: Date = Date()
    ) {
        self.id = id
        self.query = query
        self.title = title
        self.category = category
        self.icon = icon
        self.summary = summary
        self.detailedContent = detailedContent
        self.keyPoints = keyPoints
        self.suggestedActions = suggestedActions
        self.timestamp = timestamp
    }
}

@MainActor
public final class NotchModel: ObservableObject {
    // Apple Dynamic Island & Physical Notch Resting Baseline
    public var idleWidth: CGFloat = 179
    public var idleHeight: CGFloat = 32
    public static let standaloneTopClearance: CGFloat = 66.0
    public var standaloneTopClearance: CGFloat { Self.standaloneTopClearance }
    
    // Expanded Island Dimensions (640 width, 225 shortened length)
    public let expandedWidth: CGFloat = 640
    public let expandedHeight: CGFloat = 225
    
    // Compact Staging Stage Dimensions (Sleek staging view before 3rd design: 380 width, 125 height)
    public let compactStageWidth: CGFloat = 380
    public let compactStageHeight: CGFloat = 125
    
    // Spotlight Typing Bar Dimensions (Horizontal Expansion on Hover: widened to 510 pt, perfectly balanced, not too fat)
    public let spotlightBarWidth: CGFloat = 510
    public let spotlightBarHeight: CGFloat = 38
    
    // Shrunk Timer Popup Dimensions (The 3rd Option: 340 pt, strictly less than 460 pt)
    public let timerPopupWidth: CGFloat = 340
    public let timerPopupHeight: CGFloat = 135
    
    @Published public var interactionMode: MorphInteractionMode = .spotlightBar
    @Published public var spotlightQuery: String = ""
    @Published public var isSpotlightBarActive: Bool = false
    @Published public var isTimerPopupActive: Bool = false
    @Published public var isPomodoroSessionActive: Bool = false
    @Published public var isEditingTimerInPill: Bool = false
    @Published public var pillEditingText: String = ""
    @Published public var requestedTimerMinutes: Int = 25
    @Published public var customTimerTitle: String = "Focus Session"
    
    // Direct conversational answers & AI Intelligence in Dynamic Island
    @Published public var directAnswerText: String = ""
    @Published public var directAnswerIcon: String = "sparkles"
    @Published public var isShowingDirectAnswer: Bool = false
    @Published public var activeAIResponse: MorphAIResponse? = nil
    @Published public var activeBackgroundTaskPill: MorphBackgroundTaskPillState = .none
    
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
        
        let timerRunning = pomodoro.isRunning || (isPomodoroSessionActive && pomodoro.timeRemaining > 0 && !pomodoro.isCompleted)
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
            return 300
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
            if interactionMode == .spotlightBar && selectedTab == .home && activeAIResponse == nil && activeContextFeature == nil {
                return compactStageWidth
            }
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
            if interactionMode == .spotlightBar && selectedTab == .home && activeAIResponse == nil && activeContextFeature == nil {
                return compactStageHeight
            }
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
            if isSpotlightBarActive || activeBackgroundTaskPill != .none || isShowingDirectAnswer {
                return .spotlightBar
            } else if isCompactActive {
                return .extendedPill
            } else if isHovered {
                return .spotlightBar
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
    }
    
    public func handleSpotlightSubmit() {
        let trimmed = spotlightQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let command = MorphSpotlightCommandParser.parse(trimmed)
        executeSpotlightCommand(command, originalQuery: trimmed)
    }
    
    public func executeSpotlightCommand(_ command: MorphSpotlightCommand, originalQuery: String? = nil) {
        let query = originalQuery ?? spotlightQuery
        switch command {
        case .answer(let text, let icon):
            let isGeneralAI = isGeneralAIQuery(query)
            if isGeneralAI {
                self.directAnswerText = text
                self.directAnswerIcon = icon
                self.isShowingDirectAnswer = true
                let aiResp = MorphSpotlightCommandParser.generateAIResponse(for: query, briefAnswer: text, icon: icon)
                displayInBigUI(aiResponse: aiResp)
            } else {
                self.directAnswerText = text
                self.directAnswerIcon = icon
                self.isShowingDirectAnswer = true
                self.activeBackgroundTaskPill = .directAnswer(text: text, icon: icon)
                self.isSpotlightBarActive = false
                self.spotlightQuery = ""
                self.isExpanded = false
                if let ctrl = MorphController.shared {
                    ctrl.scheduleWindowShrink()
                }
            }
            
        case .timer(let minutes, let title, let autoStart):
            startFocusTimerInPill(minutes: minutes, title: title, autoStart: autoStart, asBackgroundTaskPill: true)
            
        case .timerControl(let action):
            executeTimerControlAction(action)
            
        case .music(let action):
            executeMusicAction(action)
            
        case .note(let action):
            executeNoteAction(action)
            
        case .calendar(let action):
            executeCalendarAction(action)
            
        case .navigation(let tab):
            openFeature(tab)
        }
    }
    
    private func isGeneralAIQuery(_ query: String) -> Bool {
        let lower = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let directQuestions = [
            "time", "what time", "what time is it", "clock",
            "date", "what is the date", "what's the date", "today's date", "day is it", "what day is it",
            "hello", "hi", "hey", "good morning", "good afternoon", "good evening",
            "how are you", "focus tip", "give me a tip", "quote", "motivate me", "joke", "tell me a joke"
        ]
        if directQuestions.contains(where: { lower == $0 || lower.contains($0) }) {
            return false
        }
        
        // Comprehensive questions, study plans, guides & deep explanations open the large UI
        if lower.hasPrefix("how to") || lower.hasPrefix("how do") || lower.hasPrefix("why") || lower.hasPrefix("explain") || lower.contains("study plan") || lower.contains("help") || lower.contains("features") || lower.contains("commands") || lower.contains("cross entropy") {
            return true
        }
        
        // Direct task entries (e.g. "reading response #4", "finish the design") stay in the pill HUD
        let taskIndicators = ["reading", "essay", "homework", "review", "code", "design", "write", "finish", "prepare", "draft", "project", "presentation", "assignment", "paper"]
        if taskIndicators.contains(where: { lower.contains($0) }) {
            return false
        }
        return true
    }
    
    public func executeTimerControlAction(_ action: TimerControlAction) {
        self.isSpotlightBarActive = false
        self.spotlightQuery = ""
        
        switch action {
        case .pause:
            self.pomodoro.pause()
            self.activeBackgroundTaskPill = .timer(title: "Paused", minutes: self.pomodoro.remainingMinutes)
            self.isExpanded = false
            if let ctrl = MorphController.shared {
                ctrl.scheduleWindowShrink()
            }
            
        case .resume:
            self.pomodoro.start()
            self.isPomodoroSessionActive = true
            let title = self.customTimerTitle.isEmpty ? "Focus Session" : self.customTimerTitle
            self.activeBackgroundTaskPill = .timer(title: title, minutes: self.pomodoro.remainingMinutes)
            self.isExpanded = false
            if let ctrl = MorphController.shared {
                ctrl.scheduleWindowShrink()
            }
            
        case .stop:
            self.stopFocusTimerFromPill()
            
        case .adjust(let minutesDelta):
            self.pomodoro.adjustTime(deltaMinutes: minutesDelta)
            if !self.isPomodoroSessionActive {
                self.isPomodoroSessionActive = true
                self.pomodoro.start()
            }
            let sign = minutesDelta >= 0 ? "+\(minutesDelta)m" : "\(minutesDelta)m"
            self.activeBackgroundTaskPill = .timer(title: "Adjusted (\(sign))", minutes: self.pomodoro.remainingMinutes)
            self.isExpanded = false
            if let ctrl = MorphController.shared {
                ctrl.scheduleWindowShrink()
            }
            
        case .queryStatus:
            let mins = self.pomodoro.remainingMinutes
            let secs = Int(self.pomodoro.timeRemaining) % 60
            let timeStr = String(format: "%02d:%02d", mins, secs)
            let stateStr = self.pomodoro.isRunning ? "Remaining" : "Paused"
            self.activeBackgroundTaskPill = .timer(title: "\(stateStr) \(timeStr)", minutes: mins)
            self.isExpanded = false
            if let ctrl = MorphController.shared {
                ctrl.scheduleWindowShrink()
            }
        }
    }
    
    public func displayInBigUI(aiResponse: MorphAIResponse) {
        self.activeAIResponse = aiResponse
        self.isSpotlightBarActive = false
        self.spotlightQuery = ""
        self.isShowingDirectAnswer = true
        self.activeContextFeature = nil
        withAnimation(MorphUniversalAnimation.stateExpansion) {
            self.isExpanded = true
        }
        if let ctrl = MorphController.shared {
            ctrl.expandPanel()
            if !MorphEnvironment.isTestingEnvironment {
                NSApp.activate(ignoringOtherApps: true)
                ctrl.panel.makeKeyAndOrderFront(nil)
            }
        }
    }
    
    public func executeMusicAction(_ action: MusicAction) {
        self.isSpotlightBarActive = false
        self.spotlightQuery = ""
        
        switch action {
        case .play(let query):
            if let q = query, !q.isEmpty {
                self.media.playSearch(q)
            } else {
                self.media.play()
            }
            let title = self.media.trackTitle.isEmpty ? (query ?? "Music") : self.media.trackTitle
            self.activeBackgroundTaskPill = .media(trackTitle: title, artist: self.media.artistName)
            self.selectedTab = .music
            self.isExpanded = false
            if let ctrl = MorphController.shared {
                ctrl.scheduleWindowShrink()
            }
            
        case .pause:
            self.media.pause()
            self.activeBackgroundTaskPill = .media(trackTitle: self.media.trackTitle.isEmpty ? "Paused" : self.media.trackTitle, artist: self.media.artistName)
            self.selectedTab = .music
            self.isExpanded = false
            if let ctrl = MorphController.shared {
                ctrl.scheduleWindowShrink()
            }
            
        case .next:
            self.media.nextTrack()
            self.activeBackgroundTaskPill = .media(trackTitle: self.media.trackTitle.isEmpty ? "Next Track" : self.media.trackTitle, artist: self.media.artistName)
            self.selectedTab = .music
            self.isExpanded = false
            if let ctrl = MorphController.shared {
                ctrl.scheduleWindowShrink()
            }
            
        case .previous:
            self.media.previousTrack()
            self.activeBackgroundTaskPill = .media(trackTitle: self.media.trackTitle.isEmpty ? "Previous Track" : self.media.trackTitle, artist: self.media.artistName)
            self.selectedTab = .music
            self.isExpanded = false
            if let ctrl = MorphController.shared {
                ctrl.scheduleWindowShrink()
            }
            
        case .volumeUp:
            let newVol = min(1.0, self.media.volume + 0.1)
            self.media.setVolume(newVol)
            self.activeBackgroundTaskPill = .media(trackTitle: "Volume \(Int(round(newVol * 100)))%", artist: self.media.trackTitle.isEmpty ? "Morph Media" : self.media.trackTitle)
            self.selectedTab = .music
            self.isExpanded = false
            if let ctrl = MorphController.shared {
                ctrl.scheduleWindowShrink()
            }
            
        case .volumeDown:
            let newVol = max(0.0, self.media.volume - 0.1)
            self.media.setVolume(newVol)
            self.activeBackgroundTaskPill = .media(trackTitle: "Volume \(Int(round(newVol * 100)))%", artist: self.media.trackTitle.isEmpty ? "Morph Media" : self.media.trackTitle)
            self.selectedTab = .music
            self.isExpanded = false
            if let ctrl = MorphController.shared {
                ctrl.scheduleWindowShrink()
            }
            
        case .mute:
            self.media.toggleMute()
            let status = self.media.isMuted ? "Muted" : "Unmuted"
            self.activeBackgroundTaskPill = .media(trackTitle: status, artist: self.media.trackTitle.isEmpty ? "Morph Media" : self.media.trackTitle)
            self.selectedTab = .music
            self.isExpanded = false
            if let ctrl = MorphController.shared {
                ctrl.scheduleWindowShrink()
            }
            
        case .queryStatus:
            let title = self.media.trackTitle.isEmpty ? (self.media.isPlaying ? "Playing Audio" : "No track playing") : self.media.trackTitle
            let artist = self.media.artistName.isEmpty ? (self.media.isPlaying ? "Playing" : "Paused") : self.media.artistName
            self.activeBackgroundTaskPill = .media(trackTitle: title, artist: artist)
            self.selectedTab = .music
            self.isExpanded = false
            if let ctrl = MorphController.shared {
                ctrl.scheduleWindowShrink()
            }
            
        case .open:
            // General music request -> open larger UI to Music page so user can pick
            openFeature(.music)
        }
    }
    
    public func executeNoteAction(_ action: NoteAction) {
        self.isSpotlightBarActive = false
        self.spotlightQuery = ""
        
        switch action {
        case .add(let text, let pinToNotch):
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            
            if self.scratchpad.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                self.scratchpad.text = trimmed
            } else {
                self.scratchpad.text += "\n" + trimmed
            }
            
            if pinToNotch {
                self.isNotePinnedToNotch = true
            }
            self.activeBackgroundTaskPill = .note(previewText: trimmed)
            self.selectedTab = .notes
            self.isExpanded = false
            if let ctrl = MorphController.shared {
                ctrl.scheduleWindowShrink()
            }
            
        case .view:
            // General notes request -> open larger UI to Notes page so user can pick & edit
            openFeature(.notes)
            
        case .clear:
            self.scratchpad.clear()
            self.isNotePinnedToNotch = false
            self.activeBackgroundTaskPill = .note(previewText: "Notes cleared")
            self.selectedTab = .notes
            self.isExpanded = false
            if let ctrl = MorphController.shared {
                ctrl.scheduleWindowShrink()
            }
            
        case .readPreview:
            let currentNotes = self.scratchpad.text.trimmingCharacters(in: .whitespacesAndNewlines)
            let preview = currentNotes.isEmpty ? "No notes saved yet" : (currentNotes.components(separatedBy: .newlines).first ?? currentNotes)
            self.activeBackgroundTaskPill = .note(previewText: preview)
            self.selectedTab = .notes
            self.isExpanded = false
            if let ctrl = MorphController.shared {
                ctrl.scheduleWindowShrink()
            }
            
        case .copyToClipboard:
            self.scratchpad.copyAll()
            self.activeBackgroundTaskPill = .note(previewText: "Copied notes to clipboard")
            self.selectedTab = .notes
            self.isExpanded = false
            if let ctrl = MorphController.shared {
                ctrl.scheduleWindowShrink()
            }
        }
    }
    
    public func executeCalendarAction(_ action: CalendarAction) {
        self.isSpotlightBarActive = false
        self.spotlightQuery = ""
        
        switch action {
        case .add(let title, let hour, let minute, let duration):
            self.calendar.addQuickEvent(
                title: title,
                durationMinutes: duration,
                startHour: hour,
                startMinute: minute
            )
            self.selectedTab = .calendar
            let briefing = self.calendar.fetchTodayBriefing()
            self.activeBackgroundTaskPill = .calendar(
                title: "Added: \(title)",
                timeText: briefing.detail,
                meetLink: nil,
                fullEvent: nil
            )
            self.isExpanded = false
            if let ctrl = MorphController.shared {
                ctrl.scheduleWindowShrink()
            }
            
        case .todaySummary:
            self.selectedTab = .calendar
            let briefing = self.calendar.fetchTodayBriefing()
            self.activeBackgroundTaskPill = .calendar(
                title: briefing.headline,
                timeText: briefing.detail,
                meetLink: briefing.meetLink,
                fullEvent: briefing.event
            )
            self.isExpanded = false
            if let ctrl = MorphController.shared {
                ctrl.scheduleWindowShrink()
            }
            
        case .open:
            openFeature(.calendar)
        }
    }
    
    public func startFocusTimerInPill(minutes: Int, title: String = "Focus Session", autoStart: Bool = true, asBackgroundTaskPill: Bool = false) {
        self.requestedTimerMinutes = minutes
        self.customTimerTitle = title
        self.pomodoro.setCustomDuration(minutes: minutes, saveAsPreference: false)
        self.isPomodoroSessionActive = true
        self.isTimerPopupActive = false
        self.isSpotlightBarActive = false
        self.isEditingTimerInPill = false
        self.isHovered = false
        self.isExpanded = false
        self.activeContextFeature = nil
        self.spotlightQuery = ""
        
        if autoStart {
            self.pomodoro.start()
        }
        
        if asBackgroundTaskPill {
            self.activeBackgroundTaskPill = .timer(title: title, minutes: minutes)
        } else {
            self.activeBackgroundTaskPill = .none
        }
        
        withAnimation(MorphUniversalAnimation.stateExpansion) {
            // Smoothly transitions into the lengthened background pill HUD
        }
        if let ctrl = MorphController.shared {
            ctrl.panel.ignoresMouseEvents = false
            ctrl.scheduleWindowShrink()
        }
    }
    
    public func stopFocusTimer() {
        pomodoro.pause()
        pomodoro.reset()
        isPomodoroSessionActive = false
        isEditingTimerInPill = false
        isTimerPopupActive = false
        activeBackgroundTaskPill = .none
        spotlightQuery = ""
        withAnimation(MorphUniversalAnimation.stateRetraction) {
            // Smoothly collapses back to resting notch
        }
        if let ctrl = MorphController.shared {
            ctrl.scheduleWindowShrink()
        }
    }
    
    public func startEditingTimerInPill() {
        if !customTimerTitle.isEmpty {
            self.pillEditingText = "\(customTimerTitle) \(pomodoro.remainingMinutes)m"
        } else {
            self.pillEditingText = "\(pomodoro.remainingMinutes)m"
        }
        withAnimation(MorphUniversalAnimation.stateExpansion) {
            self.isEditingTimerInPill = true
        }
        if let ctrl = MorphController.shared {
            ctrl.panel.ignoresMouseEvents = false
            ctrl.panel.makeKeyAndOrderFront(nil)
        }
    }
    
    public func commitPillTimerEdit() {
        let trimmed = pillEditingText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            let command = MorphSpotlightCommandParser.parse(trimmed)
            switch command {
            case .timer(let minutes, let title, _):
                self.customTimerTitle = title
                self.requestedTimerMinutes = minutes
                self.pomodoro.setCustomDuration(minutes: minutes, saveAsPreference: false)
                self.isPomodoroSessionActive = true
                self.pomodoro.start()
            default:
                executeSpotlightCommand(command)
            }
        }
        withAnimation(MorphUniversalAnimation.stateRetraction) {
            self.isEditingTimerInPill = false
        }
    }
    
    public func cancelPillTimerEdit() {
        withAnimation(MorphUniversalAnimation.stateRetraction) {
            self.isEditingTimerInPill = false
        }
    }
    
    public func triggerTimerPopup(minutes: Int, title: String = "Focus Session", autoStart: Bool = true) {
        startFocusTimerInPill(minutes: minutes, title: title, autoStart: autoStart)
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
    
    /// Completely resets all transient state when Morph collapses so that upon re-opening,
    /// Morph starts 100% fresh and never remembers past typed queries or lingering dialogs.
    public func resetTransientStateOnCollapse() {
        self.spotlightQuery = ""
        self.isShowingDirectAnswer = false
        self.activeBackgroundTaskPill = .none
        self.directAnswerText = ""
        self.directAnswerIcon = "sparkles"
        self.isEditingTimerInPill = false
        self.pillEditingText = ""
        self.isTimerPopupActive = false
        self.activeAIResponse = nil
        self.isCommandBarPresented = false
        self.isSpotlightBarActive = false
        self.isHovered = false
        if !isPomodoroSessionActive {
            self.isExpanded = false
        }
    }
    
    public func addFiveMinutesToTimer() {
        self.pomodoro.timeRemaining += 300
    }
    
    public func subtractFiveMinutesFromTimer() {
        self.pomodoro.timeRemaining = max(60, self.pomodoro.timeRemaining - 300)
    }
    
    public func stopFocusTimerFromPill() {
        self.stopFocusTimer()
        self.activeBackgroundTaskPill = .none
        if let ctrl = MorphController.shared {
            ctrl.dismissToStealth()
        }
    }
    
    public func dismissBackgroundTaskPill() {
        self.activeBackgroundTaskPill = .none
        self.isShowingDirectAnswer = false
        if let ctrl = MorphController.shared {
            ctrl.dismissToStealth()
        }
    }
    
    public func resetSpotlightBar() {
        if let ctrl = MorphController.shared {
            ctrl.dismissToStealth()
        } else {
            withAnimation(MorphUniversalAnimation.stealthRetraction) {
                self.resetTransientStateOnCollapse()
            }
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
        activeAIResponse = nil
        isSpotlightBarActive = false
        spotlightQuery = ""
        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
            selectedTab = tab
            if tab != .home {
                lastUsedFeatureTab = tab
            }
            activeContextFeature = nil
            isCommandBarPresented = false
            isExpanded = true
        }
        if let ctrl = MorphController.shared {
            ctrl.expandPanel()
            if !MorphEnvironment.isTestingEnvironment {
                NSApp.activate(ignoringOtherApps: true)
                ctrl.panel.makeKeyAndOrderFront(nil)
            }
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
