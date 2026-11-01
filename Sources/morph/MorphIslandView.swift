import SwiftUI
import UniformTypeIdentifiers

public struct MorphIslandView: View {
    @ObservedObject var model: NotchModel
    @ObservedObject private var shortcutManager = ShortcutManager.shared
    var onMouseEnter: () -> Void
    var onMouseExit: () -> Void
    @State private var isNotchDragTargeted: Bool = false
    @State private var hoveredTab: MorphTab? = nil
    @Namespace private var navTabNamespace
    
    public init(model: NotchModel, onMouseEnter: @escaping () -> Void = {}, onMouseExit: @escaping () -> Void = {}) {
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
        } else {
            return 18 // Apple Dynamic Island 4-sided squircle pill
        }
    }
    
    private var topRadius: CGFloat {
        if model.isExpanded {
            return 28
        } else {
            return 18 // Fully rounded 4-sided squircle pill
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
                // Background Base Shape: Hardware Obsidian when collapsed (blending into physical notch), theme canvas when expanded
                UnevenRoundedRectangle(
                    topLeadingRadius: topRadius,
                    bottomLeadingRadius: cornerRadius,
                    bottomTrailingRadius: cornerRadius,
                    topTrailingRadius: topRadius,
                    style: .continuous
                )
                .fill(
                    model.isExpanded
                        ? model.theme.canvasBackground
                        : (model.isCompactActive
                            ? Color.black
                            : (model.isHovered ? Color.black : Color.clear))
                )
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
                                colors: [model.theme.dropTargetBorder, model.theme.dropTargetBorder.opacity(0.65)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            : LinearGradient(
                                colors: [
                                    Color.white.opacity(model.isHovered ? 0.35 : (model.isExpanded ? 0.20 : 0.22)),
                                    Color.white.opacity(model.isHovered ? 0.20 : (model.isExpanded ? 0.08 : 0.12))
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                        style: StrokeStyle(
                            lineWidth: model.dropShelf.isDraggingOverNotch ? 1.5 : (model.isHovered ? 1.0 : 0.75),
                            dash: model.dropShelf.isDraggingOverNotch ? [6, 3] : []
                        )
                    )
                )
                .shadow(
                    color: model.dropShelf.isDraggingOverNotch
                        ? model.theme.dropTargetGlow
                        : (model.isExpanded || model.isCompactActive || model.isHovered
                            ? Color.black.opacity(0.40)
                            : Color.clear),
                    radius: model.isExpanded ? 24 : 10,
                    x: 0,
                    y: model.isExpanded ? 10 : 4
                )
                
                // Content: Idle / Compact Notch vs Expanded Island
                Group {
                    switch model.islandState {
                    case .fullExpanded:
                        expandedView
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .top)),
                                removal: .opacity.combined(with: .scale(scale: 0.98, anchor: .top))
                            ))
                    case .extendedPill:
                        compactActiveNotchView
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.94, anchor: .center)),
                                removal: .opacity.combined(with: .scale(scale: 0.94, anchor: .center))
                            ))
                    case .resting:
                        idleFlushNotchView
                            .transition(.opacity)
                    }
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
                    if model.isExpanded {
                        onMouseEnter()
                    }
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
            .animation(MorphUniversalAnimation.stateExpansion, value: model.isExpanded)
            .animation(MorphUniversalAnimation.stateElongation, value: model.isCompactActive)
            .animation(MorphUniversalAnimation.tabSwitch, value: model.selectedTab)
            .animation(MorphUniversalAnimation.stateExpansion, value: model.activeContextFeature)
            
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
    
    // MARK: - 1. Idle Transparent Dynamic Island Outline (No text, no dots, pure whisper outline)
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
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        )
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Center: Hardware camera notch blind spot (zero elements behind camera!)
                Color.clear
                    .frame(width: model.idleWidth, height: model.idleHeight)
                    .contentShape(Rectangle())
                
                // Right Wing: Outside camera notch, 100% visible
                rightCompactWing
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        )
                    )
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
            withAnimation(MorphUniversalAnimation.stateExpansion) {
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
                        .replacingOccurrences(of: "\n", with: " — ")
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
            // Suppressed when a contextual feature (such as Form Tracker) is active to maximize content stage
            if model.activeContextFeature == nil {
                horizontalFeatureBar
            }
            
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
                        MediaView(media: model.media, model: model, calendar: model.calendar, theme: model.theme)
                            .transition(.asymmetric(insertion: .opacity, removal: .opacity))
                    case .notes:
                        ScratchpadView(scratchpad: model.scratchpad, theme: model.theme, model: model)
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
        .overlay(alignment: .top) {
            if model.isCommandBarPresented {
                MorphCommandBarView(model: model)
                    .padding(.top, notchBlindHeight + 2)
                    .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
            }
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
                    MorphHaptics.levelChange()
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        model.selectedTab = tab
                        model.activeContextFeature = nil
                        model.isCommandBarPresented = false
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
                    .foregroundColor(model.selectedTab == tab ? model.theme.activePillText : model.theme.inactivePillText)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(
                        ZStack {
                            if model.selectedTab == tab {
                                Capsule()
                                    .fill(model.theme.activePillBackground)
                                    .matchedGeometryEffect(id: "ActiveTabPill", in: navTabNamespace)
                            } else {
                                Capsule()
                                    .fill(hoveredTab == tab ? model.theme.cardBackgroundElevated : model.theme.inactivePillBackground)
                            }
                        }
                    )
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(
                                model.selectedTab == tab
                                    ? (model.theme.isDark ? Color.clear : Color.black.opacity(0.12))
                                    : model.theme.hairlineBorder,
                                lineWidth: 0.5
                            )
                    )
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.14)) {
                        hoveredTab = hovering ? tab : (hoveredTab == tab ? nil : hoveredTab)
                    }
                }
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
                    .accessibilityLabel("Back to Home")
                    .help("Back (Esc)")
                    
                    if contextFeature == .formTracker {
                        HStack(spacing: 5) {
                            Image(systemName: "doc.text.fill")
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundColor(.white)
                            Text(model.formTracker.activeSession?.formTitle ?? (model.formTracker.detectedFormTitle.isEmpty ? "Google Form" : model.formTracker.detectedFormTitle))
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundColor(model.theme.textPrimary)
                                .lineLimit(1)
                        }
                    } else {
                        Text(contextFeature.rawValue)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(model.theme.textSecondary)
                            .lineLimit(1)
                    }
                } else {
                    // Profile Avatar Pill with Name & Breadcrumb
                    Button(action: {
                        MorphHaptics.levelChange()
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
                    .accessibilityLabel("Profile and Preferences")
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
                
                if model.activeContextFeature == .formTracker, let session = model.formTracker.activeSession, session.totalQuestions > 0 {
                    Text("\(session.answeredCount)/\(session.totalQuestions) Answered")
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3.5)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                        )
                }
                
                if !shortcutManager.lastTriggeredShortcut.isEmpty {
                    Text(shortcutManager.lastTriggeredShortcut)
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .foregroundColor(model.theme.badgeText)
                        .lineLimit(1)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(model.theme.badgeBackground)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(model.theme.hairlineBorder, lineWidth: 0.5)
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.92)))
                }
                
                // ⌘K Quick Command Button Pill
                Button(action: {
                    model.toggleCommandBar()
                }) {
                    HStack(spacing: 2) {
                        Image(systemName: "command")
                            .font(.system(size: 8, weight: .bold))
                        Text("K")
                            .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                    }
                    .foregroundColor(model.isCommandBarPresented ? model.theme.activePillText : model.theme.textSecondary)
                    .padding(.horizontal, 6.5)
                    .frame(height: 22)
                    .background(model.isCommandBarPresented ? model.theme.activePillBackground : model.theme.cardBackground)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(model.isCommandBarPresented ? model.theme.activeBorder : model.theme.hairlineBorder, lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Quick Command Bar")
                .help("Quick Command Bar (⌘K)")
                
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
                .accessibilityLabel(model.theme.isDark ? "Switch to Light Theme" : "Switch to Dark Theme")
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
                .accessibilityLabel(model.isPinned ? "Unpin Island" : "Pin Island Open")
                .help(model.isPinned ? "Unpin Window (⌘P)" : "Pin Window Open (⌘P)")
                
                // Collapse Button
                Button(action: {
                    MorphHaptics.levelChange()
                    withAnimation(.spring(response: 0.30, dampingFraction: 0.86)) {
                        model.isCommandBarPresented = false
                        model.isPinned = false
                        model.isExpanded = false
                        model.activeContextFeature = nil
                    }
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
                .accessibilityLabel("Collapse Island to Notch")
                .help("Collapse to Notch (⌘W or ⌘M)")
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .onChange(of: shortcutManager.lastTriggeredShortcut) { _, newValue in
                guard !newValue.isEmpty else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    if shortcutManager.lastTriggeredShortcut == newValue {
                        withAnimation(.easeOut(duration: 0.2)) {
                            shortcutManager.lastTriggeredShortcut = ""
                        }
                    }
                }
            }
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
                // Sleek Notch Offline HUD Pill (Monochromatic Obsidian/Silver)
                HStack(spacing: 3) {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 7.5, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.9))
                    Text(media.offlineHUDMessage.isEmpty ? "Offline • Downloads Opened" : media.offlineHUDMessage)
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.9))
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.14))
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(Color.white.opacity(0.28), lineWidth: 0.5)
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
                // Sleek Notch Offline HUD Pill (Monochromatic Obsidian/Silver)
                HStack(spacing: 3) {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 7.5, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.9))
                    Text(media.offlineHUDMessage.isEmpty ? "Offline • Downloads Opened" : media.offlineHUDMessage)
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.9))
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.14))
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(Color.white.opacity(0.28), lineWidth: 0.5)
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

// MARK: - Apple Spotlight-Inspired Quick Command Bar (⌘K)

public struct MorphCommandItem: Identifiable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let iconName: String
    public let shortcutBadge: String
    public let action: () -> Void
    
    public init(
        id: String,
        title: String,
        subtitle: String,
        iconName: String,
        shortcutBadge: String,
        action: @escaping () -> Void
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.iconName = iconName
        self.shortcutBadge = shortcutBadge
        self.action = action
    }
}

public struct MorphCommandBarView: View {
    @ObservedObject public var model: NotchModel
    @ObservedObject private var theme: MorphTheme = .shared
    @State private var searchQuery: String = ""
    @State private var selectedIndex: Int = 0
    @FocusState private var isSearchFocused: Bool
    
    public init(model: NotchModel) {
        self.model = model
        self.theme = model.theme
    }
    
    public var allCommands: [MorphCommandItem] {
        [
            MorphCommandItem(
                id: "toggle_timer",
                title: "Start / Pause Focus Timer",
                subtitle: model.pomodoro.isRunning ? "Pause active \(model.pomodoro.formattedTime) countdown" : "Resume \(model.pomodoro.formattedTime) focus session",
                iconName: model.pomodoro.isRunning ? "pause.circle.fill" : "timer",
                shortcutBadge: "⌘T",
                action: {
                    model.pomodoro.toggle()
                    model.openFeature(.timer)
                }
            ),
            MorphCommandItem(
                id: "focus_25m",
                title: "Focus: 25m Deep Work",
                subtitle: "Start a 25-minute Pomodoro sprint",
                iconName: "flame.fill",
                shortcutBadge: "25m",
                action: {
                    model.pomodoro.switchMode(.work)
                    model.pomodoro.setCustomDuration(minutes: 25, saveAsPreference: false)
                    model.pomodoro.start()
                    model.openFeature(.timer)
                }
            ),
            MorphCommandItem(
                id: "focus_45m",
                title: "Focus: 45m Flow",
                subtitle: "Start a 45-minute deep flow session",
                iconName: "bolt.fill",
                shortcutBadge: "45m",
                action: {
                    model.pomodoro.switchMode(.work)
                    model.pomodoro.setCustomDuration(minutes: 45, saveAsPreference: false)
                    model.pomodoro.start()
                    model.openFeature(.timer)
                }
            ),
            MorphCommandItem(
                id: "focus_5m_break",
                title: "Focus: 5m Short Break",
                subtitle: "Switch to a 5-minute recharge break",
                iconName: "cup.and.saucer.fill",
                shortcutBadge: "5m",
                action: {
                    model.pomodoro.switchMode(.shortBreak)
                    model.pomodoro.setCustomDuration(minutes: 5, saveAsPreference: false)
                    model.pomodoro.start()
                    model.openFeature(.timer)
                }
            ),
            MorphCommandItem(
                id: "play_pause_music",
                title: "Play / Pause Music",
                subtitle: model.media.trackTitle.isEmpty ? "Toggle media playback" : "\(model.media.isPlaying ? "Pause" : "Play") \(model.media.trackTitle)",
                iconName: model.media.isPlaying ? "pause.fill" : "play.fill",
                shortcutBadge: "⌘⏎",
                action: {
                    model.media.togglePlay()
                    model.isCommandBarPresented = false
                }
            ),
            MorphCommandItem(
                id: "next_track",
                title: "Next Track",
                subtitle: "Skip to the next song in queue",
                iconName: "forward.fill",
                shortcutBadge: "⌘]",
                action: {
                    model.media.nextTrack()
                    model.isCommandBarPresented = false
                }
            ),
            MorphCommandItem(
                id: "previous_track",
                title: "Previous Track",
                subtitle: "Return to the previous song",
                iconName: "backward.fill",
                shortcutBadge: "⌘[",
                action: {
                    model.media.previousTrack()
                    model.isCommandBarPresented = false
                }
            ),
            MorphCommandItem(
                id: "pin_note_notch",
                title: "Pin / Unpin Note to Notch",
                subtitle: model.isNotePinnedToNotch ? "Unpin scratchpad from compact notch" : "Keep scratchpad visible under the notch",
                iconName: model.isNotePinnedToNotch ? "pin.slash.fill" : "pin.fill",
                shortcutBadge: "⌘⇧P",
                action: {
                    model.isNotePinnedToNotch.toggle()
                    model.isCommandBarPresented = false
                }
            ),
            MorphCommandItem(
                id: "copy_scratchpad",
                title: "Copy Scratchpad to Clipboard",
                subtitle: "Copy all scratchpad notes (\(model.scratchpad.wordCount) words)",
                iconName: "doc.on.doc.fill",
                shortcutBadge: "⌘⇧C",
                action: {
                    model.scratchpad.copyAll()
                    model.isCommandBarPresented = false
                }
            ),
            MorphCommandItem(
                id: "open_calendar",
                title: "Open Calendar & Agenda",
                subtitle: "View upcoming meetings and schedule events",
                iconName: "calendar",
                shortcutBadge: "⌘6",
                action: {
                    model.openFeature(.calendar)
                }
            ),
            MorphCommandItem(
                id: "sync_profile_calendar",
                title: "Sync Profile & Calendar",
                subtitle: "Refresh Supabase telemetry and Google Calendar",
                iconName: "arrow.triangle.2.circlepath",
                shortcutBadge: "⌘R",
                action: {
                    model.calendar.syncWithGoogle()
                    Task {
                        await model.supabase.fetchProfile()
                    }
                    model.isCommandBarPresented = false
                }
            ),
            MorphCommandItem(
                id: "toggle_theme",
                title: "Toggle Dark / Light Theme",
                subtitle: model.theme.isDark ? "Switch to Light Ceramic appearance" : "Switch to Dark Obsidian appearance",
                iconName: model.theme.isDark ? "sun.max.fill" : "moon.fill",
                shortcutBadge: "Theme",
                action: {
                    model.toggleTheme()
                    model.isCommandBarPresented = false
                }
            ),
            MorphCommandItem(
                id: "pin_unpin_island",
                title: "Pin / Unpin Island",
                subtitle: model.isPinned ? "Allow island to auto-collapse on cursor exit" : "Keep island locked open on screen",
                iconName: model.isPinned ? "lock.open.fill" : "lock.fill",
                shortcutBadge: "⌘P",
                action: {
                    model.togglePin()
                    model.isCommandBarPresented = false
                }
            )
        ]
    }
    
    public func filteredCommands(for query: String) -> [MorphCommandItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return allCommands }
        return allCommands.filter {
            $0.title.lowercased().contains(trimmed) ||
            $0.subtitle.lowercased().contains(trimmed) ||
            $0.shortcutBadge.lowercased().contains(trimmed)
        }
    }
    
    private var visibleCommands: [MorphCommandItem] {
        filteredCommands(for: searchQuery)
    }
    
    public var body: some View {
        ZStack(alignment: .top) {
            // Subtle backdrop click catcher
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(theme.canvasBackground.opacity(0.94))
                .onTapGesture {
                    dismissCommandBar()
                }
            
            VStack(spacing: 6) {
                // Search Input Bar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(theme.textSecondary)
                    
                    TextField("Type a command or search actions...", text: $searchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(theme.textPrimary)
                        .focused($isSearchFocused)
                        .onSubmit {
                            executeSelectedCommand()
                        }
                    
                    if !searchQuery.isEmpty {
                        Button(action: {
                            searchQuery = ""
                            selectedIndex = 0
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(theme.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Text("ESC")
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .foregroundColor(theme.badgeText)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(theme.badgeBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        .onTapGesture {
                            dismissCommandBar()
                        }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(theme.surfaceInset)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(theme.focusRingBorder, lineWidth: 1)
                )
                
                // Filtered Command List
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 3) {
                            let items = visibleCommands
                            if items.isEmpty {
                                Text("No matching commands")
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundColor(theme.textTertiary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.vertical, 18)
                            } else {
                                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                                    let isSelected = index == min(selectedIndex, max(0, items.count - 1))
                                    Button(action: {
                                        MorphHaptics.generic()
                                        item.action()
                                    }) {
                                        HStack(spacing: 8) {
                                            Image(systemName: item.iconName)
                                                .font(.system(size: 10.5, weight: .semibold))
                                                .foregroundColor(isSelected ? theme.activePillText : theme.textPrimary)
                                                .frame(width: 20, height: 20)
                                                .background(
                                                    Circle()
                                                        .fill(isSelected ? theme.activePillText.opacity(0.14) : theme.cardBackground)
                                                )
                                            
                                            VStack(alignment: .leading, spacing: 1) {
                                                Text(item.title)
                                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                                    .foregroundColor(isSelected ? theme.activePillText : theme.textPrimary)
                                                    .lineLimit(1)
                                                
                                                Text(item.subtitle)
                                                    .font(.system(size: 9, weight: .regular))
                                                    .foregroundColor(isSelected ? theme.activePillText.opacity(0.75) : theme.textSecondary)
                                                    .lineLimit(1)
                                            }
                                            
                                            Spacer(minLength: 4)
                                            
                                            Text(item.shortcutBadge)
                                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                                .foregroundColor(isSelected ? theme.activePillText : theme.badgeText)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(
                                                    Capsule()
                                                        .fill(isSelected ? theme.activePillText.opacity(0.18) : theme.badgeBackground)
                                                )
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 5)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .fill(isSelected ? theme.activePillBackground : theme.cardBackgroundSubtle)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .id(item.id)
                                    .onHover { hovering in
                                        if hovering {
                                            selectedIndex = index
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .onChange(of: selectedIndex) { _, newIdx in
                        let items = visibleCommands
                        if items.indices.contains(newIdx) {
                            withAnimation(.easeOut(duration: 0.12)) {
                                proxy.scrollTo(items[newIdx].id, anchor: .center)
                            }
                        }
                    }
                }
            }
            .padding(8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(theme.activeBorder, lineWidth: 0.8)
        )
        .shadow(color: theme.windowShadow, radius: 14, x: 0, y: 6)
        .onAppear {
            selectedIndex = 0
            isSearchFocused = true
        }
        .onChange(of: searchQuery) { _, _ in
            selectedIndex = 0
        }
        .onKeyPress(.downArrow) {
            let count = visibleCommands.count
            if count > 0 {
                selectedIndex = (selectedIndex + 1) % count
                MorphHaptics.alignment()
            }
            return .handled
        }
        .onKeyPress(.upArrow) {
            let count = visibleCommands.count
            if count > 0 {
                selectedIndex = (selectedIndex - 1 + count) % count
                MorphHaptics.alignment()
            }
            return .handled
        }
        .onKeyPress(.escape) {
            dismissCommandBar()
            return .handled
        }
    }
    
    private func executeSelectedCommand() {
        let items = visibleCommands
        guard !items.isEmpty else { return }
        let idx = min(max(0, selectedIndex), items.count - 1)
        MorphHaptics.generic()
        items[idx].action()
    }
    
    private func dismissCommandBar() {
        withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
            model.isCommandBarPresented = false
        }
    }
}

