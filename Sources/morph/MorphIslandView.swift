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
            return 28
        } else if model.isCompactActive {
            return 20
        } else {
            return 18 // Visually distinct, generous smooth curvature matching physical MacBook notch
        }
    }
    
    private var topRadius: CGFloat {
        if model.isExpanded {
            return 28
        } else if !model.hasPhysicalNotch {
            return cornerRadius
        } else {
            return 0
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
                    topLeadingRadius: topRadius,
                    bottomLeadingRadius: cornerRadius,
                    bottomTrailingRadius: cornerRadius,
                    topTrailingRadius: topRadius,
                    style: .continuous
                )
                .fill(Color.black)
                .overlay(
                    // Notch Border Edges: Hairline border matching physical MacBook notch contour
                    UnevenRoundedRectangle(
                        topLeadingRadius: topRadius,
                        bottomLeadingRadius: cornerRadius,
                        bottomTrailingRadius: cornerRadius,
                        topTrailingRadius: topRadius,
                        style: .continuous
                    )
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(model.isExpanded ? 0.20 : 0.28),
                                Color.white.opacity(model.isExpanded ? 0.08 : 0.16)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
                )
                .shadow(
                    color: model.isExpanded ? Color.black.opacity(0.65) : Color.black.opacity(0.3),
                    radius: model.isExpanded ? 24 : 8,
                    x: 0,
                    y: model.isExpanded ? 10 : 4
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
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: topRadius,
                    bottomLeadingRadius: cornerRadius,
                    bottomTrailingRadius: cornerRadius,
                    topTrailingRadius: topRadius,
                    style: .continuous
                )
            )
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
    
    // MARK: - 1. Idle Flush Notch View (Smooth border radius, no sharp corners)
    private var idleFlushNotchView: some View {
        HStack {
            Spacer()
            // Ambient micro indicator
            Circle()
                .fill(Color.white.opacity(0.18))
                .frame(width: 3.5, height: 3.5)
            Spacer()
        }
        .frame(width: model.idleWidth, height: model.idleHeight)
        .contentShape(Rectangle())
    }
    
    // MARK: - 2. Compact Active Notch View (Dynamic Island extending below & around camera notch)
    private var compactActiveNotchView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Left Wing: Outside camera notch, 100% visible to user!
                HStack(spacing: 6) {
                    if model.pomodoro.isRunning {
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 2)
                                .frame(width: 14, height: 14)
                            
                            Circle()
                                .trim(from: 0, to: CGFloat(model.pomodoro.progress))
                                .stroke(Color(red: 0.2, green: 0.9, blue: 0.6), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                                .frame(width: 14, height: 14)
                        }
                        
                        Text(model.pomodoro.formattedTime)
                            .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    } else if model.media.isPlaying {
                        HStack(spacing: 5) {
                            if let art = model.media.albumArtURL, let url = URL(string: art) {
                                AsyncImage(url: url) { phase in
                                    if let img = phase.image {
                                        img.resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 17, height: 17)
                                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                                    } else {
                                        Image(systemName: "music.note")
                                            .font(.system(size: 9.5, weight: .bold))
                                            .foregroundColor(.cyan)
                                    }
                                }
                            } else {
                                Image(systemName: "music.note")
                                    .font(.system(size: 9.5, weight: .bold))
                                    .foregroundColor(.cyan)
                            }
                            
                            Text(model.media.trackTitle.isEmpty ? "Playing" : model.media.trackTitle)
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .frame(maxWidth: 82, alignment: .leading)
                        }
                    }
                }
                .padding(.leading, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Center: Blind spot spacer matching hardware camera cutout
                Color.clear
                    .frame(width: model.idleWidth, height: model.idleHeight)
                
                // Right Wing: Outside camera notch, 100% visible to user!
                HStack(spacing: 6) {
                    if model.media.isPlaying {
                        HStack(alignment: .bottom, spacing: 2) {
                            ForEach(0..<4, id: \.self) { i in
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(red: 0.4, green: 0.9, blue: 1.0), Color.white],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .frame(width: 2.2, height: max(3, 13 * model.media.visualizerBars[i % 3]))
                                    .animation(.easeOut(duration: 0.1), value: model.media.visualizerBars[i % 3])
                            }
                        }
                        .frame(height: 13, alignment: .bottom)
                        
                        Circle()
                            .fill(Color.white.opacity(0.75))
                            .frame(width: 4, height: 4)
                    } else if model.pomodoro.isRunning {
                        Text(model.pomodoro.mode == .work ? "FOCUS" : "BREAK")
                            .font(.system(size: 8.5, weight: .heavy, design: .rounded))
                            .foregroundColor(Color.white.opacity(0.9))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2.5)
                            .background(Color.white.opacity(0.14))
                            .clipShape(Capsule())
                    }
                }
                .padding(.trailing, 12)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .frame(height: model.idleHeight)
            
            // Bottom Shelf: Sits directly BELOW the camera notch (100% visible to user!)
            HStack(spacing: 6) {
                if model.pomodoro.isRunning && model.media.isPlaying {
                    Text("FOCUS • \(model.pomodoro.formattedTime)")
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.85))
                    Text("•")
                        .foregroundColor(Color.white.opacity(0.3))
                        .font(.system(size: 7))
                    Text(model.media.trackTitle.isEmpty ? "Audio" : model.media.trackTitle)
                        .font(.system(size: 8.5, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.7))
                        .lineLimit(1)
                } else if model.media.isPlaying {
                    Text(model.media.artistName.isEmpty ? "YouTube Music Active" : model.media.artistName)
                        .font(.system(size: 8.5, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.7))
                        .lineLimit(1)
                } else if model.pomodoro.isRunning {
                    Text("Deep Focus active • Hover to expand")
                        .font(.system(size: 8.5, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.7))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: model.compactHeight - model.idleHeight)
            .padding(.bottom, 2)
        }
        .frame(width: model.compactWidth, height: model.compactHeight)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                model.isExpanded = true
            }
        }
    }
    
    // MARK: - 3. Expanded Island View (640 x 300 pt)
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
                HStack(spacing: 3.5) {
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
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                            .foregroundColor(model.selectedTab == tab ? .black : Color.white.opacity(0.6))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3.5)
                            .background(
                                model.selectedTab == tab
                                    ? Color.white
                                    : Color.white.opacity(0.08)
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
