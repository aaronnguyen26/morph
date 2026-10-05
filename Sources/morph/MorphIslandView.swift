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
        if model.isExpanded {
            return 26
        } else if model.isCompactActive {
            return 11
        } else {
            return 10 // Exact smooth curvature blending with physical notch
        }
    }
    
    // Notch blind-spot geometry
    private var notchBlindWidth: CGFloat {
        max(model.idleWidth + 10, 185)
    }
    
    private var notchBlindHeight: CGFloat {
        max(model.idleHeight + 2, 34)
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                // Background Base Shape: Pure OLED Black with Notch Contour
                UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: cornerRadius,
                    bottomTrailingRadius: cornerRadius,
                    topTrailingRadius: 0,
                    style: .continuous
                )
                .fill(Color.black)
                .overlay(
                    // Notch Border Edges: Hairline border matching physical MacBook notch contour
                    // Active even before the app is open so it blends seamlessly into the notch
                    UnevenRoundedRectangle(
                        topLeadingRadius: 0,
                        bottomLeadingRadius: cornerRadius,
                        bottomTrailingRadius: cornerRadius,
                        topTrailingRadius: 0,
                        style: .continuous
                    )
                    .stroke(
                        Color.white.opacity(model.isExpanded ? 0.14 : 0.12),
                        lineWidth: 1
                    )
                )
                .shadow(
                    color: model.isExpanded ? Color.black.opacity(0.6) : Color.clear,
                    radius: model.isExpanded ? 24 : 0,
                    x: 0,
                    y: model.isExpanded ? 10 : 0
                )
                
                // Content: Idle / Compact Notch vs Expanded Island
                if model.isExpanded {
                    expandedView
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .top)),
                            removal: .opacity
                        ))
                } else if model.isCompactActive {
                    compactActiveNotchView
                        .transition(.opacity)
                } else {
                    idleFlushNotchView
                        .transition(.opacity)
                }
            }
            .frame(width: currentWidth, height: currentHeight, alignment: .top)
            .animation(.spring(response: 0.35, dampingFraction: 0.78), value: model.isExpanded)
            .animation(.spring(response: 0.35, dampingFraction: 0.78), value: model.isCompactActive)
            .animation(.spring(response: 0.3, dampingFraction: 0.78), value: model.selectedTab)
            
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
    
    // MARK: - 1. Idle Flush Notch View (Blends into physical notch with rounded border edge)
    private var idleFlushNotchView: some View {
        Color.black
            .frame(width: model.idleWidth, height: model.idleHeight)
            .contentShape(Rectangle())
    }
    
    // MARK: - 2. Compact Active Notch View (Displays on the notch itself when timer/music active)
    private var compactActiveNotchView: some View {
        HStack(spacing: 0) {
            // Left Wing: Timer countdown & micro progress ring
            HStack(spacing: 4) {
                if model.pomodoro.isRunning {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.18), lineWidth: 1.8)
                            .frame(width: 11, height: 11)
                        
                        Circle()
                            .trim(from: 0, to: CGFloat(model.pomodoro.progress))
                            .stroke(Color.white, style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .frame(width: 11, height: 11)
                    }
                    
                    Text(model.pomodoro.formattedTime)
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
            }
            .padding(.leading, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Center: Black spacer matching hardware webcam cutout
            Color.clear
                .frame(width: model.idleWidth, height: model.idleHeight)
            
            // Right Wing: Live 3-bar animated audio visualizer
            HStack(spacing: 3) {
                if model.media.isPlaying {
                    HStack(alignment: .bottom, spacing: 2) {
                        ForEach(0..<3, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(Color.white.opacity(0.85))
                                .frame(width: 2, height: max(3, 10 * model.media.visualizerBars[i]))
                                .animation(.easeOut(duration: 0.1), value: model.media.visualizerBars[i])
                        }
                    }
                    .frame(height: 10, alignment: .bottom)
                }
            }
            .padding(.trailing, 8)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(width: model.compactWidth, height: model.idleHeight)
        .contentShape(Rectangle())
    }
    
    // MARK: - 3. Expanded Island View (580 x 240 pt)
    private var expandedView: some View {
        VStack(spacing: 4) {
            // Top Notch Row: Wings on Left/Right, Empty Center Blind Spot for Hardware Notch
            topNotchRow
                .frame(height: notchBlindHeight)
            
            // Main Feature Body: Sits completely BELOW the notch blind spot!
            ZStack {
                switch model.selectedTab {
                case .home:
                    HomeView(model: model)
                        .transition(.asymmetric(insertion: .opacity, removal: .opacity))
                case .timer:
                    PomodoroView(pomodoro: model.pomodoro)
                        .transition(.asymmetric(insertion: .opacity, removal: .opacity))
                case .music:
                    MediaView(media: model.media)
                        .transition(.asymmetric(insertion: .opacity, removal: .opacity))
                case .notes:
                    ScratchpadView(scratchpad: model.scratchpad)
                        .transition(.asymmetric(insertion: .opacity, removal: .opacity))
                }
            }
            .frame(maxHeight: .infinity)
        }
        .padding(.horizontal, 14)
        .padding(.top, 4)
        .padding(.bottom, 10)
        .frame(width: model.expandedWidth, height: model.expandedHeight, alignment: .top)
    }
    
    // MARK: - Top Notch Row (Wings visible, Center completely empty)
    private var topNotchRow: some View {
        HStack(spacing: 0) {
            // LEFT WING (Outside Notch: 100% Visible)
            HStack(spacing: 6) {
                if model.selectedTab != .home {
                    Button(action: {
                        model.returnToHome()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 9, weight: .bold))
                            Text("Home")
                                .font(.system(size: 10.5, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                } else {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(Color.white.opacity(0.8))
                            .frame(width: 5, height: 5)
                        
                        Text("MORPH")
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                            .tracking(1.4)
                    }
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // CENTER BLIND SPOT: Sits directly beneath hardware camera notch.
            // MUST BE KEPT COMPLETELY CLEAR OF ANY TEXT OR FEATURES!
            Color.clear
                .frame(width: notchBlindWidth, height: notchBlindHeight)
            
            // RIGHT WING (Outside Notch: 100% Visible)
            HStack(spacing: 5) {
                Spacer()
                
                // Tabs
                HStack(spacing: 3) {
                    ForEach(MorphTab.allCases) { tab in
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                model.selectedTab = tab
                            }
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: tab.iconName)
                                    .font(.system(size: 8.5))
                                Text(tab.rawValue)
                                    .font(.system(size: 9.5, weight: model.selectedTab == tab ? .bold : .medium))
                            }
                            .foregroundColor(model.selectedTab == tab ? .black : Color.white.opacity(0.55))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3.5)
                            .background(
                                model.selectedTab == tab
                                    ? Color.white
                                    : Color.white.opacity(0.06)
                            )
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                // Pin Button
                Button(action: {
                    model.togglePin()
                }) {
                    Image(systemName: model.isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 9.5))
                        .foregroundColor(model.isPinned ? .white : Color.white.opacity(0.5))
                        .frame(width: 22, height: 22)
                        .background(model.isPinned ? Color.white.opacity(0.25) : Color.white.opacity(0.06))
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
                        .frame(width: 22, height: 22)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Collapse to notch")
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}
