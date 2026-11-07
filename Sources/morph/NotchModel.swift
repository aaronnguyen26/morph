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
    case glassIsland = "Glass Island (Liquid Glass Dynamic Island)"
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

// MARK: - Color Hex Initializer
extension Color {
    public init(hex: String) {
        let clean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: clean).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch clean.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 255, 255, 255)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255.0,
            green: Double(g) / 255.0,
            blue: Double(b) / 255.0,
            opacity: Double(a) / 255.0
        )
    }
    
    public var toHex: String {
        return NSColor(self).toHexString
    }
}

extension NSColor {
    public var toHexString: String {
        guard let rgbColor = usingColorSpace(.sRGB) else {
            return "#ffffff"
        }
        let r = Int(round(rgbColor.redComponent * 255.0))
        let g = Int(round(rgbColor.greenComponent * 255.0))
        let b = Int(round(rgbColor.blueComponent * 255.0))
        return String(format: "#%02x%02x%02x", r, g, b)
    }
}

// MARK: - Glass Island HTML Specification Models
public enum GlassIslandState: String, CaseIterable, Equatable {
    case idle
    case prompt
    case timer
    case calendar
    case music
    case notes
    case forms
    case drops
    case reply
    case profile
}

public enum MorphGlassFeature: String, CaseIterable, Identifiable, Codable {
    case timer
    case calendar
    case music
    case notes
    case forms
    case drops
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .timer: return "Focus Timer"
        case .calendar: return "Calendar"
        case .music: return "Music Player"
        case .notes: return "Notes & Scratchpad"
        case .forms: return "Form Assistant"
        case .drops: return "Drop Shelf"
        }
    }
    
    public var iconName: String {
        switch self {
        case .timer: return "timer"
        case .calendar: return "calendar"
        case .music: return "music.note"
        case .notes: return "doc.text"
        case .forms: return "list.bullet.clipboard"
        case .drops: return "tray.and.arrow.down"
        }
    }
    
    public var description: String {
        switch self {
        case .timer: return "Pomodoro sessions & time tracking"
        case .calendar: return "Daily agenda & meeting schedules"
        case .music: return "YouTube Music player & library"
        case .notes: return "Quick notes & markdown scratchpad"
        case .forms: return "Real-time form detection & autofill"
        case .drops: return "Staged files, PDFs & quick drag-and-drop"
        }
    }
    
    public var state: GlassIslandState {
        switch self {
        case .timer: return .timer
        case .calendar: return .calendar
        case .music: return .music
        case .notes: return .notes
        case .forms: return .forms
        case .drops: return .drops
        }
    }
    
    public var tintColorHex: String {
        switch self {
        case .timer: return "#ff9a7a"
        case .calendar: return "#6ab7ff"
        case .music: return "#ff7ab8"
        case .notes: return "#ffd36a"
        case .forms: return "#8ff0b4"
        case .drops: return "#38bdf8"
        }
    }
}

public struct MorphFeatureColorPreset: Identifiable, Hashable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let hex: String
    
    public init(id: String, name: String, hex: String) {
        self.id = id
        self.name = name
        self.hex = hex
    }
    
    public static let standardPresets: [MorphFeatureColorPreset] = [
        MorphFeatureColorPreset(id: "coral", name: "Sunset Coral", hex: "#ff9a7a"),
        MorphFeatureColorPreset(id: "sky", name: "Electric Sky", hex: "#6ab7ff"),
        MorphFeatureColorPreset(id: "neon_pink", name: "Neon Pink", hex: "#ff7ab8"),
        MorphFeatureColorPreset(id: "amber", name: "Amber Gold", hex: "#ffd36a"),
        MorphFeatureColorPreset(id: "emerald", name: "Mint Emerald", hex: "#8ff0b4"),
        MorphFeatureColorPreset(id: "violet", name: "Cosmic Violet", hex: "#b79cff"),
        MorphFeatureColorPreset(id: "lavender", name: "Soft Lavender", hex: "#a78bfa"),
        MorphFeatureColorPreset(id: "cyan", name: "Cyan Teal", hex: "#22d3ee"),
        MorphFeatureColorPreset(id: "rose", name: "Crimson Rose", hex: "#f43f5e")
    ]
}

public enum GlassFormMode: String, CaseIterable, Equatable {
    case live
    case copies
    case profile
}

public enum GlassTimerStatus: String, CaseIterable, Equatable {
    case ready
    case running
    case paused
    case done
}

public enum GlassMusicSubtab: String, CaseIterable, Identifiable {
    case playing = "now"
    case library = "lib"
    case queue = "queue"
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .playing: return "Playing"
        case .library: return "Library"
        case .queue: return "Queue"
        }
    }
}

public struct GlassTrack: Equatable, Identifiable {
    public let id: UUID
    public var title: String
    public var artist: String
    public var duration: Int
    public var gradientHexes: [String]
    public var videoId: String?
    public var thumbnailURL: String?
    
    public init(
        id: UUID = UUID(),
        title: String,
        artist: String,
        duration: Int,
        gradientHexes: [String],
        videoId: String? = nil,
        thumbnailURL: String? = nil
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.duration = duration
        self.gradientHexes = gradientHexes
        self.videoId = videoId
        self.thumbnailURL = thumbnailURL
    }
}

public struct GlassCalendarEvent: Equatable, Identifiable {
    public let id: UUID
    public var startMinute: Int
    public var title: String
    public var location: String
    public var colorHex: String
    
    public init(id: UUID = UUID(), startMinute: Int, title: String, location: String, colorHex: String) {
        self.id = id
        self.startMinute = startMinute
        self.title = title
        self.location = location
        self.colorHex = colorHex
    }
    
    public var formattedTime: String {
        let h = startMinute / 60
        let ap = h >= 12 ? "PM" : "AM"
        let h12 = (h % 12 == 0) ? 12 : (h % 12)
        let m = startMinute % 60
        return String(format: "%d:%02d %@", h12, m, ap)
    }
}

public struct GlassNote: Equatable, Identifiable {
    public var id: UUID
    public var title: String
    public var body: String
    
    public init(id: UUID = UUID(), title: String, body: String) {
        self.id = id
        self.title = title
        self.body = body
    }
}

public enum GlassNotesMode: String, CaseIterable, Equatable {
    case list
    case edit
}

public enum MorphIntermediaryStageState: Equatable {
    case home(greeting: String, subtitle: String)
    case timer(minutes: Int, title: String)
    case music(query: String?, trackTitle: String, artist: String, isPlaying: Bool)
    case calendar(headline: String, subtitle: String, meetLink: String?)
    case notes(previewText: String)
    case answer(query: String, headline: String, subtitle: String, icon: String)
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
    
    // Glass Island / Intermediary Action Stage Dimensions (440 width, 142 height)
    public let compactStageWidth: CGFloat = 440
    public let compactStageHeight: CGFloat = 142
    
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
    @Published public var activeIntermediaryStage: MorphIntermediaryStageState? = nil
    
    // MARK: - Glass Island HTML Design State
    @Published public var glassIslandState: GlassIslandState = .idle
    public var isGlassIslandEnabled: Bool {
        get { interactionMode == .glassIsland }
        set {
            if newValue {
                interactionMode = .glassIsland
            } else if interactionMode == .glassIsland {
                interactionMode = .spotlightBar
            }
        }
    }
    
    // Focus Timer State
    @Published public var glassTimerMins: Int = 25
    @Published public var glassTimerLeft: Int = 1500
    @Published public var glassTimerDur: Int = 1500
    @Published public var glassTimerStatus: GlassTimerStatus = .ready
    @Published public var glassTimerDoneCount: Int = 1
    private var glassTimerTimer: Timer? = nil
    private var glassTimerEndTime: Date? = nil
    
    // Music Player State
    @Published public var glassMusicSubtab: GlassMusicSubtab = .playing
    @Published public var glassMusicSearchText: String = ""
    @Published public var glassSelectedPlaylist: YTMPlaylist? = nil
    @Published public var glassTracks: [GlassTrack] = []
    @Published public var glassTrackIndex: Int = 0
    @Published public var glassTrackCurrentSeconds: Int = 0
    @Published public var _simulatedGlassMusicPlaying: Bool = false
    public var isGlassMusicPlaying: Bool {
        get { media.isPlaying || _simulatedGlassMusicPlaying }
        set {
            if newValue {
                media.play()
                _simulatedGlassMusicPlaying = true
            } else {
                media.pause()
                _simulatedGlassMusicPlaying = false
            }
        }
    }
    
    public var isBackgroundMusicActive: Bool {
        guard isFeatureEnabled(.music) else { return false }
        if isGlassMusicPlaying || media.isPlaying { return true }
        if case .media = activeBackgroundTaskPill { return true }
        return false
    }
    
    public var isBackgroundTimerActive: Bool {
        guard isFeatureEnabled(.timer) else { return false }
        if isGlassTimerActive { return true }
        if case .timer = activeBackgroundTaskPill { return true }
        return false
    }
    
    public var isBackgroundFormActive: Bool {
        // Only considered active when the forms feature is enabled in the profile
        // AND a form is actively detected on screen right now (showing on the stealth pill).
        guard isFeatureEnabled(.forms) else { return false }
        return formTracker.isFormDetected
    }
    
    public var isBackgroundDropActive: Bool {
        guard isFeatureEnabled(.drops) else { return false }
        return dropShelf.hasItems || dropShelf.isDraggingOverNotch
    }
    
    public var contextualOpenState: GlassIslandState {
        // Priority: active background tasks (timer/music) always take precedence over
        // form detection so hovering opens the thing already visible on the stealth pill.
        // Forms and Drop Shelf are contextual destinations when active.
        if dropShelf.isDraggingOverNotch && isFeatureEnabled(.drops) {
            return .drops
        } else if isBackgroundMusicActive && isFeatureEnabled(.music) {
            return .music
        } else if isBackgroundTimerActive && isFeatureEnabled(.timer) {
            return .timer
        } else if isBackgroundDropActive {
            return .drops
        } else if isBackgroundFormActive {
            // isBackgroundFormActive already checks isFeatureEnabled(.forms)
            return .forms
        } else if calendar.showNotchAlert && isFeatureEnabled(.calendar) {
            return .calendar
        } else {
            return .prompt
        }
    }
    private var glassMusicTimer: Timer? = nil
    @Published public var hasPromptedMusicSignIn: Bool = false
    @Published public var targetedHoverGlassState: GlassIslandState? = nil
    
    // Calendar State
    /// Index (Mon = 0 ... Sun = 6) of the selected day inside the week shown by the glass calendar.
    /// Backed by `calendar.selectedDate` so the 3-Day / Week / Month views share one source of truth.
    /// Assigning an index selects that weekday of the *current* (today's) week.
    public var glassSelectedDayIndex: Int {
        get {
            let weekday = Calendar.current.component(.weekday, from: calendar.selectedDate)
            return (weekday == 1) ? 6 : (weekday - 2)
        }
        set {
            let cal = Calendar.current
            let weekday = cal.component(.weekday, from: Date())
            let monOffset = (weekday == 1) ? -6 : (2 - weekday)
            guard let monday = cal.date(byAdding: .day, value: monOffset, to: cal.startOfDay(for: Date())),
                  let target = cal.date(byAdding: .day, value: max(0, min(6, newValue)), to: monday) else { return }
            calendar.selectedDate = target
            calendar.displayedMonth = target
        }
    }
    @Published public var hasPromptedCalendarSignIn: Bool = false
    @Published public var glassCalendarEvents: [Int: [GlassCalendarEvent]] = [:]
    
    // Notes State
    @Published public var glassNotesMode: GlassNotesMode = .list
    @Published public var glassNotes: [GlassNote] = []
    @Published public var glassActiveNoteId: UUID? = nil
    @Published public var glassEditTitle: String = ""
    @Published public var glassEditBody: String = ""
    
    // Reply State
    @Published public var glassReplyQuery: String = ""
    @Published public var glassReplyAnswer: String = "Prompts that mention the timer, calendar, music or notes are routed there. Connect a model to answer anything else."
    @Published public var isGlassReplyLoading: Bool = false
    
    // Prompt Input
    @Published public var glassPromptText: String = ""
    @Published public var isGlassIslandPinned: Bool = false
    
    // Form Assistant State
    @Published public var glassFormMode: GlassFormMode = .live
    @Published public var selectedFormCopyId: String? = nil
    @Published public var isFormCopyDetailOpen: Bool = false
    
    // Feature Toggles (Configurable Toolbar Feature Symbols)
    @Published public var enabledFeatures: Set<MorphGlassFeature> = Set(MorphGlassFeature.allCases)
    
    public func isFeatureEnabled(_ feature: MorphGlassFeature) -> Bool {
        return enabledFeatures.contains(feature)
    }
    
    public func setFeature(_ feature: MorphGlassFeature, isEnabled: Bool) {
        if isEnabled {
            enabledFeatures.insert(feature)
        } else {
            enabledFeatures.remove(feature)
            if glassIslandState == feature.state {
                setGlassIslandState(.profile)
            }
        }
        syncFormTrackerFeatureState()
        let array = Array(enabledFeatures.map { $0.rawValue })
        UserDefaults.standard.set(array, forKey: "com.morph.enabled_features")
    }
    
    public func toggleFeature(_ feature: MorphGlassFeature) {
        setFeature(feature, isEnabled: !isFeatureEnabled(feature))
    }
    
    public func loadEnabledFeatures() {
        if let stored = UserDefaults.standard.stringArray(forKey: "com.morph.enabled_features") {
            let features = stored.compactMap { MorphGlassFeature(rawValue: $0) }
            if !features.isEmpty {
                self.enabledFeatures = Set(features)
                syncFormTrackerFeatureState()
                return
            }
        }
        self.enabledFeatures = Set(MorphGlassFeature.allCases)
        syncFormTrackerFeatureState()
    }
    
    private func syncFormTrackerFeatureState() {
        let formsEnabled = isFeatureEnabled(.forms)
        formTracker.isFormFeatureEnabled = formsEnabled
        if !formsEnabled {
            if formTracker.isFormDetected || formTracker.isTracking {
                if let current = formTracker.activeSession {
                    formTracker.suspendedSession = current
                }
                formTracker.isFormDetected = false
                formTracker.isJustDetected = false
                formTracker.isTracking = false
            }
            if activeContextFeature == .formTracker {
                activeContextFeature = nil
            }
        }
    }
    
    // Feature Color Customization (Live & Persisted)
    @Published public var customFeatureColors: [MorphGlassFeature: String] = [:]
    
    public func featureTintColorHex(_ feature: MorphGlassFeature) -> String {
        return customFeatureColors[feature] ?? feature.tintColorHex
    }
    
    public func setCustomFeatureColor(_ hex: String, for feature: MorphGlassFeature) {
        var cleanHex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanHex.hasPrefix("#") {
            cleanHex = "#" + cleanHex
        }
        customFeatureColors[feature] = cleanHex
        saveCustomFeatureColors()
    }
    
    public func resetFeatureColor(for feature: MorphGlassFeature) {
        customFeatureColors.removeValue(forKey: feature)
        saveCustomFeatureColors()
    }
    
    public func saveCustomFeatureColors() {
        var dict: [String: String] = [:]
        for (feat, color) in customFeatureColors {
            dict[feat.rawValue] = color
        }
        UserDefaults.standard.set(dict, forKey: "com.morph.custom_feature_colors")
    }
    
    public func loadCustomFeatureColors() {
        guard let stored = UserDefaults.standard.dictionary(forKey: "com.morph.custom_feature_colors") as? [String: String] else {
            return
        }
        var loaded: [MorphGlassFeature: String] = [:]
        for (key, val) in stored {
            if let feat = MorphGlassFeature(rawValue: key) {
                loaded[feat] = val
            }
        }
        self.customFeatureColors = loaded
    }
    
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
        initGlassState()
        checkInitialLaunchStep()
    }
    
    private func initGlassState() {
        loadEnabledFeatures()
        loadCustomFeatureColors()
        if !media.quickPicks.isEmpty {
            syncGlassTracks(from: media.quickPicks)
        } else if !media.playlist.isEmpty {
            syncGlassTracks(from: media.playlist)
        } else {
            syncGlassTracks(from: YTMParser.defaultQuickPicks)
        }
        
        let trimmedScratch = scratchpad.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedScratch.isEmpty {
            glassNotes = [GlassNote(title: "Scratchpad", body: trimmedScratch)]
        } else {
            glassNotes = [GlassNote(title: "Quick Note", body: "Write your thoughts, ideas, or to-dos here. Changes save automatically.")]
        }
        
        glassSelectedDayIndex = glassTodayDayIndex
        calendar.goToToday()
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
        
        // Priority 3: Form Tracker (Strictly context-aware: active when an application form is
        // detected on screen AND the forms feature is enabled in the user's profile)
        if formTracker.isFormDetected && isFeatureEnabled(.forms) {
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
    
    public var isIntermediaryStageActive: Bool {
        guard isExpanded else { return false }
        if activeIntermediaryStage != nil { return true }
        if interactionMode == .spotlightBar && selectedTab == .home && activeAIResponse == nil && activeContextFeature == nil {
            return true
        }
        return false
    }
    
    // MARK: - Glass Island HTML Specification Metrics
    public var isGlassTimerActive: Bool {
        return glassTimerStatus == .running || glassTimerStatus == .paused
    }
    
    public var glassIslandWidth: CGFloat {
        switch glassIslandState {
        case .idle:
            if dropShelf.isDraggingOverNotch {
                return 280
            }
            let hasDrops = isBackgroundDropActive
            let hasForm = isBackgroundFormActive
            let hasTimer = isGlassTimerActive && isFeatureEnabled(.timer)
            let hasMusic = isGlassMusicPlaying && isFeatureEnabled(.music)
            if hasDrops {
                if hasForm {
                    return 390
                } else if hasTimer && hasMusic {
                    return 360
                } else if hasTimer || hasMusic {
                    return 300
                } else {
                    return 220
                }
            }
            if hasForm {
                if hasTimer && hasMusic {
                    return 410
                } else if hasMusic {
                    return 380
                } else if hasTimer {
                    return 370
                } else {
                    return 300
                }
            } else if hasTimer && hasMusic {
                return 268
            } else if hasTimer {
                return 208
            } else if hasMusic {
                return 196
            } else {
                return 176
            }
        case .prompt, .timer, .calendar, .music, .notes, .forms, .drops, .reply, .profile:
            return 460
        }
    }
    
    public var glassIslandHeight: CGFloat {
        switch glassIslandState {
        case .idle:
            return 38
        case .prompt:
            return isPromptPeekActive ? 108 : 56
        case .timer:
            return 258
        case .calendar:
            return 308
        case .music:
            return 384
        case .notes:
            return 284
        case .forms:
            return 284
        case .drops:
            return 284
        case .reply:
            return 152
        case .profile:
            return 380
        }
    }
    
    public var glassIslandRadius: CGFloat {
        switch glassIslandState {
        case .idle:
            return 19
        case .prompt:
            return 28
        case .timer, .calendar, .music, .notes, .forms, .drops, .reply, .profile:
            return 34
        }
    }
    
    public var glassIslandTintHex: String {
        switch glassIslandState {
        case .idle, .prompt:
            return "#cfd8ff"
        case .timer:
            return featureTintColorHex(.timer)
        case .calendar:
            return featureTintColorHex(.calendar)
        case .music:
            return featureTintColorHex(.music)
        case .notes:
            return featureTintColorHex(.notes)
        case .forms:
            return featureTintColorHex(.forms)
        case .drops:
            return featureTintColorHex(.drops)
        case .reply:
            return "#b79cff"
        case .profile:
            return "#a78bfa"
        }
    }
    
    public var isPromptPeekActive: Bool {
        guard glassIslandState == .prompt else { return false }
        let clean = glassPromptText.trimmingCharacters(in: .whitespacesAndNewlines)
        return !clean.isEmpty
    }
    
    public struct PromptPeekInfo: Equatable {
        public var title: String
        public var subtitle: String
        public var icon: String
        public var actionType: String
        public var matchedRecordId: String? = nil
        
        public init(
            title: String,
            subtitle: String,
            icon: String,
            actionType: String,
            matchedRecordId: String? = nil
        ) {
            self.title = title
            self.subtitle = subtitle
            self.icon = icon
            self.actionType = actionType
            self.matchedRecordId = matchedRecordId
        }
    }
    
    public var promptPeekInfo: PromptPeekInfo? {
        let q = glassPromptText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return nil }
        let lower = q.lowercased()
        
        // 1. Check form memory storage match (from Supabase or local memory)
        let memories = supabase.searchMemories(query: q)
        if let match = memories.first {
            let snippet = match.body.replacingOccurrences(of: "\n", with: " · ").prefix(60)
            return PromptPeekInfo(
                title: "Form Memory: \(match.title.isEmpty ? "Saved Copy" : match.title)",
                subtitle: "“\(snippet)”",
                icon: "doc.plaintext.fill",
                actionType: "memory",
                matchedRecordId: match.id
            )
        }
        
        if let matchCopy = formTracker.savedFormCopies.first(where: {
            $0.formTitle.localizedCaseInsensitiveContains(q) || q.localizedCaseInsensitiveContains($0.formTitle)
        }) {
            return PromptPeekInfo(
                title: "Form Memory: \(matchCopy.formTitle)",
                subtitle: "“\(matchCopy.previewSummary)”",
                icon: "doc.plaintext.fill",
                actionType: "memory",
                matchedRecordId: matchCopy.id
            )
        }
        
        if let matchReceipt = supabase.formReceipts.first(where: {
            $0.formTitle.localizedCaseInsensitiveContains(q) || q.localizedCaseInsensitiveContains($0.formTitle)
        }) {
            return PromptPeekInfo(
                title: "Form Memory: \(matchReceipt.formTitle)",
                subtitle: "“\(matchReceipt.totalQuestions) questions captured”",
                icon: "doc.plaintext.fill",
                actionType: "memory",
                matchedRecordId: matchReceipt.id
            )
        }
        
        // 2. Check input question or autofill command
        if lower.contains("input") || lower == "fill question" || lower == "fill this" {
            return PromptPeekInfo(
                title: "Input Saved Answer",
                subtitle: "Input recorded answer for active question into form",
                icon: "arrow.down.doc.fill",
                actionType: "inputQuestion"
            )
        }
        if lower.contains("autofill") || lower == "fill" || lower == "fill form" {
            return PromptPeekInfo(
                title: "Autofill Google Form",
                subtitle: "Fill saved answers into active form",
                icon: "pencil.and.outline",
                actionType: "autofill"
            )
        }
        
        // 2B. Drop Shelf / Staged Files Command
        if lower.contains("drop") || lower.contains("shelf") || lower == "files" || lower == "stash" || lower == "staged" {
            return PromptPeekInfo(
                title: "Open Drop Shelf",
                subtitle: dropShelf.hasItems ? "\(dropShelf.count) staged files ready to dispatch" : "Drop files to stage & drag out",
                icon: "tray.and.arrow.down.fill",
                actionType: "drops"
            )
        }
        
        // 3. Check notes
        let notePattern = #"^(?:note|remember|jot)\s*[:\-]?\s*(.+)$"#
        if let regex = try? NSRegularExpression(pattern: notePattern, options: [.caseInsensitive]),
           regex.firstMatch(in: q, options: [], range: NSRange(location: 0, length: q.utf16.count)) != nil {
            return PromptPeekInfo(
                title: "Save as a note",
                subtitle: "“\(q.prefix(50))” · stored in Memory",
                icon: "doc.text.fill",
                actionType: "note"
            )
        }
        
        // 4. Check focus timer
        let timerPattern = #"\b(?:focus|timer|pomodoro)\b(?:\D*(\d{1,3}))?"#
        if let regex = try? NSRegularExpression(pattern: timerPattern, options: [.caseInsensitive]),
           let m = regex.firstMatch(in: lower, options: [], range: NSRange(location: 0, length: lower.utf16.count)) {
            var mins = 25
            if m.numberOfRanges > 1 && m.range(at: 1).location != NSNotFound {
                if let r = Range(m.range(at: 1), in: lower), let parsed = Int(lower[r]) {
                    mins = max(1, min(180, parsed))
                }
            }
            return PromptPeekInfo(
                title: "Start a \(mins)-minute focus session",
                subtitle: "The timer starts right away",
                icon: "timer",
                actionType: "timer"
            )
        }
        
        // 5. Check calendar
        let calPattern = #"\b(calendar|schedule|agenda|meeting|meetings|today|next up)\b"#
        if let regex = try? NSRegularExpression(pattern: calPattern, options: [.caseInsensitive]),
           regex.firstMatch(in: lower, options: [], range: NSRange(location: 0, length: lower.utf16.count)) != nil {
            return PromptPeekInfo(
                title: "Open today’s schedule",
                subtitle: "Shows your next event",
                icon: "calendar",
                actionType: "calendar"
            )
        }
        
        // 6. Check music
        let musicPattern = #"\b(play|pause|music|song|track|skip|next)\b"#
        if let regex = try? NSRegularExpression(pattern: musicPattern, options: [.caseInsensitive]),
           regex.firstMatch(in: lower, options: [], range: NSRange(location: 0, length: lower.utf16.count)) != nil {
            let action = lower.contains("pause") ? "Pause music" : (lower.contains("skip") || lower.contains("next") ? "Skip track" : "Play music")
            return PromptPeekInfo(
                title: action,
                subtitle: "YouTube Music",
                icon: "music.note",
                actionType: "music"
            )
        }
        
        // 7. Check form keywords
        if lower.contains("form") || lower.contains("receipt") || lower.contains("history") || lower.contains("judge") {
            return PromptPeekInfo(
                title: "Open Form Assistant",
                subtitle: "View live form and saved memory copies",
                icon: "list.bullet.clipboard.fill",
                actionType: "forms"
            )
        }
        
        // 8. Default ask
        return PromptPeekInfo(
            title: "Ask “\(q.prefix(32))”",
            subtitle: "Saved to Memory as a prompt",
            icon: "sparkles",
            actionType: "ask"
        )
    }
    
    public var formattedGlassTimerTime: String {
        let mins = glassTimerLeft / 60
        let secs = glassTimerLeft % 60
        return String(format: "%02d:%02d", mins, secs)
    }
    
    public var glassMusicTitle: String {
        if !media.trackTitle.isEmpty {
            return media.trackTitle
        }
        if media.isBrowserConnected {
            return "YouTube Music Connected"
        }
        if !glassTracks.isEmpty && glassTrackIndex < glassTracks.count {
            return glassTracks[glassTrackIndex].title
        }
        return "No Track Playing"
    }
    
    public var glassMusicArtist: String {
        if !media.artistName.isEmpty {
            return media.artistName
        }
        if media.isBrowserConnected {
            return media.sourceName
        }
        if !glassTracks.isEmpty && glassTrackIndex < glassTracks.count {
            return glassTracks[glassTrackIndex].artist
        }
        return media.isSignedIn ? "YouTube Music" : "Sign in to YouTube Music"
    }
    
    public var formattedGlassTrackCurrentTime: String {
        let sec = Int(media.currentTime > 0 ? media.currentTime : TimeInterval(glassTrackCurrentSeconds))
        let mins = sec / 60
        let secs = sec % 60
        return String(format: "%d:%02d", mins, secs)
    }
    
    public var formattedGlassTrackDuration: String {
        let dur = Int(media.duration > 0 ? media.duration : TimeInterval(glassTracks.isEmpty ? 0 : glassTracks[glassTrackIndex].duration))
        if dur <= 0 {
            return "--:--"
        }
        let mins = dur / 60
        let secs = dur % 60
        return String(format: "%d:%02d", mins, secs)
    }
    
    public var glassTimerProgress: CGFloat {
        if glassTimerStatus == .done { return 1.0 }
        return CGFloat(max(0, glassTimerDur - glassTimerLeft)) / CGFloat(max(1, glassTimerDur))
    }
    
    public var currentWidth: CGFloat {
        if isGlassIslandEnabled {
            return glassIslandWidth
        }
        switch islandState {
        case .spotlightBar:
            return spotlightBarWidth
        case .timerPopup:
            return timerPopupWidth
        case .fullExpanded:
            if isIntermediaryStageActive {
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
        if isGlassIslandEnabled {
            return glassIslandHeight
        }
        switch islandState {
        case .spotlightBar:
            return spotlightBarHeight
        case .timerPopup:
            return timerPopupHeight
        case .fullExpanded:
            if isIntermediaryStageActive {
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
        case .glassIsland:
            if isCompactActive {
                return .extendedPill
            } else {
                return .resting
            }
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
        self.activeIntermediaryStage = nil
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
        if isGlassIslandEnabled && !isGlassIslandPinned {
            self.glassIslandState = .idle
            self.targetedHoverGlassState = nil
            self.glassPromptText = ""
            if self.glassNotesMode == .edit {
                self.closeGlassNote()
            }
        }
    }
    
    // MARK: - Glass Island Intermediary Action Staging System
    public func presentIntermediaryHome() {
        let hour = Calendar.current.component(.hour, from: Date())
        let name = supabase.currentUser.firstName.isEmpty ? "Minh" : supabase.currentUser.firstName
        let greeting = hour < 12 ? "Good morning, \(name)" : (hour < 17 ? "Good afternoon, \(name)" : "Good evening, \(name)")
        self.activeIntermediaryStage = .home(
            greeting: greeting,
            subtitle: "\(screenName) • Schedule Clear"
        )
        self.isSpotlightBarActive = false
        self.spotlightQuery = ""
        withAnimation(MorphUniversalAnimation.stateExpansion) {
            self.isExpanded = true
        }
        if let ctrl = MorphController.shared {
            ctrl.expandPanel()
        }
    }
    
    public func presentIntermediaryTimer(minutes: Int, title: String) {
        self.requestedTimerMinutes = minutes
        self.customTimerTitle = title
        self.activeIntermediaryStage = .timer(minutes: minutes, title: title)
        self.isSpotlightBarActive = false
        self.spotlightQuery = ""
        withAnimation(MorphUniversalAnimation.stateExpansion) {
            self.isExpanded = true
        }
        if let ctrl = MorphController.shared {
            ctrl.expandPanel()
        }
    }
    
    public func commitIntermediaryTimer(minutes: Int? = nil, title: String? = nil) {
        let mins = minutes ?? self.requestedTimerMinutes
        let t = title ?? (self.customTimerTitle.isEmpty ? "Focus Session" : self.customTimerTitle)
        self.activeIntermediaryStage = nil
        startFocusTimerInPill(minutes: mins, title: t, autoStart: true, asBackgroundTaskPill: true)
    }
    
    public func presentIntermediaryMusic(action: MusicAction) {
        let fallbackTrack = glassTracks.first?.title ?? (media.isSignedIn ? "YouTube Music" : "Connect YouTube Music")
        let fallbackArtist = glassTracks.first?.artist ?? (media.isSignedIn ? "Your Library" : "Sign in to play")
        let track = self.media.trackTitle.isEmpty ? fallbackTrack : self.media.trackTitle
        let artist = self.media.artistName.isEmpty ? fallbackArtist : self.media.artistName
        switch action {
        case .play(let query):
            self.activeIntermediaryStage = .music(query: query, trackTitle: query ?? track, artist: artist, isPlaying: self.media.isPlaying)
        case .open, .queryStatus, .pause, .next, .previous, .volumeUp, .volumeDown, .mute:
            self.activeIntermediaryStage = .music(query: nil, trackTitle: track, artist: artist, isPlaying: self.media.isPlaying)
        }
        self.isSpotlightBarActive = false
        self.spotlightQuery = ""
        withAnimation(MorphUniversalAnimation.stateExpansion) {
            self.isExpanded = true
        }
        if let ctrl = MorphController.shared {
            ctrl.expandPanel()
        }
    }
    
    public func commitIntermediaryMusic(play: Bool) {
        self.activeIntermediaryStage = nil
        if play {
            if media.trackTitle.isEmpty || !media.isPlaying {
                toggleGlassMusicPlay()
            } else {
                self.media.play()
            }
        } else {
            self.media.pause()
        }
        let title = self.media.trackTitle.isEmpty ? (glassTracks.first?.title ?? "YouTube Music") : self.media.trackTitle
        let artist = self.media.artistName.isEmpty ? (glassTracks.first?.artist ?? "Your Library") : self.media.artistName
        self.activeBackgroundTaskPill = .media(trackTitle: title, artist: artist)
        self.selectedTab = .music
        self.isExpanded = false
        if let ctrl = MorphController.shared {
            ctrl.scheduleWindowShrink()
        }
    }
    
    public func presentIntermediaryCalendar(action: CalendarAction) {
        let briefing = self.calendar.fetchTodayBriefing()
        let headline = "Monday 2"
        let subtitle = briefing.detail.isEmpty ? "November 2026 • Sample events • Next up: Team Sync" : "November 2026 • \(briefing.detail)"
        self.activeIntermediaryStage = .calendar(headline: headline, subtitle: subtitle, meetLink: briefing.meetLink)
        self.isSpotlightBarActive = false
        self.spotlightQuery = ""
        withAnimation(MorphUniversalAnimation.stateExpansion) {
            self.isExpanded = true
        }
        if let ctrl = MorphController.shared {
            ctrl.expandPanel()
        }
    }
    
    public func commitIntermediaryCalendarJoinCall() {
        self.activeIntermediaryStage = nil
        let briefing = self.calendar.fetchTodayBriefing()
        if let link = briefing.meetLink, let url = URL(string: link) {
            NSWorkspace.shared.open(url)
        }
        self.activeBackgroundTaskPill = .calendar(title: "Call Joined", timeText: "Online", meetLink: briefing.meetLink, fullEvent: nil)
        self.isExpanded = false
        if let ctrl = MorphController.shared {
            ctrl.scheduleWindowShrink()
        }
    }
    
    public func presentIntermediaryNote(action: NoteAction) {
        let currentNotes = self.scratchpad.text.trimmingCharacters(in: .whitespacesAndNewlines)
        var preview = currentNotes.isEmpty ? "buy oat milk" : (currentNotes.components(separatedBy: .newlines).first ?? currentNotes)
        switch action {
        case .add(let text, _):
            preview = text
            if self.scratchpad.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                self.scratchpad.text = text
            } else {
                self.scratchpad.text += "\n" + text
            }
        case .clear:
            self.scratchpad.clear()
            preview = "Notes cleared"
        case .copyToClipboard:
            self.scratchpad.copyAll()
            preview = "Copied to clipboard"
        case .view, .readPreview:
            break
        }
        self.activeIntermediaryStage = .notes(previewText: preview)
        self.isSpotlightBarActive = false
        self.spotlightQuery = ""
        withAnimation(MorphUniversalAnimation.stateExpansion) {
            self.isExpanded = true
        }
        if let ctrl = MorphController.shared {
            ctrl.expandPanel()
        }
    }
    
    public func commitIntermediaryNotesPin() {
        var preview = "buy oat milk"
        if case .notes(let p) = activeIntermediaryStage, !p.isEmpty {
            preview = p
        } else {
            let current = self.scratchpad.text.trimmingCharacters(in: .whitespacesAndNewlines)
            preview = current.isEmpty ? "buy oat milk" : (current.components(separatedBy: .newlines).first ?? current)
        }
        self.activeIntermediaryStage = nil
        self.isNotePinnedToNotch = true
        self.activeBackgroundTaskPill = .note(previewText: preview)
        self.isExpanded = false
        if let ctrl = MorphController.shared {
            ctrl.scheduleWindowShrink()
        }
    }
    
    public func presentIntermediaryAnswer(query: String, headline: String, subtitle: String, icon: String) {
        self.activeIntermediaryStage = .answer(query: query, headline: headline, subtitle: subtitle, icon: icon)
        self.isSpotlightBarActive = false
        self.spotlightQuery = ""
        withAnimation(MorphUniversalAnimation.stateExpansion) {
            self.isExpanded = true
        }
        if let ctrl = MorphController.shared {
            ctrl.expandPanel()
        }
    }
    
    public func commitIntermediaryAnswerDone() {
        guard case .answer(_, let headline, _, let icon) = activeIntermediaryStage else {
            if let ctrl = MorphController.shared {
                ctrl.dismissToStealth()
            }
            return
        }
        self.activeIntermediaryStage = nil
        self.activeBackgroundTaskPill = .directAnswer(text: headline, icon: icon)
        self.isExpanded = false
        if let ctrl = MorphController.shared {
            ctrl.scheduleWindowShrink()
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
    
    public func syncGlassTracks(from items: [YTMPlaylistItem]) {
        guard !items.isEmpty else { return }
        let converted = items.prefix(15).map { item in
            GlassTrack(
                title: item.title,
                artist: item.artist,
                duration: item.durationSeconds,
                gradientHexes: ["#ff7ab8", "#6a5cff", "#16d9c5"],
                videoId: item.videoId,
                thumbnailURL: item.thumbnailURL
            )
        }
        if !converted.isEmpty {
            self.glassTracks = converted
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
            
        // Sync real YouTube Music tracks to Glass Island tracks
        media.$quickPicks
            .sink { [weak self] picks in
                self?.syncGlassTracks(from: picks)
            }
            .store(in: &cancellables)
            
        media.$playlist
            .sink { [weak self] queue in
                guard let self = self, self.media.quickPicks.isEmpty else { return }
                self.syncGlassTracks(from: queue)
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
                // Guard: only auto-surface when the forms feature is enabled in the profile
                guard self.isFeatureEnabled(.forms) else { return }
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
            
            if tab == .calendar {
                glassSelectedDayIndex = glassTodayDayIndex
                calendar.goToToday()
            }
            
            if isGlassIslandEnabled {
                switch tab {
                case .home:
                    setGlassIslandState(.prompt)
                case .timer:
                    setGlassIslandState(.timer)
                case .music:
                    setGlassIslandState(.music)
                case .notes:
                    setGlassIslandState(.notes)
                case .calendar:
                    setGlassIslandState(.calendar)
                case .profile:
                    setGlassIslandState(.profile)
                }
            }
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
            
            if formTracker.isFormDetected && isFeatureEnabled(.forms) {
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
    
    // MARK: - Glass Island State Actions
    public func setGlassIslandState(_ state: GlassIslandState) {
        if let feature = MorphGlassFeature.allCases.first(where: { $0.state == state }),
           !isFeatureEnabled(feature) {
            self.glassIslandState = .prompt
            return
        }
        self.glassIslandState = state
        if state == .idle {
            self.isGlassIslandPinned = false
            self.glassPromptText = ""
            if self.glassNotesMode == .edit {
                self.closeGlassNote()
            }
        }
        if state != .idle {
            if let ctrl = MorphController.shared {
                ctrl.expandPanel()
                ctrl.panel?.ignoresMouseEvents = false
            }
        }
        
        // Automatic browser sign-in prompt on first user access and ensure today's date
        if state == .calendar {
            self.glassSelectedDayIndex = glassTodayDayIndex
            self.calendar.goToToday()
            promptCalendarSignInIfNeeded()
        } else if state == .music {
            promptMusicSignInIfNeeded()
        }
    }
    
    public func promptCalendarSignInIfNeeded() {
        guard !hasPromptedCalendarSignIn else { return }
        hasPromptedCalendarSignIn = true
        if !calendar.isSignedIn && !MorphEnvironment.isTestingEnvironment {
            calendar.signInWithGoogle()
        }
    }
    
    public func promptMusicSignInIfNeeded() {
        guard !hasPromptedMusicSignIn else { return }
        hasPromptedMusicSignIn = true
        if !media.isSignedIn && !media.isBrowserConnected && !MorphEnvironment.isTestingEnvironment {
            media.openSignIn()
        }
    }
    
    // MARK: - Glass Island Real Calendar Helpers
    public var glassTodayDayIndex: Int {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: Date())
        return (weekday == 1) ? 6 : (weekday - 2) // Monday = 0, ..., Sunday = 6
    }
    
    /// The 7 dates (Mon...Sun) of the week containing the selected date.
    public var glassCurrentWeekDates: [Date] {
        return calendar.datesForCurrentWeek()
    }
    
    public var glassSelectedDate: Date {
        return calendar.selectedDate
    }
    
    public var glassRealCalendarEvents: [CalendarEvent] {
        return calendar.eventsForDate(glassSelectedDate)
    }
    
    public var formattedGlassMonthYear: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: glassSelectedDate)
    }
    
    public var formattedGlassDayTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE d"
        return formatter.string(from: glassSelectedDate)
    }
    
    public func toggleGlassIslandTab(_ tabState: GlassIslandState) {
        if glassIslandState == tabState {
            setGlassIslandState(.prompt)
        } else {
            setGlassIslandState(tabState)
        }
    }
    
    public func dismissGlassIslandToIdle() {
        setGlassIslandState(.idle)
    }
    
    // MARK: - Glass Island Timer Methods
    public func startGlassTimer() {
        if glassTimerStatus == .done {
            glassTimerLeft = glassTimerDur
        }
        glassTimerStatus = .running
        glassTimerEndTime = Date().addingTimeInterval(TimeInterval(glassTimerLeft))
        glassTimerTimer?.invalidate()
        glassTimerTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if let end = self.glassTimerEndTime {
                    self.glassTimerLeft = max(0, Int(ceil(end.timeIntervalSinceNow)))
                    if self.glassTimerLeft == 0 {
                        self.glassTimerTimer?.invalidate()
                        self.glassTimerTimer = nil
                        self.glassTimerStatus = .done
                        self.glassTimerDoneCount = min(4, self.glassTimerDoneCount + 1)
                    }
                }
            }
        }
    }
    
    public func pauseGlassTimer() {
        glassTimerTimer?.invalidate()
        glassTimerTimer = nil
        glassTimerStatus = .paused
    }
    
    public func toggleGlassTimer() {
        if glassTimerStatus == .running {
            pauseGlassTimer()
        } else {
            startGlassTimer()
        }
    }
    
    public func resetGlassTimer() {
        glassTimerTimer?.invalidate()
        glassTimerTimer = nil
        glassTimerLeft = glassTimerDur
        glassTimerStatus = .ready
    }
    
    public func setGlassTimerMinutes(_ mins: Int) {
        glassTimerMins = mins
        glassTimerDur = mins * 60
        resetGlassTimer()
    }
    
    public func previewGlassTimer(status: GlassTimerStatus) {
        glassTimerTimer?.invalidate()
        glassTimerTimer = nil
        glassTimerMins = 25
        glassTimerDur = 1500
        switch status {
        case .ready:
            glassTimerLeft = 1500
            glassTimerStatus = .ready
        case .running:
            glassTimerLeft = 1122
            glassTimerStatus = .running
            glassTimerEndTime = Date().addingTimeInterval(TimeInterval(glassTimerLeft))
            startGlassTimer()
        case .paused:
            glassTimerLeft = 727
            glassTimerStatus = .paused
        case .done:
            glassTimerLeft = 0
            glassTimerStatus = .done
        }
    }
    
    // MARK: - Glass Island Music Methods
    public func toggleGlassMusicPlay() {
        if isGlassMusicPlaying {
            media.pause()
            _simulatedGlassMusicPlaying = false
        } else {
            if media.trackTitle.isEmpty || !media.isPlaying {
                // If not currently playing, start the active track or first recommendation
                if !glassTracks.isEmpty && glassTrackIndex < glassTracks.count {
                    let track = glassTracks[glassTrackIndex]
                    if let vid = track.videoId, !vid.isEmpty {
                        media.engine.play(videoId: vid)
                    } else if !track.title.isEmpty {
                        media.playSearch("\(track.title) \(track.artist)")
                    } else {
                        media.play()
                    }
                } else if let firstPick = media.quickPicks.first {
                    media.playQuickPick(firstPick)
                } else if media.isSignedIn {
                    media.playQuickVibe("supermix")
                } else {
                    media.openSignIn()
                }
            } else {
                media.play()
            }
            _simulatedGlassMusicPlaying = true
        }
        glassMusicTimer?.invalidate()
        glassMusicTimer = nil
        if isGlassMusicPlaying {
            glassMusicTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self = self, self.isGlassMusicPlaying else { return }
                    if self.media.currentTime > 0 {
                        self.glassTrackCurrentSeconds = Int(self.media.currentTime)
                    } else {
                        self.glassTrackCurrentSeconds += 1
                    }
                }
            }
        }
    }
    
    public func skipGlassMusic(_ delta: Int = 1) {
        if !glassTracks.isEmpty {
            glassTrackIndex = (glassTrackIndex + delta + glassTracks.count) % glassTracks.count
            let track = glassTracks[glassTrackIndex]
            if let vid = track.videoId, !vid.isEmpty {
                media.engine.play(videoId: vid)
            } else if !track.title.isEmpty {
                media.playSearch("\(track.title) \(track.artist)")
            } else if delta > 0 {
                media.nextTrack()
            } else {
                media.previousTrack()
            }
        } else if delta > 0 {
            media.nextTrack()
        } else {
            media.previousTrack()
        }
        glassTrackCurrentSeconds = 0
    }
    
    public func prevGlassMusic() {
        if glassTrackCurrentSeconds > 3 || media.currentTime > 3 {
            seekGlassMusic(to: 0)
        } else {
            skipGlassMusic(-1)
        }
    }
    
    public func seekGlassMusic(to seconds: Int) {
        let curDur = Double(!glassTracks.isEmpty ? glassTracks[glassTrackIndex].duration : (media.duration > 0 ? Int(media.duration) : 180))
        let fraction = curDur > 0 ? Double(seconds) / curDur : 0
        media.seek(to: fraction)
        media.currentTime = Double(seconds)
        glassTrackCurrentSeconds = max(0, min(seconds, Int(curDur)))
    }
    
    public func setGlassMusicSubtab(_ subtab: GlassMusicSubtab) {
        glassMusicSubtab = subtab
    }
    
    public func selectGlassPlaylist(_ playlist: YTMPlaylist?) {
        glassSelectedPlaylist = playlist
    }
    
    public var glassAllLibraryTracks: [YTMPlaylistItem] {
        var all: [YTMPlaylistItem] = []
        if !media.trackTitle.isEmpty {
            all.append(YTMPlaylistItem(
                id: "current_now_playing",
                title: media.trackTitle,
                artist: media.artistName,
                duration: formattedGlassTrackDuration,
                isPlaying: media.isPlaying,
                thumbnailURL: media.albumArtURL
            ))
        }
        all.append(contentsOf: media.playlist)
        all.append(contentsOf: media.quickPicks)
        for pl in media.playlists {
            all.append(contentsOf: pl.tracks)
        }
        for track in glassTracks {
            all.append(YTMPlaylistItem(
                id: track.id.uuidString,
                title: track.title,
                artist: track.artist,
                duration: String(format: "%d:%02d", track.duration / 60, track.duration % 60),
                isPlaying: false,
                videoId: track.videoId,
                thumbnailURL: track.thumbnailURL
            ))
        }
        return YTMPlaylistItem.deduplicate(all)
    }
    
    public var glassFilteredLibraryTracks: [YTMPlaylistItem] {
        let q = glassMusicSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty {
            return glassAllLibraryTracks
        }
        return glassAllLibraryTracks.filter {
            $0.title.lowercased().contains(q) || $0.artist.lowercased().contains(q)
        }
    }
    
    public func playGlassLibraryTrack(_ track: YTMPlaylistItem) {
        glassTrackCurrentSeconds = 0
        if let pl = glassSelectedPlaylist {
            media.selectPlaylist(pl)
            media.playSongInSelectedPlaylist(track)
        } else {
            media.playQueueTrack(track)
        }
        _simulatedGlassMusicPlaying = true
        media.isPlaying = true
    }
    
    public func playGlassSelectedPlaylistAll(shuffle: Bool = false) {
        guard let pl = glassSelectedPlaylist else { return }
        glassTrackCurrentSeconds = 0
        media.selectPlaylist(pl)
        if shuffle {
            media.toggleShuffle()
        }
        media.playEntireSelectedPlaylist()
        _simulatedGlassMusicPlaying = true
        media.isPlaying = true
    }
    
    // MARK: - Glass Island Notes Methods
    public func openGlassNote(id: UUID) {
        guard let note = glassNotes.first(where: { $0.id == id }) else { return }
        glassActiveNoteId = id
        glassEditTitle = note.title
        glassEditBody = note.body
        glassNotesMode = .edit
    }
    
    public func closeGlassNote() {
        if let id = glassActiveNoteId, let idx = glassNotes.firstIndex(where: { $0.id == id }) {
            let t = glassEditTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            let b = glassEditBody.trimmingCharacters(in: .whitespacesAndNewlines)
            if t.isEmpty && b.isEmpty {
                glassNotes.remove(at: idx)
            } else {
                glassNotes[idx].title = glassEditTitle
                glassNotes[idx].body = glassEditBody
            }
        }
        glassActiveNoteId = nil
        glassNotesMode = .list
    }
    
    public func addGlassNote(title: String = "", body: String = "") {
        let note = GlassNote(title: title, body: body)
        glassNotes.insert(note, at: 0)
        openGlassNote(id: note.id)
    }
    
    // MARK: - Glass Island Prompt Submission & Routing
    public func submitGlassIslandPrompt(_ rawQuery: String) {
        let q = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        
        let lower = q.lowercased()
        
        // 0A. Supabase Memory Storage Retrieval (Form Copies & Input Data)
        let memories = supabase.searchMemories(query: q)
        if let match = memories.first {
            selectedFormCopyId = match.id
            isFormCopyDetailOpen = true
            glassFormMode = .copies
            glassPromptText = ""
            setGlassIslandState(.forms)
            return
        }
        
        if let matchCopy = formTracker.savedFormCopies.first(where: {
            $0.formTitle.localizedCaseInsensitiveContains(q) || q.localizedCaseInsensitiveContains($0.formTitle)
        }) {
            selectedFormCopyId = matchCopy.id
            isFormCopyDetailOpen = true
            glassFormMode = .copies
            glassPromptText = ""
            setGlassIslandState(.forms)
            return
        }
        
        if let matchReceipt = supabase.formReceipts.first(where: {
            $0.formTitle.localizedCaseInsensitiveContains(q) || q.localizedCaseInsensitiveContains($0.formTitle)
        }) {
            selectedFormCopyId = matchReceipt.id
            isFormCopyDetailOpen = true
            glassFormMode = .copies
            glassPromptText = ""
            setGlassIslandState(.forms)
            return
        }
        
        // 0B1. Question Input Command: "input", "input answer", "fill question", "input question", "fill this"
        if lower == "input" || lower == "input answer" || lower == "input question" || lower == "fill question" || lower == "fill this" {
            _ = formTracker.inputSavedAnswerForActiveQuestion()
            glassPromptText = ""
            setGlassIslandState(.idle)
            return
        }
        
        // 0B. Autofill Command: "autofill", "fill", "fill form"
        if lower == "autofill" || lower == "fill" || lower == "fill form" {
            _ = formTracker.autofillActiveForm()
            glassPromptText = ""
            setGlassIslandState(.idle)
            return
        }
        
        // 0C. Forms / Assistant Routing: "form", "forms", "receipt", "history", "judge"
        let formPattern = #"\b(form|forms|autofill|fill|judge|judging|receipt|receipts|response|responses|history|past)\b"#
        if let regex = try? NSRegularExpression(pattern: formPattern, options: [.caseInsensitive]),
           regex.firstMatch(in: lower, options: [], range: NSRange(location: 0, length: lower.utf16.count)) != nil {
            if lower.contains("receipt") || lower.contains("history") || lower.contains("past") || lower.contains("response") {
                glassFormMode = .copies
            } else {
                glassFormMode = .live
            }
            glassPromptText = ""
            setGlassIslandState(.forms)
            return
        }
        
        // 0D. Drop Shelf Routing: "drop", "drops", "shelf", "drop shelf", "stash", "staged", "files"
        let dropPattern = #"\b(drop|drops|shelf|stash|staged|files|file shelf)\b"#
        if let regex = try? NSRegularExpression(pattern: dropPattern, options: [.caseInsensitive]),
           regex.firstMatch(in: lower, options: [], range: NSRange(location: 0, length: lower.utf16.count)) != nil {
            glassPromptText = ""
            setGlassIslandState(.drops)
            return
        }
        
        // 1. Note matching: "note: ...", "remember ...", "jot ..."
        let notePattern = #"^(?:note|remember|jot)\s*[:\-]?\s*(.+)$"#
        if let regex = try? NSRegularExpression(pattern: notePattern, options: [.caseInsensitive]),
           let match = regex.firstMatch(in: q, options: [], range: NSRange(location: 0, length: q.utf16.count)) {
            if let range = Range(match.range(at: 1), in: q) {
                let noteText = String(q[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                let noteTitle = noteText.count > 26 ? String(noteText.prefix(26)).trimmingCharacters(in: .whitespacesAndNewlines) + "…" : noteText
                let n = GlassNote(title: noteTitle, body: noteText)
                glassNotes.insert(n, at: 0)
                glassNotesMode = .list
                glassPromptText = ""
                setGlassIslandState(.notes)
                return
            }
        }
        
        // 2. Focus / Timer matching: "focus 25", "timer 15", "pomodoro 50"
        let timerPattern = #"\b(?:focus|timer|pomodoro)\b(?:\D*(\d{1,3}))?"#
        if let regex = try? NSRegularExpression(pattern: timerPattern, options: [.caseInsensitive]),
           let match = regex.firstMatch(in: lower, options: [], range: NSRange(location: 0, length: lower.utf16.count)) {
            var mins = 25
            if match.numberOfRanges > 1 && match.range(at: 1).location != NSNotFound {
                if let r = Range(match.range(at: 1), in: lower), let parsed = Int(lower[r]) {
                    mins = max(1, min(180, parsed))
                }
            }
            setGlassTimerMinutes(mins)
            startGlassTimer()
            glassPromptText = ""
            setGlassIslandState(.timer)
            return
        }
        
        // 3. Calendar matching: "calendar", "schedule", "agenda", "meeting", "meetings", "today", "next up"
        let calPattern = #"\b(calendar|schedule|agenda|meeting|meetings|today|next up)\b"#
        if let regex = try? NSRegularExpression(pattern: calPattern, options: [.caseInsensitive]),
           regex.firstMatch(in: lower, options: [], range: NSRange(location: 0, length: lower.utf16.count)) != nil {
            glassSelectedDayIndex = glassTodayDayIndex
            calendar.goToToday()
            glassPromptText = ""
            setGlassIslandState(.calendar)
            return
        }
        
        // 4. Music matching: "play", "pause", "music", "song", "track", "skip", "next"
        let musicPattern = #"\b(play|pause|music|song|track|skip|next)\b"#
        if let regex = try? NSRegularExpression(pattern: musicPattern, options: [.caseInsensitive]),
           regex.firstMatch(in: lower, options: [], range: NSRange(location: 0, length: lower.utf16.count)) != nil {
            if lower.contains("pause") {
                if isGlassMusicPlaying { toggleGlassMusicPlay() }
            } else if lower.contains("skip") || lower.contains("next") {
                skipGlassMusic(1)
                if !isGlassMusicPlaying { toggleGlassMusicPlay() }
            } else {
                if !isGlassMusicPlaying { toggleGlassMusicPlay() }
            }
            glassPromptText = ""
            setGlassIslandState(.music)
            return
        }
        
        // 5. Default Reply routing
        glassReplyQuery = q
        isGlassReplyLoading = true
        glassPromptText = ""
        setGlassIslandState(.reply)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.isGlassReplyLoading = false
        }
    }
}
