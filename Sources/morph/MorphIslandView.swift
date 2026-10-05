import SwiftUI

public struct MorphIslandView: View {
    @ObservedObject var model: NotchModel
    var onMouseEnter: () -> Void
    var onMouseExit: () -> Void
    
    public init(model: NotchModel, onMouseEnter: @escaping () -> Void, onMouseExit: @escaping () -> Void) {
        self.model = model
        self.onMouseEnter = onMouseEnter
        self.onMouseExit = onMouseExit
    }
    
    private var currentWidth: CGFloat {
        model.currentWidth
    }
    
    private var currentHeight: CGFloat {
        model.currentHeight
    }
    
    private var cornerRadius: CGFloat {
        switch model.currentDisplayState {
        case .idle: return 12
        case .pill: return 18
        case .expanded: return 22
        }
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                // Background Base Shape
                UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: cornerRadius,
                    bottomTrailingRadius: cornerRadius,
                    topTrailingRadius: 0,
                    style: .continuous
                )
                .fill(Color(red: 0.05, green: 0.05, blue: 0.07))
                .overlay(
                    // Ambient radial glow
                    RadialGradient(
                        colors: [
                            model.selectedAccent.color.opacity(model.isExpanded ? 0.16 : 0.08),
                            Color.clear
                        ],
                        center: .top,
                        startRadius: 5,
                        endRadius: model.isExpanded ? 240 : 80
                    )
                )
                .overlay(
                    // Border stroke
                    UnevenRoundedRectangle(
                        topLeadingRadius: 0,
                        bottomLeadingRadius: cornerRadius,
                        bottomTrailingRadius: cornerRadius,
                        topTrailingRadius: 0,
                        style: .continuous
                    )
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.18),
                                model.selectedAccent.color.opacity(model.isExpanded ? 0.45 : 0.25),
                                Color.white.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                )
                .shadow(
                    color: model.isExpanded
                        ? model.selectedAccent.color.opacity(0.25)
                        : (model.pomodoro.isCompleted ? Color(red: 0.2, green: 0.9, blue: 0.55).opacity(0.4) : Color.black.opacity(0.4)),
                    radius: model.isExpanded ? 20 : 8,
                    x: 0,
                    y: model.isExpanded ? 8 : 2
                )
                
                // Content based on Display State
                switch model.currentDisplayState {
                case .expanded:
                    expandedView
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .top)),
                            removal: .opacity
                        ))
                case .pill:
                    activePillView
                        .transition(.opacity)
                case .idle:
                    idleNotchView
                        .transition(.opacity)
                }
            }
            .frame(width: currentWidth, height: currentHeight, alignment: .top)
            .animation(.spring(response: 0.35, dampingFraction: 0.78), value: model.currentDisplayState)
            .animation(.spring(response: 0.35, dampingFraction: 0.78), value: model.selectedTab)
            .animation(.easeInOut(duration: 0.2), value: model.selectedAccent)
            
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onHover { hovering in
            if hovering {
                onMouseEnter()
            } else {
                onMouseExit()
            }
        }
    }
    
    // MARK: - 1. Idle Notch View (179 x 32 pt)
    private var idleNotchView: some View {
        HStack {
            Circle()
                .fill(model.selectedAccent.color)
                .frame(width: 4, height: 4)
                .padding(.leading, 12)
            
            Spacer()
            
            Text("MORPH")
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .foregroundColor(Color.white.opacity(0.35))
                .tracking(1.2)
            
            Spacer()
            
            Circle()
                .fill(Color.white.opacity(0.2))
                .frame(width: 4, height: 4)
                .padding(.trailing, 12)
        }
        .frame(width: model.idleWidth, height: model.idleHeight)
    }
    
    // MARK: - 2. Active Pill View (300 x 44 pt)
    private var activePillView: some View {
        HStack(spacing: 0) {
            // Left Wing: Pomodoro Status (Width ~55 pt)
            HStack(spacing: 5) {
                // Mini countdown ring or flame icon
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.15), lineWidth: 2)
                        .frame(width: 14, height: 14)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(model.pomodoro.progress))
                        .stroke(
                            model.pomodoro.isCompleted ? Color(red: 0.2, green: 0.9, blue: 0.55) : model.selectedAccent.color,
                            style: StrokeStyle(lineWidth: 2, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 14, height: 14)
                    
                    if model.pomodoro.isRunning {
                        Circle()
                            .fill(model.selectedAccent.color)
                            .frame(width: 4, height: 4)
                    }
                }
                
                Text(model.pomodoro.formattedTime)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(model.pomodoro.isCompleted ? Color(red: 0.2, green: 0.9, blue: 0.55) : .white)
            }
            .frame(width: 55, alignment: .leading)
            .padding(.leading, 12)
            
            // Center Cutout Spacer (Hardware Notch Baseline ~179 pt)
            Spacer()
                .frame(minWidth: model.idleWidth - 10)
            
            // Right Wing: Audio Visualizer & Media State (Width ~55 pt)
            HStack(spacing: 5) {
                if model.media.isMuted {
                    Image(systemName: "speaker.slash.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.red)
                } else {
                    // Live 3-Bar Equalizer
                    HStack(alignment: .bottom, spacing: 2.5) {
                        ForEach(0..<3, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(model.selectedAccent.color)
                                .frame(width: 2.5, height: max(3, 14 * model.media.visualizerBars[i]))
                                .animation(.easeOut(duration: 0.1), value: model.media.visualizerBars[i])
                        }
                    }
                    .frame(height: 14, alignment: .bottom)
                }
                
                Image(systemName: model.media.isPlaying ? "play.circle.fill" : "pause.circle.fill")
                    .font(.system(size: 10))
                    .foregroundColor(Color.white.opacity(0.6))
            }
            .frame(width: 55, alignment: .trailing)
            .padding(.trailing, 12)
        }
        .frame(width: model.pillWidth, height: model.pillHeight)
        .contentShape(Rectangle())
    }
    
    // MARK: - 3. Expanded Island View (440 x 140 pt)
    private var expandedView: some View {
        VStack(spacing: 6) {
            // Top Navigation & Control Bar
            topNavigationBar
            
            // Main Feature Body (440 x 140 pt ratio)
            ZStack {
                switch model.selectedTab {
                case .timer:
                    PomodoroView(pomodoro: model.pomodoro, accentColor: model.selectedAccent.color)
                        .transition(.asymmetric(insertion: .opacity, removal: .opacity))
                case .music:
                    MediaView(media: model.media, accentColor: model.selectedAccent.color)
                        .transition(.asymmetric(insertion: .opacity, removal: .opacity))
                case .notes:
                    ScratchpadView(scratchpad: model.scratchpad, accentColor: model.selectedAccent.color)
                        .transition(.asymmetric(insertion: .opacity, removal: .opacity))
                }
            }
            .frame(maxHeight: .infinity)
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .frame(width: model.expandedWidth, height: model.expandedHeight, alignment: .top)
    }
    
    // MARK: - Top Navigation Bar
    private var topNavigationBar: some View {
        HStack(alignment: .center, spacing: 8) {
            // Brand Logo & Title
            HStack(spacing: 5) {
                Image(systemName: "sparkles")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(model.selectedAccent.color)
                
                Text("MORPH")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .tracking(1.2)
            }
            
            Spacer()
            
            // Three Feature Navigation Tabs
            HStack(spacing: 4) {
                ForEach(MorphTab.allCases) { tab in
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            model.selectedTab = tab
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: tab.iconName)
                                .font(.system(size: 9))
                            Text(tab.rawValue)
                                .font(.system(size: 10, weight: model.selectedTab == tab ? .bold : .medium))
                        }
                        .foregroundColor(model.selectedTab == tab ? .white : Color.white.opacity(0.55))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3.5)
                        .background(
                            model.selectedTab == tab
                                ? model.selectedAccent.color.opacity(0.28)
                                : Color.white.opacity(0.06)
                        )
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Spacer()
            
            // Pin Toggle Button
            Button(action: {
                model.togglePin()
            }) {
                Image(systemName: model.isPinned ? "pin.fill" : "pin")
                    .font(.system(size: 10))
                    .foregroundColor(model.isPinned ? model.selectedAccent.color : Color.white.opacity(0.5))
                    .frame(width: 20, height: 20)
                    .background(model.isPinned ? model.selectedAccent.color.opacity(0.2) : Color.white.opacity(0.06))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help(model.isPinned ? "Unpin Window" : "Pin Window Open")
            
            // Collapse Button
            Button(action: {
                model.isPinned = false
                model.isExpanded = false
            }) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.6))
                    .frame(width: 20, height: 20)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Collapse to notch")
        }
    }
}
