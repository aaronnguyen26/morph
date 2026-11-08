import Foundation
import NaturalLanguage

public struct MorphQuickAction: Identifiable, Equatable {
    public var id: String { command }
    public let title: String
    public let command: String
    public let icon: String
    
    public init(title: String, command: String, icon: String) {
        self.title = title
        self.command = command
        self.icon = icon
    }
}

public struct MorphIntelligenceResult: Equatable {
    public enum IntentType: Equatable {
        case general(targetState: GlassIslandState)
        case specific(
            answer: String,
            domain: String,
            icon: String,
            tintColorHex: String,
            actionTitle: String?,
            targetState: GlassIslandState?
        )
        case actionExecuted(
            confirmation: String,
            domain: String,
            icon: String,
            tintColorHex: String,
            actionTitle: String?,
            targetState: GlassIslandState?
        )
        case noAction(
            message: String,
            quickActions: [MorphQuickAction]
        )
    }
    
    public let intentType: IntentType
    
    public init(intentType: IntentType) {
        self.intentType = intentType
    }
}

// MARK: - Supported Morph Feature Domains

public enum MorphFeatureDomain: String, CaseIterable {
    case calendar = "Calendar"
    case timer = "Focus Timer"
    case music = "Music Player"
    case drops = "Drop Shelf"
    case notes = "Notes"
    case forms = "Form Assistant"
    case profile = "Profile"
    case system = "Morph"
    
    public var state: GlassIslandState {
        switch self {
        case .calendar: return .calendar
        case .timer: return .timer
        case .music: return .music
        case .drops: return .drops
        case .notes: return .notes
        case .forms: return .forms
        case .profile: return .profile
        case .system: return .profile
        }
    }
    
    /// Rich keyword and colloquial anchors for Siri AI comprehension
    var primaryKeywords: Set<String> {
        switch self {
        case .calendar:
            return [
                "calendar", "schedule", "meeting", "event", "appointment", "agenda",
                "call", "standup", "sync", "busy", "free", "plans", "plan", "today",
                "plate", "afternoon", "morning", "day", "availability", "time"
            ]
        case .timer:
            return [
                "timer", "focus", "countdown", "pomodoro", "clock", "stopwatch",
                "break", "session", "deepwork", "lock in", "locked in", "ticking",
                "remaining", "freeze"
            ]
        case .music:
            return [
                "music", "song", "track", "artist", "audio", "playback", "playlist",
                "tune", "tunes", "sound", "volume", "album", "singing", "singer",
                "playing", "jam", "jams", "listen", "listening", "shuffle", "mute"
            ]
        case .drops:
            return [
                "shelf", "file", "files", "document", "documents", "attachment",
                "attachments", "staged", "drop", "drops", "clipping", "dragged",
                "clutter", "airdrop"
            ]
        case .notes:
            return [
                "note", "notes", "scratchpad", "memo", "jot", "thought", "idea",
                "reminder", "todo", "written", "write"
            ]
        case .forms:
            return [
                "form", "forms", "field", "fields", "autofill", "receipt",
                "receipts", "detection", "fill", "question", "input"
            ]
        case .profile:
            return [
                "profile", "user", "account", "identity", "status", "role",
                "email", "avatar", "me", "settings", "preference", "afk", "logged in"
            ]
        case .system:
            return [
                "morph", "feature", "features", "capability", "capabilities",
                "island", "notch", "context", "assistant", "help"
            ]
        }
    }
    
    /// Vector embedding anchor words used to compute semantic distance via NLEmbedding
    var embeddingAnchors: [String] {
        switch self {
        case .calendar:
            return ["calendar", "schedule", "meeting", "event", "appointment", "agenda"]
        case .timer:
            return ["timer", "focus", "countdown", "pomodoro", "clock"]
        case .music:
            return ["music", "song", "track", "artist", "audio", "playback"]
        case .drops:
            return ["shelf", "file", "document", "attachment", "staged", "drop"]
        case .notes:
            return ["note", "scratchpad", "memo", "thought", "idea"]
        case .forms:
            return ["form", "field", "autofill", "input", "receipt"]
        case .profile:
            return ["profile", "user", "account", "identity", "status"]
        case .system:
            return ["assistant", "system", "tool", "features", "capabilities"]
        }
    }
}

// MARK: - Linguistic Analysis Model for Siri AI

public struct MorphNLUTaggedUtterance {
    public let raw: String
    public let clean: String
    public let lower: String
    public let coreLower: String // Politeness stripped, e.g. "could you please freeze the timer" -> "freeze the timer"
    public let tokens: [String]
    public let lemmas: [String]
    public let lexicalClasses: [String: String]
    public let lemmasSet: Set<String>
    public let tokensSet: Set<String>
    public let isInterrogative: Bool
    public let detectedDurationMinutes: Int?
    public let detectedDate: Date?
    public let cleanTextWithoutDate: String
}

// MARK: - Siri AI Local Intelligence Engine

@MainActor
public final class MorphLocalIntelligenceEngine {
    public static let shared = MorphLocalIntelligenceEngine()
    
    private let wordEmbedding: NLEmbedding? = NLEmbedding.wordEmbedding(for: .english)
    private let dateDetector: NSDataDetector? = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
    
    private let englishStopwords: Set<String> = [
        "the", "a", "an", "is", "are", "was", "were", "be", "do", "does", "did",
        "have", "has", "had", "got", "i", "me", "my", "you", "your", "it", "its",
        "for", "with", "at", "by", "from", "up", "about", "into", "over", "after",
        "any", "some", "can", "could", "would", "should", "shall", "will", "on",
        "in", "to", "of", "and", "or", "but", "there", "then", "just", "what",
        "when", "where", "who", "how", "which", "why"
    ]
    
    private let politenessPrefixes = [
        "could you please ", "would you mind ", "can you please ", "can you ", "can we ",
        "i want to ", "i would like to ", "i'd like to ", "i need to ", "let's ",
        "help me ", "please ", "tell me ", "hey morph ", "morph ", "kindly "
    ]
    
    private let actionStarters = [
        "pause", "stop", "freeze", "halt", "resume", "play", "skip", "next",
        "previous", "prev", "back", "mute", "unmute", "silence", "shuffle",
        "clear", "empty", "dump", "wipe", "flush", "delete", "remove",
        "add", "schedule", "book", "note", "remember", "jot", "remind",
        "autofill", "fill", "paste", "set", "lock in", "deep work", "focus",
        "take five", "take 5", "clean up", "put on"
    ]
    
    public init() {}
    
    /// Evaluates any natural user prompt or conversational request like Siri AI,
    /// bounded strictly within Morph's features (Timer, Calendar, Music, Notes, Drop Shelf, Forms, Profile).
    /// Prompts are NEVER added to persistent memory.
    public func evaluate(query: String, model: NotchModel) -> MorphIntelligenceResult {
        let clean = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else {
            return fallbackNoAction(cleanQuery: clean)
        }
        
        // 1. Linguistic Tokenization & Lemmatization via NLTagger, NSDataDetector & Colloquial Normalizer
        let utterance = analyzeUtterance(clean)
        
        // 2. Score Semantic Proximity across Morph Domains via Vector Distance & Lemma Scoring
        let domainScores = computeDomainScores(utterance)
        let topDomainPair = domainScores.max(by: { $0.value < $1.value })
        let bestDomain = (topDomainPair?.value ?? 0) >= 0.70 ? topDomainPair?.key : nil
        
        let isDirectOrIndirectAction = isActionRequest(core: utterance.coreLower)
        
        // =========================================================================
        // STEP 1: DIRECT OR INDIRECT ACTION COMMANDS
        // (Even if phrased politely/indirectly: "could you please pause the timer", "can you skip this song")
        // =========================================================================
        if isDirectOrIndirectAction {
            if let actionResult = evaluateActions(utterance, bestDomain: bestDomain, model: model) {
                return actionResult
            }
        }
        
        // =========================================================================
        // STEP 2: EXPLICIT INTERROGATIVES & INQUIRIES
        // (Questions ending with '?' or starting with wh/aux words, or conversational inquiry cues)
        // =========================================================================
        if utterance.isInterrogative || hasQuestionIntent(utterance) {
            // Check Profile inquiries first ("who am i", "my role", "my status")
            if isProfileInquiry(utterance) {
                return answerProfileQuestion(model: model)
            }
            
            // Check System capability inquiries ("what can morph do", "how does drop shelf work")
            if isSystemInquiry(utterance) {
                return answerMorphSystemQuestion(utterance: utterance)
            }
            
            // Check domain-specific conversational questions
            if let targetDomain = bestDomain {
                return answerSpecificQuestion(domain: targetDomain, utterance: utterance, model: model)
            }
            
            // Out of boundary question (e.g. general trivia, math, weather) -> Siri AI boundary guide
            return fallbackNoAction(cleanQuery: clean)
        }
        
        // =========================================================================
        // STEP 3: DIRECT ACTION FALLBACK
        // (Fallback if not caught by explicit action starters)
        // =========================================================================
        if let actionResult = evaluateActions(utterance, bestDomain: bestDomain, model: model) {
            return actionResult
        }
        
        // =========================================================================
        // STEP 4: GENERAL NAVIGATIONAL COMMANDS
        // (Opening corresponding feature tabs, e.g. "open calendar", "music", "notes")
        // =========================================================================
        if let navDomain = evaluateNavigation(utterance, bestDomain: bestDomain) {
            return MorphIntelligenceResult(intentType: .general(targetState: navDomain.state))
        }
        
        // =========================================================================
        // STEP 5: NO ACTION FALLBACK (Siri AI polite boundary guidance + quick action pills)
        // =========================================================================
        return fallbackNoAction(cleanQuery: clean)
    }
    
    // MARK: - Siri AI Polite Boundary Guidance
    
    private func fallbackNoAction(cleanQuery: String) -> MorphIntelligenceResult {
        let msg: String
        if cleanQuery.isEmpty {
            msg = "I'm ready. You can ask me about your schedule, timer, music, notes, files, or forms."
        } else {
            msg = "I can help with your calendar, focus timer, music, notes, drop shelf, and forms on your Mac. Would you like to check today's schedule or start a focus session?"
        }
        
        return MorphIntelligenceResult(intentType: .noAction(
            message: msg,
            quickActions: [
                MorphQuickAction(title: "Focus 25", command: "focus 25", icon: "timer"),
                MorphQuickAction(title: "Schedule", command: "open calendar", icon: "calendar"),
                MorphQuickAction(title: "Drop Shelf", command: "open drop shelf", icon: "tray.and.arrow.down"),
                MorphQuickAction(title: "Next Song", command: "next song", icon: "forward.fill")
            ]
        ))
    }
    
    // MARK: - NLU Parsing & Semantic Scoring
    
    public func analyzeUtterance(_ text: String) -> MorphNLUTaggedUtterance {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var lower = clean.lowercased()
        
        // Normalize colloquial contractions
        lower = lower.replacingOccurrences(of: "wanna", with: "want to")
        lower = lower.replacingOccurrences(of: "gonna", with: "going to")
        lower = lower.replacingOccurrences(of: "gotta", with: "got to")
        
        // Strip conversational politeness prefixes for core intent matching
        var core = lower
        for prefix in politenessPrefixes {
            if core.hasPrefix(prefix) {
                core.removeFirst(prefix.count)
                break
            }
        }
        core = core.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Extract linguistic tokens, lemmas, and lexical parts of speech via Apple NLTagger
        let tagger = NLTagger(tagSchemes: [.lemma, .lexicalClass])
        tagger.string = clean
        
        var tokens: [String] = []
        var lemmas: [String] = []
        var lexicalClasses: [String: String] = [:]
        
        tagger.enumerateTags(in: clean.startIndex..<clean.endIndex, unit: .word, scheme: .lemma) { tag, range in
            let word = String(clean[range]).lowercased()
            if !word.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                tokens.append(word)
                let lemma = (tag?.rawValue ?? word).lowercased()
                lemmas.append(lemma)
            }
            return true
        }
        
        tagger.enumerateTags(in: clean.startIndex..<clean.endIndex, unit: .word, scheme: .lexicalClass) { tag, range in
            let word = String(clean[range]).lowercased()
            if let tagClass = tag?.rawValue {
                lexicalClasses[word] = tagClass
            }
            return true
        }
        
        // Interrogative detection: question mark, wh-word, auxiliary inversion, or inquiry cues
        let whStarters = ["what", "when", "where", "who", "how", "which", "why"]
        let auxStarters = ["is", "are", "am", "do", "does", "did", "can", "could", "will", "would", "have", "has", "got"]
        let firstWord = tokens.first ?? ""
        let isWh = whStarters.contains(firstWord) || lower.hasPrefix("what's") || lower.hasPrefix("whats") || lower.hasPrefix("who's") || lower.hasPrefix("how's")
        let isAux = auxStarters.contains(firstWord)
        let isInterrogative = lower.contains("?") || isWh || isAux
        
        // Dynamic duration extraction (supports "lock in for an hour", "take five", "45 mins", etc.)
        let durationMinutes = extractDuration(from: lower)
        
        // Date & temporal detection via Apple NSDataDetector
        var detectedDate: Date? = nil
        var strippedText = clean
        if let detector = dateDetector {
            let matches = detector.matches(in: clean, range: NSRange(location: 0, length: clean.utf16.count))
            if let firstMatch = matches.first, let d = firstMatch.date {
                detectedDate = d
                if let r = Range(firstMatch.range, in: clean) {
                    var mutable = clean
                    mutable.removeSubrange(r)
                    strippedText = mutable.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        
        return MorphNLUTaggedUtterance(
            raw: text,
            clean: clean,
            lower: lower,
            coreLower: core,
            tokens: tokens,
            lemmas: lemmas,
            lexicalClasses: lexicalClasses,
            lemmasSet: Set(lemmas),
            tokensSet: Set(tokens),
            isInterrogative: isInterrogative,
            detectedDurationMinutes: durationMinutes,
            detectedDate: detectedDate,
            cleanTextWithoutDate: strippedText
        )
    }
    
    private func isActionRequest(core: String) -> Bool {
        for starter in actionStarters {
            if core.hasPrefix(starter) {
                return true
            }
        }
        return false
    }
    
    public func computeDomainScores(_ u: MorphNLUTaggedUtterance) -> [MorphFeatureDomain: Double] {
        var scores: [MorphFeatureDomain: Double] = [:]
        for domain in MorphFeatureDomain.allCases {
            scores[domain] = 0.0
        }
        
        for domain in MorphFeatureDomain.allCases {
            var score = 0.0
            
            // 1. Direct keyword & lemma hits (weight +2.5 to +3.0)
            for lemma in u.lemmas {
                if domain.primaryKeywords.contains(lemma) {
                    score += 2.5
                }
            }
            
            for token in u.tokens {
                if domain.primaryKeywords.contains(token) {
                    score += 2.0
                }
            }
            
            // 2. Vector embedding proximity distance (filtered for non-stopwords, threshold 1.15)
            if let emb = wordEmbedding {
                let meaningfulTokens = u.tokens.filter { !englishStopwords.contains($0) && $0.count > 1 }
                for token in meaningfulTokens {
                    for anchor in domain.embeddingAnchors {
                        let distance = emb.distance(between: token, and: anchor)
                        if distance < 1.15 {
                            score += (1.15 - distance)
                        }
                    }
                }
            }
            
            scores[domain] = score
        }
        
        return scores
    }
    
    private func isProfileInquiry(_ u: MorphNLUTaggedUtterance) -> Bool {
        let l = u.lower
        if l.contains("who am i") || l.contains("who is logged in") || l.contains("who's logged in") || l.contains("signed in") || l.contains("who is signed in") {
            return true
        }
        if (l.contains("my") && (l.contains("email") || l.contains("name") || l.contains("role") || l.contains("status") || l.contains("account") || l.contains("profile"))) {
            return true
        }
        return false
    }
    
    private func isSystemInquiry(_ u: MorphNLUTaggedUtterance) -> Bool {
        let l = u.lower
        return l.contains("morph") || l.contains("how do i use") || l.contains("what can you do") || l.contains("features") || l.contains("capabilities")
    }
    
    // MARK: - Action Conduction
    
    private func evaluateActions(_ u: MorphNLUTaggedUtterance, bestDomain: MorphFeatureDomain?, model: NotchModel) -> MorphIntelligenceResult? {
        let l = u.lower
        let core = u.coreLower
        let lemmas = u.lemmasSet
        let tokens = u.tokensSet
        
        // ---------------------------------------------------------------------
        // 1. TIMER ACTIONS (Pause, Resume, Reset, Focus Duration, Break)
        // ---------------------------------------------------------------------
        
        // Explicit duration: "focus 25", "timer 15", "lock in for an hour", "take five", "start a 45 minute focus session"
        if let mins = u.detectedDurationMinutes, (lemmas.contains("focus") || lemmas.contains("timer") || lemmas.contains("pomodoro") || tokens.contains("start") || core.contains("lock in") || core.contains("take five") || core.contains("take 5") || core.contains("break")) {
            let clamped = max(1, min(180, mins))
            model.setGlassTimerMinutes(clamped)
            model.startGlassTimer()
            return MorphIntelligenceResult(intentType: .general(targetState: .timer))
        }
        
        // Pause timer: "pause timer", "stop focus", "freeze countdown", "halt timer", "hold up the timer", "could you please pause the timer"
        let isPauseVerb = lemmas.contains("pause") || lemmas.contains("stop") || lemmas.contains("freeze") || lemmas.contains("halt") || core.contains("hold up") || core.hasPrefix("pause") || core.hasPrefix("freeze")
        if isPauseVerb && (bestDomain == .timer || tokens.contains("timer") || tokens.contains("focus") || tokens.contains("countdown") || core.contains("timer") || core.contains("countdown")) {
            model.pauseGlassTimer()
            let secondsLeft = model.glassTimerLeft
            let minsLeft = secondsLeft / 60
            let remSecs = secondsLeft % 60
            let confirmation = "Focus timer paused with \(minsLeft)m \(remSecs)s remaining."
            return MorphIntelligenceResult(intentType: .actionExecuted(
                confirmation: confirmation,
                domain: "Focus Timer",
                icon: "pause.circle.fill",
                tintColorHex: model.featureTintColorHex(.timer),
                actionTitle: "Resume Timer",
                targetState: .timer
            ))
        }
        
        // Resume / unpause timer: "resume timer", "continue focus", "unpause countdown", "keep going"
        let isResumeVerb = lemmas.contains("resume") || lemmas.contains("continue") || lemmas.contains("unpause") || core.contains("keep going") || core.hasPrefix("resume") || core.hasPrefix("unpause")
        if isResumeVerb && (bestDomain == .timer || tokens.contains("timer") || tokens.contains("focus") || tokens.contains("countdown") || core.contains("timer")) {
            model.startGlassTimer()
            let secondsLeft = model.glassTimerLeft
            let minsLeft = secondsLeft / 60
            let remSecs = secondsLeft % 60
            let confirmation = "Focus timer resumed with \(minsLeft)m \(remSecs)s remaining."
            return MorphIntelligenceResult(intentType: .actionExecuted(
                confirmation: confirmation,
                domain: "Focus Timer",
                icon: "play.circle.fill",
                tintColorHex: model.featureTintColorHex(.timer),
                actionTitle: "Open Timer",
                targetState: .timer
            ))
        }
        
        // Reset timer: "reset timer", "restart focus", "clear timer"
        let isResetVerb = lemmas.contains("reset") || lemmas.contains("restart") || core.hasPrefix("reset")
        if isResetVerb && (bestDomain == .timer || tokens.contains("timer") || tokens.contains("focus")) {
            model.resetGlassTimer()
            let confirmation = "Focus timer reset to \(model.glassTimerMins) minutes."
            return MorphIntelligenceResult(intentType: .actionExecuted(
                confirmation: confirmation,
                domain: "Focus Timer",
                icon: "arrow.counterclockwise.circle.fill",
                tintColorHex: model.featureTintColorHex(.timer),
                actionTitle: "Start Focus",
                targetState: .timer
            ))
        }
        
        // ---------------------------------------------------------------------
        // 2. MUSIC ACTIONS (Pause, Play, Next, Previous, Mute, Shuffle)
        // ---------------------------------------------------------------------
        
        // Pause music: "pause music", "pause song", "stop music", bare "pause"
        if isPauseVerb && (bestDomain == .music || tokens.contains("music") || tokens.contains("song") || tokens.contains("track") || core == "pause" || core == "stop music" || core == "pause music") {
            if model.isGlassMusicPlaying {
                model.toggleGlassMusicPlay()
            }
            return MorphIntelligenceResult(intentType: .actionExecuted(
                confirmation: "Music playback paused.",
                domain: "Music Player",
                icon: "pause.fill",
                tintColorHex: model.featureTintColorHex(.music),
                actionTitle: "Resume Music",
                targetState: .music
            ))
        }
        
        // Play / resume music: "play music", "put on some tunes", "jam out", "resume music", bare "play"
        let isPlayVerb = lemmas.contains("play") || core.contains("put on") || core.contains("jam out") || core.hasPrefix("play")
        if (isPlayVerb || isResumeVerb) && (bestDomain == .music || tokens.contains("music") || tokens.contains("song") || tokens.contains("track") || tokens.contains("tunes") || core == "play" || core.contains("tunes")) {
            if !model.isGlassMusicPlaying {
                model.toggleGlassMusicPlay()
            }
            let title = model.media.trackTitle.isEmpty ? "YouTube Music" : model.media.trackTitle
            return MorphIntelligenceResult(intentType: .actionExecuted(
                confirmation: "Music playing: \"\(title)\".",
                domain: "Music Player",
                icon: "play.fill",
                tintColorHex: model.featureTintColorHex(.music),
                actionTitle: "Open Music",
                targetState: .music
            ))
        }
        
        // Next track: "next song", "skip", "next track", "skip track", "don't like this song", "skip this"
        let isNextVerb = lemmas.contains("next") || lemmas.contains("skip") || lemmas.contains("forward") || core.contains("don't like") || core.hasPrefix("skip")
        if isNextVerb && (bestDomain == .music || tokens.contains("music") || tokens.contains("song") || tokens.contains("track") || core == "skip" || core == "next" || core.contains("skip")) {
            model.skipGlassMusic(1)
            return MorphIntelligenceResult(intentType: .actionExecuted(
                confirmation: "Skipped to next track.",
                domain: "Music Player",
                icon: "forward.fill",
                tintColorHex: model.featureTintColorHex(.music),
                actionTitle: "Open Music",
                targetState: .music
            ))
        }
        
        // Previous track: "previous song", "prev song", "back song", "prev track", "go back"
        let isPrevVerb = lemmas.contains("previous") || tokens.contains("prev") || tokens.contains("back") || lemmas.contains("rewind") || core.hasPrefix("prev")
        if isPrevVerb && (bestDomain == .music || tokens.contains("music") || tokens.contains("song") || tokens.contains("track")) {
            model.skipGlassMusic(-1)
            return MorphIntelligenceResult(intentType: .actionExecuted(
                confirmation: "Skipped to previous track.",
                domain: "Music Player",
                icon: "backward.fill",
                tintColorHex: model.featureTintColorHex(.music),
                actionTitle: "Open Music",
                targetState: .music
            ))
        }
        
        // Mute / Unmute: "mute", "silence the music", "silence", "shh", "quiet down"
        if lemmas.contains("mute") || tokens.contains("mute") || core.contains("silence") || core == "shh" {
            if !model.media.isMuted {
                model.media.toggleMute()
            }
            return MorphIntelligenceResult(intentType: .actionExecuted(
                confirmation: "Music muted.",
                domain: "Music Player",
                icon: "speaker.slash.fill",
                tintColorHex: model.featureTintColorHex(.music),
                actionTitle: "Unmute",
                targetState: .music
            ))
        }
        
        if lemmas.contains("unmute") || tokens.contains("unmute") {
            if model.media.isMuted {
                model.media.toggleMute()
            }
            return MorphIntelligenceResult(intentType: .actionExecuted(
                confirmation: "Music unmuted.",
                domain: "Music Player",
                icon: "speaker.wave.2.fill",
                tintColorHex: model.featureTintColorHex(.music),
                actionTitle: "Open Music",
                targetState: .music
            ))
        }
        
        // Shuffle: "shuffle", "mix it up", "randomize playback"
        if lemmas.contains("shuffle") || tokens.contains("shuffle") || tokens.contains("randomize") || core.contains("mix it up") {
            model.media.toggleShuffle()
            let stateStr = model.media.isShuffle ? "turned on" : "turned off"
            return MorphIntelligenceResult(intentType: .actionExecuted(
                confirmation: "Music shuffle is now \(stateStr).",
                domain: "Music Player",
                icon: "shuffle",
                tintColorHex: model.featureTintColorHex(.music),
                actionTitle: "Open Music",
                targetState: .music
            ))
        }
        
        // ---------------------------------------------------------------------
        // 3. DROP SHELF ACTIONS (Clear, Copy Paths, AirDrop / Share)
        // ---------------------------------------------------------------------
        
        // Clear shelf: "clear shelf", "empty shelf", "dump the staged files", "clean up the clutter", "flush shelf"
        let isClearVerb = lemmas.contains("clear") || lemmas.contains("empty") || lemmas.contains("dump") || lemmas.contains("flush") || lemmas.contains("wipe") || core.contains("clean up") || core.hasPrefix("clear")
        if isClearVerb && (bestDomain == .drops || tokens.contains("shelf") || tokens.contains("staged") || core.contains("shelf") || (tokens.contains("files") && !tokens.contains("note"))) {
            let prevCount = model.dropShelf.count
            model.dropShelf.clearAll()
            let msg = prevCount > 0 ? "Drop Shelf cleared. \(prevCount) staged file\(prevCount == 1 ? "" : "s") removed." : "Drop Shelf is now empty."
            return MorphIntelligenceResult(intentType: .actionExecuted(
                confirmation: msg,
                domain: "Drop Shelf",
                icon: "trash",
                tintColorHex: model.featureTintColorHex(.drops),
                actionTitle: "Open Shelf",
                targetState: .drops
            ))
        }
        
        // Copy paths: "copy paths", "copy staged paths", "grab file paths", "clipboard paths"
        let isCopyVerb = lemmas.contains("copy") || tokens.contains("clipboard") || core.contains("grab file paths")
        if isCopyVerb && (bestDomain == .drops || tokens.contains("path") || tokens.contains("paths") || tokens.contains("shelf") || tokens.contains("files")) {
            let count = model.dropShelf.count
            if count > 0 {
                model.dropShelf.copyAllFilePaths()
                return MorphIntelligenceResult(intentType: .actionExecuted(
                    confirmation: "Copied \(count) staged file path\(count == 1 ? "" : "s") to your clipboard.",
                    domain: "Drop Shelf",
                    icon: "doc.on.doc",
                    tintColorHex: model.featureTintColorHex(.drops),
                    actionTitle: "Open Shelf",
                    targetState: .drops
                ))
            } else {
                return MorphIntelligenceResult(intentType: .actionExecuted(
                    confirmation: "Drop Shelf is empty. Drag files over the notch to stage them first.",
                    domain: "Drop Shelf",
                    icon: "tray.and.arrow.down",
                    tintColorHex: model.featureTintColorHex(.drops),
                    actionTitle: "Open Shelf",
                    targetState: .drops
                ))
            }
        }
        
        // Share / AirDrop: "share files", "airdrop files", "share staged", "dispatch files", "airdrop these"
        let isShareVerb = lemmas.contains("share") || tokens.contains("airdrop") || tokens.contains("dispatch")
        if isShareVerb && (bestDomain == .drops || tokens.contains("shelf") || tokens.contains("files") || tokens.contains("staged")) {
            let count = model.dropShelf.count
            if count > 0 {
                model.dropShelf.triggerShareAll()
                return MorphIntelligenceResult(intentType: .actionExecuted(
                    confirmation: "Opening share sheet for \(count) staged file\(count == 1 ? "" : "s").",
                    domain: "Drop Shelf",
                    icon: "square.and.arrow.up",
                    tintColorHex: model.featureTintColorHex(.drops),
                    actionTitle: "Open Shelf",
                    targetState: .drops
                ))
            } else {
                return MorphIntelligenceResult(intentType: .actionExecuted(
                    confirmation: "Drop Shelf is empty. Drag files over the notch to share them.",
                    domain: "Drop Shelf",
                    icon: "tray.and.arrow.down",
                    tintColorHex: model.featureTintColorHex(.drops),
                    actionTitle: "Open Shelf",
                    targetState: .drops
                ))
            }
        }
        
        // ---------------------------------------------------------------------
        // 4. NOTES ACTIONS (Delete Latest, Clear All, Create Note)
        // ---------------------------------------------------------------------
        
        // Delete latest note: "delete last note", "remove latest note", "throw away recent note"
        let isDeleteVerb = lemmas.contains("delete") || lemmas.contains("remove") || core.contains("throw away") || core.hasPrefix("delete")
        if isDeleteVerb && (bestDomain == .notes || tokens.contains("note") || tokens.contains("notes") || core.contains("note")) {
            if tokens.contains("all") || l.contains("clear notes") {
                let count = model.glassNotes.count
                model.glassNotes.removeAll()
                return MorphIntelligenceResult(intentType: .actionExecuted(
                    confirmation: count > 0 ? "Cleared all \(count) notes." : "Notes are already empty.",
                    domain: "Notes",
                    icon: "trash",
                    tintColorHex: model.featureTintColorHex(.notes),
                    actionTitle: "Open Notes",
                    targetState: .notes
                ))
            } else {
                if !model.glassNotes.isEmpty {
                    let removed = model.glassNotes.removeFirst()
                    return MorphIntelligenceResult(intentType: .actionExecuted(
                        confirmation: "Deleted latest note: “\(removed.title)”.",
                        domain: "Notes",
                        icon: "trash",
                        tintColorHex: model.featureTintColorHex(.notes),
                        actionTitle: "Open Notes",
                        targetState: .notes
                    ))
                } else {
                    return MorphIntelligenceResult(intentType: .actionExecuted(
                        confirmation: "You have no notes to delete.",
                        domain: "Notes",
                        icon: "doc.text",
                        tintColorHex: model.featureTintColorHex(.notes),
                        actionTitle: "Open Notes",
                        targetState: .notes
                    ))
                }
            }
        }
        
        // Create note: "note: ...", "remember ...", "jot down ...", "remind me to ...", "write a note ..."
        if let noteText = extractNotePayload(from: u) {
            let noteTitle = noteText.count > 26 ? String(noteText.prefix(26)).trimmingCharacters(in: .whitespacesAndNewlines) + "…" : noteText
            let n = GlassNote(title: noteTitle, body: noteText)
            model.glassNotes.insert(n, at: 0)
            return MorphIntelligenceResult(intentType: .actionExecuted(
                confirmation: "Saved note: “\(noteTitle)”.",
                domain: "Notes",
                icon: "doc.text.fill",
                tintColorHex: model.featureTintColorHex(.notes),
                actionTitle: "Open Notes",
                targetState: .notes
            ))
        }
        
        // ---------------------------------------------------------------------
        // 5. CALENDAR ACTIONS (Add Event, Schedule, Book)
        // ---------------------------------------------------------------------
        if let eventPayload = extractCalendarEventPayload(from: u) {
            model.calendar.addQuickEvent(title: eventPayload, durationMinutes: 30)
            return MorphIntelligenceResult(intentType: .actionExecuted(
                confirmation: "Added event “\(eventPayload)” to your calendar.",
                domain: "Calendar",
                icon: "calendar.badge.plus",
                tintColorHex: model.featureTintColorHex(.calendar),
                actionTitle: "Open Calendar",
                targetState: .calendar
            ))
        }
        
        // ---------------------------------------------------------------------
        // 6. FORM ASSISTANT ACTIONS (Autofill, Input Answer)
        // ---------------------------------------------------------------------
        if lemmas.contains("autofill") || l == "fill form" || l == "fill this form" || l == "fill" || core.contains("paste my info") || core.hasPrefix("autofill") {
            _ = model.formTracker.autofillActiveForm()
            return MorphIntelligenceResult(intentType: .general(targetState: .idle))
        }
        
        if (tokens.contains("input") && (tokens.contains("answer") || tokens.contains("question"))) || l == "fill question" || l == "fill this" {
            _ = model.formTracker.inputSavedAnswerForActiveQuestion()
            return MorphIntelligenceResult(intentType: .general(targetState: .idle))
        }
        
        // ---------------------------------------------------------------------
        // 7. PROFILE ACTIONS (Set Status)
        // ---------------------------------------------------------------------
        if let newStatus = extractStatusPayload(from: u) {
            model.supabase.currentUser.currentStatus = newStatus
            return MorphIntelligenceResult(intentType: .actionExecuted(
                confirmation: "Status updated to “\(newStatus)”.",
                domain: "Profile",
                icon: "person.crop.circle",
                tintColorHex: model.featureTintColorHex(.timer),
                actionTitle: "Edit Profile",
                targetState: .profile
            ))
        }
        
        return nil
    }
    
    // MARK: - Specific Question Answering (Siri AI Style)
    
    private func hasQuestionIntent(_ u: MorphNLUTaggedUtterance) -> Bool {
        let questionCues: Set<String> = [
            "check", "tell", "show", "find", "list", "how", "what", "when", "who", "where", "which"
        ]
        return !u.lemmasSet.isDisjoint(with: questionCues) || u.lower.contains("what's") || u.lower.contains("who's") || u.lower.contains("how's") || u.lower.contains("got any")
    }
    
    private func answerSpecificQuestion(domain: MorphFeatureDomain, utterance: MorphNLUTaggedUtterance, model: NotchModel) -> MorphIntelligenceResult {
        switch domain {
        case .calendar:
            return answerCalendarQuestion(utterance: utterance, model: model)
        case .drops:
            return answerDropShelfQuestion(model: model)
        case .timer:
            return answerTimerQuestion(model: model)
        case .music:
            return answerMusicQuestion(model: model)
        case .notes:
            return answerNotesQuestion(utterance: utterance, model: model)
        case .profile:
            return answerProfileQuestion(model: model)
        case .forms:
            return answerFormQuestion(model: model)
        case .system:
            return answerMorphSystemQuestion(utterance: utterance)
        }
    }
    
    // MARK: - Siri AI Conversational Synthesizers
    
    private func answerCalendarQuestion(utterance: MorphNLUTaggedUtterance, model: NotchModel) -> MorphIntelligenceResult {
        let calendar = model.calendar
        let cal = Calendar.current
        let now = Date()
        let upcoming = calendar.events.filter { $0.endTime > now }.sorted(by: { $0.startTime < $1.startTime })
        let todayEvents = calendar.events.filter { cal.isDate($0.startTime, inSameDayAs: now) }
        let currentEvent = calendar.events.first(where: { $0.startTime <= now && $0.endTime > now })
        
        let answer: String
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        
        if let current = currentEvent {
            let endTimeStr = current.isAllDay ? "end of day" : timeFormatter.string(from: current.endTime)
            let remMin = max(1, Int(current.endTime.timeIntervalSince(now) / 60))
            var text = "You're currently in \"\(current.title)\" until \(endTimeStr) (\(remMin)m remaining)."
            if upcoming.count > 1 {
                let next = upcoming[1]
                let nextTime = timeFormatter.string(from: next.startTime)
                text += " Up next: \"\(next.title)\" at \(nextTime)."
            }
            answer = text
        } else if let next = upcoming.first {
            let timeStr = next.isAllDay ? "All Day" : timeFormatter.string(from: next.startTime)
            let diffMins = Int(next.startTime.timeIntervalSince(now) / 60)
            
            let relText: String
            if next.isAllDay {
                relText = "today"
            } else if diffMins > 60 {
                let hours = diffMins / 60
                let remMins = diffMins % 60
                relText = remMins > 0 ? "in \(hours)h \(remMins)m" : "in \(hours)h"
            } else if diffMins > 0 {
                relText = "in \(diffMins)m"
            } else if diffMins == 0 {
                relText = "starting now"
            } else {
                relText = "happening now"
            }
            
            var text = "Your next event is \"\(next.title)\" at \(timeStr) (\(relText))."
            if todayEvents.count > 1 {
                text += " You have \(todayEvents.count) total events on your schedule today."
            }
            if next.meetLink != nil {
                text += " (Google Meet attached)"
            }
            answer = text
        } else if !todayEvents.isEmpty {
            answer = "You have completed all \(todayEvents.count) scheduled events for today! Your calendar is clear for the rest of the day."
        } else {
            answer = "You have no meetings or events scheduled for today. Your calendar is completely clear."
        }
        
        return MorphIntelligenceResult(intentType: .specific(
            answer: answer,
            domain: "Calendar",
            icon: "calendar",
            tintColorHex: model.featureTintColorHex(.calendar),
            actionTitle: "Open Calendar",
            targetState: .calendar
        ))
    }
    
    private func answerDropShelfQuestion(model: NotchModel) -> MorphIntelligenceResult {
        let shelf = model.dropShelf
        let count = shelf.count
        
        let answer: String
        if count > 0 {
            let names = shelf.stagedItems.prefix(3).map { $0.name }.joined(separator: ", ")
            let moreText = count > 3 ? " and \(count - 3) more" : ""
            answer = "You have \(count) staged file\(count == 1 ? "" : "s") on the Drop Shelf: \"\(names)\"\(moreText). Ready to drag out or share."
        } else {
            answer = "Your Drop Shelf is currently empty. Drag any file or document over the notch to stage it instantly without cluttering the search bar."
        }
        
        return MorphIntelligenceResult(intentType: .specific(
            answer: answer,
            domain: "Drop Shelf",
            icon: "tray.and.arrow.down",
            tintColorHex: model.featureTintColorHex(.drops),
            actionTitle: "Open Drop Shelf",
            targetState: .drops
        ))
    }
    
    private func answerTimerQuestion(model: NotchModel) -> MorphIntelligenceResult {
        let status = model.glassTimerStatus
        let secondsLeft = model.glassTimerLeft
        let minsLeft = secondsLeft / 60
        let remSecs = secondsLeft % 60
        let totalMins = model.glassTimerMins
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        let finishDate = Date().addingTimeInterval(TimeInterval(secondsLeft))
        let finishTimeStr = timeFormatter.string(from: finishDate)
        
        let answer: String
        switch status {
        case .running:
            answer = "Focus timer is currently running with \(minsLeft)m \(remSecs)s remaining out of your \(totalMins)m session (finishing at \(finishTimeStr))."
        case .paused:
            answer = "Focus timer is paused with \(minsLeft)m remaining."
        case .ready:
            answer = "Focus timer is ready for a \(totalMins)-minute focus session. Type \"focus 25\" to begin."
        case .done:
            answer = "Your focus session is completed! Great job."
        }
        
        return MorphIntelligenceResult(intentType: .specific(
            answer: answer,
            domain: "Focus Timer",
            icon: "timer",
            tintColorHex: model.featureTintColorHex(.timer),
            actionTitle: "Open Timer",
            targetState: .timer
        ))
    }
    
    private func answerMusicQuestion(model: NotchModel) -> MorphIntelligenceResult {
        let isPlaying = model.media.isPlaying
        let title = model.media.trackTitle
        let artist = model.media.artistName
        
        let answer: String
        if isPlaying {
            answer = "Currently playing \"\(title)\" by \(artist) on YouTube Music."
        } else if !title.isEmpty && title != "YouTube Music" {
            answer = "Music is currently paused. Last track: \"\(title)\" by \(artist)."
        } else {
            answer = "No music is currently playing. Open the Music tab to play from your library or quick picks."
        }
        
        return MorphIntelligenceResult(intentType: .specific(
            answer: answer,
            domain: "Music Player",
            icon: "music.note",
            tintColorHex: model.featureTintColorHex(.music),
            actionTitle: "Open Music",
            targetState: .music
        ))
    }
    
    private func answerNotesQuestion(utterance: MorphNLUTaggedUtterance, model: NotchModel) -> MorphIntelligenceResult {
        let notes = model.glassNotes
        
        if notes.isEmpty {
            return MorphIntelligenceResult(intentType: .specific(
                answer: "You haven't saved any notes yet. Type \"note: [your thoughts]\" to jot down an idea instantly.",
                domain: "Notes",
                icon: "doc.text",
                tintColorHex: model.featureTintColorHex(.notes),
                actionTitle: "Open Notes",
                targetState: .notes
            ))
        }
        
        let l = utterance.lower
        if l.contains("about") || l.contains("find") || l.contains("search") {
            let cleanedSearch = l
                .replacingOccurrences(of: "find note", with: "")
                .replacingOccurrences(of: "search notes", with: "")
                .replacingOccurrences(of: "about", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            if !cleanedSearch.isEmpty,
               let match = notes.first(where: { $0.title.localizedCaseInsensitiveContains(cleanedSearch) || $0.body.localizedCaseInsensitiveContains(cleanedSearch) }) {
                return MorphIntelligenceResult(intentType: .specific(
                    answer: "Found note \"\(match.title)\": \"\(match.body.prefix(100))\(match.body.count > 100 ? "…" : "")\".",
                    domain: "Notes",
                    icon: "doc.text",
                    tintColorHex: model.featureTintColorHex(.notes),
                    actionTitle: "Open Notes",
                    targetState: .notes
                ))
            }
        }
        
        let latest = notes[0]
        let answer = "You have \(notes.count) note\(notes.count == 1 ? "" : "s"). Latest: \"\(latest.title)\" (\(latest.body.prefix(80))\(latest.body.count > 80 ? "…" : ""))."
        return MorphIntelligenceResult(intentType: .specific(
            answer: answer,
            domain: "Notes",
            icon: "doc.text",
            tintColorHex: model.featureTintColorHex(.notes),
            actionTitle: "Open Notes",
            targetState: .notes
        ))
    }
    
    private func answerProfileQuestion(model: NotchModel) -> MorphIntelligenceResult {
        let user = model.supabase.currentUser
        let name = user.displayName
        let email = user.email.isEmpty ? "Local Explorer (No cloud sync)" : user.email
        let role = user.targetRole.isEmpty ? "Morph Explorer" : user.targetRole
        let status = user.currentStatus.isEmpty ? "Active" : user.currentStatus
        
        let answer = "You are signed in as \(name) (\(email)). Role: \(role), Status: \(status)."
        return MorphIntelligenceResult(intentType: .specific(
            answer: answer,
            domain: "Profile",
            icon: "person.crop.circle",
            tintColorHex: model.featureTintColorHex(.timer),
            actionTitle: "Edit Profile",
            targetState: .profile
        ))
    }
    
    private func answerFormQuestion(model: NotchModel) -> MorphIntelligenceResult {
        let tracker = model.formTracker
        let receiptsCount = model.supabase.formReceipts.count + tracker.savedFormCopies.count
        let isDetected = tracker.isFormDetected
        
        let answer: String
        if isDetected {
            let formTitle = !tracker.detectedFormTitle.isEmpty ? tracker.detectedFormTitle : (tracker.activeSession?.formTitle ?? "Active web/app form")
            answer = "A form is actively detected on screen: \"\(formTitle)\". 1-click autofill with your Morph profile is ready."
        } else {
            answer = "No form is currently detected on screen. Form Assistant has \(receiptsCount) saved receipt\(receiptsCount == 1 ? "" : "s") in memory."
        }
        
        return MorphIntelligenceResult(intentType: .specific(
            answer: answer,
            domain: "Form Assistant",
            icon: "list.bullet.clipboard",
            tintColorHex: model.featureTintColorHex(.forms),
            actionTitle: "Open Forms",
            targetState: .forms
        ))
    }
    
    private func answerMorphSystemQuestion(utterance: MorphNLUTaggedUtterance) -> MorphIntelligenceResult {
        let l = utterance.lower
        let answer: String
        if l.contains("drop shelf") || l.contains("shelf") {
            answer = "Drop Shelf lets you drag any files or clippings directly over the top notch. They stay staged in liquid glass ready to inspect, copy paths, or AirDrop, without cluttering the search bar."
        } else if l.contains("form") {
            answer = "Form Assistant automatically detects login & registration inputs on your screen to provide 1-click autofill with your profile data, working seamlessly in the background."
        } else {
            answer = "Morph is your macOS Dynamic Island with 6 integrated liquid glass tools: Focus Timer, Google Calendar, YouTube Music, Notes, Form Assistant, and Drop Shelf. Features trigger contextually or via the command bar."
        }
        
        return MorphIntelligenceResult(intentType: .specific(
            answer: answer,
            domain: "Morph",
            icon: "sparkles",
            tintColorHex: "#38bdf8",
            actionTitle: "Explore Profile",
            targetState: .profile
        ))
    }
    
    // MARK: - Navigation Evaluation
    
    private func evaluateNavigation(_ u: MorphNLUTaggedUtterance, bestDomain: MorphFeatureDomain?) -> MorphFeatureDomain? {
        let tokens = u.tokens
        let lemmas = u.lemmasSet
        let clean = u.clean.lowercased()
        
        let navVerbs: Set<String> = ["open", "show", "launch", "view"]
        let hasNavVerb = !lemmas.isDisjoint(with: navVerbs) || clean.hasPrefix("go to ") || clean.hasPrefix("switch to ")
        
        if let domain = bestDomain {
            if hasNavVerb {
                return domain
            }
            if tokens.count <= 2 {
                switch domain {
                case .calendar where tokens.contains("calendar") || tokens.contains("schedule") || tokens.contains("today"):
                    return .calendar
                case .timer where tokens.contains("timer") || tokens.contains("focus"):
                    return .timer
                case .music where tokens.contains("music") || tokens.contains("player"):
                    return .music
                case .notes where tokens.contains("notes") || tokens.contains("scratchpad"):
                    return .notes
                case .drops where tokens.contains("shelf") || tokens.contains("drops") || tokens.contains("dropshelf"):
                    return .drops
                case .forms where tokens.contains("forms") || tokens.contains("form"):
                    return .forms
                case .profile where tokens.contains("profile") || tokens.contains("settings"):
                    return .profile
                default:
                    break
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Parameter & Payload Extraction Helpers
    
    private func stripPolitenessFromClean(_ text: String) -> String {
        let lower = text.lowercased()
        for p in politenessPrefixes {
            if lower.hasPrefix(p) {
                let startIdx = text.index(text.startIndex, offsetBy: p.count)
                return String(text[startIdx...]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func extractDuration(from text: String) -> Int? {
        let lower = text.lowercased()
        
        if lower.contains("hour") || lower.contains("1 hr") || lower.contains("an hour") {
            return 60
        }
        if lower.contains("take five") || lower.contains("take 5") {
            return 5
        }
        if lower.contains("take ten") || lower.contains("take 10") {
            return 10
        }
        
        let patterns = [
            #"\b(?:lock\s+in|focus|timer|deep\s*work|work|session|break)\s+(?:for\s+)?(\d{1,3})\s*(?:min|mins|minute|minutes|m)?\b"#,
            #"\b(\d{1,3})\s*(?:min|mins|minute|minutes|m)\b"#,
            #"\b(\d{1,2})\s*(?:hr|hrs|hour|hours|h)\b"#
        ]
        
        for (idx, pattern) in patterns.enumerated() {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: lower, options: [], range: NSRange(location: 0, length: lower.utf16.count)),
               let r = Range(match.range(at: 1), in: lower),
               let num = Int(lower[r]) {
                if idx == 2 {
                    return num * 60
                }
                return num
            }
        }
        return nil
    }
    
    private func extractNotePayload(from u: MorphNLUTaggedUtterance) -> String? {
        let pattern = #"^(?:note|remember|jot|remind\s+me\s+(?:to|that)|write\s+(?:down|a\s+note))\s*[:\-]?\s*(.+)$"#
        for text in [u.clean, stripPolitenessFromClean(u.clean)] {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
               let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)),
               let r = Range(match.range(at: 1), in: text) {
                let body = String(text[r]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !body.isEmpty { return body }
            }
        }
        return nil
    }
    
    private func extractCalendarEventPayload(from u: MorphNLUTaggedUtterance) -> String? {
        let pattern = #"^(?:add\s+event|schedule|create\s+meeting|new\s+event|book(?:\s+time)?(?:\s+with|\s+for)?)\s+(.+)$"#
        for text in [u.clean, stripPolitenessFromClean(u.clean)] {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
               let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)),
               let r = Range(match.range(at: 1), in: text) {
                let candidate = String(text[r]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !candidate.isEmpty { return candidate }
            }
        }
        return nil
    }
    
    private func extractStatusPayload(from u: MorphNLUTaggedUtterance) -> String? {
        let pattern = #"^(?:set\s+(?:my\s+)?status\s+to|change\s+status\s+to|status\s*:)\s*(.+)$"#
        for text in [u.clean, stripPolitenessFromClean(u.clean)] {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
               let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)),
               let r = Range(match.range(at: 1), in: text) {
                let candidate = String(text[r]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !candidate.isEmpty { return candidate }
            }
        }
        return nil
    }
}
