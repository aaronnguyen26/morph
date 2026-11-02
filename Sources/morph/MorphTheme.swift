import SwiftUI
import AppKit
import Combine

/// Tactile trackpad haptic feedback engine for macOS Force Touch trackpads.
/// Automatically suppresses hardware actuator calls when running inside the test suite
/// while recording invocation counts for deterministic verification.
@MainActor
public enum MorphHaptics {
    public static private(set) var lastPerformedFeedbackCount: Int = 0
    
    public static func resetTestCounter() {
        lastPerformedFeedbackCount = 0
    }
    
    /// Subtle detent click for rotary dial increments, scrubbers, and alignment snaps.
    public static func alignment() {
        lastPerformedFeedbackCount += 1
        guard !MorphEnvironment.isTestingEnvironment else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
    }
    
    /// Distinct tactile step for tab transitions, mode changes, and pin toggles.
    public static func levelChange() {
        lastPerformedFeedbackCount += 1
        guard !MorphEnvironment.isTestingEnvironment else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .default)
    }
    
    /// Crisp confirmation tap for completed actions, clipboard copies, and mascot impulses.
    public static func generic() {
        lastPerformedFeedbackCount += 1
        guard !MorphEnvironment.isTestingEnvironment else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
    }
}

/// Supported appearance modes for Morph.
public enum MorphThemeMode: String, CaseIterable, Identifiable {
    case dark = "Dark"
    case light = "Light"
    case system = "System"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .dark: return "moon.fill"
        case .light: return "sun.max.fill"
        case .system: return "circle.lefthalf.filled"
        }
    }
}

/// Central design system theme provider for Morph, synthesizing Apple macOS Sequoia
/// precision glassmorphism and Google Material 3 tonal elevation across Dark Obsidian
/// and Light Ceramic modes.
@MainActor
public final class MorphTheme: ObservableObject {
    public static let shared = MorphTheme()
    
    private let kThemeModeKey = "MorphThemeMode"
    
    @Published public var mode: MorphThemeMode {
        didSet {
            UserDefaults.standard.set(mode.rawValue, forKey: kThemeModeKey)
            updateEffectiveAppearance()
        }
    }
    
    @Published public private(set) var isDark: Bool = true
    
    private var cancellables = Set<AnyCancellable>()
    
    public init() {
        let saved = UserDefaults.standard.string(forKey: kThemeModeKey)
        let initialMode = saved.flatMap(MorphThemeMode.init(rawValue:)) ?? .dark
        self.mode = initialMode
        updateEffectiveAppearance()
        observeSystemThemeChanges()
    }
    
    public func toggleTheme() {
        if isDark {
            mode = .light
        } else {
            mode = .dark
        }
        MorphHaptics.levelChange()
    }
    
    public func setMode(_ newMode: MorphThemeMode) {
        mode = newMode
    }
    
    private func updateEffectiveAppearance() {
        switch mode {
        case .dark:
            isDark = true
        case .light:
            isDark = false
        case .system:
            if let appearance = NSApp?.effectiveAppearance ?? NSAppearance.currentDrawing() as NSAppearance? {
                isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            } else {
                isDark = true
            }
        }
    }
    
    private func observeSystemThemeChanges() {
        DistributedNotificationCenter.default().publisher(for: Notification.Name("AppleInterfaceThemeChangedNotification"))
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self, self.mode == .system else { return }
                self.updateEffectiveAppearance()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Semantic Color System
    
    /// Canvas root background for the expanded notch island
    public var canvasBackground: Color {
        isDark ? Color(red: 0.031, green: 0.031, blue: 0.039) // #08080A Obsidian
               : Color(red: 0.965, green: 0.965, blue: 0.976) // #F6F6F9 Alabaster Ceramic
    }
    
    /// Secondary container background
    public var canvasSecondary: Color {
        isDark ? Color(red: 0.071, green: 0.071, blue: 0.082) // #121215
               : Color(red: 0.935, green: 0.935, blue: 0.950)
    }
    
    /// Standard card / panel surface
    public var cardBackground: Color {
        isDark ? Color.white.opacity(0.08)
               : Color.black.opacity(0.05)
    }
    
    /// Apple Liquid Glass material background
    public var liquidGlassBackground: Color {
        isDark ? Color.black.opacity(0.72)
               : Color.white.opacity(0.68)
    }
    
    /// Apple Liquid Glass card surface
    public var liquidGlassCard: Color {
        isDark ? Color.white.opacity(0.08)
               : Color.white.opacity(0.65)
    }
    
    /// Apple Liquid Glass hairline specular dual-stop gradient
    public var liquidGlassSpecularBorder: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(isDark ? 0.38 : 0.65),
                Color.white.opacity(isDark ? 0.12 : 0.25),
                Color.white.opacity(isDark ? 0.04 : 0.10),
                Color.white.opacity(isDark ? 0.20 : 0.40)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// Subtle card surface for secondary controls
    public var cardBackgroundSubtle: Color {
        isDark ? Color.white.opacity(0.05)
               : Color.black.opacity(0.035)
    }
    
    /// Elevated surface for focused / hovered elements
    public var cardBackgroundElevated: Color {
        isDark ? Color.white.opacity(0.14)
               : Color.black.opacity(0.09)
    }
    
    /// Specular perimeter hairline border
    public var hairlineBorder: Color {
        isDark ? Color.white.opacity(0.10)
               : Color.black.opacity(0.10)
    }
    
    /// Inset separator hairline
    public var hairlineSubtle: Color {
        isDark ? Color.white.opacity(0.05)
               : Color.black.opacity(0.06)
    }
    
    /// Active element perimeter highlight
    public var activeBorder: Color {
        isDark ? Color.white.opacity(0.28)
               : Color.black.opacity(0.25)
    }
    
    /// Primary high-contrast text
    public var textPrimary: Color {
        isDark ? Color.white
               : Color(red: 0.07, green: 0.07, blue: 0.09)
    }
    
    /// Secondary descriptive text
    public var textSecondary: Color {
        isDark ? Color.white.opacity(0.68)
               : Color(red: 0.07, green: 0.07, blue: 0.09).opacity(0.72)
    }
    
    /// Tertiary / placeholder / unit label text
    public var textTertiary: Color {
        isDark ? Color.white.opacity(0.38)
               : Color(red: 0.07, green: 0.07, blue: 0.09).opacity(0.52)
    }
    
    /// Active pill button fill
    public var activePillBackground: Color {
        isDark ? Color.white
               : Color(red: 0.08, green: 0.08, blue: 0.10)
    }
    
    /// Active pill button text
    public var activePillText: Color {
        isDark ? Color.black
               : Color.white
    }
    
    /// Inactive pill button fill
    public var inactivePillBackground: Color {
        isDark ? Color.white.opacity(0.08)
               : Color.black.opacity(0.06)
    }
    
    /// Inactive pill button text
    public var inactivePillText: Color {
        isDark ? Color.white.opacity(0.70)
               : Color(red: 0.07, green: 0.07, blue: 0.09).opacity(0.70)
    }
    
    /// Progress ring background circular track
    public var dialTrack: Color {
        isDark ? Color.white.opacity(0.10)
               : Color.black.opacity(0.08)
    }
    
    /// Focus Mode accent: Pure monochrome high contrast (White in Dark, Black in Light)
    public var focusAccent: Color {
        isDark ? Color.white : Color(red: 0.08, green: 0.08, blue: 0.10)
    }
    
    /// Short Break Mode accent: High-density silver (Silver-white in Dark, Charcoal in Light)
    public var shortBreakAccent: Color {
        isDark ? Color(white: 0.85) : Color(white: 0.25)
    }
    
    /// Long Break Mode accent: Mid-tone silver
    public var longBreakAccent: Color {
        isDark ? Color(white: 0.72) : Color(white: 0.38)
    }
    
    /// Mode accent dynamic resolver
    public func accentColor(for pomodoroMode: PomodoroMode) -> Color {
        switch pomodoroMode {
        case .work: return focusAccent
        case .shortBreak: return shortBreakAccent
        case .longBreak: return longBreakAccent
        }
    }
    
    /// Ambient window shadow color
    public var windowShadow: Color {
        isDark ? Color.black.opacity(0.65)
               : Color.black.opacity(0.16)
    }
    
    /// High-contrast monochromatic border for active drag-and-drop targets
    public var dropTargetBorder: Color {
        isDark ? Color.white.opacity(0.68)
               : Color.black.opacity(0.45)
    }
    
    /// Subtle monochromatic ambient bloom for active drag-and-drop targets
    public var dropTargetGlow: Color {
        isDark ? Color.white.opacity(0.22)
               : Color.black.opacity(0.12)
    }
    
    /// Monochromatic badge surface for status pills and extension tags
    public var badgeBackground: Color {
        isDark ? Color.white.opacity(0.14)
               : Color.black.opacity(0.08)
    }
    
    /// High-legibility monochromatic badge label color
    public var badgeText: Color {
        isDark ? Color.white.opacity(0.92)
               : Color(red: 0.07, green: 0.07, blue: 0.09).opacity(0.92)
    }
    
    /// Interactive hover highlight surface
    public var elevatedHoverBackground: Color {
        isDark ? Color.white.opacity(0.18)
               : Color.black.opacity(0.12)
    }
    
    /// Crisp focus ring border for active text inputs and command palettes
    public var focusRingBorder: Color {
        isDark ? Color.white.opacity(0.42)
               : Color.black.opacity(0.36)
    }
    
    /// Recessed well background for text editors and search inputs
    public var surfaceInset: Color {
        isDark ? Color.black.opacity(0.38)
               : Color.black.opacity(0.04)
    }
}
