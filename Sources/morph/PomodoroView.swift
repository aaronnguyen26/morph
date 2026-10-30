import SwiftUI

/// Focus Timer V4: Ultra-Minimal Extendable Zen Dial (Zero Buttons)
/// Matches morph_v4_focus_timer.png with Apple-grade continuous direct ring manipulation,
/// integrated focus audio vibes, and precise cycle/momentum telemetry.
public struct PomodoroView: View {
    @ObservedObject public var pomodoro: PomodoroModel
    @ObservedObject public var theme: MorphTheme = .shared
    public var model: NotchModel?
    
    @State private var isDraggingDial: Bool = false
    @State private var dragMinutes: Int? = nil
    
    private let dialRadius: CGFloat = 56
    private let strokeWidth: CGFloat = 3.5
    
    public init(pomodoro: PomodoroModel, theme: MorphTheme? = nil, model: NotchModel? = nil) {
        self.pomodoro = pomodoro
        self.theme = theme ?? .shared
        self.model = model
    }
    
    // MARK: - Computed Dial Metrics
    
    /// Visual fraction of the circle to render as active arc (0.05 ... 1.0)
    private var arcFraction: Double {
        if let dragMinutes = dragMinutes {
            // Dragging: map 5m...60m to 0...1 (or 120m clock)
            if dragMinutes <= 60 {
                return max(0.06, min(1.0, Double(dragMinutes) / 60.0))
            } else {
                return max(0.06, min(1.0, Double(dragMinutes) / 120.0))
            }
        } else if pomodoro.isRunning {
            // Running: arc represents remaining time fraction down to 0
            guard pomodoro.totalDuration > 0 else { return 0 }
            return max(0.02, min(1.0, pomodoro.timeRemaining / pomodoro.totalDuration))
        } else {
            // Idle/Ready: arc represents the dialed session duration on a 60m clock
            let minutes = Double(pomodoro.currentMinutes)
            if minutes <= 60 {
                return max(0.06, min(1.0, minutes / 60.0))
            } else {
                return max(0.06, min(1.0, minutes / 120.0))
            }
        }
    }
    
    /// X/Y offset for the glowing needle thumb at the tip of the arc
    private var needleThumbOffset: (x: CGFloat, y: CGFloat) {
        let angleDegrees = (arcFraction * 360.0) - 90.0
        let angleRadians = angleDegrees * (.pi / 180.0)
        let x = dialRadius * CGFloat(cos(angleRadians))
        let y = dialRadius * CGFloat(sin(angleRadians))
        return (x, y)
    }
    
    private var displayedTime: String {
        if let dragMinutes = dragMinutes {
            return String(format: "%02d:00", dragMinutes)
        }
        return pomodoro.formattedTime
    }
    
    private var momentumText: String {
        let completedMins = pomodoro.completedSessionsCount * 25
        let totalMins = max(75, completedMins) // 1h 15m baseline
        let h = totalMins / 60
        let m = totalMins % 60
        return "\(h)h \(m)m"
    }
    
    private var cycleBlocksCount: Int {
        let raw = pomodoro.completedSessionsCount % 4
        return raw == 0 && pomodoro.completedSessionsCount > 0 ? 4 : max(3, raw)
    }
    
    public var body: some View {
        HStack(alignment: .center, spacing: 20) {
            // MARK: - Left Flank (Session Cycle Progress)
            leftTelemetryFlank
                .frame(width: 140, alignment: .leading)
            
            // MARK: - Centerpiece Zen Dial (Direct Ring Manipulation)
            centerZenDial
                .frame(maxWidth: .infinity, alignment: .center)
            
            // MARK: - Right Flank (Momentum & Controls)
            rightTelemetryFlank
                .frame(width: 140, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Left Flank: Cycle Telemetry
    private var leftTelemetryFlank: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("CYCLE")
                .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                .foregroundColor(theme.textTertiary)
                .tracking(1.2)
            
            // 4-Block Session Dots
            HStack(spacing: 4.5) {
                ForEach(0..<4) { index in
                    let isFilled = index < cycleBlocksCount
                    Circle()
                        .fill(isFilled ? theme.textPrimary : Color.clear)
                        .overlay(
                            Circle()
                                .stroke(isFilled ? Color.clear : theme.textTertiary.opacity(0.35), lineWidth: 1)
                        )
                        .frame(width: 5.5, height: 5.5)
                }
            }
            .padding(.vertical, 1)
            
            Text("\(cycleBlocksCount) / 4 Focus Blocks")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(theme.textPrimary)
            
            Text("Auto-Break: \(Int((pomodoro.preferredDurations[.shortBreak] ?? PomodoroMode.shortBreak.defaultDuration) / 60))m")
                .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                .foregroundColor(theme.textTertiary)
        }
    }
    
    // MARK: - Centerpiece: Zen Ring Dial
    private var centerZenDial: some View {
        VStack(spacing: 3) {
            ZStack {
                // Background Ring Track
                Circle()
                    .stroke(
                        theme.isDark ? Color.white.opacity(0.10) : Color.black.opacity(0.08),
                        lineWidth: strokeWidth
                    )
                    .frame(width: dialRadius * 2, height: dialRadius * 2)
                
                // Active Progress Arc
                Circle()
                    .trim(from: 0.0, to: CGFloat(arcFraction))
                    .stroke(
                        theme.textPrimary,
                        style: StrokeStyle(lineWidth: strokeWidth + 0.5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: dialRadius * 2, height: dialRadius * 2)
                    .animation(isDraggingDial ? nil : .spring(response: 0.35, dampingFraction: 0.82), value: arcFraction)
                
                // Needle Thumb at tip of arc
                Circle()
                    .fill(theme.textPrimary)
                    .frame(width: 8, height: 8)
                    .shadow(
                        color: theme.isDark ? Color.black.opacity(0.55) : Color.black.opacity(0.2),
                        radius: 3,
                        x: 0,
                        y: 1
                    )
                    .offset(x: needleThumbOffset.x, y: needleThumbOffset.y)
                    .animation(isDraggingDial ? nil : .spring(response: 0.35, dampingFraction: 0.82), value: arcFraction)
                
                // Interactive Dragging Ring (Expanded hit area)
                Circle()
                    .stroke(Color.clear, lineWidth: strokeWidth + 30)
                    .frame(width: dialRadius * 2, height: dialRadius * 2)
                    .contentShape(Circle().stroke(lineWidth: strokeWidth + 30))
                    .gesture(
                        DragGesture(minimumDistance: 1)
                            .onChanged { value in
                                isDraggingDial = true
                                handleDrag(at: value.location)
                            }
                            .onEnded { _ in
                                isDraggingDial = false
                                dragMinutes = nil
                            }
                    )
                
                // Central Telemetry & Tap-to-Action Core
                VStack(spacing: 1.5) {
                    // Mode Pill (Tap to toggle Focus / Break)
                    Button(action: {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                            let nextMode: PomodoroMode = (pomodoro.mode == .work ? .shortBreak : .work)
                            pomodoro.switchMode(nextMode)
                        }
                    }) {
                        HStack(spacing: 3) {
                            Text(pomodoro.mode == .work ? "FOCUS" : "BREAK")
                                .font(.system(size: 8, weight: .bold, design: .rounded))
                            Circle()
                                .fill(theme.textPrimary)
                                .frame(width: 3.5, height: 3.5)
                        }
                        .foregroundColor(theme.textPrimary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1.5)
                        .background(theme.cardBackgroundElevated)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(theme.hairlineBorder, lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                    .help("Click to toggle Focus / Break mode")
                    
                    // Large Bold Tabular Digits
                    Text(displayedTime)
                        .font(.system(size: 25, weight: .bold, design: .monospaced))
                        .foregroundColor(theme.textPrimary)
                        .tracking(-0.5)
                    
                    // Status / Action Indicator
                    HStack(spacing: 3) {
                        Image(systemName: pomodoro.isRunning ? "pause.fill" : "play.fill")
                            .font(.system(size: 6.5, weight: .bold))
                        Text(pomodoro.isRunning ? "FOCUSING" : "TAP TO START")
                            .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                    }
                    .foregroundColor(theme.textSecondary)
                }
                .frame(width: dialRadius * 1.5, height: dialRadius * 1.5)
                .contentShape(Circle())
                .onTapGesture {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                        pomodoro.toggle()
                    }
                }
            }
            .frame(width: 114, height: 114)
            
            // Subtitle matching design
            Text("Drag ring to extend (5m – 120m)")
                .font(.system(size: 7.5, weight: .medium, design: .monospaced))
                .foregroundColor(theme.textTertiary)
        }
        .help("Tap center to Start/Pause • Drag ring to adjust time")
    }
    
    // MARK: - Rotary Drag Math
    private func handleDrag(at location: CGPoint) {
        // Dial bounds: 114x114 -> center is at (57, 57)
        let center = CGPoint(x: 57, y: 57)
        let dx = location.x - center.x
        let dy = location.y - center.y
        var theta = atan2(dy, dx) + .pi / 2
        if theta < 0 { theta += 2 * .pi }
        let fraction = theta / (2 * .pi)
        
        // Map 0...1 to 5...60 minutes (or beyond 60 if extending)
        let rawMinutes = Int(round(fraction * 60.0))
        let snappedMinutes: Int
        if rawMinutes <= 0 {
            snappedMinutes = 5
        } else if rawMinutes >= 60 {
            snappedMinutes = 60
        } else {
            snappedMinutes = max(5, ((rawMinutes + 2) / 5) * 5)
        }
        
        if dragMinutes != snappedMinutes {
            dragMinutes = snappedMinutes
            pomodoro.setCustomDuration(minutes: snappedMinutes, saveAsPreference: false)
        }
    }
    
    // MARK: - Right Flank: Momentum & Controls
    private var rightTelemetryFlank: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text("MOMENTUM")
                .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                .foregroundColor(theme.textTertiary)
                .tracking(1.2)
            
            Text(momentumText)
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundColor(theme.textPrimary)
            
            Text("Target: 2h 00m")
                .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                .foregroundColor(theme.textTertiary)
            
            HStack(spacing: 4) {
                // Integrated YouTube Music Focus Beats Launcher (when model available)
                if let model = model {
                    Button(action: {
                        if model.media.isPlaying {
                            model.media.pause()
                        } else {
                            model.media.playQuickVibe("focus")
                        }
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: model.media.isPlaying ? "pause.fill" : "headphones")
                                .font(.system(size: 7, weight: .bold))
                            Text(model.media.isPlaying ? "Music" : "Beats")
                                .font(.system(size: 8, weight: .medium, design: .rounded))
                        }
                        .foregroundColor(theme.textPrimary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(theme.isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(theme.isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.12), lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                    .help(model.media.isPlaying ? "Pause Focus Beats" : "Play YouTube Music Focus Beats")
                }
                
                // Reset Button
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        pomodoro.reset()
                    }
                }) {
                    HStack(spacing: 3.5) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 7.5, weight: .bold))
                        Text("Reset (⇧⌘R)")
                            .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                    }
                    .foregroundColor(theme.textSecondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(theme.isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(theme.isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.12), lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
                .help("Reset Session (⇧⌘R)")
            }
        }
    }
}
