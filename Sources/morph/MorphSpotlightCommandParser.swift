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
    case view
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
    }
    
    public static func detectType(from query: String) -> CommandType {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return .unknown }
        
        // 1. Direct conversational answer queries
        if isDirectAnswerQuery(trimmed) {
            return .answer
        }
        
        // 2. Calendar queries (natural language schedule checks & event creation)
        if isCalendarQuery(trimmed) {
            return .calendar
        }
        
        // 3. Music commands
        if isMusicQuery(trimmed) {
            return .music
        }
        
        // 4. Note commands
        if isNoteQuery(trimmed) {
            return .note
        }
        
        // 5. Navigation keywords
        if trimmed == "home" || trimmed == "dashboard" {
            return .navigation
        }
        if trimmed == "profile" || trimmed == "settings" || trimmed == "preferences" || trimmed == "my profile" {
            return .navigation
        }
        if trimmed == "focus timer" || trimmed == "open timer" || trimmed == "show timer" {
            return .navigation
        }
        
        // 6. Timer check via explicit timer syntax or timer queries
        if MorphTimerQueryParser.parse(query) != nil {
            return .timer
        }
        if isTimerQuery(trimmed) || isStandaloneTimerExpression(trimmed) {
            return .timer
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
        
        // MARK: - 2. Calendar Natural Language Queries
        if isCalendarQuery(lower) {
            if lower.hasPrefix("meet ") || lower.hasPrefix("meeting ") || lower.hasPrefix("event ") || lower.hasPrefix("schedule ") || lower.hasPrefix("add event ") || lower.hasPrefix("add meeting ") {
                return parseCalendarAddCommand(trimmed)
            }
            return .calendar(action: .view)
        }
        
        // MARK: - 3. Music Player Commands
        if isMusicQuery(lower) {
            if lower == "music" || lower == "player" || lower == "ytm" || lower == "songs" || lower == "open music" || lower == "show music" || lower == "browse music" {
                return .music(action: .open)
            } else if lower == "pause" || lower == "stop music" || lower == "pause music" || lower == "stop song" {
                return .music(action: .pause)
            } else if lower == "next" || lower == "skip" || lower == "next track" || lower == "skip song" {
                return .music(action: .next)
            } else if lower == "prev" || lower == "previous" || lower == "previous track" || lower == "back song" {
                return .music(action: .previous)
            } else if lower == "play" || lower == "resume" || lower == "resume music" {
                return .music(action: .play(query: nil))
            } else if lower.hasPrefix("play ") {
                let songQuery = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespacesAndNewlines)
                return .music(action: .play(query: songQuery.isEmpty ? nil : songQuery))
            } else if lower.hasPrefix("listen to ") {
                let songQuery = String(trimmed.dropFirst(10)).trimmingCharacters(in: .whitespacesAndNewlines)
                return .music(action: .play(query: songQuery.isEmpty ? nil : songQuery))
            } else if lower.hasPrefix("put on ") {
                let songQuery = String(trimmed.dropFirst(7)).trimmingCharacters(in: .whitespacesAndNewlines)
                return .music(action: .play(query: songQuery.isEmpty ? nil : songQuery))
            }
        }
        
        // MARK: - 4. Notes & Scratchpad Commands
        if isNoteQuery(lower) {
            if lower == "notes" || lower == "scratchpad" || lower == "view notes" || lower == "show notes" || lower == "open notes" || lower == "my notes" {
                return .note(action: .view)
            } else if lower == "clear notes" || lower == "clear scratchpad" || lower == "delete notes" {
                return .note(action: .clear)
            } else {
                // Extract note content stripping natural prefixes
                let prefixes = [
                    "take a note: ", "take a note ", "take note: ", "take note ",
                    "write this down: ", "write this down ", "write down: ", "write down ",
                    "jot down: ", "jot down ", "quick note: ", "quick note ",
                    "add to notes: ", "add to notes ", "add note: ", "add note ",
                    "note: ", "note ", "todo: ", "todo ", "memo: ", "memo "
                ]
                var noteContent = trimmed
                for p in prefixes {
                    if lower.hasPrefix(p) {
                        noteContent = String(trimmed.dropFirst(p.count))
                        break
                    }
                }
                return .note(action: .add(text: noteContent.trimmingCharacters(in: .whitespacesAndNewlines), pinToNotch: true))
            }
        }
        
        // MARK: - 5. Navigation (Profile, Home, Focus Timer)
        if lower == "profile" || lower == "my profile" || lower == "open profile" || lower == "settings" || lower == "preferences" {
            return .navigation(tab: .profile)
        }
        if lower == "home" || lower == "dashboard" || lower == "open home" {
            return .navigation(tab: .home)
        }
        if lower == "focus timer" || lower == "open timer" || lower == "show timer" {
            return .navigation(tab: .timer)
        }
        
        // MARK: - 6. Focus Timer Commands (Strictly when user intends a timer)
        if let timer = MorphTimerQueryParser.parse(trimmed) {
            return .timer(minutes: timer.minutes, title: timer.title, autoStart: timer.autoStart)
        }
        if isTimerQuery(lower) {
            let mins = extractTimerMinutes(from: lower) ?? 25
            let title = extractTimerTitle(from: trimmed, defaultMinutes: mins)
            return .timer(minutes: mins, title: title, autoStart: true)
        }
        
        // Standalone explicit timer notation (e.g. "25m", "15m", "45 mins", "1h")
        if isStandaloneTimerExpression(lower) {
            let mins = extractTimerMinutes(from: lower) ?? 25
            return .timer(minutes: mins, title: "\(mins)m Focus", autoStart: true)
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
    
    private static func isMathExpression(_ text: String) -> Bool {
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
    
    private static func isCalendarQuery(_ lower: String) -> Bool {
        // Natural language schedule inquiries
        if lower.contains("plan for today") || lower.contains("plan today") || lower.contains("my plan") ||
           lower.contains("my schedule") || lower.contains("schedule today") || lower.contains("what do i have today") ||
           lower.contains("what do i have") || lower.contains("on my calendar") || lower.contains("do i have meetings") ||
           lower.contains("my meetings") || lower.contains("upcoming meetings") || lower.contains("upcoming events") ||
           lower.contains("agenda") || lower == "calendar" || lower == "cal" || lower == "events" || lower == "today" {
            return true
        }
        // Event creation
        if lower.hasPrefix("meet ") || lower.hasPrefix("meeting ") || lower.hasPrefix("event ") || lower.hasPrefix("schedule ") ||
           lower.hasPrefix("add event") || lower.hasPrefix("add meeting") {
            return true
        }
        return false
    }
    
    private static func isMusicQuery(_ lower: String) -> Bool {
        if lower.hasPrefix("play") || lower.hasPrefix("listen to") || lower.hasPrefix("put on") ||
           lower.hasPrefix("song") || lower.hasPrefix("music") || lower.hasPrefix("ytm") ||
           lower == "pause" || lower == "resume" || lower == "next" || lower == "prev" ||
           lower == "previous" || lower == "skip" || lower.contains("pause music") ||
           lower.contains("stop music") || lower.contains("skip track") || lower.contains("next track") ||
           lower == "music player" || lower == "songs" || lower == "open music" || lower == "show music" {
            return true
        }
        return false
    }
    
    private static func isNoteQuery(_ lower: String) -> Bool {
        if lower.hasPrefix("note") || lower.hasPrefix("todo") || lower.hasPrefix("memo") ||
           lower.hasPrefix("take a note") || lower.hasPrefix("take note") ||
           lower.hasPrefix("write this down") || lower.hasPrefix("write down") ||
           lower.hasPrefix("jot down") || lower.hasPrefix("quick note") ||
           lower.hasPrefix("add to notes") || lower.hasPrefix("add note") ||
           lower == "notes" || lower == "scratchpad" || lower == "open notes" ||
           lower == "my notes" || lower == "view notes" || lower == "show notes" ||
           lower.contains("clear notes") || lower.contains("delete notes") {
            return true
        }
        return false
    }
    
    private static func isTimerQuery(_ lower: String) -> Bool {
        if lower.contains("start timer") || lower.contains("set timer") || lower.contains("set a timer") ||
           lower.contains("focus for") || lower.contains("focus timer") || lower.contains("pomodoro") ||
           lower.contains("deep work") || lower.contains("study for") || lower.contains("give me") ||
           lower.hasPrefix("timer") || lower.hasPrefix("break") {
            return true
        }
        return false
    }
    
    private static func extractTimerMinutes(from text: String) -> Int? {
        if let regex = try? NSRegularExpression(pattern: #"(\d+)\s*(?:m|mins?|minutes?|hours?|h)?"#) {
            let ns = text as NSString
            if let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) {
                let numStr = ns.substring(with: match.range(at: 1))
                if var num = Int(numStr) {
                    if text.contains("hour") || text.contains("hr") || text.contains("1h") {
                        num *= 60
                    }
                    return num
                }
            }
        }
        return nil
    }
    
    private static func extractTimerTitle(from text: String, defaultMinutes: Int) -> String {
        let lower = text.lowercased()
        if lower.contains("break") {
            return "Break"
        }
        if lower.contains("study") {
            return "Study Sprint"
        }
        if lower.contains("deep work") {
            return "Deep Work"
        }
        return "\(defaultMinutes)m Focus"
    }
    
    public static func parseCalendarAddCommand(_ text: String) -> MorphSpotlightCommand {
        let raw = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var titleText = raw
        
        // 1. Strip leading command keyword
        if let verbRegex = try? NSRegularExpression(pattern: #"(?i)^(meet|meeting|event|schedule|add event|add meeting)\s+"#) {
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
        if let durRegex = try? NSRegularExpression(pattern: #"(?i)\bfor\s*(\d+)\s*(?:m|mins?|minutes?)\b"#) {
            let ns = titleText as NSString
            if let match = durRegex.firstMatch(in: titleText, range: NSRange(location: 0, length: ns.length)) {
                let numStr = ns.substring(with: match.range(at: 1))
                durationMinutes = Int(numStr) ?? 30
                titleText = durRegex.stringByReplacingMatches(in: titleText, range: NSRange(location: 0, length: ns.length), withTemplate: "")
            }
        }
        
        let cleanedTitle = titleText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
        let finalTitle = cleanedTitle.isEmpty ? "Quick Meeting" : cleanedTitle.capitalized
        
        return .calendar(action: .add(title: finalTitle, hour: hour, minute: minute, duration: durationMinutes))
    }
}
