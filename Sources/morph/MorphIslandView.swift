import SwiftUI
import UniformTypeIdentifiers

public struct MorphIslandView: View {
    @ObservedObject var model: NotchModel
    var onMouseEnter: () -> Void
    var onMouseExit: () -> Void
    @State private var isNotchDragTargeted: Bool = false
    
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
                .fill(model.theme.canvasBackground)
                .overlay(
                    // Luxury ambient background texture
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
                        model.dropShelf.isDraggingOverNotch
                            ? LinearGradient(
                                colors: [Color.cyan.opacity(0.85), Color.cyan.opacity(0.5)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            : LinearGradient(
                                colors: [
                                    model.theme.isDark ? Color.white.opacity(model.isExpanded ? 0.20 : 0.28) : Color.black.opacity(model.isExpanded ? 0.12 : 0.18),
                                    model.theme.isDark ? Color.white.opacity(model.isExpanded ? 0.08 : 0.16) : Color.black.opacity(model.isExpanded ? 0.06 : 0.10)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                        style: StrokeStyle(
                            lineWidth: model.dropShelf.isDraggingOverNotch ? 1.5 : 1,
                            dash: model.dropShelf.isDraggingOverNotch ? [6, 3] : []
                        )
                    )
                )
                .shadow(
                    color: model.dropShelf.isDraggingOverNotch
                        ? Color.cyan.opacity(0.55)
                        : (model.isExpanded ? model.theme.windowShadow : (model.theme.isDark ? Color.black.opacity(0.3) : Color.black.opacity(0.12))),
                    radius: model.dropShelf.isDraggingOverNotch ? 16 : (model.isExpanded ? 24 : 8),
                    x: 0,
                    y: model.isExpanded ? 10 : 4
                )
                
                // Content: Idle / Compact Notch vs Expanded Island
                if model.isExpanded {
                    expandedView
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.98, anchor: .top)),
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
            .onDrop(of: [.fileURL], isTargeted: $isNotchDragTargeted) { providers in
                handleNotchFileDrop(providers: providers)
            }
            .onChange(of: isNotchDragTargeted) { _, targeted in
                model.dropShelf.isDraggingOverNotch = targeted
            }
            .animation(.spring(response: 0.38, dampingFraction: 0.82), value: model.isExpanded)
            .animation(.spring(response: 0.38, dampingFraction: 0.82), value: model.isCompactActive)
            .animation(.spring(response: 0.30, dampingFraction: 0.82), value: model.selectedTab)
            .animation(.spring(response: 0.38, dampingFraction: 0.82), value: model.activeContextFeature)
            
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
    
    private func handleNotchFileDrop(providers: [NSItemProvider]) -> Bool {
        var didLoadAny = false
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let fileURL = url {
                        Task { @MainActor in
                            model.dropShelf.stageFile(url: fileURL)
                            model.openContextualFeature(.dropShelf)
                        }
                    }
                }
                didLoadAny = true
            }
        }
        return didLoadAny
    }
    
    // MARK: - 1. Idle Flush Notch View (Smooth border radius, no sharp corners, zero dots)
    private var idleFlushNotchView: some View {
        Color.clear
            .frame(width: model.idleWidth, height: model.idleHeight)
            .contentShape(Rectangle())
            .onTapGesture {
                model.syncExpandedFeatureWithActiveContext()
                withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                    model.isExpanded = true
                }
            }
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
                    .contentShape(Rectangle())
                
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
        .onTapGesture {
            model.syncExpandedFeatureWithActiveContext()
            withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                model.isExpanded = true
            }
        }
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
        case .calendarAndMedia:
            CompactCalendarWingLeft(calendar: model.calendar, model: model)
        case .notesPinned:
            CompactNotesWingLeft(model: model)
        case .calendarAlert:
            CompactCalendarWingLeft(calendar: model.calendar, model: model)
        case .meetingFlight:
            CompactMeetingWingLeft(controller: model.meetingController, model: model)
        case .dropShelfActive:
            CompactDropShelfWingLeft(shelf: model.dropShelf, model: model)
        case .formTrackerActive:
            CompactFormTrackerWingLeft(formTracker: model.formTracker, model: model)
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
        case .calendarAndMedia:
            CompactMediaWingRight(media: model.media, model: model)
        case .notesPinned:
            expandChevron
                .padding(.trailing, 10)
        case .calendarAlert:
            CompactCalendarWingRight(calendar: model.calendar, model: model)
        case .meetingFlight:
            CompactMeetingWingRight(controller: model.meetingController, model: model)
        case .dropShelfActive:
            CompactDropShelfWingRight(shelf: model.dropShelf, model: model)
        case .formTrackerActive:
            CompactFormTrackerWingRight(formTracker: model.formTracker, model: model)
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
            model.syncExpandedFeatureWithActiveContext()
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
    
    // MARK: - 3. Expanded Island View (640 x 225 pt)
    private var expandedView: some View {
        VStack(spacing: 4) {
            // Top Notch Row: Wings on Left/Right, Empty Center Blind Spot for Hardware Notch
            topNotchRow
                .frame(height: notchBlindHeight)
            
            // Unified Horizontal Navigation Bar (The Bar Above: Focus, Home, Music, Notes, Calendar, Profile)
            horizontalFeatureBar
            
            // Main Feature Body: Sits completely BELOW the notch blind spot and horizontal bar!
            ZStack {
                if let contextFeature = model.activeContextFeature {
                    switch contextFeature {
                    case .meetingFlight:
                        MeetingFlightControllerView(model: model)
                            .transition(.asymmetric(insertion: .opacity, removal: .opacity))
                    case .dropShelf:
                        DropShelfView(model: model)
                            .transition(.asymmetric(insertion: .opacity, removal: .opacity))
                    case .formTracker:
                        ApplicationFormTrackerView(model: model)
                            .transition(.asymmetric(insertion: .opacity, removal: .opacity))
                    }
                } else {
                    switch model.selectedTab {
                    case .home:
                        HomeView(model: model)
                            .transition(.asymmetric(insertion: .opacity, removal: .opacity))
                    case .timer:
                        PomodoroView(pomodoro: model.pomodoro, model: model)
                            .transition(.asymmetric(insertion: .opacity, removal: .opacity))
                    case .music:
                        MediaView(media: model.media)
                            .transition(.asymmetric(insertion: .opacity, removal: .opacity))
                    case .notes:
                        ScratchpadView(scratchpad: model.scratchpad)
                            .transition(.asymmetric(insertion: .opacity, removal: .opacity))
                    case .calendar:
                        CalendarView(calendar: model.calendar, meetingController: model.meetingController)
                            .transition(.asymmetric(insertion: .opacity, removal: .opacity))
                    case .profile:
                        ProfileView(model: model)
                            .transition(.asymmetric(insertion: .opacity, removal: .opacity))
                    }
                }
            }
            .frame(maxHeight: .infinity)
        }
        .padding(.horizontal, 10)
        .padding(.top, 2)
        .padding(.bottom, 6)
        .frame(width: model.expandedWidth, height: model.expandedHeight, alignment: .top)
    }
    
    // MARK: - Horizontal Navigation Feature Bar (Home, Focus Timer, Music, Notes, Calendar, Profile)
    private var horizontalFeatureBar: some View {
        HStack(spacing: 6) {
            Spacer(minLength: 0)
            
            ForEach([MorphTab.home, .timer, .music, .notes, .calendar, .profile]) { tab in
                Button(action: {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                        model.selectedTab = tab
                        model.activeContextFeature = nil
                    }
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: tab.iconName)
                            .font(.system(size: 9.5, weight: model.selectedTab == tab ? .bold : .medium))
                        Text(tab == .timer ? "Focus Timer" : tab.rawValue)
                            .font(.system(size: 9.5, weight: model.selectedTab == tab ? .bold : .medium, design: .rounded))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .foregroundColor(model.selectedTab == tab ? Color.black : Color.white.opacity(0.85))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(
                        model.selectedTab == tab
                            ? Color.white
                            : model.theme.inactivePillBackground
                    )
                    .clipShape(Capsule())
                    .environment(\.colorScheme, model.selectedTab == tab ? .light : .dark)
                    .overlay(
                        Capsule()
                            .stroke(
                                model.selectedTab == tab
                                    ? Color.clear
                                    : model.theme.hairlineBorder,
                                lineWidth: 0.5
                            )
                    )
                }
                .buttonStyle(.plain)
                .help("\(tab == .timer ? "Focus Timer" : tab.rawValue) (\(shortcutForTab(tab)))")
            }
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2.5)
        .frame(maxWidth: .infinity, alignment: .center)
    }
    
    // MARK: - Top Notch Row (Wings visible, Center completely empty)
    private var topNotchRow: some View {
        HStack(spacing: 0) {
            // LEFT WING (Outside Notch: 100% Visible)
            HStack(spacing: 6) {
                if let contextFeature = model.activeContextFeature {
                    Button(action: {
                        model.closeContextualFeature()
                    }) {
                        HStack(spacing: 3.5) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 9, weight: .bold))
                            Text("Back")
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(model.theme.textPrimary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(model.theme.cardBackgroundElevated)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(model.theme.hairlineBorder, lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                    .fixedSize(horizontal: true, vertical: true)
                    .help("Back (Esc)")
                    
                    Text(contextFeature == .formTracker ? "Form Tracker" : contextFeature.rawValue)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(model.theme.textSecondary)
                        .lineLimit(1)
                } else {
                    // Profile Avatar Pill with Name & Breadcrumb
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            model.selectedTab = .profile
                        }
                    }) {
                        HStack(spacing: 5) {
                            ZStack {
                                Circle()
                                    .fill(model.theme.cardBackgroundElevated)
                                    .frame(width: 18, height: 18)
                                Text(model.supabase.currentUser.displayInitials)
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(model.theme.textPrimary)
                            }
                            Text(model.supabase.currentUser.firstName)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(model.theme.textPrimary)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3.5)
                        .background(model.theme.cardBackground)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(model.theme.hairlineBorder, lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                    .help("Profile & Preferences (⌘5 or ⌘,)")
                    
                    Text((model.selectedTab == .timer ? "Focus" : model.selectedTab.rawValue).uppercased())
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .foregroundColor(model.theme.textTertiary)
                        .tracking(1.0)
                        .lineLimit(1)
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
                
                // Theme Toggle Button
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        model.toggleTheme()
                    }
                }) {
                    Image(systemName: model.theme.isDark ? "sun.max.fill" : "moon.fill")
                        .font(.system(size: 8.5))
                        .foregroundColor(model.theme.textSecondary)
                        .frame(width: 22, height: 22)
                        .background(model.theme.cardBackground)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(model.theme.hairlineBorder, lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
                .help(model.theme.isDark ? "Switch to Light Ceramic Theme" : "Switch to Dark Obsidian Theme")
                
                // Pin Button
                Button(action: {
                    model.togglePin()
                }) {
                    Image(systemName: model.isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 8.5))
                        .foregroundColor(model.isPinned ? model.theme.textPrimary : model.theme.textTertiary)
                        .frame(width: 22, height: 22)
                        .background(model.isPinned ? model.theme.cardBackgroundElevated : model.theme.cardBackground)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(model.theme.hairlineBorder, lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
                .help(model.isPinned ? "Unpin Window (⌘P)" : "Pin Window Open (⌘P)")
                
                // Collapse Button
                Button(action: {
                    model.isPinned = false
                    model.isExpanded = false
                    model.activeContextFeature = nil
                }) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundColor(model.theme.textSecondary)
                        .frame(width: 22, height: 22)
                        .background(model.theme.cardBackground)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(model.theme.hairlineBorder, lineWidth: 0.5)
                        )
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
            if model.theme.isDark {
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
            } else {
                // Procedural light frosted alabaster gradient
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.96),
                        Color(red: 0.96, green: 0.96, blue: 0.98).opacity(0.92),
                        Color(red: 0.94, green: 0.94, blue: 0.96).opacity(0.90)
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
                model.syncExpandedFeatureWithActiveContext()
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
            } else if media.showOfflineHUD {
                // Sleek Notch Offline HUD Pill
                HStack(spacing: 3) {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 7.5, weight: .bold))
                        .foregroundColor(Color(red: 1.0, green: 0.72, blue: 0.2))
                    Text(media.offlineHUDMessage.isEmpty ? "Offline • Downloads Opened" : media.offlineHUDMessage)
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.95))
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color(red: 0.22, green: 0.14, blue: 0.04))
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(Color(red: 1.0, green: 0.72, blue: 0.2).opacity(0.4), lineWidth: 0.5)
                )
                .transition(.scale.combined(with: .opacity))
            } else if media.showRepeatHUD {
                // Sleek Notch Repeat HUD Pill
                HStack(spacing: 3.5) {
                    Image(systemName: media.repeatMode.iconName)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(media.repeatMode == .off ? Color.white.opacity(0.5) : Color.white)
                    Text(media.repeatMode.hudTitle)
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.95))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2.5)
                .background(media.repeatMode == .off ? Color.white.opacity(0.12) : Color.white.opacity(0.22))
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
                model.syncExpandedFeatureWithActiveContext()
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
            } else if media.showOfflineHUD {
                // Sleek Notch Offline HUD Pill
                HStack(spacing: 3) {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 7.5, weight: .bold))
                        .foregroundColor(Color(red: 1.0, green: 0.72, blue: 0.2))
                    Text(media.offlineHUDMessage.isEmpty ? "Offline • Downloads Opened" : media.offlineHUDMessage)
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.95))
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color(red: 0.22, green: 0.14, blue: 0.04))
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(Color(red: 1.0, green: 0.72, blue: 0.2).opacity(0.4), lineWidth: 0.5)
                )
                .transition(.scale.combined(with: .opacity))
            } else if media.showRepeatHUD {
                HStack(spacing: 3) {
                    Image(systemName: media.repeatMode.iconName)
                        .font(.system(size: 7.5, weight: .bold))
                        .foregroundColor(media.repeatMode == .off ? Color.white.opacity(0.5) : Color.white)
                    Text(media.repeatMode.hudTitle)
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.95))
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(media.repeatMode == .off ? Color.white.opacity(0.12) : Color.white.opacity(0.22))
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
            
            Button(action: {
                model.syncExpandedFeatureWithActiveContext()
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
                    .foregroundColor(.white.opacity(0.85))
                
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
                    .background(Color.white)
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
                model.syncExpandedFeatureWithActiveContext()
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

