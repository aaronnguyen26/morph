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
        model.isExpanded ? 22 : 12
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
                .fill(Color(red: 0.04, green: 0.04, blue: 0.06))
                .overlay(
                    // Subtle ambient radial glow when expanded
                    RadialGradient(
                        colors: [
                            model.selectedAccent.color.opacity(model.isExpanded ? 0.16 : 0.0),
                            Color.clear
                        ],
                        center: .top,
                        startRadius: 5,
                        endRadius: model.isExpanded ? 240 : 40
                    )
                )
                .overlay(
                    // Border stroke (visible when expanded, subtle when idle)
                    UnevenRoundedRectangle(
                        topLeadingRadius: 0,
                        bottomLeadingRadius: cornerRadius,
                        bottomTrailingRadius: cornerRadius,
                        topTrailingRadius: 0,
                        style: .continuous
                    )
                    .stroke(
                        model.isExpanded
                            ? LinearGradient(
                                colors: [
                                    Color.white.opacity(0.18),
                                    model.selectedAccent.color.opacity(0.4),
                                    Color.white.opacity(0.08)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [Color.clear, Color.clear],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                        lineWidth: 1
                    )
                )
                .shadow(
                    color: model.isExpanded
                        ? model.selectedAccent.color.opacity(0.25)
                        : Color.clear,
                    radius: model.isExpanded ? 20 : 0,
                    x: 0,
                    y: model.isExpanded ? 8 : 0
                )
                
                // Content: Idle Notch vs Expanded Island
                if model.isExpanded {
                    expandedView
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .top)),
                            removal: .opacity
                        ))
                } else {
                    idleFlushNotchView
                        .transition(.opacity)
                }
            }
            .frame(width: currentWidth, height: currentHeight, alignment: .top)
            .animation(.spring(response: 0.35, dampingFraction: 0.78), value: model.isExpanded)
            .animation(.spring(response: 0.3, dampingFraction: 0.78), value: model.selectedTab)
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
    
    // MARK: - Idle Flush Notch View (179 x 32 pt, 100% Flush, Never Sticking Out)
    private var idleFlushNotchView: some View {
        Color.black
            .frame(width: model.idleWidth, height: model.idleHeight)
            .contentShape(Rectangle())
    }
    
    // MARK: - Expanded Island View (460 x 175 pt)
    private var expandedView: some View {
        VStack(spacing: 6) {
            // Top Navigation Bar
            topNavigationBar
            
            // Active Tab Workspace / Home Hub
            ZStack {
                switch model.selectedTab {
                case .home:
                    HomeView(model: model)
                        .transition(.asymmetric(insertion: .opacity, removal: .opacity))
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
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .frame(width: model.expandedWidth, height: model.expandedHeight, alignment: .top)
    }
    
    // MARK: - Top Navigation Bar
    private var topNavigationBar: some View {
        HStack(alignment: .center, spacing: 8) {
            // Brand Logo or Back to Home Button
            if model.selectedTab != .home {
                Button(action: {
                    model.returnToHome()
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 9, weight: .bold))
                        Text("Home")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(model.selectedAccent.color)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(model.selectedAccent.color.opacity(0.15))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            } else {
                HStack(spacing: 5) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(model.selectedAccent.color)
                    
                    Text("MORPH")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .tracking(1.2)
                }
            }
            
            Spacer()
            
            // Four Navigation Tabs: [Home] [Focus] [Music] [Notes]
            HStack(spacing: 3) {
                ForEach(MorphTab.allCases) { tab in
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            model.selectedTab = tab
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: tab.iconName)
                                .font(.system(size: 8.5))
                            Text(tab.rawValue)
                                .font(.system(size: 9.5, weight: model.selectedTab == tab ? .bold : .medium))
                        }
                        .foregroundColor(model.selectedTab == tab ? .white : Color.white.opacity(0.55))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
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
                    .font(.system(size: 9.5))
                    .foregroundColor(model.isPinned ? model.selectedAccent.color : Color.white.opacity(0.5))
                    .frame(width: 20, height: 20)
                    .background(model.isPinned ? model.selectedAccent.color.opacity(0.2) : Color.white.opacity(0.06))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help(model.isPinned ? "Unpin Island" : "Pin Island Open")
            
            // Collapse Button
            Button(action: {
                model.isPinned = false
                model.isExpanded = false
            }) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 9, weight: .bold))
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
