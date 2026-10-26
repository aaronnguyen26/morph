import SwiftUI
import Combine

public enum PomodoroMode: String, CaseIterable, Identifiable {
    case work = "Work"
    case shortBreak = "Short Break"
    case longBreak = "Long Break"
    
    public var id: String { rawValue }
    
    public var defaultDuration: TimeInterval {
        switch self {
        case .work: return 25 * 60
        case .shortBreak: return 5 * 60
        case .longBreak: return 15 * 60
        }
    }
    
    public var iconName: String {
        switch self {
        case .work: return "flame.fill"
        case .shortBreak: return "cup.and.saucer.fill"
        case .longBreak: return "leaf.fill"
        }
    }
    
    public var preferenceKey: String {
        switch self {
        case .work: return "MorphPomodoroWorkDuration"
        case .shortBreak: return "MorphPomodoroShortBreakDuration"
        case .longBreak: return "MorphPomodoroLongBreakDuration"
        }
    }
    
    public var defaultPresets: [Int] {
        switch self {
        case .work: return [25, 45, 50, 60]
        case .shortBreak: return [3, 5, 10, 15]
        case .longBreak: return [15, 20, 30, 45]
        }
    }
}

@MainActor
public final class PomodoroModel: ObservableObject {
    @Published public var mode: PomodoroMode = .work
    @Published public var timeRemaining: TimeInterval = 25 * 60
    @Published public var totalDuration: TimeInterval = 25 * 60
    @Published public var isRunning: Bool = false
    @Published public var isCompleted: Bool = false
    @Published public var completedSessionsCount: Int = 0
    @Published public var preferredDurations: [PomodoroMode: TimeInterval] = [:]
    
    private var timerCancellable: AnyCancellable?
    private let userDefaults = UserDefaults.standard
    
    private let kModeKey = "MorphPomodoroMode"
    private let kTimeRemainingKey = "MorphPomodoroTimeRemaining"
    private let kTotalDurationKey = "MorphPomodoroTotalDuration"
    private let kCompletedCountKey = "MorphPomodoroCompletedCount"
    
    public init() {
        restoreState()
    }
    
    public var formattedTime: String {
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    public var progress: Double {
        guard totalDuration > 0 else { return 0 }
        return max(0, min(1, 1.0 - (timeRemaining / totalDuration)))
    }
    
    public var currentMinutes: Int {
        return max(1, Int(round(totalDuration / 60.0)))
    }
    
    public var remainingMinutes: Int {
        return max(0, Int(ceil(timeRemaining / 60.0)))
    }
    
    public var currentPresets: [Int] {
        return mode.defaultPresets
    }
    
    public func preferredDuration(for targetMode: PomodoroMode) -> TimeInterval {
        if let custom = preferredDurations[targetMode], custom > 0 {
            return custom
        }
        let saved = userDefaults.double(forKey: targetMode.preferenceKey)
        if saved > 0 {
            preferredDurations[targetMode] = saved
            return saved
        }
        return targetMode.defaultDuration
    }
    
    public func setPreferredDuration(minutes: Int, for targetMode: PomodoroMode) {
        let clampedMinutes = max(1, min(180, minutes))
        let duration = TimeInterval(clampedMinutes * 60)
        preferredDurations[targetMode] = duration
        userDefaults.set(duration, forKey: targetMode.preferenceKey)
        
        if mode == targetMode {
            setCustomDuration(minutes: clampedMinutes, saveAsPreference: false)
        }
    }
    
    public func restoreDefaultDuration(for targetMode: PomodoroMode) {
        userDefaults.removeObject(forKey: targetMode.preferenceKey)
        preferredDurations[targetMode] = targetMode.defaultDuration
        if mode == targetMode {
            setCustomDuration(minutes: Int(targetMode.defaultDuration / 60), saveAsPreference: false)
        }
    }
    
    public func isUsingCustomPreference(for targetMode: PomodoroMode) -> Bool {
        let currentPref = preferredDuration(for: targetMode)
        return abs(currentPref - targetMode.defaultDuration) > 1.0
    }
    
    public func start() {
        guard !isRunning else { return }
        isRunning = true
        isCompleted = false
        
        timerCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.tick()
                }
            }
        saveState()
    }
    
    public func pause() {
        isRunning = false
        timerCancellable?.cancel()
        timerCancellable = nil
        saveState()
    }
    
    public func toggle() {
        if isRunning {
            pause()
        } else {
            start()
        }
    }
    
    public func reset() {
        pause()
        timeRemaining = totalDuration
        isCompleted = false
        saveState()
    }
    
    public func switchMode(_ newMode: PomodoroMode) {
        pause()
        mode = newMode
        totalDuration = preferredDuration(for: newMode)
        timeRemaining = totalDuration
        isCompleted = false
        saveState()
    }
    
    public func setCustomDuration(minutes: Int, saveAsPreference: Bool = true) {
        let clamped = max(1, min(180, minutes))
        pause()
        totalDuration = TimeInterval(clamped * 60)
        timeRemaining = totalDuration
        isCompleted = false
        if saveAsPreference {
            preferredDurations[mode] = totalDuration
            userDefaults.set(totalDuration, forKey: mode.preferenceKey)
        }
        saveState()
    }
    
    public func adjustTime(deltaMinutes: Int) {
        let deltaSeconds = TimeInterval(deltaMinutes * 60)
        let newRemaining = timeRemaining + deltaSeconds
        // Clamp remaining time between 10 seconds and 3 hours
        let clampedRemaining = max(10, min(180 * 60, newRemaining))
        timeRemaining = clampedRemaining
        if timeRemaining > totalDuration {
            totalDuration = timeRemaining
        }
        if isCompleted && timeRemaining > 0 {
            isCompleted = false
        }
        saveState()
    }
    
    private func tick() {
        if timeRemaining > 1 {
            timeRemaining -= 1
        } else {
            // Completed
            timeRemaining = 0
            pause()
            isCompleted = true
            if mode == .work {
                completedSessionsCount += 1
            }
            saveState()
        }
    }
    
    private func saveState() {
        userDefaults.set(mode.rawValue, forKey: kModeKey)
        userDefaults.set(timeRemaining, forKey: kTimeRemainingKey)
        userDefaults.set(totalDuration, forKey: kTotalDurationKey)
        userDefaults.set(completedSessionsCount, forKey: kCompletedCountKey)
    }
    
    private func restoreState() {
        // Load per-mode preferences
        for m in PomodoroMode.allCases {
            let saved = userDefaults.double(forKey: m.preferenceKey)
            if saved > 0 {
                preferredDurations[m] = saved
            } else {
                preferredDurations[m] = m.defaultDuration
            }
        }
        
        if let savedMode = userDefaults.string(forKey: kModeKey),
           let parsedMode = PomodoroMode(rawValue: savedMode) {
            self.mode = parsedMode
        }
        
        let savedDuration = userDefaults.double(forKey: kTotalDurationKey)
        if savedDuration > 0 {
            self.totalDuration = savedDuration
        } else {
            self.totalDuration = self.preferredDuration(for: self.mode)
        }
        
        let savedRemaining = userDefaults.double(forKey: kTimeRemainingKey)
        if savedRemaining > 0 && savedRemaining <= self.totalDuration {
            self.timeRemaining = savedRemaining
        } else {
            self.timeRemaining = self.totalDuration
        }
        self.completedSessionsCount = userDefaults.integer(forKey: kCompletedCountKey)
    }
}
