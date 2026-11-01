import SwiftUI
import AppKit

/// Captures two-finger vertical trackpad scroll wheel events over the Zen Dial
/// without obstructing SwiftUI tap or rotary drag gestures.
struct DialScrollWheelCatcher: NSViewRepresentable {
    var onScrollStep: (Int) -> Void
    
    func makeNSView(context: Context) -> ScrollWheelCatcherNSView {
        let view = ScrollWheelCatcherNSView()
        view.onScrollStep = onScrollStep
        return view
    }
    
    func updateNSView(_ nsView: ScrollWheelCatcherNSView, context: Context) {
        nsView.onScrollStep = onScrollStep
    }
    
    final class ScrollWheelCatcherNSView: NSView {
        var onScrollStep: ((Int) -> Void)?
        private var accumulatedDeltaY: CGFloat = 0
        private var localMonitor: Any?
        
        override func hitTest(_ point: NSPoint) -> NSView? {
            return nil
        }
        
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let monitor = localMonitor {
                NSEvent.removeMonitor(monitor)
                localMonitor = nil
            }
            guard window != nil else { return }
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel]) { [weak self] event in
                guard let self = self, let win = self.window, event.window == win else {
                    return event
                }
                let locInView = self.convert(event.locationInWindow, from: nil)
                if self.bounds.contains(locInView) {
                    self.scrollWheel(with: event)
                }
                return event
            }
        }
        
        override func removeFromSuperview() {
            if let monitor = localMonitor {
                NSEvent.removeMonitor(monitor)
                localMonitor = nil
            }
            super.removeFromSuperview()
        }
        
        override func scrollWheel(with event: NSEvent) {
            let delta = event.scrollingDeltaY != 0 ? event.scrollingDeltaY : event.deltaY
            guard abs(delta) > 0.05 else { return }
            
            if event.hasPreciseScrollingDeltas {
                accumulatedDeltaY += delta
                let threshold: CGFloat = 12.0
                if abs(accumulatedDeltaY) >= threshold {
                    let step = accumulatedDeltaY > 0 ? 5 : -5
                    accumulatedDeltaY = 0
                    onScrollStep?(step)
                }
            } else {
                let step = delta > 0 ? 5 : -5
                onScrollStep?(step)
            }
        }
    }
}

/// Focus Timer V4: Ultra-Minimal Extendable Zen Dial
/// Matches morph_v4_focus_timer.png with Apple-grade continuous direct ring manipulation,
/// two-finger scroll wheel adjustment, quick presets, and authentic cycle/momentum telemetry.
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
    
    /// Visual fraction of the circle to render as active arc (0.04 ... 1.0 on a 120m clock)
    private var arcFraction: Double {
        if let dragMinutes = dragMinutes {
            return max(0.04, min(1.0, Double(dragMinutes) / 120.0))
        } else if pomodoro.isRunning {
            // Running: arc represents remaining time fraction down to 0
            guard pomodoro.totalDuration > 0 else { return 0 }
            return max(0.02, min(1.0, pomodoro.timeRemaining / pomodoro.totalDuration))
        } else {
            // Idle/Ready: arc represents the dialed session duration on a 120m clock
            let minutes = Double(pomodoro.currentMinutes)
            return max(0.04, min(1.0, minutes / 120.0))
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
            let hours = dragMinutes / 60
            let mins = dragMinutes % 60
            if hours > 0 {
                return String(format: "%d:%02d:00", hours, mins)
            } else {
                return String(format: "%02d:00", dragMinutes)
            }
        }
        return pomodoro.formattedTime
    }
    
    private var currentElapsedMins: Int {
        guard pomodoro.mode == .work, pomodoro.totalDuration > pomodoro.timeRemaining else {
            return 0
        }
        return max(0, Int((pomodoro.totalDuration - pomodoro.timeRemaining) / 60.0))
    }
    
    private var momentumText: String {
        let completedMins = pomodoro.completedSessionsCount * 25
        let totalMins = max(SupabaseService.shared.currentUser.totalFocusMinutes, completedMins) + currentElapsedMins
        let h = totalMins / 60
        let m = totalMins % 60
        return "\(h)h \(m)m"
    }
    
    private var cycleBlocksCount: Int {
        let raw = pomodoro.completedSessionsCount % 4
        return (raw == 0 && pomodoro.completedSessionsCount > 0) ? 4 : raw
    }
    
    private var modePillLabel: String {
        switch pomodoro.mode {
        case .work: return "FOCUS"
        case .shortBreak: return "BREAK"
        case .longBreak: return "LONG"
        }
    }
    
    private var nextModeInCycle: PomodoroMode {
        switch pomodoro.mode {
        case .work: return .shortBreak
        case .shortBreak: return .longBreak
        case .longBreak: return .work
        }
    }
    
    public var body: some View {
        HStack(alignment: .center, spacing: 20) {
            // MARK: - Left Flank (Session Cycle Progress & Presets)
            leftCycleFlank
                .frame(width: 145, alignment: .leading)
            
            // MARK: - Centerpiece Zen Dial (Direct Ring Manipulation)
            centerZenDial
                .frame(maxWidth: .infinity, alignment: .center)
            
            // MARK: - Right Flank (Momentum & Controls)
            rightMomentumFlank
                .frame(width: 145, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Left Flank: Cycle Telemetry & Quick Presets
    private var leftCycleFlank: some View {
        VStack(alignment: .leading, spacing: 4.5) {
            Text("CYCLE")
                .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                .foregroundColor(theme.textTertiary)
                .tracking(1.2)
            
            // 4-Block Session Dots (Highlights active in-progress block when running)
            HStack(spacing: 5) {
                ForEach(0..<4, id: \.self) { index in
                    let isFilled = index < cycleBlocksCount
                    let isActiveBlock = pomodoro.isRunning && pomodoro.mode == .work && index == (pomodoro.completedSessionsCount % 4)
                    Circle()
                        .fill(isFilled ? theme.textPrimary : (isActiveBlock ? theme.textSecondary : Color.clear))
                        .overlay(
                            Circle()
                                .stroke(
                                    isFilled || isActiveBlock ? theme.textPrimary : theme.textTertiary.opacity(0.4),
                                    lineWidth: isActiveBlock ? 1.25 : 1
                                )
                        )
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.vertical, 1)
            
            Text("\(cycleBlocksCount) / 4 Focus Blocks")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(theme.textPrimary)
            
            // Quick Duration Presets
            HStack(spacing: 3.5) {
                ForEach(pomodoro.currentPresets, id: \.self) { preset in
                    let isSelected = pomodoro.currentMinutes == preset && !pomodoro.isRunning
                    Button(action: {
                        MorphHaptics.alignment()
                        withAnimation(.spring(response: 0.26, dampingFraction: 0.8)) {
                            pomodoro.setCustomDuration(minutes: preset, saveAsPreference: true)
                        }
                    }) {
                        Text("\(preset)m")
                            .font(.system(size: 8, weight: isSelected ? .bold : .semibold, design: .monospaced))
                            .foregroundColor(isSelected ? theme.activePillText : theme.textSecondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(isSelected ? theme.activePillBackground : theme.cardBackground)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(theme.hairlineBorder, lineWidth: 0.5)
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Set \(preset) minute duration")
                }
            }
            .padding(.top, 2)
        }
    }
    
    // MARK: - Centerpiece: Zen Ring Dial
    private var centerZenDial: some View {
        VStack(spacing: 3) {
            ZStack {
                // Background Ring Track
                Circle()
                    .stroke(
                        theme.dialTrack,
                        lineWidth: strokeWidth
                    )
                    .frame(width: dialRadius * 2, height: dialRadius * 2)
                
                // Active Progress Arc
                Circle()
                    .trim(from: 0.0, to: CGFloat(arcFraction))
                    .stroke(
                        theme.accentColor(for: pomodoro.mode),
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
                
                // Two-Finger Scroll Wheel Catcher overlaid quietly on the Zen Dial
                DialScrollWheelCatcher { delta in
                    MorphHaptics.alignment()
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
                        pomodoro.adjustTime(deltaMinutes: delta > 0 ? 5 : -5)
                    }
                }
                .frame(width: 114, height: 114)
                
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
                    // Mode Pill (Tap to cycle Focus -> Short Break -> Long Break -> Focus)
                    Button(action: {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                            pomodoro.switchMode(nextModeInCycle)
                        }
                    }) {
                        HStack(spacing: 3) {
                            Text(modePillLabel)
                                .font(.system(size: 8, weight: .bold, design: .rounded))
                            Circle()
                                .fill(theme.accentColor(for: pomodoro.mode))
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
                    .help("Click to cycle Focus / Short Break / Long Break")
                    
                    // Large Bold Tabular Digits
                    Text(displayedTime)
                        .font(.system(size: displayedTime.count > 5 ? 20 : 25, weight: .bold, design: .monospaced))
                        .foregroundColor(theme.textPrimary)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
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
            Text("Drag ring or scroll to adjust")
                .font(.system(size: 7.5, weight: .medium, design: .monospaced))
                .foregroundColor(theme.textTertiary)
        }
        .help("Tap center to Start/Pause • Drag ring or scroll to adjust time")
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
        
        // Map 0...1 to 5...120 minutes (up to 2 hours) in 5m steps
        let rawMinutes = Int(round(fraction * 120.0))
        let snappedMinutes: Int
        if rawMinutes <= 0 {
            snappedMinutes = 5
        } else if rawMinutes >= 120 {
            snappedMinutes = 120
        } else {
            snappedMinutes = max(5, ((rawMinutes + 2) / 5) * 5)
        }
        
        if snappedMinutes != pomodoro.currentMinutes {
            MorphHaptics.alignment()
        }
        
        if dragMinutes != snappedMinutes {
            dragMinutes = snappedMinutes
            pomodoro.setCustomDuration(minutes: snappedMinutes, saveAsPreference: false)
        }
    }
    
    // MARK: - Right Flank: Momentum & Controls
    private var rightMomentumFlank: some View {
        VStack(alignment: .trailing, spacing: 4.5) {
            Text("MOMENTUM")
                .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                .foregroundColor(theme.textTertiary)
                .tracking(1.2)
            
            Text(momentumText)
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundColor(theme.textPrimary)
            
            HStack(spacing: 6) {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        pomodoro.reset()
                    }
                }) {
                    Text("Reset (⇧⌘R)")
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundColor(theme.textTertiary)
                        .underline(true, color: theme.textTertiary.opacity(0.4))
                }
                .buttonStyle(.plain)
                .help("Reset Session (⇧⌘R)")
                
                Text("•")
                    .font(.system(size: 8))
                    .foregroundColor(theme.textTertiary.opacity(0.4))
                
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        pomodoro.switchMode(nextModeInCycle)
                    }
                }) {
                    Text("Skip (⇧⌘S)")
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundColor(theme.textTertiary)
                        .underline(true, color: theme.textTertiary.opacity(0.4))
                }
                .buttonStyle(.plain)
                .help("Skip Session / Break (⇧⌘S)")
            }
        }
    }
}
