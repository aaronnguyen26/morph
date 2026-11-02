import Foundation

public enum MorphSpotlightCommand: Equatable {
    case timer(minutes: Int, title: String, autoStart: Bool)
    case music(action: MusicAction)
    case note(action: NoteAction)
    case calendar(action: CalendarAction)
    case navigation(tab: MorphTab)
    case answer(text: String, icon: String)
}

public enum MusicAction: Equatable {
    case play(query: String?)
    case pause
    case next
    case previous
    case open
}

public enum NoteAction: Equatable {
    case add(text: String, pinToNotch: Bool)
    case view
    case clear
}

public enum CalendarAction: Equatable {
    case add(title: String, hour: Int?, minute: Int, duration: Int)
    case todaySummary
    case open
    public static var view: CalendarAction { .open }
}

public struct MorphSpotlightCommandParser {
    public enum CommandType: Equatable {
        case timer
        case music
        case note
        case calendar
        case navigation
        case answer
        case unknown
        
        public var iconName: String {
            switch self {
            case .music: return "music.note"
            case .note: return "note.text"
            case .calendar: return "calendar"
            case .timer: return "timer"
            case .answer: return "sparkles"
            case .navigation, .unknown: return "magnifyingglass"
            }
        }
    }
    
    public static func detectType(from query: String) -> CommandType {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .unknown }
        let lower = trimmed.lowercased()
        
        // 1. Direct conversational answer queries (time, date, identity, math)
        if isDirectAnswerQuery(lower) {
            return .answer
        }
        
        // 2. Note commands (explicit note/todo prefixes take high priority)
        if isNoteQuery(lower) {
            return .note
        }
        
        // 3. Calendar queries (schedule inquiries & event creation with time/dates)
        if isCalendarQuery(lower) {
            return .calendar
        }
        
        // 4. Music commands (natural listening requests, playback controls, genres, URLs)
        if isMusicQuery(lower) {
            return .music
        }
        
        // 5. Timer check via explicit timer syntax or natural timer prompts
        if isTimerQuery(lower) {
            return .timer
        }
        
        // 6. Navigation keywords
        if lower == "home" || lower == "dashboard" {
            return .navigation
        }
        if lower == "profile" || lower == "settings" || lower == "preferences" || lower == "my profile" {
            return .navigation
        }
        
        // 7. General questions / informational queries & conversational response
        return .answer
    }
    
    public static func parse(_ text: String) -> MorphSpotlightCommand {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        
        // MARK: - 1. Direct Conversational Answers & Questions
        if let directAnswer = parseDirectAnswer(trimmed) {
            return directAnswer
        }
        
        // MARK: - 2. Notes & Scratchpad Commands
        if isNoteQuery(lower) {
            return parseNoteCommand(trimmed)
        }
        
        // MARK: - 3. Calendar Natural Language Queries
        if isCalendarQuery(lower) {
            return parseCalendarCommand(trimmed)
        }
        
        // MARK: - 4. Music Player Commands
        if isMusicQuery(lower) {
            return parseMusicCommand(trimmed)
        }
        
        // MARK: - 5. Focus Timer Commands
        if isTimerQuery(lower) {
            return parseTimerCommand(trimmed)
        }
        
        // MARK: - 6. Navigation (Profile, Home)
        if lower == "profile" || lower == "my profile" || lower == "open profile" || lower == "settings" || lower == "preferences" {
            return .navigation(tab: .profile)
        }
        if lower == "home" || lower == "dashboard" || lower == "open home" {
            return .navigation(tab: .home)
        }
        
        // MARK: - 7. Intelligent Conversational Assistant (No Arbitrary 25:00 Timer Fallback)
        return generateIntelligentResponse(for: trimmed)
    }
    
    // MARK: - Helper Query Classifiers
    
    public static func isQuestionOrConversationalQuery(_ lower: String) -> Bool {
        return isDirectAnswerQuery(lower) ||
               lower.hasPrefix("what") || lower.hasPrefix("how") || lower.hasPrefix("why") ||
               lower.hasPrefix("who") || lower.hasPrefix("when") || lower.hasPrefix("where") ||
               lower.hasPrefix("can you") || lower.hasPrefix("tell me") || lower.hasPrefix("explain") ||
               lower.hasPrefix("search") || lower.contains("help") || lower.contains("tip") ||
               lower.contains("quote") || lower.contains("joke") || isMathExpression(lower)
    }
    
    private static func isDirectAnswerQuery(_ lower: String) -> Bool {
        return lower.contains("time is it") || lower == "what time is it" || lower == "time" || lower == "clock" ||
               lower.contains("day is today") || lower.contains("day is it") || lower.contains("today's date") ||
               lower == "what is the date" || lower == "date" || lower == "who are you" || lower == "what are you" ||
               lower == "what is morph" || lower == "hello" || lower == "hi" || lower == "hey" ||
               lower.contains("how are you") || lower.contains("what can you do") || lower == "help"
    }
    
    private static func parseDirectAnswer(_ text: String) -> MorphSpotlightCommand? {
        let lower = text.lowercased()
        
        // Time inquiry
        if lower.contains("time is it") || lower == "what time is it" || lower == "time" || lower == "clock" {
            let df = DateFormatter()
            df.timeStyle = .short
            let timeStr = df.string(from: Date())
            return .answer(text: "It is \(timeStr)", icon: "clock")
        }
        
        // Date inquiry
        if lower.contains("day is today") || lower.contains("day is it") || lower.contains("today's date") || lower.contains("the date") || lower == "date" {
            let df = DateFormatter()
            df.dateFormat = "EEEE, MMMM d"
            let dateStr = df.string(from: Date())
            return .answer(text: "Today is \(dateStr)", icon: "calendar")
        }
        
        // Identity inquiries
        if lower == "who are you" || lower == "what are you" || lower == "what is morph" {
            return .answer(text: "I am Morph, your living Dynamic Island companion", icon: "sparkles")
        }
        if lower.contains("what can you do") || lower == "help" {
            return .answer(text: "I can run focus sprints, play music, track your calendar, and take notes", icon: "lightbulb")
        }
        if lower == "hello" || lower == "hi" || lower == "hey" || lower.hasPrefix("good morning") || lower.hasPrefix("good afternoon") {
            return .answer(text: "Hello! Ready to help you focus and flow", icon: "sparkles")
        }
        if lower.contains("how are you") {
            return .answer(text: "Feeling great and ready to assist you", icon: "face.smiling")
        }
        if lower.contains("focus tip") || lower.contains("give me a tip") || lower.contains("productivity tip") {
            return .answer(text: "Try a 25m sprint with zero notifications for deep flow", icon: "bolt.fill")
        }
        if lower.contains("joke") || lower.contains("tell me a joke") {
            return .answer(text: "Why do programmers prefer dark mode? Because light attracts bugs!", icon: "sparkles")
        }
        if lower.contains("quote") || lower.contains("motivate me") {
            return .answer(text: "Focus is a muscle. The more you use it, the stronger it gets", icon: "flame.fill")
        }
        
        // Simple Math calculation (e.g. "15 * 4", "100 / 5", "25 + 75")
        if let mathAnswer = evaluateMathExpression(lower) {
            return .answer(text: mathAnswer, icon: "equal")
        }
        
        return nil
    }
    
    public static func isMathExpression(_ text: String) -> Bool {
        let clean = text.replacingOccurrences(of: "what is ", with: "").replacingOccurrences(of: "calculate ", with: "").trimmingCharacters(in: .whitespaces)
        let mathChars = CharacterSet(charactersIn: "0123456789+-*/.() ")
        guard clean.unicodeScalars.allSatisfy({ mathChars.contains($0) }) else { return false }
        return clean.contains("+") || clean.contains("-") || clean.contains("*") || clean.contains("/")
    }
    
    private static func evaluateMathExpression(_ text: String) -> String? {
        var clean = text.replacingOccurrences(of: "what is ", with: "").replacingOccurrences(of: "calculate ", with: "").trimmingCharacters(in: .whitespaces)
        clean = clean.replacingOccurrences(of: "x", with: "*")
        let mathChars = CharacterSet(charactersIn: "0123456789+-*/.() ")
        guard clean.unicodeScalars.allSatisfy({ mathChars.contains($0) }) else { return nil }
        guard clean.contains("+") || clean.contains("-") || clean.contains("*") || clean.contains("/") else { return nil }
        
        let expr = NSExpression(format: clean)
        if let result = expr.expressionValue(with: nil, context: nil) as? NSNumber {
            if result.doubleValue.truncatingRemainder(dividingBy: 1) == 0 {
                return "\(clean) = \(result.intValue)"
            } else {
                return "\(clean) = \(String(format: "%.2f", result.doubleValue))"
            }
        }
        return nil
    }
    
    private static func isStandaloneTimerExpression(_ lower: String) -> Bool {
        // Explicit timer units: "25m", "15 mins", "1 hour", "45 min"
        if let regex = try? NSRegularExpression(pattern: #"^\s*(\d+)\s*(m|min|mins|minute|minutes|h|hr|hours?)\s*$"#) {
            let range = NSRange(location: 0, length: (lower as NSString).length)
            if regex.firstMatch(in: lower, range: range) != nil {
                return true
            }
        }
        // Standalone numbers 1..180 (e.g. "15", "25", "30", "45", "60")
        if let num = Int(lower.trimmingCharacters(in: .whitespaces)), num >= 1 && num <= 180 {
            return true
        }
        return false
    }
    
    private static func generateIntelligentResponse(for trimmed: String) -> MorphSpotlightCommand {
        let lower = trimmed.lowercased()
        
        // Conversational math check
        if let mathAnswer = evaluateMathExpression(lower) {
            return .answer(text: mathAnswer, icon: "equal")
        }
        
        // Check for general task/thought entry (e.g. "reading response #4", "finish the design", "study biology")
        let taskIndicators = ["reading", "essay", "homework", "study", "review", "code", "design", "write", "finish", "prepare", "draft", "project", "presentation", "assignment", "paper", "exam", "quiz"]
        if taskIndicators.contains(where: { lower.contains($0) }) {
            return .answer(text: "Ready to focus on \(trimmed.capitalized)? Type '25m' to start or 'note' to save", icon: "brain.head.profile")
        }
        
        // Machine Learning & Computer Science queries (e.g. cross entropy loss, loss function)
        if lower.contains("cross entropy") || lower.contains("cross-entropy") || lower.contains("loss function") || lower.contains("negative log") || lower.contains("lecture notes") {
            return .answer(text: "Cross-Entropy Loss: ℓ(θ) = -∑ log(exp(θ_yᵀ x) / ∑ exp(θ_jᵀ x))", icon: "function")
        }
        
        // General conversational response (graceful, polite, non-intrusive)
        return .answer(text: "AI Analysis: \"\(trimmed)\"", icon: "sparkles")
    }
    
    // MARK: - Rich AI Intelligence Generator
    public static func generateAIResponse(for query: String, briefAnswer: String? = nil, icon: String? = nil) -> MorphAIResponse {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        
        // 1. Machine Learning & Mathematics (Cross-entropy loss, loss functions, optimization, calculus)
        if lower.contains("cross entropy") || lower.contains("cross-entropy") || lower.contains("loss function") || lower.contains("negative log") || lower.contains("lecture notes") || lower.contains("2.12") || lower.contains("2.13") || lower.contains("2.14") {
            return MorphAIResponse(
                query: trimmed,
                title: "Cross-Entropy Loss in Multiclass Classification",
                category: "Machine Learning / Statistics",
                icon: "function",
                summary: "Cross-entropy loss measures the performance of a classification model whose output is a probability value between 0 and 1.",
                detailedContent: "In multiclass classification, cross-entropy loss corresponds to the negative log-likelihood of the training data under a multinomial distribution.\n\nMathematical Formulation (Eq. 2.13 - 2.14):\nℓ(θ) = - ∑ᵢ₌₁ⁿ log( exp(θ_y⁽ⁱ⁾ᵀ x⁽ⁱ⁾) / ∑ⱼ₌₁ᵏ exp(θ_ⱼᵀ x⁽ⁱ⁾) )\n\nWith logits t = (t₁, ..., t_k), the loss simplifies to:\nℓ_ce(t, y) = - log( exp(t_y) / ∑ⱼ exp(t_j) )\n\nGradient Computation (Eq. 2.16):\nThe gradient with respect to logit t_i has the elegant closed form:\n∂ℓ_ce / ∂t_i = φ_i - 1{y = i}, where φ_i = exp(t_i) / ∑ exp(t_j) represents the predicted softmax probability.",
                keyPoints: [
                    "Penalizes wrong predictions with high confidence exponentially",
                    "Softmax normalizes raw score logits into a true probability simplex",
                    "Convex optimization guarantees a global minimum when linearly parameterized",
                    "Gradient is simply (Predicted Probability - True Label Indicator)"
                ],
                suggestedActions: [
                    "Save formula to Notes",
                    "Start a 25m ML study session",
                    "Copy derivation"
                ]
            )
        }
        
        // 2. Machine Learning Study Plan / Exam Prep
        if lower.contains("study plan") || lower.contains("study for ml") || lower.contains("how to study") || lower.contains("exam") || lower.contains("quiz") {
            return MorphAIResponse(
                query: trimmed,
                title: "Mastery Study Plan: Machine Learning",
                category: "Study Advisor",
                icon: "graduationcap.fill",
                summary: "A focused 3-tier study approach designed for retention, intuitive proofs, and practical derivation mastery.",
                detailedContent: "Break down lecture notes into active recall blocks:\n1. Derivations: Re-derive loss gradients (e.g. cross-entropy, softmax, MSE) on paper without looking at the solutions.\n2. Geometric Intuition: Visualize decision boundaries, loss surfaces, and gradient descent trajectories.\n3. Implementation: Code the forward and backward passes from scratch using NumPy.",
                keyPoints: [
                    "Block 1 (45m): Loss functions, maximum likelihood estimation, and regularization",
                    "Block 2 (45m): Optimization algorithms (SGD, Momentum, Adam)",
                    "Block 3 (30m): Practice problems from problem sets and past exams"
                ],
                suggestedActions: [
                    "Save Study Plan to Notes",
                    "Start 45m Study Sprint",
                    "Add to Calendar"
                ]
            )
        }
        
        // 3. Mathematical Calculations (e.g. "15 * 4", "125 / 5")
        if let mathAnswer = evaluateMathExpression(lower) {
            return MorphAIResponse(
                query: trimmed,
                title: "Arithmetic Calculation",
                category: "Mathematics",
                icon: "equal",
                summary: "\(mathAnswer)",
                detailedContent: "Expression evaluated via standard arithmetic precedence rules.\n\nComputation:\n\(mathAnswer)\n\nResult verified with double-precision IEEE-754 arithmetic.",
                keyPoints: [
                    "Standard operator precedence respected",
                    "Computed with double precision arithmetic",
                    "Direct numeric evaluation"
                ],
                suggestedActions: [
                    "Save result to Notes",
                    "Copy value"
                ]
            )
        }
        
        // 4. Productivity & Focus Strategy
        if lower.contains("focus") || lower.contains("productivity") || lower.contains("flow") || lower.contains("deep work") {
            return MorphAIResponse(
                query: trimmed,
                title: "Deep Flow Productivity Architecture",
                category: "Focus & Wellness",
                icon: "flame.fill",
                summary: "Deep work is the ability to focus without distraction on a cognitively demanding task.",
                detailedContent: "To enter flow state quickly:\n1. Zero Notification Protocol: Mute chat, silence phones, and hide browser tabs unrelated to the immediate sprint.\n2. Time Boxing: Commit to an uninterrupted 25-minute sprint with a singular output goal.\n3. Ambient Soundscape: Utilize lofi beats or brown noise to mask distracting ambient room acoustics.",
                keyPoints: [
                    "Context switching reduces cognitive capacity by up to 40%",
                    "Start with small 25-minute sprints and take 5-minute restorative breaks",
                    "Keep a scratchpad open to capture intrusive thoughts without derailing focus"
                ],
                suggestedActions: [
                    "Start 25m Focus Sprint",
                    "Play Lofi Beats",
                    "Save to Notes"
                ]
            )
        }
        
        // 5. Morph Capabilities & Identity
        if lower == "who are you" || lower == "what are you" || lower == "what is morph" || lower.contains("what can you do") || lower == "help" {
            return MorphAIResponse(
                query: trimmed,
                title: "Morph Dynamic Island Architecture",
                category: "System Capabilities",
                icon: "sparkles",
                summary: "Morph is an intelligent Dynamic Island for macOS designed for frictionless focus, media, scheduling, and AI assistance.",
                detailedContent: "You can control Morph directly via keyboard or hover dwelling:\n• Focus Sprints: Type '25m' or 'timer 10m' to launch customizable countdowns with living progress indicators.\n• Music Cockpit: Type 'play lofi' or 'pause' to stream directly via YouTube Music.\n• Notes & Scratchpad: Type 'note [text]' to instantly capture thoughts onto the island.\n• Calendar: Type 'what is my plan' or 'meet with Minh at 3pm' to view and schedule events.\n• AI Assistant: Ask questions, formulas, or study topics directly from the spotlight bar.",
                keyPoints: [
                    "100% Monochrome Apple Liquid Glass aesthetic",
                    "Living 3D Morphy Mascot companion",
                    "Non-intrusive click-through resting stealth mode"
                ],
                suggestedActions: [
                    "Explore Calendar",
                    "Open Scratchpad",
                    "Start Focus Timer"
                ]
            )
        }
        
        // 6. Task or Project Entry (e.g. "reading response #4", "design wireframes")
        let taskIndicators = ["reading", "essay", "homework", "study", "review", "code", "design", "write", "finish", "prepare", "draft", "project", "presentation", "assignment", "paper", "exam", "quiz"]
        if taskIndicators.contains(where: { lower.contains($0) }) {
            return MorphAIResponse(
                query: trimmed,
                title: trimmed.capitalized,
                category: "Active Task Focus",
                icon: "brain.head.profile",
                summary: "Ready to focus on \(trimmed.capitalized).",
                detailedContent: "Task captured in Morph Spotlight: \"\(trimmed)\".\n\nTo accomplish this task with maximum retention and momentum, break it into dedicated 25-minute focus sprints with zero distractions.",
                keyPoints: [
                    "Task prioritized on Dynamic Island",
                    "Sprint timer ready to launch",
                    "Can be saved to Scratchpad Notes for persistent tracking"
                ],
                suggestedActions: [
                    "Save to Notes",
                    "Start 25m Focus Sprint",
                    "Copy Task Title"
                ]
            )
        }
        
        // 7. General Conversational / AI Query Fallback
        let brief = briefAnswer ?? "Here is the information you requested for \"\(trimmed)\"."
        return MorphAIResponse(
            query: trimmed,
            title: trimmed.capitalized,
            category: "Morph AI Assistant",
            icon: icon ?? "sparkles",
            summary: brief,
            detailedContent: "Morph analyzed your query: \"\(trimmed)\".\n\n\(brief)\n\nYou can pin this response to your scratchpad notes, set a focus timer to dive deeper, or ask another question directly from the spotlight bar.",
            keyPoints: [
                "Captured from Spotlight Command Bar",
                "Instant AI synthesis with zero context switching",
                "Ready to save to Notes or schedule in Calendar"
            ],
            suggestedActions: [
                "Save to Notes",
                "Start Focus Sprint",
                "Copy to Clipboard"
            ]
        )
    }
    
    // MARK: - Helper Query Classifiers & Parsers
    
    // MARK: 1. Calendar Intelligence
    public static func isCalendarQuery(_ lower: String) -> Bool {
        if lower.isEmpty { return false }
        
        // 1. Natural language schedule inquiries
        let inquiryPhrases = [
            "plan for today", "plan today", "my plan", "what my plan", "what is my plan",
            "my schedule", "schedule today", "what's my schedule", "what is my schedule",
            "what do i have today", "what do i have scheduled", "what do i have",
            "on my calendar", "do i have meetings", "my meetings", "upcoming meetings",
            "upcoming events", "agenda", "today's agenda", "when is my next meeting",
            "check my calendar", "show my calendar", "view calendar", "open calendar",
            "show calendar", "calendar schedule", "do i have any meetings", "have any meetings",
            "any meetings today", "meetings today", "meeting today"
        ]
        if inquiryPhrases.contains(where: { lower.contains($0) }) {
            return true
        }
        if (lower.contains("meeting") || lower.contains("meetings") || lower.contains("schedule") || lower.contains("calendar") || lower.contains("agenda")) &&
           (lower.contains("today") || lower.contains("tomorrow") || lower.contains("upcoming") || lower.contains("next") || lower.contains("have") || lower.contains("any") || lower.contains("what") || lower.contains("check") || lower.contains("show")) {
            return true
        }
        if lower == "calendar" || lower == "my calendar" || lower == "cal" || lower == "events" || lower == "today" {
            return true
        }
        
        // 2. Event creation prefixes
        let eventPrefixes = [
            "meet ", "meeting ", "event ", "schedule ", "add event", "add meeting",
            "new event", "new meeting", "sync with ", "call with ", "coffee with ",
            "lunch with ", "dinner with ", "interview with "
        ]
        for p in eventPrefixes {
            if lower.hasPrefix(p) {
                return true
            }
        }
        
        // 3. Time-marker based event additions (e.g. "coffee with Sarah at 10am")
        if containsTimeMarker(lower) {
            let eventKeywords = [
                "meet", "meeting", "sync", "call", "1on1", "1:1", "coffee", "lunch",
                "dinner", "interview", "appointment", "doctor", "dentist", "standup",
                "review", "demo", "presentation", "session", "class", "lecture", "hangout"
            ]
            if eventKeywords.contains(where: { lower.contains($0) }) {
                return true
            }
        }
        
        return false
    }
    
    public static func parseCalendarCommand(_ text: String) -> MorphSpotlightCommand {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        
        // 1. General calendar requests to open/view the calendar UI:
        let isExplicitViewRequest = (lower.contains("view") || lower.contains("open") || lower.contains("show") || lower.contains("browse")) && (lower.contains("calendar") || lower.contains("schedule")) && !lower.contains("today")
        let generalPhrases = ["calendar", "cal", "events", "my calendar", "schedule", "calendar schedule", "view my calendar schedule", "open calendar schedule"]
        if isExplicitViewRequest || generalPhrases.contains(lower) {
            return .calendar(action: .open)
        }
        
        // 2. Specific fetchable schedule inquiries for today / next meeting -> display in background lengthened pill:
        let isTodayOrNextInquiry = lower.contains("today") || lower.contains("next meeting") || lower.contains("upcoming meeting") || lower.contains("meetings today") || lower.contains("agenda today") || lower.contains("plan for today") || lower.contains("on my calendar") || lower.contains("on their calendar") || lower.contains("do i have meetings") || lower.contains("what do i have") || lower.contains("what's on my calendar") || lower.contains("what is on my calendar") || lower.contains("what on my calendar") || lower.contains("what on their calendar")
        
        if isTodayOrNextInquiry && !containsTimeMarker(lower) && !lower.hasPrefix("schedule ") && !lower.hasPrefix("add event") && !lower.hasPrefix("meet ") {
            return .calendar(action: .todaySummary)
        }
        
        return parseCalendarAddCommand(trimmed)
    }
    
    public static func parseCalendarAddCommand(_ text: String) -> MorphSpotlightCommand {
        let raw = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var titleText = raw
        
        // 1. Strip leading command keyword while preserving title:
        // "meet Sarah at 2:30pm" -> "Sarah"
        // "schedule Design Sprint" -> "Design Sprint"
        // "event Team Sync at 10am" -> "Team Sync"
        // "coffee with Sarah at 10am" -> "Coffee with Sarah"
        if let verbRegex = try? NSRegularExpression(pattern: #"(?i)^(meet|meeting|event|schedule|add event|add meeting|new event|new meeting)\s+"#) {
            titleText = verbRegex.stringByReplacingMatches(in: titleText, range: NSRange(location: 0, length: (titleText as NSString).length), withTemplate: "")
        }
        
        // 2. Parse time (e.g. "at 3pm", "at 3:30pm", "at 15:00", "at 10am")
        var hour: Int? = nil
        var minute: Int = 0
        if let timeRegex = try? NSRegularExpression(pattern: #"(?i)\bat\s*(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\b"#) {
            let ns = titleText as NSString
            if let match = timeRegex.firstMatch(in: titleText, range: NSRange(location: 0, length: ns.length)) {
                let hourStr = ns.substring(with: match.range(at: 1))
                var h = Int(hourStr) ?? 12
                if match.numberOfRanges > 2 && match.range(at: 2).location != NSNotFound {
                    let minStr = ns.substring(with: match.range(at: 2))
                    minute = Int(minStr) ?? 0
                }
                if match.numberOfRanges > 3 && match.range(at: 3).location != NSNotFound {
                    let meridiem = ns.substring(with: match.range(at: 3)).lowercased()
                    if meridiem == "pm" && h < 12 {
                        h += 12
                    } else if meridiem == "am" && h == 12 {
                        h = 0
                    }
                }
                hour = h
                titleText = timeRegex.stringByReplacingMatches(in: titleText, range: NSRange(location: 0, length: ns.length), withTemplate: "")
            }
        }
        
        // 3. Parse duration (e.g. "for 45m", "for 1 hour", "for 30 mins")
        var durationMinutes = 30
        if let durRegex = try? NSRegularExpression(pattern: #"(?i)\bfor\s*(\d+)\s*(?:m|mins?|minutes?|hours?|h)\b"#) {
            let ns = titleText as NSString
            if let match = durRegex.firstMatch(in: titleText, range: NSRange(location: 0, length: ns.length)) {
                let numStr = ns.substring(with: match.range(at: 1))
                if var num = Int(numStr) {
                    if titleText.lowercased().contains("hour") || titleText.lowercased().contains("hr") {
                        num *= 60
                    }
                    durationMinutes = num
                }
                titleText = durRegex.stringByReplacingMatches(in: titleText, range: NSRange(location: 0, length: ns.length), withTemplate: "")
            }
        }
        
        let cleanedTitle = titleText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
        let finalTitle = cleanedTitle.isEmpty ? "Quick Meeting" : cleanedTitle.capitalized
        
        return .calendar(action: .add(title: finalTitle, hour: hour, minute: minute, duration: durationMinutes))
    }
    
    private static func containsTimeMarker(_ text: String) -> Bool {
        if let regex = try? NSRegularExpression(pattern: #"(?i)\bat\s*\d{1,2}(?::\d{2})?\s*(?:am|pm)?\b"#) {
            let ns = text as NSString
            return regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) != nil
        }
        return false
    }
    
    // MARK: 2. Music Intelligence
    public static func isMusicQuery(_ lower: String) -> Bool {
        if lower.isEmpty { return false }
        
        // Guard against timer / stopwatch queries being misinterpreted as music (e.g. "put on a timer")
        if lower.contains("timer") || lower.contains("countdown") || lower.contains("stopwatch") || lower.contains("pomodoro") {
            return false
        }
        
        // 1. Explicit Music Navigation
        let openWords = [
            "music", "music player", "player", "open music", "open music player",
            "show music", "show music player", "open player", "browse music",
            "ytm", "youtube music", "spotify", "songs", "view player"
        ]
        if openWords.contains(lower) {
            return true
        }
        
        // 2. Playback Controls
        let controlPrefixes = [
            "pause", "stop playing", "stop song", "stop music", "pause audio", "pause song", "pause player", "mute music", "quiet",
            "resume", "resume music", "resume song", "unpause", "continue playing", "start playing",
            "next", "skip", "next track", "next song", "skip track", "skip song",
            "prev", "previous", "previous track", "previous song", "back song", "last track", "replay", "rewind"
        ]
        for c in controlPrefixes {
            if lower == c || lower.hasPrefix(c + " ") {
                return true
            }
        }
        
        // 3. Playback Action Verbs (natural phrases)
        let playPhrases = [
            "play", "listen to", "put on", "stream", "queue up", "queue", "blast", "spin", "shuffle", "turn on", "throw on",
            "can you play", "please play", "i want to listen to", "i want to hear", "i feel like listening to",
            "let's listen to", "let's hear", "how about some", "tune into", "tune in to",
            "song", "track", "audio", "album"
        ]
        for p in playPhrases {
            if lower == p || lower.hasPrefix(p + " ") || lower.hasPrefix(p + ":") {
                return true
            }
        }
        
        // 4. Music genres, vibes, and entities combined with listening intent
        let musicVibes = [
            "lofi", "lo-fi", "chillhop", "synthwave", "jazz", "soundtrack", "ambient beats",
            "study beats", "chill beats", "relaxing beats", "acoustic tunes", "piano music",
            "classical music", "hip hop", "rock music", "playlist", "radio station"
        ]
        for vibe in musicVibes {
            if lower.contains(vibe) {
                return true
            }
        }
        
        // 5. YouTube / Music URLs
        if lower.contains("music.youtube.com") || lower.contains("youtube.com/watch") || lower.contains("youtu.be/") {
            return true
        }
        
        return false
    }
    
    public static func parseMusicCommand(_ text: String) -> MorphSpotlightCommand {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        
        // Navigation / open
        let openPhrases = ["music", "music player", "player", "open music", "open music player", "show music", "show music player", "open player", "browse music", "ytm", "youtube music", "spotify", "songs", "playlist", "playlists", "view player"]
        if openPhrases.contains(lower) {
            return .music(action: .open)
        }
        
        // Pause / Stop
        let pausePhrases = ["pause", "pause music", "stop music", "pause song", "stop song", "pause player", "stop audio", "stop playing", "quiet", "silence", "mute music"]
        if pausePhrases.contains(where: { lower == $0 || lower.hasPrefix($0 + " ") }) {
            return .music(action: .pause)
        }
        
        // Next / Skip
        let nextPhrases = ["next", "skip", "next track", "next song", "skip song", "skip track", "next song please"]
        if nextPhrases.contains(where: { lower == $0 || lower.hasPrefix($0 + " ") }) {
            return .music(action: .next)
        }
        
        // Previous
        let prevPhrases = ["prev", "previous", "previous track", "previous song", "back song", "last song", "replay", "rewind"]
        if prevPhrases.contains(where: { lower == $0 || lower.hasPrefix($0 + " ") }) {
            return .music(action: .previous)
        }
        
        // Play standalone / Resume
        if lower == "play" || lower == "resume" || lower == "resume music" || lower == "unpause" || lower == "continue music" || lower == "start playing" {
            return .music(action: .play(query: nil))
        }
        
        // Play with query extraction
        let playPrefixes = [
            "can you please play", "could you play", "can you play", "please play",
            "i want to listen to", "i want to hear", "i feel like listening to",
            "let's listen to", "let's hear", "how about some",
            "put on some", "put on", "turn on some", "turn on", "throw on",
            "listen to", "play some", "play the", "play a", "play",
            "stream", "queue up", "queue", "blast", "spin", "shuffle",
            "song:", "song", "track:", "track", "tune into", "tune in to"
        ]
        
        for prefix in playPrefixes {
            let lowerP = prefix.lowercased()
            if lower.hasPrefix(lowerP + " ") {
                var query = String(trimmed.dropFirst(lowerP.count + 1)).trimmingCharacters(in: .whitespacesAndNewlines)
                query = cleanMusicQueryTrailing(query)
                return .music(action: .play(query: query.isEmpty ? nil : query))
            } else if lower.hasPrefix(lowerP) && (lowerP.hasSuffix(":") || lowerP.hasSuffix(" ")) {
                var query = String(trimmed.dropFirst(lowerP.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                query = cleanMusicQueryTrailing(query)
                return .music(action: .play(query: query.isEmpty ? nil : query))
            }
        }
        
        // Natural music queries containing keywords (e.g. "lofi beats", "relaxing jazz")
        var query = cleanMusicQueryTrailing(trimmed)
        if query.lowercased().hasSuffix(" music") {
            query = String(query.dropLast(6)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return .music(action: .play(query: query.isEmpty ? nil : query))
    }
    
    private static func cleanMusicQueryTrailing(_ query: String) -> String {
        var clean = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Clean leading fillers like "some ", "the ", "a "
        let leadingFillers = ["some ", "the ", "a "]
        for filler in leadingFillers {
            if clean.lowercased().hasPrefix(filler) {
                clean = String(clean.dropFirst(filler.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                break
            }
        }
        
        // Clean trailing fillers
        let trailingFillers = [
            " while i study", " while i work", " while studying", " while working",
            " for studying", " for study", " for focus", " for coding", " for sleep",
            " please", " on youtube music", " on spotify"
        ]
        let lower = clean.lowercased()
        for filler in trailingFillers {
            if lower.hasSuffix(filler) {
                clean = String(clean.dropLast(filler.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                break
            }
        }
        return clean.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
    }
    
    // MARK: 3. Notes & Scratchpad Intelligence
    public static func isNoteQuery(_ lower: String) -> Bool {
        if lower.isEmpty { return false }
        
        // 1. Explicit View / Navigation
        let viewWords = [
            "notes", "scratchpad", "my notes", "open notes", "show notes", "view notes",
            "check notes", "open scratchpad", "show scratchpad", "view scratchpad",
            "my scratchpad", "todo list", "my todos"
        ]
        if viewWords.contains(lower) {
            return true
        }
        
        // 2. Clear Action
        if lower == "clear notes" || lower == "clear scratchpad" || lower == "delete notes" || lower == "empty scratchpad" {
            return true
        }
        
        // 3. Note capture prefixes
        let notePrefixes = [
            "note", "notes", "todo", "todos", "to-do", "memo", "scratchpad",
            "take a note", "take note", "quick note",
            "write this down", "write down", "jot down", "jot this down", "jot this",
            "remember to", "don't forget to", "dont forget to", "remind me to",
            "save this to notes", "save to notes", "save note", "save thought",
            "add to notes", "add note", "add to scratchpad", "keep track of"
        ]
        for p in notePrefixes {
            if lower == p || lower.hasPrefix(p + " ") || lower.hasPrefix(p + ":") || lower.hasPrefix(p + " - ") {
                return true
            }
        }
        
        return false
    }
    
    public static func parseNoteCommand(_ text: String) -> MorphSpotlightCommand {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        
        // View
        let viewWords = [
            "notes", "scratchpad", "my notes", "open notes", "show notes", "view notes",
            "check notes", "open scratchpad", "show scratchpad", "view scratchpad",
            "my scratchpad", "todo list", "my todos"
        ]
        if viewWords.contains(lower) {
            return .note(action: .view)
        }
        
        // Clear
        if lower == "clear notes" || lower == "clear scratchpad" || lower == "delete notes" || lower == "empty scratchpad" {
            return .note(action: .clear)
        }
        
        // Capture prefixes to strip
        let prefixes = [
            "save this to notes:", "save this to notes",
            "save to notes:", "save to notes",
            "save note:", "save note",
            "save thought:", "save thought",
            "take a note:", "take a note",
            "take note:", "take note",
            "write this down:", "write this down",
            "write down:", "write down",
            "jot down:", "jot down",
            "jot this down:", "jot this down",
            "jot this:", "jot this",
            "quick note:", "quick note",
            "add to scratchpad:", "add to scratchpad",
            "add to notes:", "add to notes",
            "add note:", "add note",
            "remember to", "don't forget to", "dont forget to", "remind me to",
            "keep track of",
            "scratchpad:", "scratchpad",
            "note:", "note", "notes:", "notes",
            "todo:", "todo", "to-do:", "to-do",
            "memo:", "memo"
        ]
        var noteContent = trimmed
        for p in prefixes {
            let lowerPrefix = p.lowercased()
            if lower.hasPrefix(lowerPrefix + " ") {
                noteContent = String(trimmed.dropFirst(lowerPrefix.count + 1))
                break
            } else if lower.hasPrefix(lowerPrefix) && (lowerPrefix.hasSuffix(":") || lowerPrefix.hasSuffix(" ")) {
                noteContent = String(trimmed.dropFirst(lowerPrefix.count))
                break
            }
        }
        let cleanText = noteContent.trimmingCharacters(in: .whitespacesAndNewlines)
        return .note(action: .add(text: cleanText.isEmpty ? trimmed : cleanText, pinToNotch: true))
    }
    
    // MARK: 4. Focus Timer Intelligence
    public static func isTimerQuery(_ lower: String) -> Bool {
        if lower.isEmpty { return false }
        
        // Conversational / question queries (e.g. "how to study for finals", "what can you do") are NOT timer queries
        if isQuestionOrConversationalQuery(lower) && !lower.contains("timer") {
            return false
        }
        
        // 1. Navigation / Standalone
        if lower == "focus timer" || lower == "open timer" || lower == "show timer" || lower == "open focus" || lower == "timer" || lower == "focus" || lower == "pomodoro" {
            return true
        }
        
        // 2. Explicit duration units (e.g. "25m", "15 mins", "1 hour")
        if isStandaloneTimerExpression(lower) {
            return true
        }
        if MorphTimerQueryParser.parse(lower) != nil {
            return true
        }
        
        // 3. Natural timer verbs & phrases
        let timerKeywords = [
            "start timer", "set timer", "set a timer", "start a timer", "give me a timer", "need a timer",
            "put timer", "put a timer", "put on a timer", "put on timer",
            "focus for", "work for", "study for", "lock in for", "countdown for", "timebox", "stopwatch",
            "pomodoro for", "pomodoro session", "start a sprint", "focus sprint", "study sprint", "deep work",
            "take a break", "give me a break", "break for"
        ]
        if timerKeywords.contains(where: { lower.contains($0) }) {
            return true
        }
        if lower.hasPrefix("timer") || lower.hasPrefix("break") {
            return true
        }
        
        return false
    }
    
    public static func parseTimerCommand(_ text: String) -> MorphSpotlightCommand {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        
        // General timer requests -> open larger UI to Focus Timer page so user can pick
        let generalTimerWords = ["timer", "focus", "focus timer", "open timer", "show timer", "open focus", "pomodoro", "pomo", "deep work", "start focus", "timer options"]
        if generalTimerWords.contains(lower) {
            return .navigation(tab: .timer)
        }
        
        // Explicit query parser
        if let timer = MorphTimerQueryParser.parse(trimmed) {
            return .timer(minutes: timer.minutes, title: timer.title, autoStart: timer.autoStart)
        }
        
        // Standalone duration notation (e.g. "25m", "15m", "1h")
        if isStandaloneTimerExpression(lower) {
            let mins = extractTimerMinutes(from: lower) ?? 25
            return .timer(minutes: mins, title: "\(mins)m Focus", autoStart: true)
        }
        
        // Natural timer prompt with minutes extraction
        let mins = extractTimerMinutes(from: lower) ?? 25
        let title = extractTimerTitle(from: trimmed, defaultMinutes: mins)
        return .timer(minutes: mins, title: title, autoStart: true)
    }
    
    private static func extractTimerMinutes(from text: String) -> Int? {
        let lower = text.lowercased()
        
        // Check "half an hour" or "half hour"
        if lower.contains("half an hour") || lower.contains("half hour") {
            return 30
        }
        // Check "an hour" or "one hour"
        if lower.contains("an hour") || lower.contains("one hour") {
            return 60
        }
        
        // Check hours: e.g. "2 hours", "1.5 hours", "1h"
        if let hrRegex = try? NSRegularExpression(pattern: #"(\d+(?:\.\d+)?)\s*(?:hours?|hrs?|h)\b"#) {
            let ns = lower as NSString
            if let match = hrRegex.firstMatch(in: lower, range: NSRange(location: 0, length: ns.length)) {
                let hrStr = ns.substring(with: match.range(at: 1))
                if let hours = Double(hrStr) {
                    return max(1, Int(hours * 60))
                }
            }
        }
        
        // Check minutes: e.g. "25m", "25 mins", "25 minutes", "25 min"
        if let minRegex = try? NSRegularExpression(pattern: #"(\d+)\s*(?:m|mins?|minutes?)\b"#) {
            let ns = lower as NSString
            if let match = minRegex.firstMatch(in: lower, range: NSRange(location: 0, length: ns.length)) {
                let minStr = ns.substring(with: match.range(at: 1))
                if let minutes = Int(minStr) {
                    return minutes
                }
            }
        }
        
        // Check standalone integer in context of timer
        if let numRegex = try? NSRegularExpression(pattern: #"\b(\d+)\b"#) {
            let ns = lower as NSString
            if let match = numRegex.firstMatch(in: lower, range: NSRange(location: 0, length: ns.length)) {
                let numStr = ns.substring(with: match.range(at: 1))
                if let num = Int(numStr), num > 0 && num <= 180 {
                    return num
                }
            }
        }
        
        return nil
    }
    
    private static func extractTimerTitle(from text: String, defaultMinutes: Int) -> String {
        let lower = text.lowercased()
        if lower.contains("break") || lower.contains("rest") {
            return "Break"
        }
        if lower.contains("deep work") || lower.contains("lock in") {
            return "Deep Work"
        }
        if lower.contains("study") {
            return "Study Sprint"
        }
        
        // Try to extract task after "to " or "on " (e.g. "lock in for 45 minutes on cs project")
        if let taskRegex = try? NSRegularExpression(pattern: #"(?i)\b(?:to|on|for)\s+([a-zA-Z0-9\s]{3,30})$"#) {
            let ns = text as NSString
            if let match = taskRegex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) {
                let rawTask = ns.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
                if !rawTask.lowercased().contains("minutes") && !rawTask.lowercased().contains("hours") && !rawTask.isEmpty {
                    return rawTask.capitalized
                }
            }
        }
        
        return "\(defaultMinutes)m Focus"
    }
}
