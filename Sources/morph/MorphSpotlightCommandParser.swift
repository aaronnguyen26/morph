import Foundation

public enum TimerControlAction: Equatable {
    case pause
    case resume
    case stop
    case adjust(minutesDelta: Int)
    case queryStatus
}

public enum MorphSpotlightCommand: Equatable {
    case timer(minutes: Int, title: String, autoStart: Bool)
    case timerControl(action: TimerControlAction)
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
    case volumeUp
    case volumeDown
    case mute
    case queryStatus
}

public enum NoteAction: Equatable {
    case add(text: String, pinToNotch: Bool)
    case view
    case clear
    case readPreview
    case copyToClipboard
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
    
    public static func normalizeQuery(_ text: String) -> String {
        var clean = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        let typoMap: [String: String] = [
            "timr": "timer",
            "tmr": "timer",
            "focustimer": "focus timer",
            "pomodro": "pomodoro",
            "pomo": "pomodoro",
            "calender": "calendar",
            "calander": "calendar",
            "scedule": "schedule",
            "scheudle": "schedule",
            "notepadd": "notes",
            "scratcpad": "scratchpad",
            "todoo": "todo",
            "paly": "play",
            "plau": "play",
            "musci": "music",
            "songg": "song"
        ]
        
        let words = clean.components(separatedBy: .whitespaces)
        let normalizedWords = words.map { word -> String in
            let trimmedWord = word.trimmingCharacters(in: .punctuationCharacters)
            if let correction = typoMap[trimmedWord] {
                return word.replacingOccurrences(of: trimmedWord, with: correction)
            }
            return word
        }
        clean = normalizedWords.joined(separator: " ")
        return clean
    }

    public static func detectType(from query: String) -> CommandType {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .unknown }
        let lower = trimmed.lowercased()
        let norm = normalizeQuery(lower)
        
        // 1. Direct conversational answer queries (time, date, identity, math)
        if isDirectAnswerQuery(norm) {
            return .answer
        }
        
        // 2. Timer live controls (e.g. "pause timer", "+5m", "stop timer", "time left")
        if isTimerControlQuery(norm) {
            return .timer
        }
        
        // 3. Note commands (explicit note/todo prefixes take high priority)
        if isNoteQuery(norm) {
            return .note
        }
        
        // 4. Calendar queries (schedule inquiries & event creation with time/dates)
        if isCalendarQuery(norm) {
            return .calendar
        }
        
        // 5. Music commands (natural listening requests, playback controls, genres, URLs)
        if isMusicQuery(norm) {
            return .music
        }
        
        // 6. Timer check via explicit timer syntax or natural timer prompts
        if isTimerQuery(norm) {
            return .timer
        }
        
        // 7. Navigation keywords
        if norm == "home" || norm == "dashboard" {
            return .navigation
        }
        if norm == "profile" || norm == "settings" || norm == "preferences" || norm == "my profile" {
            return .navigation
        }
        
        // 8. General questions / informational queries & conversational response
        return .answer
    }
    
    public static func parse(_ text: String) -> MorphSpotlightCommand {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        let norm = normalizeQuery(lower)
        
        // MARK: - 1. Direct Conversational Answers & Questions
        if let directAnswer = parseDirectAnswer(trimmed) {
            return directAnswer
        }
        
        // MARK: - 2. Timer Live Controls
        if let controlAction = parseTimerControl(norm) {
            return .timerControl(action: controlAction)
        }
        
        // MARK: - 3. Notes & Scratchpad Commands
        if isNoteQuery(norm) {
            return parseNoteCommand(trimmed)
        }
        
        // MARK: - 4. Calendar Natural Language Queries
        if isCalendarQuery(norm) {
            return parseCalendarCommand(trimmed)
        }
        
        // MARK: - 5. Music Player Commands
        if isMusicQuery(norm) {
            return parseMusicCommand(trimmed)
        }
        
        // MARK: - 6. Focus Timer Commands
        if isTimerQuery(norm) {
            return parseTimerCommand(trimmed)
        }
        
        // MARK: - 7. Navigation (Profile, Home)
        if norm == "profile" || norm == "my profile" || norm == "open profile" || norm == "settings" || norm == "preferences" {
            return .navigation(tab: .profile)
        }
        if norm == "home" || norm == "dashboard" || norm == "open home" {
            return .navigation(tab: .home)
        }
        
        // MARK: - 8. Intelligent Conversational Assistant (Contained to 4 core features)
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
        let norm = normalizeQuery(lower)
        // Natural verbal hour/fraction checks:
        if norm.contains("half an hour") || norm.contains("half hour") ||
           norm.contains("an hour and a half") || norm.contains("hour and a half") || norm.contains("one and a half hours") ||
           norm.contains("an hour") || norm.contains("one hour") || norm.contains("two hours") || norm.contains("quarter of an hour") {
            return true
        }
        // Explicit timer units: "25m", "15 mins", "1 hour", "45 min"
        if let regex = try? NSRegularExpression(pattern: #"^\s*(\d+)\s*(m|min|mins|minute|minutes|h|hr|hours?)\s*$"#) {
            let range = NSRange(location: 0, length: (norm as NSString).length)
            if regex.firstMatch(in: norm, range: range) != nil {
                return true
            }
        }
        // Standalone numbers 1..180 (e.g. "15", "25", "30", "45", "60")
        if let num = Int(norm.trimmingCharacters(in: .whitespaces)), num >= 1 && num <= 180 {
            return true
        }
        return false
    }
    
    // MARK: - Timer Live Controls Intelligence
    public static func isTimerControlQuery(_ lower: String) -> Bool {
        let norm = normalizeQuery(lower)
        
        // Adjustments: +5m, +10m, +15m, +5, +10, -5m, -10m, -5, add 5 mins, subtract 5 mins, add 5m to timer
        if let regex = try? NSRegularExpression(pattern: #"^(?:\+|\-|add\s+|subtract\s+|minus\s+)\s*(\d+)\s*(?:m|mins?|minutes?)?(?:\s+(?:to|from)\s+timer)?"#) {
            let range = NSRange(location: 0, length: (norm as NSString).length)
            if regex.firstMatch(in: norm, range: range) != nil {
                return true
            }
        }
        
        let controlPhrases = [
            "pause timer", "pause focus", "pause sprint", "pause countdown",
            "resume timer", "resume focus", "resume sprint", "continue timer", "unpause timer", "restart timer",
            "stop timer", "cancel timer", "reset timer", "end timer", "stop sprint", "stop focus",
            "time left", "how much time left", "how much time is left", "timer status", "timer remaining", "check timer"
        ]
        if controlPhrases.contains(where: { norm == $0 || norm.hasPrefix($0 + " ") }) {
            return true
        }
        return false
    }
    
    public static func parseTimerControl(_ text: String) -> TimerControlAction? {
        let norm = normalizeQuery(text)
        
        // Adjustments: e.g. "+5m", "-5m", "add 10 minutes", "subtract 5 mins"
        if let regex = try? NSRegularExpression(pattern: #"^(\+|\-|add\s+|subtract\s+|minus\s+)\s*(\d+)"#) {
            let ns = norm as NSString
            if let match = regex.firstMatch(in: norm, range: NSRange(location: 0, length: ns.length)) {
                let signStr = ns.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces)
                let numStr = ns.substring(with: match.range(at: 2))
                if let delta = Int(numStr) {
                    let isNegative = signStr == "-" || signStr.hasPrefix("subtract") || signStr.hasPrefix("minus")
                    let finalDelta = isNegative ? -delta : delta
                    return .adjust(minutesDelta: finalDelta)
                }
            }
        }
        
        // Pause
        if norm.contains("pause") && (norm.contains("timer") || norm.contains("focus") || norm.contains("sprint")) {
            return .pause
        }
        // Resume
        if (norm.contains("resume") || norm.contains("continue") || norm.contains("unpause") || norm.contains("restart")) && (norm.contains("timer") || norm.contains("focus") || norm.contains("sprint")) {
            return .resume
        }
        // Stop
        if (norm.contains("stop") || norm.contains("cancel") || norm.contains("reset") || norm.contains("end")) && (norm.contains("timer") || norm.contains("focus") || norm.contains("sprint")) {
            return .stop
        }
        // Status
        if norm.contains("time left") || norm.contains("timer status") || norm.contains("timer remaining") || norm.contains("check timer") {
            return .queryStatus
        }
        
        return nil
    }
    
    private static func generateIntelligentResponse(for trimmed: String) -> MorphSpotlightCommand {
        let lower = trimmed.lowercased()
        let norm = normalizeQuery(lower)
        
        // Conversational math check
        if let mathAnswer = evaluateMathExpression(norm) {
            return .answer(text: mathAnswer, icon: "equal")
        }
        
        // Check for general task/thought entry (e.g. "reading response #4", "finish the design", "study biology")
        let taskIndicators = ["reading", "essay", "homework", "study", "review", "code", "design", "write", "finish", "prepare", "draft", "project", "presentation", "assignment", "paper", "exam", "quiz"]
        if taskIndicators.contains(where: { norm.contains($0) }) {
            return .answer(text: "Ready to focus on \(trimmed.capitalized)? Type '25m' to start or 'note' to save", icon: "brain.head.profile")
        }
        
        // Machine Learning & Computer Science queries (e.g. cross entropy loss, loss function)
        if norm.contains("cross entropy") || norm.contains("cross-entropy") || norm.contains("loss function") || norm.contains("negative log") || norm.contains("lecture notes") {
            return .answer(text: "Cross-Entropy Loss: ℓ(θ) = -∑ log(exp(θ_yᵀ x) / ∑ exp(θ_jᵀ x))", icon: "function")
        }
        
        // General conversational response (graceful, polite, non-intrusive)
        return .answer(text: "AI Analysis: \"\(trimmed)\"", icon: "sparkles")
    }
    
    // MARK: - Rich AI Intelligence Generator
    public static func generateAIResponse(for query: String, briefAnswer: String? = nil, icon: String? = nil) -> MorphAIResponse {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        let norm = normalizeQuery(lower)
        
        // 1. Machine Learning & Mathematics (Cross-entropy loss, loss functions, optimization, calculus)
        if norm.contains("cross entropy") || norm.contains("cross-entropy") || norm.contains("loss function") || norm.contains("negative log") || norm.contains("lecture notes") || norm.contains("2.12") || norm.contains("2.13") || norm.contains("2.14") {
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
        if norm.contains("study plan") || norm.contains("study for ml") || norm.contains("how to study") || norm.contains("exam") || norm.contains("quiz") {
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
        if let mathAnswer = evaluateMathExpression(norm) {
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
        if norm.contains("focus") || norm.contains("productivity") || norm.contains("flow") || norm.contains("deep work") {
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
        
        // 5. Morph Capabilities & Identity (Contained to 4 core features)
        if norm == "who are you" || norm == "what are you" || norm == "what is morph" || norm.contains("what can you do") || norm == "help" || norm.contains("features") || norm.contains("commands") || norm.contains("how does morph work") || norm.contains("how to use") {
            return MorphAIResponse(
                query: trimmed,
                title: "Morph Dynamic Island Architecture",
                category: "System Capabilities",
                icon: "sparkles",
                summary: "Morph is an intelligent Dynamic Island desktop companion containing 4 focused productivity features.",
                detailedContent: "Morph operates seamlessly via keyboard prompts and resting stealth controls:\n\n1. Focus Timer: Start sprints ('25m', 'timer 45m', 'half an hour on math') and control live timers ('pause timer', '+5m', 'stop timer', 'time left').\n2. Notes & Scratchpad: Capture quick thoughts ('note [text]', 'remember to ...', 'todo: ...'), preview ('read notes'), copy to clipboard ('copy notes'), or reset ('clear notes').\n3. Calendar: Inquire about schedule ('what's on my calendar today', 'when is my next meeting', 'am i free today') or quick-schedule ('meet Sarah at 2:30pm for 45m').\n4. Music Player: Stream audio ('play lofi beats', 'put on jazz') and control playback ('pause', 'next', 'volume up', 'volume down', 'mute').",
                keyPoints: [
                    "Focus Timer: '25m', 'half an hour', 'pause timer', '+5m'",
                    "Notes: 'note [text]', 'remember to ...', 'read notes', 'copy notes'",
                    "Calendar: 'meetings today', 'meet Alex at 3pm for 45m'",
                    "Music: 'play lofi', 'volume up', 'next song', 'mute'"
                ],
                suggestedActions: [
                    "Start Focus Timer",
                    "Open Scratchpad",
                    "Explore Calendar",
                    "Play Lofi Beats"
                ]
            )
        }
        
        // 6. Task or Project Entry (e.g. "reading response #4", "design wireframes")
        let taskIndicators = ["reading", "essay", "homework", "study", "review", "code", "design", "write", "finish", "prepare", "draft", "project", "presentation", "assignment", "paper", "exam", "quiz"]
        if taskIndicators.contains(where: { norm.contains($0) }) {
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
        let norm = normalizeQuery(lower)
        
        // 1. Natural language schedule inquiries
        let inquiryPhrases = [
            "plan for today", "plan today", "my plan", "what my plan", "what is my plan",
            "my schedule", "schedule today", "what's my schedule", "what is my schedule",
            "what do i have today", "what do i have scheduled", "what do i have",
            "on my calendar", "do i have meetings", "my meetings", "upcoming meetings",
            "upcoming events", "agenda", "today's agenda", "when is my next meeting",
            "next meeting", "upcoming meeting", "what's next", "what is next",
            "check my calendar", "show my calendar", "view calendar", "open calendar",
            "show calendar", "calendar schedule", "do i have any meetings", "have any meetings",
            "any meetings today", "meetings today", "meeting today",
            "am i free today", "do i have time this afternoon", "free today"
        ]
        if inquiryPhrases.contains(where: { norm.contains($0) }) {
            return true
        }
        if (norm.contains("meeting") || norm.contains("meetings") || norm.contains("schedule") || norm.contains("calendar") || norm.contains("agenda")) &&
           (norm.contains("today") || norm.contains("tomorrow") || norm.contains("upcoming") || norm.contains("next") || norm.contains("have") || norm.contains("any") || norm.contains("what") || norm.contains("check") || norm.contains("show") || norm.contains("free")) {
            return true
        }
        if norm == "calendar" || norm == "my calendar" || norm == "cal" || norm == "events" || norm == "today" {
            return true
        }
        
        // 2. Event creation prefixes
        let eventPrefixes = [
            "meet ", "meeting ", "event ", "schedule ", "add event", "add meeting",
            "new event", "new meeting", "sync with ", "call with ", "coffee with ",
            "lunch with ", "dinner with ", "interview with ", "appointment with "
        ]
        for p in eventPrefixes {
            if norm.hasPrefix(p) {
                return true
            }
        }
        
        // 3. Time-marker based event additions (e.g. "coffee with Sarah at 10am")
        if containsTimeMarker(norm) {
            let eventKeywords = [
                "meet", "meeting", "sync", "call", "1on1", "1:1", "coffee", "lunch",
                "dinner", "interview", "appointment", "doctor", "dentist", "standup",
                "review", "demo", "presentation", "session", "class", "lecture", "hangout"
            ]
            if eventKeywords.contains(where: { norm.contains($0) }) {
                return true
            }
        }
        
        return false
    }
    
    public static func parseCalendarCommand(_ text: String) -> MorphSpotlightCommand {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let norm = normalizeQuery(trimmed)
        
        // 1. General calendar requests to open/view the calendar UI:
        let isExplicitViewRequest = (norm.contains("view") || norm.contains("open") || norm.contains("show") || norm.contains("browse")) && (norm.contains("calendar") || norm.contains("schedule")) && !norm.contains("today")
        let generalPhrases = ["calendar", "cal", "events", "my calendar", "schedule", "calendar schedule", "view my calendar schedule", "open calendar schedule"]
        if isExplicitViewRequest || generalPhrases.contains(norm) {
            return .calendar(action: .open)
        }
        
        // 2. Specific fetchable schedule inquiries for today / next meeting -> display in background lengthened pill:
        let isTodayOrNextInquiry = norm.contains("today") || norm.contains("next meeting") || norm.contains("upcoming meeting") || norm.contains("meetings today") || norm.contains("agenda today") || norm.contains("plan for today") || norm.contains("on my calendar") || norm.contains("on their calendar") || norm.contains("do i have meetings") || norm.contains("what do i have") || norm.contains("what's on my calendar") || norm.contains("what is on my calendar") || norm.contains("what on my calendar") || norm.contains("what on their calendar") || norm.contains("what's next") || norm.contains("what is next") || norm.contains("am i free") || norm.contains("free today")
        
        if isTodayOrNextInquiry && !containsTimeMarker(norm) && !norm.hasPrefix("schedule ") && !norm.hasPrefix("add event") && !norm.hasPrefix("meet ") {
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
        
        // 3. Parse duration (e.g. "for 45m", "for 1 hour", "for 30 mins", "for half an hour")
        var durationMinutes = 30
        let lowerTitle = titleText.lowercased()
        if lowerTitle.contains("for half an hour") || lowerTitle.contains("for half hour") {
            durationMinutes = 30
            titleText = titleText.replacingOccurrences(of: "(?i)for half an hour", with: "", options: .regularExpression)
            titleText = titleText.replacingOccurrences(of: "(?i)for half hour", with: "", options: .regularExpression)
        } else if lowerTitle.contains("for an hour and a half") || lowerTitle.contains("for 1.5 hours") {
            durationMinutes = 90
            titleText = titleText.replacingOccurrences(of: "(?i)for an hour and a half", with: "", options: .regularExpression)
            titleText = titleText.replacingOccurrences(of: "(?i)for 1.5 hours", with: "", options: .regularExpression)
        } else if lowerTitle.contains("for an hour") || lowerTitle.contains("for 1 hour") || lowerTitle.contains("for 1 hr") {
            durationMinutes = 60
            titleText = titleText.replacingOccurrences(of: "(?i)for an hour", with: "", options: .regularExpression)
            titleText = titleText.replacingOccurrences(of: "(?i)for 1 hour", with: "", options: .regularExpression)
            titleText = titleText.replacingOccurrences(of: "(?i)for 1 hr", with: "", options: .regularExpression)
        } else if let durRegex = try? NSRegularExpression(pattern: #"(?i)\bfor\s*(\d+)\s*(?:m|mins?|minutes?|hours?|h)\b"#) {
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
        let norm = normalizeQuery(lower)
        
        // Guard against timer / stopwatch queries being misinterpreted as music
        if norm.contains("timer") || norm.contains("countdown") || norm.contains("stopwatch") || norm.contains("pomodoro") {
            return false
        }
        
        // 1. Explicit Music Navigation
        let openWords = [
            "music", "music player", "player", "open music", "open music player",
            "show music", "show music player", "open player", "browse music",
            "ytm", "youtube music", "spotify", "songs", "view player"
        ]
        if openWords.contains(norm) {
            return true
        }
        
        // 2. Playback Controls & Volume
        let controlPrefixes = [
            "pause", "stop playing", "stop song", "stop music", "pause audio", "pause song", "pause player", "mute music", "quiet",
            "resume", "resume music", "resume song", "unpause", "continue playing", "start playing",
            "next", "skip", "next track", "next song", "skip track", "skip song",
            "prev", "previous", "previous track", "previous song", "back song", "last track", "replay", "rewind",
            "volume up", "turn it up", "louder", "crank it up", "+vol", "boost volume",
            "volume down", "turn it down", "quieter", "softer", "-vol", "lower volume",
            "mute", "unmute",
            "what's playing", "what is playing", "current song", "what song is this", "song info", "playing now"
        ]
        for c in controlPrefixes {
            if norm == c || norm.hasPrefix(c + " ") {
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
            if norm == p || norm.hasPrefix(p + " ") || norm.hasPrefix(p + ":") {
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
            if norm.contains(vibe) {
                return true
            }
        }
        
        // 5. YouTube / Music URLs
        if norm.contains("music.youtube.com") || norm.contains("youtube.com/watch") || norm.contains("youtu.be/") {
            return true
        }
        
        return false
    }
    
    public static func parseMusicCommand(_ text: String) -> MorphSpotlightCommand {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let norm = normalizeQuery(trimmed)
        
        // Volume controls
        let volUpPhrases = ["volume up", "turn it up", "louder", "crank it up", "+vol", "boost volume", "volume +"]
        if volUpPhrases.contains(where: { norm == $0 || norm.hasPrefix($0 + " ") }) {
            return .music(action: .volumeUp)
        }
        let volDownPhrases = ["volume down", "turn it down", "quieter", "softer", "-vol", "lower volume", "volume -"]
        if volDownPhrases.contains(where: { norm == $0 || norm.hasPrefix($0 + " ") }) {
            return .music(action: .volumeDown)
        }
        if norm == "mute" || norm == "unmute" || norm == "mute music" || norm == "unmute music" {
            return .music(action: .mute)
        }
        
        // Song info / what's playing
        let queryStatusPhrases = ["what's playing", "what is playing", "current song", "what song is this", "song info", "playing now", "now playing"]
        if queryStatusPhrases.contains(where: { norm == $0 || norm.hasPrefix($0 + " ") }) {
            return .music(action: .queryStatus)
        }
        
        // Navigation / open
        let openPhrases = ["music", "music player", "player", "open music", "open music player", "show music", "show music player", "open player", "browse music", "ytm", "youtube music", "spotify", "songs", "playlist", "playlists", "view player"]
        if openPhrases.contains(norm) {
            return .music(action: .open)
        }
        
        // Pause / Stop
        let pausePhrases = ["pause", "pause music", "stop music", "pause song", "stop song", "pause player", "stop audio", "stop playing", "quiet", "silence", "mute music"]
        if pausePhrases.contains(where: { norm == $0 || norm.hasPrefix($0 + " ") }) {
            return .music(action: .pause)
        }
        
        // Next / Skip
        let nextPhrases = ["next", "skip", "next track", "next song", "skip song", "skip track", "next song please"]
        if nextPhrases.contains(where: { norm == $0 || norm.hasPrefix($0 + " ") }) {
            return .music(action: .next)
        }
        
        // Previous
        let prevPhrases = ["prev", "previous", "previous track", "previous song", "back song", "last song", "replay", "rewind"]
        if prevPhrases.contains(where: { norm == $0 || norm.hasPrefix($0 + " ") }) {
            return .music(action: .previous)
        }
        
        // Play standalone / Resume
        if norm == "play" || norm == "resume" || norm == "resume music" || norm == "unpause" || norm == "continue music" || norm == "start playing" {
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
            if norm.hasPrefix(lowerP + " ") {
                var query = String(trimmed.dropFirst(lowerP.count + 1)).trimmingCharacters(in: .whitespacesAndNewlines)
                query = cleanMusicQueryTrailing(query)
                return .music(action: .play(query: query.isEmpty ? nil : query))
            } else if norm.hasPrefix(lowerP) && (lowerP.hasSuffix(":") || lowerP.hasSuffix(" ")) {
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
        let norm = normalizeQuery(lower)
        
        // 1. Explicit View / Navigation
        let viewWords = [
            "notes", "scratchpad", "my notes", "open notes", "show notes", "view notes",
            "check notes", "open scratchpad", "show scratchpad", "view scratchpad",
            "my scratchpad", "todo list", "my todos"
        ]
        if viewWords.contains(norm) {
            return true
        }
        
        // 2. Clear Action
        let clearPhrases = ["clear notes", "clear scratchpad", "delete notes", "empty scratchpad", "erase notes"]
        if clearPhrases.contains(where: { norm == $0 || norm.hasPrefix($0 + " ") }) {
            return true
        }
        
        // 3. Inspection & Copy
        let inspectPhrases = ["read notes", "show my notes", "what are my notes", "read scratchpad", "show scratchpad text", "view scratchpad", "copy notes", "copy scratchpad", "copy note"]
        if inspectPhrases.contains(where: { norm == $0 || norm.hasPrefix($0 + " ") }) {
            return true
        }
        
        // 4. Note capture prefixes
        let notePrefixes = [
            "note", "notes", "todo", "todos", "to-do", "memo", "scratchpad",
            "take a note", "take note", "quick note",
            "write this down", "write down", "jot down", "jot this down", "jot this",
            "remember to", "don't forget to", "dont forget to", "remind me to",
            "save this to notes", "save to notes", "save note", "save thought",
            "add to notes", "add note", "add to scratchpad", "keep track of"
        ]
        for p in notePrefixes {
            if norm == p || norm.hasPrefix(p + " ") || norm.hasPrefix(p + ":") || norm.hasPrefix(p + " - ") {
                return true
            }
        }
        
        return false
    }
    
    public static func parseNoteCommand(_ text: String) -> MorphSpotlightCommand {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let norm = normalizeQuery(trimmed)
        
        // Clear
        let clearPhrases = ["clear notes", "clear scratchpad", "delete notes", "empty scratchpad", "erase notes"]
        if clearPhrases.contains(where: { norm == $0 || norm.hasPrefix($0 + " ") }) {
            return .note(action: .clear)
        }
        
        // Read preview
        let readPhrases = ["read notes", "show my notes", "what are my notes", "read scratchpad", "show scratchpad text", "view scratchpad", "read notes preview"]
        if readPhrases.contains(where: { norm == $0 || norm.hasPrefix($0 + " ") }) {
            return .note(action: .readPreview)
        }
        
        // Copy to clipboard
        let copyPhrases = ["copy notes", "copy scratchpad", "copy note", "copy my notes"]
        if copyPhrases.contains(where: { norm == $0 || norm.hasPrefix($0 + " ") }) {
            return .note(action: .copyToClipboard)
        }
        
        // View (opens large UI)
        let viewWords = [
            "notes", "scratchpad", "my notes", "open notes", "show notes", "view notes",
            "check notes", "open scratchpad", "show scratchpad", "view scratchpad",
            "my scratchpad", "todo list", "my todos"
        ]
        if viewWords.contains(norm) {
            return .note(action: .view)
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
            if norm.hasPrefix(lowerPrefix + " ") {
                noteContent = String(trimmed.dropFirst(lowerPrefix.count + 1))
                break
            } else if norm.hasPrefix(lowerPrefix) && (lowerPrefix.hasSuffix(":") || lowerPrefix.hasSuffix(" ")) {
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
        let norm = normalizeQuery(lower)
        
        // Live timer controls
        if isTimerControlQuery(norm) {
            return true
        }
        
        // Conversational / question queries (e.g. "how to study for finals", "what can you do") are NOT timer queries
        if isQuestionOrConversationalQuery(norm) && !norm.contains("timer") {
            return false
        }
        
        // 1. Navigation / Standalone
        if norm == "focus timer" || norm == "open timer" || norm == "show timer" || norm == "open focus" || norm == "timer" || norm == "focus" || norm == "pomodoro" {
            return true
        }
        
        // 2. Explicit duration units (e.g. "25m", "15 mins", "1 hour", "half an hour", "an hour and a half")
        if isStandaloneTimerExpression(norm) {
            return true
        }
        if MorphTimerQueryParser.parse(norm) != nil {
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
        if timerKeywords.contains(where: { norm.contains($0) }) {
            return true
        }
        if norm.hasPrefix("timer") || norm.hasPrefix("break") {
            return true
        }
        
        return false
    }
    
    public static func parseTimerCommand(_ text: String) -> MorphSpotlightCommand {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let norm = normalizeQuery(trimmed)
        
        // Live timer controls
        if let control = parseTimerControl(norm) {
            return .timerControl(action: control)
        }
        
        // General timer requests -> open larger UI to Focus Timer page so user can pick
        let generalTimerWords = ["timer", "focus", "focus timer", "open timer", "show timer", "open focus", "pomodoro", "pomo", "deep work", "start focus", "timer options"]
        if generalTimerWords.contains(norm) {
            return .navigation(tab: .timer)
        }
        
        // Explicit query parser
        if let timer = MorphTimerQueryParser.parse(trimmed) {
            return .timer(minutes: timer.minutes, title: timer.title, autoStart: timer.autoStart)
        }
        
        // Standalone duration notation (e.g. "25m", "15m", "1h", "half an hour")
        if isStandaloneTimerExpression(norm) {
            let mins = extractTimerMinutes(from: norm) ?? 25
            return .timer(minutes: mins, title: "\(mins)m Focus", autoStart: true)
        }
        
        // Natural timer prompt with minutes extraction
        let mins = extractTimerMinutes(from: norm) ?? 25
        let title = extractTimerTitle(from: trimmed, defaultMinutes: mins)
        return .timer(minutes: mins, title: title, autoStart: true)
    }
    
    private static func extractTimerMinutes(from text: String) -> Int? {
        let lower = text.lowercased()
        
        // Check verbal hour/fraction combinations:
        if lower.contains("an hour and a half") || lower.contains("hour and a half") || lower.contains("one and a half hours") || lower.contains("1.5 hours") {
            return 90
        }
        if lower.contains("half an hour") || lower.contains("half hour") {
            return 30
        }
        if lower.contains("quarter of an hour") || lower.contains("quarter hour") {
            return 15
        }
        if lower.contains("two hours") || lower.contains("2 hours") {
            return 120
        }
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
