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
                    // Luxury dark ambient background texture
                    backgroundImageView
                        .clipShape(
                            UnevenRoundedRectangle(
                                topLeadingRadius: topRadius,
                                bottomLeadingRadius: cornerRadius,
                                bottomTrailingRadius: cornerRadius,
                                topTrailingRadius: topRadius,
                                style: .continuous
                            )
                        )
                )
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
            .contentShape(Rectangle())
            .onHover { hovering in
                if hovering {
                    onMouseEnter()
                } else {
                    onMouseExit()
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.78), value: model.isExpanded)
            .animation(.spring(response: 0.35, dampingFraction: 0.78), value: model.isCompactActive)
            .animation(.spring(response: 0.3, dampingFraction: 0.78), value: model.selectedTab)
            
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
    
    // MARK: - 2. Compact Active Notch View (Independent Dynamic Island HUD)
    private var compactActiveNotchView: some View {
        VStack(spacing: 0) {
            // Top Notch Row: Wings on Left/Right, Empty Center Blind Spot for Hardware Notch
            HStack(spacing: 0) {
                // Left Wing: Outside camera notch, 100% visible
                leftCompactWing
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Center: Hardware camera notch blind spot (zero elements behind camera!)
                Color.clear
                    .frame(width: model.idleWidth, height: model.idleHeight)
                
                // Right Wing: Outside camera notch, 100% visible
                rightCompactWing
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .frame(height: model.idleHeight)
            
            // Bottom Shelf: Only rendered when notes are explicitly pinned!
            if model.compactHUDMode == .notesPinned {
                compactBottomShelf
                    .frame(maxWidth: .infinity)
                    .frame(height: model.compactHeight - model.idleHeight)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 3)
            }
        }
        .frame(width: model.compactWidth, height: model.compactHeight)
        .contentShape(Rectangle())
    }
    
    // MARK: - Independent Left Compact Wing
    @ViewBuilder
    private var leftCompactWing: some View {
        switch model.compactHUDMode {
        case .pomodoroOnly:
            CompactPomodoroWingLeft(pomodoro: model.pomodoro, model: model)
        case .mediaOnly:
            CompactMediaWingLeft(media: model.media, model: model)
        case .dualActive:
            CompactDualWingLeft(pomodoro: model.pomodoro, model: model)
        case .notesPinned:
            CompactNotesWingLeft(model: model)
        case .calendarAlert:
            CompactCalendarWingLeft(calendar: model.calendar, model: model)
        case .none:
            EmptyView()
        }
    }
    
    // MARK: - Independent Right Compact Wing
    @ViewBuilder
    private var rightCompactWing: some View {
        switch model.compactHUDMode {
        case .pomodoroOnly:
            CompactPomodoroWingRight(pomodoro: model.pomodoro, model: model)
        case .mediaOnly:
            CompactMediaWingRight(media: model.media, model: model)
        case .dualActive:
            CompactDualWingRight(media: model.media, model: model)
        case .notesPinned:
            expandChevron
                .padding(.trailing, 10)
        case .calendarAlert:
            CompactCalendarWingRight(calendar: model.calendar, model: model)
        case .none:
            EmptyView()
        }
    }
    
    // MARK: - Compact Bottom Shelf (Only for Notes Pinned Mode)
    private var compactBottomShelf: some View {
        HStack(spacing: 6) {
            Button(action: {
                model.selectedTab = .notes
                withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                    model.isExpanded = true
                }
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "note.text")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.white)
                    
                    let snippet = model.scratchpad.text
                        .replacingOccurrences(of: "\n", with: " • ")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    Text(snippet.isEmpty ? "Tap to view scratchpad" : snippet)
                        .font(.system(size: 9.5, weight: .medium, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.9))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .buttonStyle(.plain)
            
            Spacer(minLength: 4)
            
            Button(action: {
                model.scratchpad.copyAll()
            }) {
                HStack(spacing: 3) {
                    Image(systemName: model.scratchpad.showCopiedAlert ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 7.5, weight: .bold))
                    Text(model.scratchpad.showCopiedAlert ? "Copied!" : "Copy")
                        .font(.system(size: 8.5, weight: .bold, design: .rounded))
                }
                .foregroundColor(Color.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2.5)
                .background(Color.white.opacity(0.16))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }
    
    private var expandChevron: some View {
        Button(action: {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                model.isExpanded = true
            }
        }) {
            Image(systemName: "chevron.down")
                .font(.system(size: 7.5, weight: .bold))
                .foregroundColor(Color.white.opacity(0.45))
                .frame(width: 16, height: 16)
                .background(Color.white.opacity(0.06))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .help("Expand Island")
    }
    
    // MARK: - 3. Expanded Island View (640 x 300 pt)
    private var expandedView: some View {
        VStack(spacing: 2) {
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
                case .calendar:
                    CalendarView(calendar: model.calendar)
                        .transition(.asymmetric(insertion: .opacity, removal: .opacity))
                case .profile:
                    ProfileView(model: model)
                        .transition(.asymmetric(insertion: .opacity, removal: .opacity))
                }
            }
            .frame(maxHeight: .infinity)
        }
        .padding(.horizontal, 10)
        .padding(.top, 2)
        .padding(.bottom, 6)
        .frame(width: model.expandedWidth, height: model.expandedHeight, alignment: .top)
    }
    
    // MARK: - Top Notch Row (Wings visible, Center completely empty)
    private var topNotchRow: some View {
        HStack(spacing: 0) {
            // LEFT WING (Outside Notch: 100% Visible)
            HStack(spacing: 4) {
                if model.selectedTab != .home {
                    Button(action: {
                        model.returnToHome()
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 8.5, weight: .bold))
                            Text("Home")
                                .font(.system(size: 9.5, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3.5)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("Back to Home (⌘[)")
                } else {
                    // Profile Avatar Pill on Home screen (Pure Clean: No decorative dots!)
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            model.selectedTab = .profile
                        }
                    }) {
                        HStack(spacing: 5) {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.18))
                                    .frame(width: 16, height: 16)
                                Text(model.supabase.currentUser.displayInitials)
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            Text(model.supabase.currentUser.firstName)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3.5)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                    .help("Profile & Preferences (⌘5 or ⌘,)")
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // CENTER BLIND SPOT: Sits directly beneath hardware camera notch.
            // MUST BE KEPT COMPLETELY CLEAR OF ANY TEXT OR FEATURES!
            Color.clear
                .frame(width: notchBlindWidth, height: notchBlindHeight)
            
            // RIGHT WING (Outside Notch: 100% Visible)
            HStack(spacing: 4) {
                Spacer()
                
                // Segmented Tabs
                HStack(spacing: 3.5) {
                    ForEach([MorphTab.home, .timer, .music, .notes, .calendar]) { tab in
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
                            .foregroundColor(model.selectedTab == tab ? .black : Color.white.opacity(0.65))
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
                        .help("\(tab.rawValue) (\(shortcutForTab(tab)))")
                    }
                }
                
                // Pin Button
                Button(action: {
                    model.togglePin()
                }) {
                    Image(systemName: model.isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 8.5))
                        .foregroundColor(model.isPinned ? .white : Color.white.opacity(0.5))
                        .frame(width: 20, height: 20)
                        .background(model.isPinned ? Color.white.opacity(0.25) : Color.white.opacity(0.06))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help(model.isPinned ? "Unpin Window (⌘P)" : "Pin Window Open (⌘P)")
                
                // Collapse Button
                Button(action: {
                    model.isPinned = false
                    model.isExpanded = false
                }) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.6))
                        .frame(width: 20, height: 20)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Collapse to Notch (⌘W or ⌘M)")
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
    
    // MARK: - Background Image Texture
    private static let cachedBackgroundImage: NSImage? = {
        if let url = Bundle.main.url(forResource: "morph_bg", withExtension: "jpg"),
           let img = NSImage(contentsOf: url) {
            return img
        }
        let localPath = "Resources/morph_bg.jpg"
        if FileManager.default.fileExists(atPath: localPath),
           let img = NSImage(contentsOfFile: localPath) {
            return img
        }
        return nil
    }()
    
    @ViewBuilder
    private var backgroundImageView: some View {
        if model.isExpanded {
            if let image = Self.cachedBackgroundImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: model.expandedWidth, height: model.expandedHeight)
                    .clipped()
                    .opacity(0.85)
            } else {
                // Procedural dark ambient gradient fallback
                LinearGradient(
                    colors: [
                        Color(white: 0.12),
                        Color(white: 0.05),
                        Color(white: 0.01)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
    }
    
    private func shortcutForTab(_ tab: MorphTab) -> String {
        tab.shortcutLabel
    }
}

// MARK: - Dedicated Synchronous Collapsed Subviews

private struct CompactPomodoroWingLeft: View {
    @ObservedObject var pomodoro: PomodoroModel
    let model: NotchModel
    
    var body: some View {
        Button(action: {
            model.openFeature(.timer)
        }) {
            HStack(spacing: 6) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.18), lineWidth: 2)
                        .frame(width: 15, height: 15)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(pomodoro.progress))
                        .stroke(
                            LinearGradient(
                                colors: [Color.white, Color.white.opacity(0.4)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 15, height: 15)
                }
                
                if pomodoro.isRunning {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 3.5, height: 3.5)
                        .opacity(0.9)
                }
                
                Text(pomodoro.formattedTime)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }
            .padding(.leading, 12)
        }
        .buttonStyle(.plain)
        .help("Open Focus Timer (⌘2)")
    }
}

private struct CompactPomodoroWingRight: View {
    @ObservedObject var pomodoro: PomodoroModel
    let model: NotchModel
    
    var body: some View {
        HStack(spacing: 6) {
            Text(pomodoro.mode == .work ? "FOCUS" : "BREAK")
                .font(.system(size: 8.5, weight: .heavy, design: .rounded))
                .foregroundColor(Color.white.opacity(0.9))
                .padding(.horizontal, 6)
                .padding(.vertical, 2.5)
                .background(Color.white.opacity(0.14))
                .clipShape(Capsule())
            
            Button(action: {
                pomodoro.toggle()
            }) {
                Image(systemName: pomodoro.isRunning ? "pause.fill" : "play.fill")
                    .font(.system(size: 7.5, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 18, height: 18)
                    .background(Color.white.opacity(0.16))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            .help(pomodoro.isRunning ? "Pause Focus Timer (⌘⏎)" : "Start Focus Timer (⌘⏎)")
            
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                    model.isExpanded = true
                }
            }) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 7.5, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.45))
                    .frame(width: 16, height: 16)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Expand Island (⌘⌥M)")
        }
        .padding(.trailing, 12)
    }
}

private struct CompactMediaWingLeft: View {
    @ObservedObject var media: MediaControllerModel
    let model: NotchModel
    
    var body: some View {
        HStack(spacing: 5) {
            Button(action: {
                model.openFeature(.music)
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "music.note")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(media.trackTitle.isEmpty ? "Playing" : media.trackTitle)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .frame(maxWidth: 78, alignment: .leading)
                }
            }
            .buttonStyle(.plain)
            .help("Open Media Player (⌘3)")
            
            // Dedicated Notch Playlist Queue Trigger Button
            Button(action: {
                model.openFeature(.music)
            }) {
                Image(systemName: "music.note.list")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.8))
                    .frame(width: 17, height: 17)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("View Playlist Queue")
        }
        .padding(.leading, 12)
    }
}

private struct CompactMediaWingRight: View {
    @ObservedObject var media: MediaControllerModel
    let model: NotchModel
    
    var body: some View {
        HStack(spacing: 5) {
            if media.showVolumeHUD {
                // Sleek Notch Volume HUD Pill
                HStack(spacing: 3.5) {
                    Image(systemName: media.isMuted ? "speaker.slash.fill" : (media.volume > 0.5 ? "speaker.wave.2.fill" : "speaker.wave.1.fill"))
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                    
                    // Mini volume track
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 24, height: 3.5)
                        
                        Capsule()
                            .fill(Color.white)
                            .frame(width: max(0, min(24, 24 * CGFloat(media.isMuted ? 0 : media.volume))), height: 3.5)
                    }
                    
                    Text("\(Int((media.isMuted ? 0 : media.volume) * 100))%")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.9))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2.5)
                .background(Color.white.opacity(0.18))
                .clipShape(Capsule())
                .transition(.scale.combined(with: .opacity))
            } else {
                // Live Synchronous Equalizer
                HStack(alignment: .bottom, spacing: 2) {
                    ForEach(0..<3, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white, Color.white.opacity(0.4)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 2.5, height: max(3, 12 * CGFloat(media.visualizerBars[i % 3])))
                            .animation(.easeOut(duration: 0.12), value: media.visualizerBars[i % 3])
                    }
                }
                .frame(height: 12, alignment: .bottom)
            }
            
            Button(action: {
                media.togglePlay()
            }) {
                Image(systemName: media.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 7.5, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 18, height: 18)
                    .background(Color.white.opacity(0.16))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            .help(media.isPlaying ? "Pause Music (⌘⏎)" : "Play Music (⌘⏎)")
            
            Button(action: {
                media.nextTrack()
            }) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 18, height: 18)
                    .background(Color.white.opacity(0.16))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            .help("Next Track (⌘])")
            
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                    model.isExpanded = true
                }
            }) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 7.5, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.45))
                    .frame(width: 16, height: 16)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Expand Island (⌘⌥M)")
        }
        .padding(.trailing, 12)
    }
}

private struct CompactDualWingLeft: View {
    @ObservedObject var pomodoro: PomodoroModel
    let model: NotchModel
    
    var body: some View {
        HStack(spacing: 5) {
            Button(action: {
                model.openFeature(.timer)
            }) {
                HStack(spacing: 5) {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.18), lineWidth: 2)
                            .frame(width: 14, height: 14)
                        
                        Circle()
                            .trim(from: 0, to: CGFloat(pomodoro.progress))
                            .stroke(Color.white, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .frame(width: 14, height: 14)
                    }
                    
                    Text(pomodoro.formattedTime)
                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(.plain)
            .help("Open Focus Timer (⌘2)")
            
            Button(action: {
                pomodoro.toggle()
            }) {
                Image(systemName: pomodoro.isRunning ? "pause.fill" : "play.fill")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 17, height: 17)
                    .background(Color.white.opacity(0.16))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Pause/Resume Focus Timer (⌘⏎)")
        }
        .padding(.leading, 12)
    }
}

private struct CompactDualWingRight: View {
    @ObservedObject var media: MediaControllerModel
    let model: NotchModel
    
    var body: some View {
        HStack(spacing: 5) {
            if media.showVolumeHUD {
                HStack(spacing: 3) {
                    Image(systemName: media.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 7.5, weight: .bold))
                        .foregroundColor(.white)
                    Text("\(Int((media.isMuted ? 0 : media.volume) * 100))%")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.9))
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.18))
                .clipShape(Capsule())
                .transition(.scale.combined(with: .opacity))
            } else {
                Button(action: {
                    model.openFeature(.music)
                }) {
                    HStack(spacing: 4) {
                        HStack(alignment: .bottom, spacing: 1.5) {
                            ForEach(0..<3, id: \.self) { i in
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(Color.white)
                                    .frame(width: 2, height: max(3, 10 * CGFloat(media.visualizerBars[i % 3])))
                                    .animation(.easeOut(duration: 0.12), value: media.visualizerBars[i % 3])
                            }
                        }
                        .frame(height: 10, alignment: .bottom)
                        
                        Text(media.trackTitle.isEmpty ? "Playing" : media.trackTitle)
                            .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .frame(maxWidth: 68, alignment: .leading)
                    }
                }
                .buttonStyle(.plain)
                .help("Open Media Player (⌘3)")
            }
            
            Button(action: {
                media.togglePlay()
            }) {
                Image(systemName: media.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 17, height: 17)
                    .background(Color.white.opacity(0.16))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Pause/Play Music (⌘⏎)")
            
            Button(action: {
                media.nextTrack()
            }) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 6.5, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 17, height: 17)
                    .background(Color.white.opacity(0.16))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Next Track (⌘])")
        }
        .padding(.trailing, 12)
    }
}

private struct CompactNotesWingLeft: View {
    let model: NotchModel
    
    var body: some View {
        Button(action: {
            model.openFeature(.notes)
        }) {
            HStack(spacing: 4) {
                Image(systemName: "note.text")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
                Text("Scratchpad")
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            .padding(.leading, 12)
        }
        .buttonStyle(.plain)
        .help("Open Scratchpad (⌘4)")
    }
}

private struct CompactCalendarWingLeft: View {
    @ObservedObject var calendar: CalendarModel
    let model: NotchModel
    
    var body: some View {
        Button(action: {
            model.openFeature(.calendar)
        }) {
            HStack(spacing: 5) {
                Image(systemName: "calendar")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundColor(.cyan)
                
                if let next = calendar.activeAlertEvent ?? calendar.nextUpcomingEvent {
                    Text("In \(next.minutesUntilStart)m: \(next.title)")
                        .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .frame(maxWidth: 140, alignment: .leading)
                } else {
                    Text("Calendar")
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.leading, 12)
        .help("Open Calendar (⌘6)")
    }
}

private struct CompactCalendarWingRight: View {
    @ObservedObject var calendar: CalendarModel
    let model: NotchModel
    
    var body: some View {
        HStack(spacing: 5) {
            if let next = calendar.activeAlertEvent ?? calendar.nextUpcomingEvent, let meet = next.meetLink {
                Button(action: {
                    calendar.engine.openMeet(link: meet)
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "video.fill")
                            .font(.system(size: 7))
                        Text("Meet ↗")
                            .font(.system(size: 7.5, weight: .bold))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(Color.cyan)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("Join Google Meet")
            }
            
            Button(action: {
                calendar.dismissNotchAlert()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.5))
                    .frame(width: 16, height: 16)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Dismiss Alert")
            
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                    model.isExpanded = true
                }
            }) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 7.5, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.45))
                    .frame(width: 16, height: 16)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Expand Island")
        }
        .padding(.trailing, 12)
    }
}

