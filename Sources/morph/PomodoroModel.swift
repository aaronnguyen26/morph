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
}

@MainActor
public final class PomodoroModel: ObservableObject {
    @Published public var mode: PomodoroMode = .work
    @Published public var timeRemaining: TimeInterval = 25 * 60
    @Published public var totalDuration: TimeInterval = 25 * 60
    @Published public var isRunning: Bool = false
    @Published public var isCompleted: Bool = false
    @Published public var completedSessionsCount: Int = 0
    
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
        totalDuration = newMode.defaultDuration
        timeRemaining = totalDuration
        isCompleted = false
        saveState()
    }
    
    public func setCustomDuration(minutes: Int) {
        pause()
        totalDuration = TimeInterval(minutes * 60)
        timeRemaining = totalDuration
        isCompleted = false
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
        if let savedMode = userDefaults.string(forKey: kModeKey),
           let parsedMode = PomodoroMode(rawValue: savedMode) {
            self.mode = parsedMode
        }
        let savedDuration = userDefaults.double(forKey: kTotalDurationKey)
        if savedDuration > 0 {
            self.totalDuration = savedDuration
        } else {
            self.totalDuration = self.mode.defaultDuration
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
