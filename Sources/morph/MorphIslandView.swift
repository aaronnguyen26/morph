import SwiftUI
import AppKit
import UniformTypeIdentifiers

public struct MorphIslandView: View {
    @ObservedObject var model: NotchModel
    @ObservedObject private var shortcutManager = ShortcutManager.shared
    var onMouseEnter: () -> Void
    var onMouseExit: () -> Void
    @State private var isNotchDragTargeted: Bool = false
    @State private var hoveredTab: MorphTab? = nil
    
    // Calendar Add Event State
    @State private var isAddingGlassEvent: Bool = false
    @State private var draftEventType: String = "Event"
    @State private var draftEventTitle: String = ""
    @State private var draftEventStartDate: Date = Date()
    @State private var draftEventEndDate: Date = Date()
    @State private var draftEventDuration: Int = 30
    @State private var draftEventHour: Int = 9
    @State private var draftEventMinute: Int = 0
    @State private var draftEventIsAllDay: Bool = false
    @State private var draftEventHasMeet: Bool = false
    @State private var draftEventLocation: String = ""
    @State private var draftEventDescription: String = ""
    @State private var draftEventCalendarId: String = ""
    @State private var draftEventCalendarName: String = ""
    @State private var draftEventColorHex: String = "#3b6fb5"
    @FocusState private var isSpotlightFocused: Bool
    @FocusState private var isPillEditFocused: Bool
    @FocusState private var isGlassMusicSearchFocused: Bool
    @FocusState private var isGlassPromptFocused: Bool
    @State private var isAddingAdaptiveProfileEntry: Bool = false
    @State private var newAdaptiveQuestionText: String = ""
    @State private var newAdaptiveAnswerText: String = ""
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
        if model.isGlassIslandEnabled {
            return model.glassIslandRadius
        }
        switch model.islandState {
        case .timerPopup:
            return 24
        case .spotlightBar:
            return 19
        case .fullExpanded:
            return 28
        case .extendedPill, .resting:
            return 18
        }
    }
    
    private var topRadius: CGFloat {
        if model.isGlassIslandEnabled {
            return model.glassIslandRadius
        }
        switch model.islandState {
        case .timerPopup:
            return 24
        case .spotlightBar:
            return 19
        case .fullExpanded:
            return 28
        case .extendedPill, .resting:
            return 18
        }
    }
    
    // Notch blind-spot geometry
    private var notchBlindWidth: CGFloat {
        max(model.idleWidth + 10, 185)
    }
    
    private var notchBlindHeight: CGFloat {
        max(model.idleHeight + 2, 34)
    }
    
    private var baseNotchShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: topRadius,
            bottomLeadingRadius: cornerRadius,
            bottomTrailingRadius: cornerRadius,
            topTrailingRadius: topRadius,
            style: .continuous
        )
    }
    
    private var liquidGlassBaseFill: Color {
        if model.islandState == .spotlightBar || model.islandState == .timerPopup {
            return model.theme.isDark ? Color.black.opacity(0.85) : Color(white: 0.12).opacity(0.85)
        } else if model.isExpanded {
            return model.theme.isDark ? Color.black.opacity(0.78) : Color(white: 0.10).opacity(0.84)
        } else if model.isCompactActive {
            return model.theme.isDark ? Color.black.opacity(0.88) : Color(white: 0.12).opacity(0.88)
        } else if model.isHovered {
            return Color.black
        } else {
            return model.theme.isDark ? Color.black.opacity(0.18) : Color.white.opacity(0.12)
        }
    }
    
    private var islandBorderGradient: LinearGradient {
        if model.dropShelf.isDraggingOverNotch {
            return LinearGradient(
                colors: [model.theme.dropTargetBorder, model.theme.dropTargetBorder.opacity(0.65)],
                startPoint: .top,
                endPoint: .bottom
            )
        } else if model.islandState == .resting && !model.isHovered {
            return LinearGradient(
                colors: [
                    Color.white.opacity(model.theme.isDark ? 0.48 : 0.60),
                    Color.white.opacity(model.theme.isDark ? 0.24 : 0.35),
                    Color.white.opacity(model.theme.isDark ? 0.16 : 0.25)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if model.isExpanded {
            return LinearGradient(
                stops: [
                    .init(color: Color.white.opacity(model.theme.isDark ? 0.44 : 0.65), location: 0.0),
                    .init(color: Color.white.opacity(model.theme.isDark ? 0.18 : 0.30), location: 0.28),
                    .init(color: Color.white.opacity(model.theme.isDark ? 0.06 : 0.12), location: 0.68),
                    .init(color: Color.white.opacity(model.theme.isDark ? 0.22 : 0.45), location: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [
                    Color.white.opacity(model.theme.isDark ? 0.42 : 0.65),
                    Color.white.opacity(model.theme.isDark ? 0.16 : 0.35),
                    Color.white.opacity(model.theme.isDark ? 0.05 : 0.15),
                    Color.white.opacity(model.theme.isDark ? 0.22 : 0.45)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    private var islandBorderStyle: StrokeStyle {
        StrokeStyle(
            lineWidth: model.dropShelf.isDraggingOverNotch ? 1.5 : 1.0,
            dash: model.dropShelf.isDraggingOverNotch ? [6, 3] : []
        )
    }
    
    private var islandShadowColor: Color {
        if model.dropShelf.isDraggingOverNotch {
            return model.theme.dropTargetGlow
        } else if model.islandState == .spotlightBar || model.islandState == .timerPopup || model.isExpanded || model.isCompactActive || model.isHovered {
            return Color.black.opacity(0.40)
        } else if model.islandState == .resting && !model.isHovered {
            return Color.black.opacity(0.28)
        } else {
            return Color.clear
        }
    }
    
    @ViewBuilder
    private var islandBackgroundSurfaceView: some View {
        if model.isGlassIslandEnabled {
            if model.glassIslandState == .idle {
                glassIdleBackgroundSurface
            } else {
                glassExpandedBackgroundSurface
            }
        } else {
            baseNotchShape
                .fill(liquidGlassBaseFill)
                .background(
                    Group {
                        if model.islandState != .resting || model.isHovered {
                            baseNotchShape.fill(.ultraThinMaterial)
                        }
                    }
                )
                .overlay(
                    Group {
                        if model.isExpanded {
                            LinearGradient(
                                stops: [
                                    .init(color: Color.white.opacity(model.theme.isDark ? 0.24 : 0.38), location: 0.0),
                                    .init(color: Color.white.opacity(model.theme.isDark ? 0.06 : 0.12), location: 0.25),
                                    .init(color: Color.clear, location: 1.0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 48)
                            .clipShape(baseNotchShape)
                            .allowsHitTesting(false)
                        } else if model.islandState != .resting || model.isHovered {
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(model.theme.isDark ? 0.14 : 0.25),
                                    Color.white.opacity(0.03),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: min(currentHeight * 0.40, 28))
                            .clipShape(baseNotchShape)
                            .allowsHitTesting(false)
                        }
                    }
                )
                .overlay(
                    backgroundImageView
                        .clipShape(baseNotchShape)
                )
                .overlay(
                    baseNotchShape
                        .stroke(islandBorderGradient, style: islandBorderStyle)
                )
                .shadow(
                    color: model.isExpanded ? Color.black.opacity(0.48) : islandShadowColor,
                    radius: (model.islandState == .timerPopup || model.isExpanded) ? 28 : ((model.islandState == .resting && !model.isHovered) ? 5 : 10),
                    x: 0,
                    y: (model.islandState == .timerPopup || model.isExpanded) ? 12 : ((model.islandState == .resting && !model.isHovered) ? 2 : 4)
                )
                .shadow(
                    color: model.isExpanded ? Color.black.opacity(0.22) : Color.clear,
                    radius: 8,
                    x: 0,
                    y: 2
                )
        }
    }

    private var glassIdleBackgroundSurface: some View {
        baseNotchShape
            .fill(Color(red: 18/255, green: 18/255, blue: 28/255).opacity(0.04))
            .background(baseNotchShape.fill(.ultraThinMaterial.opacity(0.35)))
            .overlay(
                LinearGradient(
                    stops: [
                        .init(color: Color.white.opacity(0.06), location: 0.0),
                        .init(color: Color.white.opacity(0.01), location: 0.45),
                        .init(color: Color.white.opacity(0.04), location: 1.0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(baseNotchShape)
                .allowsHitTesting(false)
            )
            .overlay(
                baseNotchShape
                    .stroke(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(0.26), location: 0.0),
                                .init(color: Color.white.opacity(0.10), location: 0.28),
                                .init(color: Color.white.opacity(0.03), location: 0.55),
                                .init(color: Color.white.opacity(0.12), location: 0.80),
                                .init(color: Color.white.opacity(0.20), location: 1.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.9
                    )
            )
            .shadow(color: Color.black.opacity(0.16), radius: 6, x: 0, y: 2)
    }
    
    private var glassExpandedBackgroundSurface: some View {
        baseNotchShape
            .fill(Color(red: 26/255, green: 22/255, blue: 58/255).opacity(0.34))
            .background(baseNotchShape.fill(.ultraThinMaterial))
            .overlay(
                LinearGradient(
                    stops: [
                        .init(color: Color.white.opacity(0.22), location: 0.0),
                        .init(color: Color.white.opacity(0.05), location: 0.45),
                        .init(color: Color.white.opacity(0.12), location: 1.0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(baseNotchShape)
                .allowsHitTesting(false)
            )
            .overlay(
                baseNotchShape
                    .stroke(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(0.95), location: 0.0),
                                .init(color: Color.white.opacity(0.18), location: 0.28),
                                .init(color: Color.white.opacity(0.06), location: 0.55),
                                .init(color: Color.white.opacity(0.35), location: 0.80),
                                .init(color: Color.white.opacity(0.80), location: 1.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
            )
            .shadow(color: Color(hex: model.glassIslandTintHex).opacity(0.35), radius: 18, x: 0, y: 8)
            .shadow(color: Color.black.opacity(0.40), radius: 12, x: 0, y: 4)
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                // Background Base Shape: Apple Liquid Glass surface
                islandBackgroundSurfaceView
                
                // Content: Glass Island
                if model.isGlassIslandEnabled {
                    glassIslandRootContentView
                } else {
                    Group {
                        switch model.islandState {
                        case .spotlightBar:
                            spotlightTypingBarView
                                .transition(.opacity.animation(.easeInOut(duration: 0.22).delay(0.06)))
                        case .timerPopup:
                            compactTimerPopupView
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.96, anchor: .top).combined(with: .opacity),
                                    removal: .scale(scale: 0.96, anchor: .top).combined(with: .opacity)
                                ))
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
            .onTapGesture {
                if model.isGlassIslandEnabled && model.glassIslandState == .idle {
                    withAnimation(MorphUniversalAnimation.stateExpansion) {
                        model.setGlassIslandState(model.contextualOpenState)
                    }
                }
            }
            .onDrop(of: [.fileURL], isTargeted: $isNotchDragTargeted) { providers in
                handleNotchFileDrop(providers: providers)
            }
            .onChange(of: isNotchDragTargeted) { _, targeted in
                if model.isDropContextAwareEnabled && model.isFeatureEnabled(.drops) {
                    model.dropShelf.isDraggingOverNotch = targeted
                }
            }
            .animation(MorphUniversalAnimation.stateExpansion, value: model.glassIslandState)
            .animation(MorphUniversalAnimation.stateElongation, value: model.glassIslandWidth)
            .animation(MorphUniversalAnimation.stateExpansion, value: model.glassIslandHeight)
            .animation(model.isExpanded ? MorphUniversalAnimation.stateExpansion : MorphUniversalAnimation.stateRetraction, value: model.isExpanded)
            .animation(model.isCompactActive ? MorphUniversalAnimation.stateElongation : MorphUniversalAnimation.stealthRetraction, value: model.isCompactActive)
            .animation(MorphUniversalAnimation.tabSwitch, value: model.selectedTab)
            .animation(MorphUniversalAnimation.stateExpansion, value: model.activeContextFeature)
            .animation(model.islandState == .resting ? MorphUniversalAnimation.stealthRetraction : MorphUniversalAnimation.stateExpansion, value: model.islandState)
            .animation(model.isSpotlightBarActive ? MorphUniversalAnimation.stateElongation : MorphUniversalAnimation.stealthRetraction, value: model.isSpotlightBarActive)
            .animation(MorphUniversalAnimation.stateExpansion, value: model.isTimerPopupActive)
            
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
    
    private func handleNotchFileDrop(providers: [NSItemProvider]) -> Bool {
        guard model.isFeatureEnabled(.drops) && model.isDropContextAwareEnabled else { return false }
        var didLoadAny = false
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let fileURL = url {
                        Task { @MainActor in
                            model.dropShelf.stageFile(url: fileURL)
                            if model.isGlassIslandEnabled {
                                MorphHaptics.levelChange()
                                model.setGlassIslandState(.drops)
                            } else {
                                model.openContextualFeature(.dropShelf)
                            }
                        }
                    }
                }
                didLoadAny = true
            }
        }
        return didLoadAny
    }
    
    private var spotlightIconName: String {
        switch MorphSpotlightCommandParser.detectType(from: model.spotlightQuery) {
        case .music:
            return "music.note"
        case .note:
            return "note.text"
        case .calendar:
            return "calendar"
        case .timer:
            return "timer"
        case .answer:
            return "sparkles"
        case .navigation, .unknown:
            return "magnifyingglass"
        }
    }

    private func handleSpotlightCloseOrClear() {
        MorphHaptics.generic()
        model.spotlightQuery = ""
        isSpotlightFocused = false
        if let ctrl = MorphController.shared {
            ctrl.dismissToStealth()
        } else {
            withAnimation(MorphUniversalAnimation.stealthRetraction) {
                model.resetTransientStateOnCollapse()
            }
        }
    }

    // MARK: - Spotlight Horizontal Typing Bar (Horizontal expansion on hover: strictly for typing with right 'X' control)
    private var spotlightTypingBarView: some View {
        Group {
            if model.activeBackgroundTaskPill != .none {
                backgroundTaskPillView
            } else if model.isShowingDirectAnswer {
                directAnswerView
            } else {
                HStack(spacing: 8) {
                    // Left interactive group: Mascot, Icon, and Search Field
                    HStack(spacing: 8) {
                        // Active Living 3D Morphy Mascot (To the left of glass symbol)
                        MorphyMascotView(model: model, style: .spotlightPill)
                            .padding(.leading, 8)
                            .transition(.scale(scale: 0.85).combined(with: .opacity))
                        
                        // Glass search symbol / Dynamic Icon
                        Image(systemName: spotlightIconName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color.white.opacity(0.65))
                            .animation(.easeInOut(duration: 0.15), value: spotlightIconName)
                        
                        // Text field strictly for typing
                        TextField(
                            "Try \"focus 25\", \"play\", \"what's on today\", \"note\"...",
                            text: $model.spotlightQuery
                        )
                        .focused($isSpotlightFocused)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(.white)
                        .tint(.white)
                        .onSubmit {
                            model.handleSpotlightSubmit()
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        isSpotlightFocused = true
                        if let ctrl = MorphController.shared, !MorphEnvironment.isTestingEnvironment {
                            NSApp.activate(ignoringOtherApps: true)
                            ctrl.panel.makeKeyAndOrderFront(nil)
                        }
                    }
                    
                    Spacer(minLength: 0)
                    
                    // Interactive 'X' Button on Right of Spotlight Pill with generous tap target
                    Button(action: {
                        handleSpotlightCloseOrClear()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundColor(Color.white.opacity(0.70))
                            .frame(width: 24, height: 24)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.14))
                            )
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    .help("Close (ESC)")
                    .padding(.trailing, 8)
                }
                .frame(width: model.spotlightBarWidth, height: model.spotlightBarHeight)
                .background(
                    // Invisible 100% hit-testable shield ensuring every point across the lengthened bar is clickable
                    Color.black.opacity(0.001)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            isSpotlightFocused = true
                            if let ctrl = MorphController.shared, !MorphEnvironment.isTestingEnvironment {
                                NSApp.activate(ignoringOtherApps: true)
                                ctrl.panel.makeKeyAndOrderFront(nil)
                            }
                        }
                )
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                isSpotlightFocused = true
                if let ctrl = MorphController.shared, !MorphEnvironment.isTestingEnvironment {
                    NSApp.activate(ignoringOtherApps: true)
                    ctrl.panel.makeKeyAndOrderFront(nil)
                }
            }
        }
        .onChange(of: model.isSpotlightBarActive) { _, active in
            if active {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                    isSpotlightFocused = true
                    if let ctrl = MorphController.shared, !MorphEnvironment.isTestingEnvironment {
                        NSApp.activate(ignoringOtherApps: true)
                        ctrl.panel.makeKeyAndOrderFront(nil)
                    }
                }
            } else {
                isSpotlightFocused = false
            }
        }
    }
    
    // MARK: - Lengthened Spotlight Background Task Pill View (Direct interactive controls)
    private var backgroundTaskPillView: some View {
        HStack(spacing: 8) {
            MorphyMascotView(model: model, style: .spotlightPill)
                .padding(.leading, 8)
            
            switch model.activeBackgroundTaskPill {
            case .calendar(let title, let timeText, let meetLink, _):
                calendarPillContent(title: title, timeText: timeText, meetLink: meetLink)
                
            case .timer(let title, let minutes):
                timerPillContent(title: title, minutes: minutes)
                
            case .media(let trackTitle, let artist):
                mediaPillContent(trackTitle: trackTitle, artist: artist)
                
            case .note(let previewText):
                notePillContent(previewText: previewText)
                
            case .directAnswer(let text, let icon):
                directAnswerPillContent(text: text, icon: icon)
                
            case .none:
                EmptyView()
            }
        }
        .frame(width: model.spotlightBarWidth, height: model.spotlightBarHeight)
        .background(
            Color.black.opacity(0.001)
                .contentShape(Rectangle())
        )
    }
    
    private func calendarPillContent(title: String, timeText: String, meetLink: String?) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "calendar")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(red: 0.20, green: 0.60, blue: 1.0))
            
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                if !timeText.isEmpty {
                    Text(timeText)
                        .font(.system(size: 10, weight: .regular, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.65))
                        .lineLimit(1)
                }
            }
            
            Spacer(minLength: 4)
            
            if let link = meetLink, let url = URL(string: link) {
                Button(action: {
                    MorphHaptics.generic()
                    NSWorkspace.shared.open(url)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "video.fill")
                            .font(.system(size: 9, weight: .bold))
                        Text("Join")
                            .font(.system(size: 10.5, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color(red: 0.04, green: 0.52, blue: 1.0).opacity(0.40))
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.35), lineWidth: 0.75)
                    )
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .help("Join Video Call")
            }
            
            Button(action: {
                MorphHaptics.generic()
                model.openFeature(.calendar)
            }) {
                Text("View")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.85))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.12))
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.20), lineWidth: 0.75)
                    )
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .help("Open Full Calendar")
            
            Button(action: {
                MorphHaptics.generic()
                model.dismissBackgroundTaskPill()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.70))
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Color.white.opacity(0.14)))
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .help("Close (ESC)")
            .padding(.trailing, 8)
        }
    }
    
    private func timerPillContent(title: String, minutes: Int) -> some View {
        HStack(spacing: 7) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.18), lineWidth: 2)
                    .frame(width: 14, height: 14)
                
                Circle()
                    .trim(from: 0, to: CGFloat(model.pomodoro.progress))
                    .stroke(
                        LinearGradient(
                            colors: [Color.orange, Color.yellow],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 14, height: 14)
            }
            
            Text(model.pomodoro.formattedTime)
                .font(.system(size: 12.5, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            
            Text(model.customTimerTitle.uppercased())
                .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                .foregroundColor(Color.white.opacity(0.70))
                .lineLimit(1)
            
            Spacer(minLength: 4)
            
            Button(action: {
                MorphHaptics.generic()
                model.pomodoro.toggle()
            }) {
                Image(systemName: model.pomodoro.isRunning ? "pause.fill" : "play.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Color.white.opacity(0.16)))
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .help(model.pomodoro.isRunning ? "Pause Timer" : "Resume Timer")
            
            Button(action: {
                MorphHaptics.generic()
                model.addFiveMinutesToTimer()
            }) {
                Text("+5m")
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.90))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3.5)
                    .background(Capsule().fill(Color.white.opacity(0.12)))
                    .overlay(Capsule().stroke(Color.white.opacity(0.20), lineWidth: 0.75))
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .help("Add 5 minutes")
            
            Button(action: {
                MorphHaptics.generic()
                model.stopFocusTimerFromPill()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.70))
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Color.white.opacity(0.14)))
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .help("Stop Timer & Close")
            .padding(.trailing, 8)
        }
    }
    
    private func mediaPillContent(trackTitle: String, artist: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "music.note")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(red: 1.0, green: 0.25, blue: 0.45))
            
            HStack(spacing: 4) {
                Text(trackTitle)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                if !artist.isEmpty {
                    Text("• \(artist)")
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.65))
                        .lineLimit(1)
                }
            }
            
            Spacer(minLength: 4)
            
            Button(action: {
                MorphHaptics.generic()
                model.media.previousTrack()
            }) {
                Image(systemName: "backward.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.75))
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .help("Previous Track (F7, ⇧P, ⌘[)")
            .accessibilityLabel("Previous Track")
            
            Button(action: {
                MorphHaptics.generic()
                model.media.togglePlayPause()
            }) {
                Image(systemName: model.media.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Color.white.opacity(0.16)))
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .help(model.media.isPlaying ? "Pause Music (F8, Space, K, ⌘⏎)" : "Play Music (F8, Space, K, ⌘⏎)")
            .accessibilityLabel(model.media.isPlaying ? "Pause Music" : "Play Music")
            
            Button(action: {
                MorphHaptics.generic()
                model.media.nextTrack()
            }) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.75))
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .help("Next Track (F9, ⇧N, ⌘])")
            .accessibilityLabel("Next Track")
            
            Button(action: {
                MorphHaptics.generic()
                model.dismissBackgroundTaskPill()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.70))
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Color.white.opacity(0.14)))
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .help("Close")
            .padding(.trailing, 8)
        }
    }
    
    private func notePillContent(previewText: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "note.text")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundColor(Color(red: 1.0, green: 0.85, blue: 0.25))
            
            Text("Saved: \"\(previewText)\"")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
            
            Spacer(minLength: 4)
            
            Button(action: {
                MorphHaptics.generic()
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(previewText, forType: .string)
            }) {
                HStack(spacing: 3) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 8.5, weight: .bold))
                    Text("Copy")
                        .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                }
                .foregroundColor(Color.white.opacity(0.90))
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.white.opacity(0.12)))
                .overlay(Capsule().stroke(Color.white.opacity(0.20), lineWidth: 0.75))
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .help("Copy to Clipboard")
            
            Button(action: {
                MorphHaptics.generic()
                model.openFeature(.notes)
            }) {
                Text("View")
                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.85))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.white.opacity(0.12)))
                    .overlay(Capsule().stroke(Color.white.opacity(0.20), lineWidth: 0.75))
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .help("Open Notes")
            
            Button(action: {
                MorphHaptics.generic()
                model.dismissBackgroundTaskPill()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.70))
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Color.white.opacity(0.14)))
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .help("Close")
            .padding(.trailing, 8)
        }
    }
    
    private func directAnswerPillContent(text: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color.white.opacity(0.90))
            
            Text(text)
                .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
            
            Spacer(minLength: 4)
            
            Button(action: {
                MorphHaptics.generic()
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(text, forType: .string)
            }) {
                HStack(spacing: 3) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 8.5, weight: .bold))
                    Text("Copy")
                        .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                }
                .foregroundColor(Color.white.opacity(0.90))
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.white.opacity(0.12)))
                .overlay(Capsule().stroke(Color.white.opacity(0.20), lineWidth: 0.75))
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .help("Copy Answer")
            
            Button(action: {
                MorphHaptics.generic()
                model.dismissBackgroundTaskPill()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.70))
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Color.white.opacity(0.14)))
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .help("Close")
            .padding(.trailing, 8)
        }
    }
    
    // MARK: - Direct Answer Pill View
    private var directAnswerView: some View {
        directAnswerPillContent(text: model.directAnswerText, icon: model.directAnswerIcon)
    }
    
    // MARK: - Compact Shrunk Timer Popup (Horizontal width shrunk to 320 pt)
    private var compactTimerPopupView: some View {
        VStack(spacing: 8) {
            // Header Row: Flame Icon + Personalized Custom Title + Sprint Badge
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                    Text(model.customTimerTitle.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.85))
                        .lineLimit(1)
                }
                
                Spacer()
                
                Text("\(model.requestedTimerMinutes)m SPRINT")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2.5)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.12))
                    )
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            
            // Central Timer Display: Large Digital Countdown
            VStack(spacing: 4) {
                Text(model.pomodoro.formattedTime)
                    .font(.system(size: 32, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.white)
                
                // Progress Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.15))
                            .frame(height: 3)
                        Capsule()
                            .fill(Color.white)
                            .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(model.pomodoro.progress))), height: 3)
                    }
                }
                .frame(height: 3)
                .padding(.horizontal, 24)
            }
            
            // Bottom Controls: Play/Pause, Reset, Dismiss hint
            HStack(spacing: 16) {
                Button(action: {
                    model.pomodoro.toggle()
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: model.pomodoro.isRunning ? "pause.fill" : "play.fill")
                            .font(.system(size: 11, weight: .semibold))
                        Text(model.pomodoro.isRunning ? "Pause" : "Start")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.white))
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    model.pomodoro.reset()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10, weight: .semibold))
                        Text("Reset")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(Color.white.opacity(0.85))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.white.opacity(0.12)))
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    model.dismissTimerPopup()
                }) {
                    Text("ESC")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.50))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.white.opacity(0.20), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 10)
        }
        .frame(width: model.timerPopupWidth, height: model.timerPopupHeight)
    }
    
    // MARK: - 1. Idle Transparent Dynamic Island Outline (No text, no dots, pure whisper outline)
    private var idleFlushNotchView: some View {
        Color.clear
            .frame(width: model.idleWidth, height: model.idleHeight)
            .contentShape(Rectangle())
            .onTapGesture {
                if model.interactionMode == .spotlightBar {
                    if let ctrl = MorphController.shared {
                        ctrl.expandPanel()
                    }
                    withAnimation(MorphUniversalAnimation.stateElongation) {
                        model.isSpotlightBarActive = true
                    }
                    if let ctrl = MorphController.shared, !MorphEnvironment.isTestingEnvironment {
                        ctrl.panel.makeKey()
                    }
                } else {
                    model.syncExpandedFeatureWithActiveContext()
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                        model.isExpanded = true
                    }
                }
            }
    }
    
    // MARK: - Inline Timer Editor in Pill (Direct editing of task & duration right in the 2nd screenshot HUD)
    private var inlineTimerEditorView: some View {
        HStack(spacing: 6) {
            Image(systemName: "timer")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Color.white.opacity(0.60))
                .padding(.leading, 12)
            
            TextField(
                "Time (e.g. 25m)...",
                text: $model.pillEditingText
            )
            .focused($isPillEditFocused)
            .textFieldStyle(.plain)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .multilineTextAlignment(.center)
            .foregroundColor(.white)
            .tint(.white)
            .onSubmit {
                model.commitPillTimerEdit()
            }
            
            // Done Button
            Button(action: {
                model.commitPillTimerEdit()
            }) {
                Image(systemName: "checkmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.black)
                    .frame(width: 18, height: 18)
                    .background(Color.white)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Save timer changes (Return)")
            
            // Cancel Button
            Button(action: {
                model.cancelPillTimerEdit()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.70))
                    .frame(width: 20, height: 20)
                    .background(Color.white.opacity(0.14))
                    .clipShape(Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .help("Cancel editing (ESC)")
            .padding(.trailing, 8)
        }
        .frame(width: model.compactWidth, height: model.idleHeight)
        .contentShape(Rectangle())
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isPillEditFocused = true
            }
        }
        .onChange(of: model.isEditingTimerInPill) { _, editing in
            if editing {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    isPillEditFocused = true
                }
            } else {
                isPillEditFocused = false
            }
        }
    }

    // MARK: - Centered Focus Timer Pill HUD (Middle-centered timer display + ✕ on right)
    private var centeredPomodoroPillView: some View {
        HStack(spacing: 0) {
            // Left balanced spacer anchor matching right ✕ button visual width (38pt + 10pt = 48pt) for absolute geometric centering
            Color.clear
                .frame(width: 48, height: model.idleHeight)
            
            Spacer(minLength: 0)
            
            // Centered Timer Display: Progress ring + Monospaced formatted time
            HStack(spacing: 7) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.18), lineWidth: 2)
                        .frame(width: 13.5, height: 13.5)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(model.pomodoro.progress))
                        .stroke(
                            LinearGradient(
                                colors: [Color.white, Color.white.opacity(0.4)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 13.5, height: 13.5)
                }
                
                Text(model.pomodoro.formattedTime)
                    .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }
            
            Spacer(minLength: 0)
            
            // Right Side: Strictly the ✕ close / stop button
            Button(action: {
                model.stopFocusTimer()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.70))
                    .frame(width: 20, height: 20)
                    .background(Color.white.opacity(0.14))
                    .clipShape(Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .help("Close / Stop Timer (⌘R)")
            .frame(width: 38, height: model.idleHeight, alignment: .trailing)
            .padding(.trailing, 8)
        }
        .frame(width: model.compactWidth, height: model.idleHeight)
    }

    // MARK: - 2. Compact Active Notch View (Independent Dynamic Island HUD)
    private var compactActiveNotchView: some View {
        VStack(spacing: 0) {
            if model.isEditingTimerInPill {
                inlineTimerEditorView
            } else if model.compactHUDMode == .pomodoroOnly {
                centeredPomodoroPillView
            } else {
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
        }
        .frame(width: model.compactWidth, height: model.compactHeight)
        .contentShape(Rectangle())
        .onTapGesture {
            if model.compactHUDMode == .pomodoroOnly && !model.isEditingTimerInPill {
                model.startEditingTimerInPill()
            } else if model.compactHUDMode != .pomodoroOnly && !model.isEditingTimerInPill {
                model.syncExpandedFeatureWithActiveContext()
                withAnimation(MorphUniversalAnimation.stateExpansion) {
                    model.isExpanded = true
                }
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
    
    private var greetingGreetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let name = model.supabase.currentUser.firstName.isEmpty ? "Minh" : model.supabase.currentUser.firstName
        if hour < 12 {
            return "Good morning, \(name)"
        } else if hour < 17 {
            return "Good afternoon, \(name)"
        } else {
            return "Good evening, \(name)"
        }
    }
    
    private var stageTelemetrySubtitle: String {
        if model.pomodoro.isRunning {
            return "\(model.customTimerTitle) — \(model.pomodoro.formattedTime)"
        } else if model.media.isPlaying {
            return "Now Playing — \(model.media.trackTitle.isEmpty ? "YouTube Music" : model.media.trackTitle)"
        } else {
            return "\(model.screenName) • Schedule Clear"
        }
    }

    // MARK: - Glass Island HTML Design System Implementation
    @ViewBuilder
    private var glassIslandRootContentView: some View {
        if model.glassIslandState == .idle {
            glassIdleView
                .transition(.opacity)
        } else {
            VStack(spacing: 0) {
                // Top Prompt Bar (Pinned across all expanded states: height 40 pt)
                glassPromptBarView
                    .padding(.top, 8)
                    .padding(.horizontal, 8)
                
                // Prompt Peek Preview (when lengthened UI is active and text is present)
                if model.glassIslandState == .prompt && model.isPromptPeekActive {
                    glassPromptPeekView
                        .padding(.top, 6)
                        .padding(.horizontal, 8)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .top)),
                            removal: .opacity
                        ))
                }

                // Smart Finder Live Results Drawer (directly below prompt bar / peek)
                if model.glassIslandState == .prompt && model.isSmartFinderPanelVisible {
                    GlassSmartFinderView(model: model)
                        .padding(.top, 8)
                        .padding(.horizontal, 8)
                        .padding(.bottom, 8)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.98, anchor: .top)),
                            removal: .opacity
                        ))
                }
                
                // Panel Content (for timer, calendar, music, notes, forms, reply)
                if model.glassIslandState != .prompt {
                    glassPanelView
                        .padding(.top, 8)
                        .padding(.horizontal, 8)
                        .padding(.bottom, 8)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.98, anchor: .top)),
                            removal: .opacity.combined(with: .scale(scale: 0.98, anchor: .top))
                        ))
                }
            }
        }
    }
    
    // MARK: - Idle Capsule View (176 x 38 pt resting, up to 280 pt with Live Activity)
    // MARK: - Idle Capsule View (176 x 38 pt resting, up to 410 pt with Live Activity)
    @ViewBuilder
    private var glassIdleView: some View {
        if model.dropShelf.isDraggingOverNotch {
            miniDragOverDropView
        } else {
            let hasDrops = model.isBackgroundDropActive
            let hasForm = model.isBackgroundFormActive
            let hasMusic = model.isGlassMusicPlaying && model.isFeatureEnabled(.music)
            let hasTimer = model.isGlassTimerActive && model.isFeatureEnabled(.timer)
            HStack(spacing: 8) {
                if hasDrops {
                    miniDropShelfView
                    if hasForm {
                        Rectangle()
                            .fill(Color.white.opacity(0.18))
                            .frame(width: 1, height: 14)
                        miniFormView
                    } else if hasMusic {
                        Rectangle()
                            .fill(Color.white.opacity(0.18))
                            .frame(width: 1, height: 14)
                        miniMusicView
                    } else if hasTimer {
                        Rectangle()
                            .fill(Color.white.opacity(0.18))
                            .frame(width: 1, height: 14)
                        miniTimerView
                    }
                } else if hasForm {
                    if hasMusic {
                        miniMusicView
                        Rectangle()
                            .fill(Color.white.opacity(0.18))
                            .frame(width: 1, height: 14)
                        miniFormView
                    } else if hasTimer {
                        miniTimerView
                        Rectangle()
                            .fill(Color.white.opacity(0.18))
                            .frame(width: 1, height: 14)
                        miniFormView
                    } else {
                        miniFormView
                    }
                } else if hasTimer && hasMusic {
                    miniTimerView
                    Rectangle()
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 1, height: 14)
                    miniMusicView
                } else if hasTimer {
                    miniTimerView
                } else if hasMusic {
                    miniMusicView
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(hex: "#cfd8ff").opacity(0.85))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
    }
    
    private var miniDragOverDropView: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.down.to.line.compact")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color(hex: model.featureTintColorHex(.drops)))
            
            Text("Drop to Stash")
                .font(.system(size: 11.5, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
    }
    
    private var miniDropShelfView: some View {
        HStack(spacing: 6) {
            Image(systemName: "tray.and.arrow.down.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(hex: model.featureTintColorHex(.drops)))
            
            Text("\(model.dropShelf.count) \(model.dropShelf.count == 1 ? "file" : "files")")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
            
            if model.dropShelf.isHoldModeActive {
                Image(systemName: "pin.fill")
                    .font(.system(size: 7.5, weight: .bold))
                    .foregroundColor(Color(hex: model.featureTintColorHex(.drops)))
            }
        }
        .padding(.horizontal, 8)
        .frame(maxHeight: .infinity)
        .contentShape(Rectangle())
        .onHover { hovering in
            if hovering {
                model.targetedHoverGlassState = .drops
            } else if model.targetedHoverGlassState == .drops {
                model.targetedHoverGlassState = nil
            }
        }
        .onTapGesture {
            MorphHaptics.levelChange()
            withAnimation(MorphUniversalAnimation.stateExpansion) {
                model.setGlassIslandState(.drops)
            }
        }
        .onDrag {
            guard model.dropShelf.stagedItems.count == 1, let firstItem = model.dropShelf.stagedItems.first else {
                return NSItemProvider()
            }
            model.dropShelf.startDragOut(for: firstItem)
            let provider = NSItemProvider(object: firstItem.url as NSURL)
            provider.suggestedName = firstItem.name
            return provider
        }
    }
    
    private var miniFormView: some View {
        let toastMsg = model.formTracker.deliveryToastMessage
        let hasToast = toastMsg != nil && !(toastMsg ?? "").isEmpty
        let isErrorToast = (toastMsg ?? "").localizedCaseInsensitiveContains("enable") ||
                           (toastMsg ?? "").localizedCaseInsensitiveContains("could not") ||
                           (toastMsg ?? "").localizedCaseInsensitiveContains("no matching") ||
                           (toastMsg ?? "").localizedCaseInsensitiveContains("no active") ||
                           (toastMsg ?? "").localizedCaseInsensitiveContains("grant") ||
                           (toastMsg ?? "").localizedCaseInsensitiveContains("blocks") ||
                           (toastMsg ?? "").localizedCaseInsensitiveContains("rejected") ||
                           (toastMsg ?? "").localizedCaseInsensitiveContains("click \"") ||
                           (toastMsg ?? "").localizedCaseInsensitiveContains("syncing")
        let iconName = hasToast
            ? (isErrorToast ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
            : "list.bullet.clipboard.fill"
        let formsGreen = Color(hex: model.featureTintColorHex(.forms))
        
        return HStack(spacing: 7) {
            HStack(spacing: 7) {
                Image(systemName: iconName)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(isErrorToast ? Color.white.opacity(0.92) : formsGreen)
                
                Text(miniFormStatusText)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                Spacer(minLength: 2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture {
                guard model.isFeatureEnabled(.forms) else { return }
                MorphHaptics.levelChange()
                withAnimation(MorphUniversalAnimation.stateExpansion) {
                    model.setGlassIslandState(.forms)
                }
            }
            
            Button(action: {
                MorphHaptics.levelChange()
                if miniActionIsAutofill {
                    _ = model.formTracker.autofillActiveForm()
                } else {
                    withAnimation(MorphUniversalAnimation.stateExpansion) {
                        model.setGlassIslandState(.forms)
                    }
                }
            }) {
                Text(miniActionLabel)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(miniActionIsAutofill ? Color(hex: "#08080a") : .white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(miniActionIsAutofill ? formsGreen : Color.white.opacity(0.14))
                    )
                    .overlay(
                        Capsule()
                            .stroke(miniActionIsAutofill ? formsGreen.opacity(0.65) : Color.white.opacity(0.28), lineWidth: 0.7)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onHover { hovering in
            if hovering {
                model.targetedHoverGlassState = .forms
            } else if model.targetedHoverGlassState == .forms {
                model.targetedHoverGlassState = nil
            }
        }
    }
    
    private var miniFormStatusText: String {
        if let toast = model.formTracker.deliveryToastMessage, !toast.isEmpty {
            return toast
        }
        if let session = model.formTracker.activeSession {
            let title = cleanPersonalizedTitle(session.formTitle)
            if !title.isEmpty {
                return title
            }
        }
        let detected = cleanPersonalizedTitle(model.formTracker.detectedFormTitle)
        if !detected.isEmpty {
            return detected
        }
        return "Google Form"
    }

    private var miniActionLabel: String {
        if miniActionIsAutofill {
            return "Autofill"
        }
        if let session = model.formTracker.activeSession {
            let answered = session.fields.filter { $0.isActionableQuestion && $0.isAnswered }.count
            let total = session.totalQuestions
            if answered > 0 && total > 0 {
                return "\(answered)/\(total)"
            }
        }
        return "Active"
    }

    private func cleanPersonalizedTitle(_ raw: String) -> String {
        let clean = DefaultApplicationFormDetector.stripServiceSuffixes(
            DefaultApplicationFormDetector.cleanTitle(raw)
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        
        let genericList = ["google forms", "google form", "untitled form", "polar", ""]
        if genericList.contains(clean.lowercased()) {
            return ""
        }
        return clean
    }
    
    private var miniActionIsAutofill: Bool {
        guard let session = model.formTracker.activeSession else { return false }
        let ready = model.formTracker.readyToAutofillCount
        let answered = session.fields.filter { $0.isActionableQuestion && $0.isAnswered }.count
        let total = session.totalQuestions
        return ready > 0 && (answered < 3 || answered < total)
    }
    
    private var glassPromptPeekView: some View {
        Group {
            if let peek = model.promptPeekInfo {
                Button(action: {
                    MorphHaptics.levelChange()
                    model.submitGlassIslandPrompt(model.glassPromptText)
                }) {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.14))
                                .frame(width: 26, height: 26)
                            Image(systemName: peek.icon)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Color(hex: model.glassIslandTintHex))
                        }
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text(peek.title)
                                .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            
                            Text(peek.subtitle)
                                .font(.system(size: 11.5, weight: .regular, design: .rounded))
                                .foregroundColor(Color.white.opacity(0.75))
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Text("↵")
                            .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                            .foregroundColor(Color.white.opacity(0.85))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2.5)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color.white.opacity(0.14))
                            )
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.white.opacity(0.09))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private var miniTimerView: some View {
        HStack(spacing: 7) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.30), lineWidth: 2.6)
                    .frame(width: 16, height: 16)
                Circle()
                    .trim(from: 0, to: model.glassTimerProgress)
                    .stroke(Color(hex: "#ff9a7a"), style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 16, height: 16)
            }
            Text(model.formattedGlassTimerTime)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .opacity(model.glassTimerStatus == .paused ? 0.6 : 1.0)
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            if hovering {
                model.targetedHoverGlassState = .timer
            } else if model.targetedHoverGlassState == .timer {
                model.targetedHoverGlassState = nil
            }
        }
        .onTapGesture {
            MorphHaptics.levelChange()
            withAnimation(MorphUniversalAnimation.stateExpansion) {
                model.setGlassIslandState(.timer)
            }
        }
    }
    
    private var miniMusicView: some View {
        HStack(spacing: 7) {
            ZStack {
                if let artUrl = model.media.albumArtURL, let url = URL(string: artUrl) {
                    AsyncImage(url: url) { phase in
                        if let img = phase.image {
                            img.resizable().aspectRatio(contentMode: .fill)
                        } else {
                            miniFallbackMusicTile
                        }
                    }
                    .frame(width: 18, height: 18)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                } else {
                    miniFallbackMusicTile
                }
            }
            .frame(width: 18, height: 18)
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(Color.white.opacity(0.35), lineWidth: 1)
            )
            GlassIslandEqualizerView(isPlaying: model.isGlassMusicPlaying, height: 13, barColor: Color(hex: "#ff9fcb"))
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            if hovering {
                model.targetedHoverGlassState = .music
            } else if model.targetedHoverGlassState == .music {
                model.targetedHoverGlassState = nil
            }
        }
        .onTapGesture {
            MorphHaptics.levelChange()
            withAnimation(MorphUniversalAnimation.stateExpansion) {
                model.setGlassIslandState(.music)
            }
        }
    }
    
    private var miniFallbackMusicTile: some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color(hex: "#ff5fa8"), Color(hex: "#6a5cff")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Image(systemName: "music.note")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
            )
    }
    
    // MARK: - Prompt Bar View (40 pt height, small glass pill)
    private var glassPromptBarView: some View {
        HStack(spacing: 6) {
            // Sparkle icon
            Image(systemName: "sparkles")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(hex: model.glassIslandTintHex))
                .frame(width: 28, height: 28)
            
            // Text Input
            TextField("Search files, or try “focus 25”", text: $model.glassPromptText)
                .textFieldStyle(.plain)
                .font(.system(size: 14.5, weight: .medium, design: .rounded))
                .foregroundColor(.white)
                .focused($isGlassPromptFocused)
                .onAppear {
                    if !MorphEnvironment.isTestingEnvironment && model.glassIslandState == .prompt {
                        DispatchQueue.main.async {
                            isGlassPromptFocused = true
                        }
                    }
                }
                .onChange(of: model.glassIslandState) { _, newState in
                    if !MorphEnvironment.isTestingEnvironment {
                        DispatchQueue.main.async {
                            isGlassPromptFocused = (newState == .prompt)
                        }
                    }
                }
                .onChange(of: isGlassPromptFocused) { _, focused in
                    if !MorphEnvironment.isTestingEnvironment,
                       focused,
                       model.isGlassIslandEnabled,
                       model.glassIslandState != .prompt,
                       model.glassIslandState != .idle {
                        withAnimation(MorphUniversalAnimation.stateExpansion) {
                            model.setGlassIslandState(.prompt)
                        }
                    }
                }
                .onSubmit {
                    model.submitGlassIslandPrompt(model.glassPromptText)
                }

            // Clear Query Button
            if !model.glassPromptText.isEmpty {
                Button(action: {
                    MorphHaptics.generic()
                    model.glassPromptText = ""
                    model.clearSmartFinderState()
                    if !MorphEnvironment.isTestingEnvironment {
                        isGlassPromptFocused = true
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.45))
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .help("Clear search")
            }
            
            // Send Button
            if !model.glassPromptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button(action: {
                    model.submitGlassIslandPrompt(model.glassPromptText)
                }) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(hex: "#1a1636"))
                        .frame(width: 28, height: 28)
                        .background(Color(hex: model.glassIslandTintHex))
                        .clipShape(Circle())
                        .shadow(color: Color(hex: model.glassIslandTintHex).opacity(0.6), radius: 6)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
            
            // Separator
            Rectangle()
                .fill(Color.white.opacity(0.22))
                .frame(width: 1, height: 18)
            
            // Top 3 Most Frequently Used Feature Symbols (prevents dominating the search bar)
            ForEach(model.activeOrTopBarFeatures) { feature in
                tabButton(state: feature.state, icon: feature.iconName, label: feature.title)
            }
            
            // Profile & Settings Tab
            tabButton(state: .profile, icon: "person.crop.circle", label: "Profile & Settings")
        }
        .padding(.horizontal, 8)
        .frame(height: 40)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.22), Color.white.opacity(0.08)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
        )
    }
    
    private func tabButton(state: GlassIslandState, icon: String, label: String) -> some View {
        let isActive = model.glassIslandState == state
        return Button(action: {
            MorphHaptics.levelChange()
            withAnimation(MorphUniversalAnimation.stateExpansion) {
                model.toggleGlassIslandTab(state)
            }
        }) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: isActive ? .bold : .medium))
                .foregroundColor(isActive ? .white : Color.white.opacity(0.80))
                .frame(width: 34, height: 32)
                .background(
                    Group {
                        if isActive {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.white.opacity(0.28))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(Color.white.opacity(0.65), lineWidth: 1)
                                )
                                .shadow(color: Color(hex: model.glassIslandTintHex).opacity(0.7), radius: 8)
                        } else {
                            Color.clear
                        }
                    }
                )
                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(label)
    }
    
    // MARK: - Panel Content Routing
    @ViewBuilder
    private var glassPanelView: some View {
        switch model.glassIslandState {
        case .timer:
            glassTimerView
        case .calendar:
            glassCalendarView
        case .music:
            glassMusicView
        case .notes:
            glassNotesView
        case .forms:
            glassFormsView
        case .drops:
            glassDropShelfView
        case .reply:
            glassReplyView
        case .profile:
            glassProfileView
        case .idle, .prompt:
            EmptyView()
        }
    }
    
    // MARK: - Profile & Settings Panel View (460 x 380 pt, Liquid Glass)
    private var glassProfileView: some View {
        GlassProfileView(model: model)
    }
    
    // MARK: - Drop Shelf Panel View (460 x 284 pt, Liquid Glass)
    private var glassDropShelfView: some View {
        DropShelfView(model: model)
    }
    
    // MARK: - Form Assistant Panel View (460 x 284 pt, Liquid Glass Obsidian)
    private var glassFormsView: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 8) {
                // Top Mode Switcher & Action Buttons Row
                HStack(spacing: 8) {
                    // Mode Selector: Live, Copies (N), Profile
                    HStack(spacing: 2) {
                        formModeButton(mode: .live, label: "Live")
                        formModeButton(mode: .copies, label: "Copies (\(model.formTracker.savedFormCopies.count))")
                        formModeButton(mode: .profile, label: "Profile")
                    }
                    .padding(2)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.08))
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                            )
                    )
                    
                    Spacer(minLength: 4)
                    
                    // Action Buttons: Autofill & Save Copy
                    let formsGreen = Color(hex: model.featureTintColorHex(.forms))
                    HStack(spacing: 6) {
                        Button(action: {
                            MorphHaptics.levelChange()
                            _ = model.formTracker.autofillActiveForm()
                        }) {
                            Text("Autofill")
                                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                                .foregroundColor(Color(hex: "#08080a"))
                                .padding(.horizontal, 12)
                                .frame(height: 28)
                                .background(formsGreen)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(formsGreen.opacity(0.6), lineWidth: 0.5)
                                )
                        }
                        .buttonStyle(.plain)
                        .help("Autofill matching answers directly into the open browser form")
                        
                        Button(action: {
                            MorphHaptics.levelChange()
                            _ = model.formTracker.saveFormSnapshot(flashLabel: true)
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "square.and.arrow.down.fill")
                                    .font(.system(size: 10, weight: .semibold))
                                Text("Save")
                                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .frame(height: 28)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.22), lineWidth: 0.5)
                            )
                        }
                        .buttonStyle(.plain)
                        .help("Save form answers straight into Supabase Memory")
                    }
                }
                .frame(height: 30)
                
                // Content Pane
                Group {
                    switch model.glassFormMode {
                    case .live:
                        glassFormsLivePane
                    case .copies:
                        glassFormsCopiesPane
                    case .profile:
                        glassFormsProfilePane
                    }
                }
                .frame(maxHeight: .infinity)
            }
            
            if let toast = model.formTracker.deliveryToastMessage, !toast.isEmpty {
                let isWarning = toast.localizedCaseInsensitiveContains("enable") ||
                                toast.localizedCaseInsensitiveContains("could not") ||
                                toast.localizedCaseInsensitiveContains("no matching") ||
                                toast.localizedCaseInsensitiveContains("no active") ||
                                toast.localizedCaseInsensitiveContains("grant") ||
                                toast.localizedCaseInsensitiveContains("blocks") ||
                                toast.localizedCaseInsensitiveContains("rejected") ||
                                toast.localizedCaseInsensitiveContains("click \"") ||
                                toast.localizedCaseInsensitiveContains("syncing")
                Button(action: {
                    model.formTracker.dismissToast()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: isWarning ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color.white.opacity(0.9))
                        Text(toast)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color(hex: "#16181d").opacity(0.96))
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.22), lineWidth: 0.7)
                            )
                    )
                    .shadow(color: .black.opacity(0.45), radius: 10, y: 4)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 4)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 4)
        .animation(.easeInOut(duration: 0.2), value: model.formTracker.deliveryToastMessage)
    }
    
    // MARK: - Pane 1: Live Form Capture
    private var glassFormsLivePane: some View {
        VStack(spacing: 6) {
            // Banner
            HStack {
                let title = model.formTracker.activeSession?.formTitle ?? "No Form Active"
                Text(title)
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Spacer()
                
                let actionableCount = model.formTracker.activeSession?.fields.filter { $0.isActionableQuestion }.count ?? 0
                let answered = model.formTracker.activeSession?.fields.filter { $0.isActionableQuestion && $0.isAnswered }.count ?? 0
                let total = actionableCount > 0 ? actionableCount : (model.formTracker.activeSession?.totalQuestions ?? 0)
                Text("\(answered)/\(total) noted")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.65))
            }
            .padding(.horizontal, 4)
            
            // Fields Grid
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 5) {
                        let actionable = (model.formTracker.activeSession?.fields ?? []).filter { $0.isActionableQuestion }
                        if actionable.isEmpty {
                            VStack(spacing: 6) {
                                Image(systemName: "list.bullet.clipboard")
                                    .font(.system(size: 24))
                                    .foregroundColor(Color.white.opacity(0.3))
                                    .padding(.top, 30)
                                Text("Open a Google Form in your browser")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundColor(Color.white.opacity(0.6))
                                Text("Morph automatically detects and harvests form answers in real-time.")
                                    .font(.system(size: 10.5, weight: .regular, design: .rounded))
                                    .foregroundColor(Color.white.opacity(0.4))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 24)
                            }
                        } else {
                            let formsGreen = Color(hex: model.featureTintColorHex(.forms))
                            let focusedFieldID = model.formTracker.autoTracker?.confirmedFieldID
                            ForEach(Array(actionable.enumerated()), id: \.element.id) { idx, field in
                                let rightDisplay = model.formTracker.rightSideDisplay(for: field)
                                let isFocusedRow = (focusedFieldID == field.id)
                                HStack(spacing: 8) {
                                    Text("\(idx + 1). \(field.label)")
                                        .font(.system(size: 11.5, weight: isFocusedRow ? .semibold : .medium, design: .rounded))
                                        .foregroundColor(isFocusedRow ? .white : Color.white.opacity(0.72))
                                        .lineLimit(1)
                                        .frame(maxWidth: 160, alignment: .leading)
                                    
                                    Spacer(minLength: 4)
                                    
                                    switch rightDisplay {
                                    case .userInput(let liveVal):
                                        Text(liveVal)
                                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                            .truncationMode(isFocusedRow && liveVal.count > 26 ? .head : .tail)
                                            .multilineTextAlignment(.trailing)
                                    case .autofillSuggestion(let savedVal):
                                        HStack(spacing: 3.5) {
                                            Image(systemName: "sparkles")
                                                .font(.system(size: 8.5, weight: .bold))
                                            Text("Fill: \(savedVal)")
                                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                                .lineLimit(1)
                                                .truncationMode(.tail)
                                        }
                                        .foregroundColor(formsGreen)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(
                                            Capsule()
                                                .fill(formsGreen.opacity(0.14))
                                        )
                                        .overlay(
                                            Capsule()
                                                .stroke(formsGreen.opacity(0.32), lineWidth: 0.6)
                                        )
                                    case .empty:
                                        Text("—")
                                            .font(.system(size: 12, weight: .regular))
                                            .foregroundColor(Color.white.opacity(0.35))
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.white.opacity(isFocusedRow ? 0.13 : 0.08))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(isFocusedRow ? formsGreen.opacity(0.42) : Color.white.opacity(0.06), lineWidth: isFocusedRow ? 0.8 : 0.5)
                                )
                                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .id(field.id)
                                .onTapGesture {
                                    if case .autofillSuggestion(let savedVal) = rightDisplay {
                                        MorphHaptics.levelChange()
                                        _ = model.formTracker.inputAnswerIntoActiveQuestion(fieldID: field.id, value: savedVal)
                                    } else if let sessionIdx = model.formTracker.activeSession?.fields.firstIndex(where: { $0.id == field.id }) {
                                        model.formTracker.selectActiveField(sessionIdx)
                                    }
                                }
                            }
                        }
                    }
                }
                .onChange(of: model.formTracker.autoTracker?.confirmedFieldID) { _, newID in
                    guard let newID else { return }
                    let actionable = (model.formTracker.activeSession?.fields ?? []).filter { $0.isActionableQuestion }
                    if actionable.contains(where: { $0.id == newID }) {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            proxy.scrollTo(newID, anchor: .center)
                        }
                    }
                }
                .onChange(of: model.formTracker.activeFieldIndex) { _, newIdx in
                    guard model.formTracker.autoTracker?.confirmedFieldID == nil,
                          let fields = model.formTracker.activeSession?.fields,
                          fields.indices.contains(newIdx),
                          fields[newIdx].isActionableQuestion else { return }
                    let targetID = fields[newIdx].id
                    withAnimation(.easeInOut(duration: 0.18)) {
                        proxy.scrollTo(targetID, anchor: .center)
                    }
                }
            }
        }
    }
    
    // MARK: - Pane 2: Saved Form Copies (from Memory / Supabase)
    private var glassFormsCopiesPane: some View {
        Group {
            if model.isFormCopyDetailOpen, let copy = selectedCopyRecord {
                // Detail View
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Button(action: {
                            model.isFormCopyDetailOpen = false
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 24, height: 24)
                                .background(Color.white.opacity(0.12))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        
                        Text(copy.formTitle)
                            .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Button(action: {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(copy.formattedClipboardText, forType: .string)
                            model.formTracker.showToast("Copied all answers to clipboard!")
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: "doc.on.doc.fill")
                                    .font(.system(size: 9))
                                Text("Copy All")
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            MorphHaptics.levelChange()
                            let targetID = copy.id
                            model.isFormCopyDetailOpen = false
                            model.selectedFormCopyId = nil
                            model.formTracker.deleteSavedFormCopy(id: targetID)
                        }) {
                            Image(systemName: "trash")
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundColor(Color.white.opacity(0.80))
                                .frame(width: 24, height: 24)
                                .background(Color.white.opacity(0.10))
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.16), lineWidth: 0.5)
                                )
                        }
                        .buttonStyle(.plain)
                        .help("Delete this saved copy")
                    }
                    
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 5) {
                            ForEach(Array(copy.answers.sorted(by: { $0.key < $1.key }).enumerated()), id: \.offset) { idx, pair in
                                HStack(spacing: 8) {
                                    Text("\(idx + 1). \(pair.key)")
                                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                                        .foregroundColor(Color.white.opacity(0.65))
                                        .lineLimit(1)
                                        .frame(maxWidth: 160, alignment: .leading)
                                    
                                    Spacer(minLength: 4)
                                    
                                    Text(pair.value.isEmpty ? "—" : pair.value)
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundColor(pair.value.isEmpty ? Color.white.opacity(0.35) : .white)
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.white.opacity(0.08))
                                )
                            }
                        }
                    }
                }
            } else {
                // List of Saved Copies
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 5) {
                        if model.formTracker.savedFormCopies.isEmpty {
                            VStack(spacing: 6) {
                                Image(systemName: "folder.badge.questionmark")
                                    .font(.system(size: 24))
                                    .foregroundColor(Color.white.opacity(0.3))
                                    .padding(.top, 30)
                                Text("No saved copies yet")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundColor(Color.white.opacity(0.6))
                                Text("Saving a form archives your answers here and teaches your Adaptive Profile.")
                                    .font(.system(size: 10.5, weight: .regular, design: .rounded))
                                    .foregroundColor(Color.white.opacity(0.4))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 24)
                            }
                        } else {
                            ForEach(model.formTracker.savedFormCopies) { copy in
                                HStack(spacing: 8) {
                                    Button(action: {
                                        MorphHaptics.levelChange()
                                        model.selectedFormCopyId = copy.id
                                        model.isFormCopyDetailOpen = true
                                    }) {
                                        HStack(spacing: 8) {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(copy.formTitle)
                                                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                                                    .foregroundColor(.white)
                                                    .lineLimit(1)
                                                
                                                Text(copy.previewSummary)
                                                    .font(.system(size: 11, weight: .regular, design: .rounded))
                                                    .foregroundColor(Color.white.opacity(0.60))
                                                    .lineLimit(1)
                                            }
                                            
                                            Spacer(minLength: 4)
                                            
                                            Text(relativeTimeString(for: copy.savedAt))
                                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                                .foregroundColor(Color.white.opacity(0.45))
                                        }
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    
                                    Button(action: {
                                        MorphHaptics.levelChange()
                                        if model.selectedFormCopyId == copy.id {
                                            model.isFormCopyDetailOpen = false
                                            model.selectedFormCopyId = nil
                                        }
                                        model.formTracker.deleteSavedFormCopy(id: copy.id)
                                    }) {
                                        Image(systemName: "trash")
                                            .font(.system(size: 10.5, weight: .semibold))
                                            .foregroundColor(Color.white.opacity(0.55))
                                            .frame(width: 24, height: 24)
                                            .background(Color.white.opacity(0.08))
                                            .clipShape(Circle())
                                    }
                                    .buttonStyle(.plain)
                                    .help("Delete saved copy")
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.white.opacity(0.08))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .stroke(Color.white.opacity(0.10), lineWidth: 0.5)
                                        )
                                )
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Pane 3: Adaptive Profile (Learned from Saved Form Copies)
    private var glassFormsProfilePane: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Text("Adaptive Profile")
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("· Learned from \(model.formTracker.adaptiveSourceCount) \(model.formTracker.adaptiveSourceCount == 1 ? "copy" : "copies")")
                    .font(.system(size: 10.5, weight: .regular, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.55))
                    .lineLimit(1)
                
                Spacer()
                
                Button(action: {
                    MorphHaptics.levelChange()
                    withAnimation(.easeInOut(duration: 0.16)) {
                        isAddingAdaptiveProfileEntry.toggle()
                        if !isAddingAdaptiveProfileEntry {
                            newAdaptiveQuestionText = ""
                            newAdaptiveAnswerText = ""
                        }
                    }
                }) {
                    Text(isAddingAdaptiveProfileEntry ? "Cancel" : "+ Add")
                        .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3.5)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.18), lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)
            
            if isAddingAdaptiveProfileEntry {
                HStack(spacing: 6) {
                    TextField("Question (e.g. Portfolio URL)", text: $newAdaptiveQuestionText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.white.opacity(0.08))
                        )
                    
                    TextField("Default answer", text: $newAdaptiveAnswerText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.white.opacity(0.08))
                        )
                    
                    let canSaveCustom = !newAdaptiveQuestionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                                        !newAdaptiveAnswerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    Button(action: {
                        MorphHaptics.levelChange()
                        model.formTracker.addCustomProfileEntry(question: newAdaptiveQuestionText, answer: newAdaptiveAnswerText)
                        newAdaptiveQuestionText = ""
                        newAdaptiveAnswerText = ""
                        isAddingAdaptiveProfileEntry = false
                    }) {
                        Text("Save")
                            .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                            .foregroundColor(canSaveCustom ? Color(hex: "#08080a") : Color.white.opacity(0.45))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(canSaveCustom ? Color.white.opacity(0.92) : Color.white.opacity(0.08))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSaveCustom)
                }
                .padding(.horizontal, 4)
            }
            
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 5) {
                    if model.formTracker.adaptiveProfileEntries.isEmpty {
                        VStack(spacing: 6) {
                            Image(systemName: "sparkles.rectangle.stack")
                                .font(.system(size: 22))
                                .foregroundColor(Color.white.opacity(0.3))
                                .padding(.top, 26)
                            Text("No patterns learned yet")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(Color.white.opacity(0.6))
                            Text("Save form copies or add custom answers so Morph learns recurring questions across your forms.")
                                .font(.system(size: 10.5, weight: .regular, design: .rounded))
                                .foregroundColor(Color.white.opacity(0.4))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                    } else {
                        ForEach(Array(model.formTracker.adaptiveProfileEntries.enumerated()), id: \.element.id) { idx, entry in
                            HStack(spacing: 7) {
                                Text("\(idx + 1). \(entry.question)")
                                    .font(.system(size: 11.5, weight: .medium, design: .rounded))
                                    .foregroundColor(Color.white.opacity(0.70))
                                    .lineLimit(1)
                                    .frame(maxWidth: 148, alignment: .leading)
                                
                                Text(entry.isCustom && entry.frequency <= 1 ? "Custom" : "\(entry.frequency)×")
                                    .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                                    .foregroundColor(Color.white.opacity(0.62))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color.white.opacity(0.10)))
                                
                                Spacer(minLength: 4)
                                
                                TextField("Empty", text: Binding(
                                    get: { entry.answer },
                                    set: {
                                        model.formTracker.saveProfileAnswer(
                                            key: entry.question,
                                            value: $0,
                                            canonicalKey: entry.canonicalKey
                                        )
                                    }
                                ))
                                .textFieldStyle(.plain)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.trailing)
                                .frame(minWidth: 80)
                                
                                Button(action: {
                                    MorphHaptics.levelChange()
                                    model.formTracker.deleteAdaptiveProfileEntry(id: entry.id)
                                }) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(Color.white.opacity(0.48))
                                        .frame(width: 22, height: 22)
                                        .background(Color.white.opacity(0.06))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                                .help("Remove from Adaptive Profile")
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.white.opacity(0.08))
                            )
                        }
                    }
                }
            }
        }
    }
    
    private var selectedCopyRecord: SavedFormCopyRecord? {
        if let id = model.selectedFormCopyId {
            if let found = model.formTracker.savedFormCopies.first(where: { $0.id == id }) {
                return found
            }
            if let mem = model.supabase.memoryItems.first(where: { $0.id == id }) {
                var dict: [String: String] = [:]
                if let data = mem.metaJSON.data(using: .utf8),
                   let parsed = try? JSONDecoder().decode([String: String].self, from: data) {
                    dict = parsed
                }
                return SavedFormCopyRecord(
                    id: mem.id,
                    formTitle: mem.title.isEmpty ? "Saved Form" : mem.title,
                    savedAt: mem.createdAt,
                    answers: dict
                )
            }
            if let rec = model.supabase.formReceipts.first(where: { $0.id == id }) {
                var dict: [String: String] = [:]
                if let data = rec.fieldsJSON.data(using: .utf8),
                   let fields = try? JSONDecoder().decode([FormInputField].self, from: data) {
                    for f in fields where f.isActionableQuestion {
                        dict[f.label] = f.value
                    }
                }
                return SavedFormCopyRecord(
                    id: rec.id,
                    formTitle: rec.formTitle.isEmpty ? "Saved Form" : rec.formTitle,
                    savedAt: rec.createdAt,
                    answers: dict,
                    sourceURL: rec.sourceURL,
                    sourceAppName: rec.sourceAppName
                )
            }
        }
        return nil
    }
    
    private func formModeButton(mode: GlassFormMode, label: String) -> some View {
        let isActive = model.glassFormMode == mode
        return Button(action: {
            MorphHaptics.levelChange()
            model.glassFormMode = mode
            if mode != .copies {
                model.isFormCopyDetailOpen = false
            }
        }) {
            Text(label)
                .font(.system(size: 11.5, weight: isActive ? .bold : .medium, design: .rounded))
                .foregroundColor(isActive ? .white : Color.white.opacity(0.65))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Group {
                        if isActive {
                            Capsule()
                                .fill(Color.white.opacity(0.20))
                                .shadow(color: Color.black.opacity(0.2), radius: 3)
                        } else {
                            Color.clear
                        }
                    }
                )
        }
        .buttonStyle(.plain)
    }
    
    private func relativeTimeString(for date: Date) -> String {
        let diff = Int(Date().timeIntervalSince(date))
        if diff < 60 { return "just now" }
        if diff < 3600 { return "\(diff / 60)m ago" }
        if diff < 86400 { return "\(diff / 3600)h ago" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
    
    // MARK: - Focus Timer Panel View (460 x 258 pt)
    private var glassTimerView: some View {
        HStack(spacing: 16) {
            // Left: Progress ring (132 x 132 pt)
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.16), lineWidth: 8)
                    .frame(width: 132, height: 132)
                
                Circle()
                    .trim(from: 0, to: model.glassTimerProgress)
                    .stroke(
                        model.glassTimerStatus == .done ? Color(hex: "#8ff0b4") : Color(hex: "#ff9a7a"),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 132, height: 132)
                    .shadow(
                        color: (model.glassTimerStatus == .done ? Color(hex: "#8ff0b4") : Color(hex: "#ff9a7a")).opacity(0.6),
                        radius: 6
                    )
                
                VStack(spacing: 2) {
                    Text(model.glassTimerStatus == .done ? "Done" : model.formattedGlassTimerTime)
                        .font(.system(size: 30, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                    
                    Text(timerStatusLabel)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.70))
                }
            }
            .frame(width: 132, height: 132)
            
            // Right: Meta, Presets, Actions
            VStack(alignment: .leading, spacing: 11) {
                // Focus eyebrow + Session dots
                HStack {
                    Text("FOCUS")
                        .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                        .tracking(1.2)
                        .foregroundColor(Color.white.opacity(0.62))
                    
                    Spacer()
                    
                    HStack(spacing: 5) {
                        ForEach(0..<4, id: \.self) { idx in
                            Circle()
                                .fill(idx < model.glassTimerDoneCount ? Color(hex: "#ff9a7a") : Color.white.opacity(0.22))
                                .frame(width: 7, height: 7)
                                .shadow(color: idx < model.glassTimerDoneCount ? Color(hex: "#ff9a7a").opacity(0.8) : Color.clear, radius: 4)
                        }
                    }
                }
                
                // 3 Presets: 15 min, 25 min, 50 min
                HStack(spacing: 6) {
                    presetButton(minutes: 15)
                    presetButton(minutes: 25)
                    presetButton(minutes: 50)
                }
                
                // Actions: Start/Pause/Resume + Reset
                HStack(spacing: 8) {
                    Button(action: {
                        MorphHaptics.levelChange()
                        model.toggleGlassTimer()
                    }) {
                        HStack(spacing: 7) {
                            Image(systemName: model.glassTimerStatus == .running ? "pause.fill" : "play.fill")
                                .font(.system(size: 13, weight: .bold))
                            Text(timerMainButtonTitle)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(
                            RoundedRectangle(cornerRadius: 19, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.42), Color.white.opacity(0.18)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 19, style: .continuous)
                                        .stroke(Color.white.opacity(0.40), lineWidth: 1)
                                )
                                .shadow(color: Color(hex: "#ff9a7a").opacity(0.4), radius: 8, y: 3)
                        )
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        MorphHaptics.generic()
                        model.resetGlassTimer()
                    }) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 38, height: 38)
                            .background(
                                RoundedRectangle(cornerRadius: 19, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.35), Color.white.opacity(0.14)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 19, style: .continuous)
                                            .stroke(Color.white.opacity(0.25), lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Reset timer")
                }
            }
        }
        .padding(.horizontal, 8)
    }
    
    private var timerStatusLabel: String {
        switch model.glassTimerStatus {
        case .ready: return "Ready"
        case .running: return "Focusing"
        case .paused: return "Paused"
        case .done: return "\(model.glassTimerMins) min focused"
        }
    }
    
    private var timerMainButtonTitle: String {
        switch model.glassTimerStatus {
        case .ready: return "Start"
        case .running: return "Pause"
        case .paused: return "Resume"
        case .done: return "Again"
        }
    }
    
    private func presetButton(minutes: Int) -> some View {
        let isSelected = model.glassTimerMins == minutes
        return Button(action: {
            MorphHaptics.levelChange()
            model.setGlassTimerMinutes(minutes)
        }) {
            Text("\(minutes) min")
                .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                .foregroundColor(isSelected ? .white : Color.white.opacity(0.85))
                .frame(maxWidth: .infinity)
                .frame(height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(isSelected ? Color.white.opacity(0.30) : Color.white.opacity(0.10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(isSelected ? Color.white.opacity(0.65) : Color.white.opacity(0.20), lineWidth: 1)
                        )
                        .shadow(color: isSelected ? Color(hex: "#ff9a7a").opacity(0.5) : Color.clear, radius: 6)
                )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Calendar Panel View (460 x 308 pt)
    private var currentWeekDayDates: [Date] {
        return model.glassCurrentWeekDates
    }
    
    private var calendarSelectedDayTitle: String {
        return model.formattedGlassDayTitle
    }
    
    private var currentWeekTodayIndex: Int {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: Date())
        return (weekday == 1) ? 6 : (weekday - 2)
    }
    
    private var calendarSubtitleText: String {
        return model.calendar.isSignedIn ? "GOOGLE CALENDAR" : "LOCAL CALENDAR"
    }
    
    private var glassCalendarView: some View {
        VStack(spacing: 8) {
            // Header
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.formattedGlassMonthYear)
                        .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                        .tracking(1.2)
                        .foregroundColor(Color.white.opacity(0.62))
                    
                    Text(calendarSelectedDayTitle)
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                // Far-right action stack (Add Event button and calendar indicator)
                VStack(alignment: .trailing, spacing: 3) {
                    Text(calendarSubtitleText)
                        .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                        .tracking(1.0)
                        .foregroundColor(Color.white.opacity(0.50))
                    
                    Button(action: {
                        MorphHaptics.levelChange()
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                            isAddingGlassEvent.toggle()
                            if isAddingGlassEvent {
                                draftEventStartDate = model.glassSelectedDate
                                draftEventEndDate = model.glassSelectedDate
                                ensureDefaultCalendarSelected()
                            }
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: isAddingGlassEvent ? "xmark" : "plus")
                                .font(.system(size: 10, weight: .bold))
                            Text(isAddingGlassEvent ? "Close" : "Add Event")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(isAddingGlassEvent ? Color.white.opacity(0.22) : Color(hex: model.featureTintColorHex(.calendar)).opacity(0.26))
                                .overlay(Capsule().stroke(Color(hex: model.featureTintColorHex(.calendar)).opacity(0.65), lineWidth: 0.9))
                        )
                    }
                    .buttonStyle(.plain)
                    .help(isAddingGlassEvent ? "Close event composer" : "Add event to this day")
                }
            }
            .frame(minHeight: 40)
            
            // View mode picker + period navigation (3 Days | Week | Month)
            glassCalendarModeBar
            
            if isAddingGlassEvent {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 8) {
                        glassAddEventCard
                            .transition(.move(edge: .top).combined(with: .opacity))
                        
                        glassCalendarCurrentModeContent
                            .frame(minHeight: 220)
                    }
                    .padding(.bottom, 8)
                }
            } else {
                glassCalendarCurrentModeContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(.horizontal, 4)
        .onAppear {
            model.glassSelectedDayIndex = model.glassTodayDayIndex
            model.calendar.goToToday()
        }
    }
    
    @ViewBuilder
    private var glassCalendarCurrentModeContent: some View {
        switch model.calendar.viewMode {
        case .threeDay:
            glassThreeDayView
        case .week:
            glassWeekView
        case .month:
            glassMonthView
        }
    }
    
    // MARK: - Glass Calendar: View Modes (3 Days / Week / Month)
    private var glassCalendarTint: Color { Color(hex: model.featureTintColorHex(.calendar)) }
    
    private var glassCalendarModeBar: some View {
        HStack(spacing: 6) {
            HStack(spacing: 2) {
                ForEach(CalendarViewMode.allCases) { mode in
                    let isSelected = model.calendar.viewMode == mode
                    Button(action: {
                        MorphHaptics.alignment()
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
                            model.calendar.viewMode = mode
                            model.calendar.displayedMonth = model.calendar.selectedDate
                        }
                    }) {
                        Text(mode.rawValue)
                            .font(.system(size: 10, weight: isSelected ? .bold : .medium, design: .rounded))
                            .foregroundColor(isSelected ? .white : Color.white.opacity(0.62))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(isSelected ? glassCalendarTint.opacity(0.38) : Color.clear))
                            .overlay(Capsule().stroke(isSelected ? glassCalendarTint.opacity(0.7) : Color.clear, lineWidth: 0.8))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("Show \(mode.rawValue)")
                }
            }
            .padding(2)
            .background(Capsule().fill(Color.white.opacity(0.08)))
            
            Spacer(minLength: 4)
            
            Text(glassPeriodTitle)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.72))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            HStack(spacing: 2) {
                glassNavButton(icon: "chevron.left", help: "Previous") { model.calendar.previousPeriod() }
                Button(action: {
                    MorphHaptics.alignment()
                    model.calendar.goToToday()
                }) {
                    Text("Today")
                        .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.white.opacity(0.12)))
                }
                .buttonStyle(.plain)
                glassNavButton(icon: "chevron.right", help: "Next") { model.calendar.nextPeriod() }
            }
        }
        .frame(height: 24)
    }
    
    private func glassNavButton(icon: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            MorphHaptics.alignment()
            action()
        }) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.white.opacity(0.12)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
    
    private var glassPeriodTitle: String {
        let f = DateFormatter()
        switch model.calendar.viewMode {
        case .month:
            f.dateFormat = "MMMM yyyy"
            return f.string(from: model.calendar.displayedMonth)
        case .week, .threeDay:
            let dates = model.calendar.viewMode == .week ? model.calendar.datesForCurrentWeek() : model.calendar.datesForThreeDays()
            guard let first = dates.first, let last = dates.last else { return "" }
            f.dateFormat = "MMM d"
            let a = f.string(from: first)
            let b = f.string(from: last)
            return "\(a) – \(b)"
        }
    }
    
    private func glassSortedEvents(on date: Date) -> [CalendarEvent] {
        model.calendar.eventsForDate(date).sorted { $0.startTime < $1.startTime }
    }
    
    private func glassEventsScroll(for date: Date) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            let realEvents = glassSortedEvents(on: date)
            if realEvents.isEmpty {
                calendarEmptyOrSignInCard
            } else {
                VStack(spacing: 6) {
                    ForEach(Array(realEvents.enumerated()), id: \.element.id) { (idx, e) in
                        realCalendarEventRowView(event: e, isNext: idx == 0 && Calendar.current.isDateInToday(date))
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
    }
    
    // Week: 7-day strip + agenda of the selected day
    private var glassWeekView: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(0..<7, id: \.self) { i in
                    weekDayButton(index: i)
                }
            }
            .frame(height: 50)
            glassEventsScroll(for: model.glassSelectedDate)
        }
    }
    
    // 3 Days: three side-by-side day columns
    private var glassThreeDayView: some View {
        HStack(alignment: .top, spacing: 6) {
            ForEach(model.calendar.datesForThreeDays(), id: \.self) { date in
                glassThreeDayColumn(date: date)
            }
        }
    }
    
    private func glassThreeDayColumn(date: Date) -> some View {
        let cal = Calendar.current
        let isToday = cal.isDateInToday(date)
        let isSelected = cal.isDate(date, inSameDayAs: model.glassSelectedDate)
        let events = glassSortedEvents(on: date)
        let letterFmt = DateFormatter()
        letterFmt.dateFormat = "EEE"
        return VStack(spacing: 4) {
            Button(action: {
                MorphHaptics.levelChange()
                model.calendar.selectedDate = date
            }) {
                VStack(spacing: 1) {
                    Text(letterFmt.string(from: date).uppercased())
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.60))
                    Text("\(cal.component(.day, from: date))")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(isToday ? glassCalendarTint.opacity(0.55) : Color.clear))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isSelected ? Color.white.opacity(0.20) : Color.white.opacity(0.06))
                )
                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            
            ScrollView(.vertical, showsIndicators: false) {
                if events.isEmpty {
                    Text("No events")
                        .font(.system(size: 9.5, weight: .medium, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.40))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 14)
                } else {
                    VStack(spacing: 4) {
                        ForEach(events) { e in
                            glassCompactEventChip(event: e)
                        }
                    }
                }
            }
            .frame(maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func glassCompactEventChip(event: CalendarEvent) -> some View {
        let colorHex = event.colorHex ?? "#6ab7ff"
        let labelName: String = {
            if let cName = event.calendarName?.trimmingCharacters(in: .whitespacesAndNewlines), !cName.isEmpty, cName.lowercased() != "primary" {
                return cName
            }
            if let hex = event.colorHex, let colorLabel = GoogleCalendarColor.labelName(for: hex), !colorLabel.isEmpty {
                return colorLabel
            }
            return ""
        }()
        let timeStr: String = {
            if event.isAllDay {
                let cal = Calendar.current
                let startDay = cal.startOfDay(for: event.startTime)
                let endDay = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: event.endTime)) ?? startDay
                if endDay > startDay {
                    let f = DateFormatter()
                    f.dateFormat = "MMM d"
                    return "\(f.string(from: startDay))–\(f.string(from: endDay))"
                }
                return "All Day"
            }
            let f = DateFormatter()
            f.dateFormat = "h:mm a"
            return "\(f.string(from: event.startTime)) – \(f.string(from: event.endTime))"
        }()
        return VStack(alignment: .leading, spacing: 2) {
            Text(event.title.isEmpty ? "Untitled Event" : event.title)
                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
            
            if !labelName.isEmpty {
                Text(labelName)
                    .font(.system(size: 8.5, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: colorHex).opacity(0.95))
                    .lineLimit(1)
            }
            
            Text(timeStr)
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.75))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(hex: colorHex).opacity(0.22))
                .overlay(
                    HStack {
                        Rectangle().fill(Color(hex: colorHex)).frame(width: 2.5)
                        Spacer()
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                )
        )
    }
    
    // Month: compact month grid + agenda of the selected day
    private var glassMonthView: some View {
        HStack(alignment: .top, spacing: 10) {
            glassMonthGrid
                .frame(width: 236)
            glassEventsScroll(for: model.glassSelectedDate)
        }
    }
    
    private var glassMonthGrid: some View {
        let cal = Calendar.current
        let month = model.calendar.displayedMonth
        let comps = cal.dateComponents([.year, .month], from: month)
        let firstOfMonth = cal.date(from: comps) ?? month
        let dayCount = cal.range(of: .day, in: .month, for: firstOfMonth)?.count ?? 30
        let weekday = cal.component(.weekday, from: firstOfMonth)
        let leading = (weekday == 1) ? 6 : (weekday - 2) // Monday-first
        let totalCells = Int(ceil(Double(leading + dayCount) / 7.0)) * 7
        let letters = ["M", "T", "W", "T", "F", "S", "S"]
        return VStack(spacing: 3) {
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { i in
                    Text(letters[i])
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.55))
                        .frame(maxWidth: .infinity)
                }
            }
            ForEach(0..<(totalCells / 7), id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { col in
                        let dayNum = row * 7 + col - leading + 1
                        if dayNum >= 1 && dayNum <= dayCount,
                           let date = cal.date(byAdding: .day, value: dayNum - 1, to: firstOfMonth) {
                            glassMonthCell(date: date, dayNum: dayNum)
                        } else {
                            Color.clear.frame(maxWidth: .infinity).frame(height: 24)
                        }
                    }
                }
            }
        }
    }
    
    private func glassMonthCell(date: Date, dayNum: Int) -> some View {
        let cal = Calendar.current
        let isToday = cal.isDateInToday(date)
        let isSelected = cal.isDate(date, inSameDayAs: model.glassSelectedDate)
        let hasEvents = !model.calendar.eventsForDate(date).isEmpty
        return Button(action: {
            MorphHaptics.levelChange()
            model.calendar.selectedDate = date
        }) {
            VStack(spacing: 1) {
                Text("\(dayNum)")
                    .font(.system(size: 11, weight: isToday ? .bold : .medium, design: .rounded))
                    .foregroundColor(.white)
                Circle()
                    .fill(hasEvents ? glassCalendarTint : Color.clear)
                    .frame(width: 3, height: 3)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 24)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.26) : (isToday ? glassCalendarTint.opacity(0.28) : Color.clear))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(isSelected ? Color.white.opacity(0.6) : Color.clear, lineWidth: 1)
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
    
    private func weekDayButton(index: Int) -> some View {
        let letters = ["M", "T", "W", "T", "F", "S", "S"]
        let dates = currentWeekDayDates
        let dayNum = (index < dates.count) ? Calendar.current.component(.day, from: dates[index]) : (index + 1)
        let isSelected = (index < dates.count) && Calendar.current.isDate(dates[index], inSameDayAs: model.glassSelectedDate)
        let isToday = (index < dates.count) && Calendar.current.isDateInToday(dates[index])
        let dayDate = (index < dates.count) ? dates[index] : nil
        let hasEvents = (dayDate != nil) && !model.calendar.eventsForDate(dayDate!).isEmpty
        
        return Button(action: {
            MorphHaptics.levelChange()
            if index < dates.count { model.calendar.selectedDate = dates[index] }
        }) {
            VStack(spacing: 2) {
                Text(letters[index])
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.60))
                
                Text("\(dayNum)")
                    .font(.system(size: 15, weight: isToday ? .bold : .semibold, design: .rounded))
                    .foregroundColor(.white)
                
                Circle()
                    .fill(hasEvents ? Color(hex: "#6ab7ff") : Color.clear)
                    .frame(width: 4, height: 4)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.26) : (isToday ? Color(hex: "#6ab7ff").opacity(0.18) : Color.clear))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(isSelected ? Color.white.opacity(0.65) : (isToday ? Color(hex: "#6ab7ff").opacity(0.40) : Color.clear), lineWidth: 1)
                    )
                    .shadow(color: isSelected ? Color(hex: "#6ab7ff").opacity(0.6) : Color.clear, radius: 8)
            )
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
    
    private func realCalendarEventRowView(event: CalendarEvent, isNext: Bool) -> some View {
        let colorHex = event.colorHex ?? "#6ab7ff"
        
        let labelName: String = {
            if let cName = event.calendarName?.trimmingCharacters(in: .whitespacesAndNewlines), !cName.isEmpty, cName.lowercased() != "primary" {
                return cName
            }
            if let hex = event.colorHex, let colorLabel = GoogleCalendarColor.labelName(for: hex), !colorLabel.isEmpty {
                return colorLabel
            }
            if let loc = event.location?.trimmingCharacters(in: .whitespacesAndNewlines), !loc.isEmpty {
                return loc
            }
            if event.hasMeetLink {
                return "Google Meet"
            }
            return "Event"
        }()
        
        let subtitleText: String = {
            let baseLabel = labelName
            if let loc = event.location?.trimmingCharacters(in: .whitespacesAndNewlines),
               !loc.isEmpty,
               loc.lowercased() != baseLabel.lowercased() {
                return "\(baseLabel) • \(loc)"
            } else if event.hasMeetLink && baseLabel.lowercased() != "google meet" {
                return "\(baseLabel) • Google Meet"
            }
            return baseLabel
        }()
        
        let timeStr: String = {
            if event.isAllDay {
                let cal = Calendar.current
                let startDay = cal.startOfDay(for: event.startTime)
                let endDay = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: event.endTime)) ?? startDay
                if endDay > startDay {
                    let f = DateFormatter()
                    f.dateFormat = "MMM d"
                    return "\(f.string(from: startDay)) – \(f.string(from: endDay))"
                }
                return "All Day"
            }
            let f = DateFormatter()
            f.dateFormat = "h:mm a"
            let start = f.string(from: event.startTime)
            let end = f.string(from: event.endTime)
            return "\(start) – \(end)"
        }()
        
        return HStack(alignment: .center, spacing: 9) {
            Circle()
                .fill(Color(hex: colorHex))
                .frame(width: 8, height: 8)
                .shadow(color: Color(hex: colorHex).opacity(0.8), radius: 3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title.isEmpty ? "Untitled Event" : event.title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                
                HStack(spacing: 4) {
                    Text(subtitleText)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(Color(hex: colorHex).opacity(0.92))
                        .lineLimit(1)
                }
            }
            
            Spacer(minLength: 8)
            
            VStack(alignment: .trailing, spacing: 1.5) {
                Text(timeStr)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.85))
                    .lineLimit(1)
                
                if event.isNow {
                    Text("NOW")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "#6ab7ff"))
                        .padding(.horizontal, 4.5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color(hex: "#6ab7ff").opacity(0.20)))
                } else if event.isStartingSoon && !event.isAllDay {
                    Text("SOON")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.75))
                        .padding(.horizontal, 4.5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.white.opacity(0.15)))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .frame(minHeight: 46)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isNext ? Color.white.opacity(0.18) : Color.white.opacity(0.09))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(
                            event.colorHex != nil
                                ? Color(hex: colorHex).opacity(0.65)
                                : (isNext ? Color(hex: "#6ab7ff").opacity(0.70) : Color.white.opacity(0.18)),
                            lineWidth: 1
                        )
                )
        )
    }
    
    private func ensureDefaultCalendarSelected() {
        let labels = model.calendar.availableCalendarLabels
        if draftEventCalendarId.isEmpty || !labels.contains(where: { $0.id == draftEventCalendarId }) {
            if let primary = labels.first(where: { $0.isPrimary }) ?? labels.first {
                draftEventCalendarId = primary.id
                draftEventCalendarName = primary.name
                draftEventColorHex = primary.colorHex
            }
        }
    }
    
    private var glassAddEventCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            glassAddEventTypeAndTitleRow
            glassAddEventCalendarLabelsRow
            glassAddEventDateSpanRow
            glassAddEventTimeRow
            glassAddEventDetailsRow
            glassAddEventActionRow
        }
        .padding(9)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.ultraThinMaterial.opacity(0.85))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.40),
                                    Color.white.opacity(0.12),
                                    Color.white.opacity(0.04)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.0
                        )
                )
                .shadow(color: Color.black.opacity(0.20), radius: 12, y: 4)
        )
        .onAppear {
            ensureDefaultCalendarSelected()
        }
    }
    
    private var glassAddEventTypeAndTitleRow: some View {
        VStack(spacing: 5) {
            // Type switcher: Event vs Task
            HStack(spacing: 4) {
                ForEach(["Event", "Task"], id: \.self) { type in
                    let isSel = draftEventType == type
                    Button(action: {
                        MorphHaptics.alignment()
                        withAnimation(.spring(response: 0.22, dampingFraction: 0.8)) {
                            draftEventType = type
                            if type == "Task" {
                                draftEventIsAllDay = true
                            }
                        }
                    }) {
                        HStack(spacing: 3.5) {
                            Image(systemName: type == "Event" ? "calendar" : "checkmark.circle.fill")
                                .font(.system(size: 8.5, weight: .bold))
                            Text(type)
                                .font(.system(size: 9.5, weight: isSel ? .bold : .medium, design: .rounded))
                        }
                        .foregroundColor(isSel ? .white : Color.white.opacity(0.60))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(isSel ? Color.white.opacity(0.20) : Color.white.opacity(0.04))
                                .overlay(Capsule().stroke(isSel ? Color.white.opacity(0.35) : Color.white.opacity(0.08), lineWidth: 0.8))
                        )
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
                
                Text(draftEventType == "Task" ? "MULTI-DAY TASK" : "CALENDAR EVENT")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundColor(Color.white.opacity(0.45))
            }
            
            // Title input
            HStack(spacing: 7) {
                Image(systemName: draftEventType == "Task" ? "checklist" : "calendar.badge.plus")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundColor(Color(hex: draftEventColorHex))
                
                TextField(draftEventType == "Task" ? "Task title or action item..." : "Event title...", text: $draftEventTitle)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .onSubmit {
                        submitGlassEvent()
                    }
                
                if !draftEventTitle.isEmpty {
                    Button(action: { draftEventTitle = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 10.5))
                            .foregroundColor(Color.white.opacity(0.45))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                    )
            )
        }
    }
    
    private var glassAddEventCalendarLabelsRow: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Text(draftEventType == "Task" ? "LIST / CALENDAR" : "CALENDAR")
                    .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundColor(Color.white.opacity(0.50))
                
                Spacer()
                
                if !draftEventCalendarName.isEmpty {
                    HStack(spacing: 3.5) {
                        Circle()
                            .fill(Color(hex: draftEventColorHex))
                            .frame(width: 4.5, height: 4.5)
                        Text(draftEventCalendarName)
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .foregroundColor(Color(hex: draftEventColorHex))
                    }
                }
            }
            .padding(.horizontal, 2)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    ForEach(model.calendar.availableCalendarLabels) { option in
                        let isSelected = draftEventCalendarId == option.id || (draftEventCalendarId.isEmpty && option.isPrimary)
                        Button(action: {
                            MorphHaptics.levelChange()
                            withAnimation(.spring(response: 0.24, dampingFraction: 0.8)) {
                                draftEventCalendarId = option.id
                                draftEventCalendarName = option.name
                                draftEventColorHex = option.colorHex
                            }
                        }) {
                            HStack(spacing: 4.5) {
                                Circle()
                                    .fill(Color(hex: option.colorHex))
                                    .frame(width: 5.5, height: 5.5)
                                    .shadow(color: isSelected ? Color(hex: option.colorHex).opacity(0.8) : Color.clear, radius: 2)
                                
                                Text(option.name)
                                    .font(.system(size: 9.5, weight: isSelected ? .bold : .medium, design: .rounded))
                                    .foregroundColor(isSelected ? .white : Color.white.opacity(0.70))
                            }
                            .padding(.horizontal, 7.5)
                            .padding(.vertical, 3.5)
                            .background(
                                Capsule()
                                    .fill(isSelected ? Color(hex: option.colorHex).opacity(0.28) : Color.white.opacity(0.06))
                                    .overlay(
                                        Capsule()
                                            .stroke(
                                                isSelected ? Color(hex: option.colorHex).opacity(0.85) : Color.white.opacity(0.12),
                                                lineWidth: isSelected ? 1.0 : 0.7
                                            )
                                    )
                                    .shadow(color: isSelected ? Color(hex: option.colorHex).opacity(0.4) : Color.clear, radius: 3)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 1)
                .padding(.horizontal, 1)
            }
        }
    }
    
    private var calendarDaySpanCount: Int {
        let cal = Calendar.current
        let s = cal.startOfDay(for: draftEventStartDate)
        let e = cal.startOfDay(for: draftEventEndDate)
        let days = cal.dateComponents([.day], from: s, to: e).day ?? 0
        return max(1, days + 1)
    }
    
    private func glassDateStepperChip(date: Date, onDecrement: @escaping () -> Void, onIncrement: @escaping () -> Void) -> some View {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"
        return HStack(spacing: 2) {
            Button(action: {
                MorphHaptics.alignment()
                onDecrement()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 6.5, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.65))
                    .frame(width: 14, height: 16)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            Text(f.string(from: date))
                .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
            
            Button(action: {
                MorphHaptics.alignment()
                onIncrement()
            }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 6.5, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.65))
                    .frame(width: 14, height: 16)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2.5)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.07))
                .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 0.8))
        )
    }
    
    private var glassAddEventDateSpanRow: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Text("DATE SPAN")
                    .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundColor(Color.white.opacity(0.50))
                
                Spacer()
                
                let daysCount = calendarDaySpanCount
                if daysCount > 1 {
                    Text("\(daysCount) DAYS")
                        .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: "#6ab7ff"))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(Capsule().fill(Color(hex: "#6ab7ff").opacity(0.20)))
                }
            }
            .padding(.horizontal, 2)
            
            HStack(spacing: 5) {
                // Start Date
                glassDateStepperChip(
                    date: draftEventStartDate,
                    onDecrement: {
                        let cal = Calendar.current
                        if let newStart = cal.date(byAdding: .day, value: -1, to: draftEventStartDate) {
                            draftEventStartDate = newStart
                            if draftEventEndDate < newStart { draftEventEndDate = newStart }
                        }
                    },
                    onIncrement: {
                        let cal = Calendar.current
                        if let newStart = cal.date(byAdding: .day, value: 1, to: draftEventStartDate) {
                            draftEventStartDate = newStart
                            if draftEventEndDate < newStart { draftEventEndDate = newStart }
                        }
                    }
                )
                
                Image(systemName: "arrow.right")
                    .font(.system(size: 7.5, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.40))
                
                // End Date
                glassDateStepperChip(
                    date: draftEventEndDate,
                    onDecrement: {
                        let cal = Calendar.current
                        if let newEnd = cal.date(byAdding: .day, value: -1, to: draftEventEndDate),
                           newEnd >= Calendar.current.startOfDay(for: draftEventStartDate) {
                            draftEventEndDate = newEnd
                        }
                    },
                    onIncrement: {
                        let cal = Calendar.current
                        if let newEnd = cal.date(byAdding: .day, value: 1, to: draftEventEndDate) {
                            draftEventEndDate = newEnd
                        }
                    }
                )
                
                Spacer()
                
                // Multi-day presets
                HStack(spacing: 2.5) {
                    ForEach([("1d", 0), ("+1d", 1), ("+2d", 2), ("+3d", 3), ("+1w", 7)], id: \.0) { item in
                        let cal = Calendar.current
                        let targetEnd = cal.date(byAdding: .day, value: item.1, to: draftEventStartDate) ?? draftEventStartDate
                        let isSel = cal.isDate(draftEventEndDate, inSameDayAs: targetEnd)
                        Button(action: {
                            MorphHaptics.levelChange()
                            draftEventEndDate = targetEnd
                        }) {
                            Text(item.0)
                                .font(.system(size: 8, weight: isSel ? .bold : .medium, design: .rounded))
                                .foregroundColor(isSel ? .white : Color.white.opacity(0.60))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2.5)
                                .background(
                                    Capsule()
                                        .fill(isSel ? Color(hex: "#6ab7ff").opacity(0.35) : Color.white.opacity(0.05))
                                        .overlay(Capsule().stroke(isSel ? Color(hex: "#6ab7ff").opacity(0.75) : Color.clear, lineWidth: 0.8))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
    
    private var glassAddEventTimeRow: some View {
        HStack(spacing: 5) {
            // All Day toggle
            Button(action: {
                MorphHaptics.levelChange()
                draftEventIsAllDay.toggle()
            }) {
                HStack(spacing: 3.5) {
                    Image(systemName: draftEventIsAllDay ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 9, weight: .bold))
                    Text("All-Day")
                        .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                }
                .foregroundColor(draftEventIsAllDay ? Color(hex: "#6ab7ff") : Color.white.opacity(0.70))
                .padding(.horizontal, 7)
                .padding(.vertical, 3.5)
                .background(
                    Capsule()
                        .fill(draftEventIsAllDay ? Color(hex: "#6ab7ff").opacity(0.22) : Color.white.opacity(0.06))
                        .overlay(Capsule().stroke(draftEventIsAllDay ? Color(hex: "#6ab7ff").opacity(0.6) : Color.white.opacity(0.14), lineWidth: 0.8))
                )
            }
            .buttonStyle(.plain)
            
            if !draftEventIsAllDay {
                // Time stepper
                HStack(spacing: 3) {
                    Button(action: {
                        draftEventHour = (draftEventHour - 1 + 24) % 24
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(Color.white.opacity(0.65))
                    }
                    .buttonStyle(.plain)
                    
                    let displayHour = (draftEventHour % 12 == 0) ? 12 : (draftEventHour % 12)
                    let ampm = draftEventHour >= 12 ? "PM" : "AM"
                    Text(String(format: "%d:%02d %@", displayHour, draftEventMinute, ampm))
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    
                    Button(action: {
                        draftEventHour = (draftEventHour + 1) % 24
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(Color.white.opacity(0.65))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3.5)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.06))
                        .overlay(Capsule().stroke(Color.white.opacity(0.14), lineWidth: 0.8))
                )
                
                // Duration chips
                HStack(spacing: 2.5) {
                    ForEach([15, 30, 60], id: \.self) { d in
                        Button(action: { draftEventDuration = d }) {
                            Text("\(d)m")
                                .font(.system(size: 8.5, weight: .bold, design: .rounded))
                                .foregroundColor(draftEventDuration == d ? Color.white : Color.white.opacity(0.55))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule()
                                        .fill(draftEventDuration == d ? Color(hex: "#6ab7ff").opacity(0.35) : Color.white.opacity(0.05))
                                        .overlay(Capsule().stroke(draftEventDuration == d ? Color(hex: "#6ab7ff").opacity(0.75) : Color.clear, lineWidth: 0.8))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                if draftEventType == "Event" {
                    // Google Meet toggle
                    Button(action: {
                        MorphHaptics.levelChange()
                        draftEventHasMeet.toggle()
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: draftEventHasMeet ? "video.fill" : "video")
                                .font(.system(size: 8))
                            Text("Meet")
                                .font(.system(size: 8.5, weight: .semibold))
                        }
                        .foregroundColor(draftEventHasMeet ? Color(hex: "#6ab7ff") : Color.white.opacity(0.65))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3.5)
                        .background(
                            Capsule()
                                .fill(draftEventHasMeet ? Color(hex: "#6ab7ff").opacity(0.22) : Color.white.opacity(0.06))
                                .overlay(Capsule().stroke(draftEventHasMeet ? Color(hex: "#6ab7ff").opacity(0.6) : Color.white.opacity(0.14), lineWidth: 0.8))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    private var glassAddEventDetailsRow: some View {
        HStack(spacing: 5) {
            // Location
            HStack(spacing: 3.5) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 8))
                    .foregroundColor(Color.white.opacity(0.50))
                TextField("Location...", text: $draftEventLocation)
                    .textFieldStyle(.plain)
                    .font(.system(size: 9.5, design: .rounded))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3.5)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.white.opacity(0.10), lineWidth: 0.8))
            )
            
            // Notes / Description
            HStack(spacing: 3.5) {
                Image(systemName: "text.alignleft")
                    .font(.system(size: 8))
                    .foregroundColor(Color.white.opacity(0.50))
                TextField(draftEventType == "Task" ? "Task details..." : "Notes...", text: $draftEventDescription)
                    .textFieldStyle(.plain)
                    .font(.system(size: 9.5, design: .rounded))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3.5)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.white.opacity(0.10), lineWidth: 0.8))
            )
        }
    }
    
    private var glassAddEventActionRow: some View {
        HStack(spacing: 7) {
            let df: DateFormatter = {
                let f = DateFormatter()
                f.dateFormat = "MMM d"
                return f
            }()
            
            HStack(spacing: 3) {
                Image(systemName: draftEventType == "Task" ? "checklist" : "calendar")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.45))
                
                let rangeText: String = {
                    if calendarDaySpanCount > 1 {
                        return "\(df.string(from: draftEventStartDate)) – \(df.string(from: draftEventEndDate))"
                    }
                    return df.string(from: draftEventStartDate)
                }()
                
                Text(rangeText)
                    .font(.system(size: 8.5, weight: .medium, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.55))
            }
            
            Spacer()
            
            Button(action: {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                    isAddingGlassEvent = false
                }
            }) {
                Text("Cancel")
                    .font(.system(size: 9.5, weight: .medium, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.65))
                    .padding(.horizontal, 8.5)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.06))
                            .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.8))
                    )
            }
            .buttonStyle(.plain)
            
            Button(action: {
                submitGlassEvent()
            }) {
                HStack(spacing: 3.5) {
                    Image(systemName: draftEventType == "Task" ? "checkmark" : "plus")
                        .font(.system(size: 8, weight: .bold))
                    Text(draftEventType == "Task" ? "Add Task" : "Add Event")
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 3.5)
                .background(
                    Capsule()
                        .fill(draftEventTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.white.opacity(0.12) : Color(hex: draftEventColorHex))
                        .overlay(
                            Capsule().stroke(Color.white.opacity(0.35), lineWidth: 0.8)
                        )
                        .shadow(color: draftEventTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.clear : Color(hex: draftEventColorHex).opacity(0.5), radius: 5)
                )
            }
            .buttonStyle(.plain)
            .disabled(draftEventTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
    
    private func submitGlassEvent() {
        let trimmed = draftEventTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let cal = Calendar.current
        var comp = cal.dateComponents([.year, .month, .day], from: draftEventStartDate)
        comp.hour = draftEventHour
        comp.minute = draftEventMinute
        let startDate = draftEventIsAllDay ? cal.startOfDay(for: draftEventStartDate) : (cal.date(from: comp) ?? draftEventStartDate)
        
        // Multi-day end date calculation
        let endDate: Date
        if draftEventIsAllDay {
            let endDayStart = cal.startOfDay(for: max(draftEventEndDate, draftEventStartDate))
            endDate = cal.date(byAdding: .day, value: 1, to: endDayStart) ?? endDayStart.addingTimeInterval(86400)
        } else {
            if cal.isDate(draftEventStartDate, inSameDayAs: draftEventEndDate) {
                endDate = startDate.addingTimeInterval(Double(draftEventDuration * 60))
            } else {
                var endComp = cal.dateComponents([.year, .month, .day], from: draftEventEndDate)
                endComp.hour = (draftEventHour + (draftEventDuration / 60)) % 24
                endComp.minute = (draftEventMinute + (draftEventDuration % 60)) % 60
                let calculatedEnd = cal.date(from: endComp) ?? draftEventEndDate
                endDate = max(calculatedEnd, startDate.addingTimeInterval(Double(draftEventDuration * 60)))
            }
        }
        
        let finalTitle = trimmed
        let taskDescPrefix = draftEventType == "Task" ? "[Task] " : ""
        let finalDesc: String? = {
            let userDesc = draftEventDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            if !userDesc.isEmpty {
                return "\(taskDescPrefix)\(userDesc)"
            }
            return draftEventType == "Task" ? "Task created via Morph" : nil
        }()
        
        model.calendar.addQuickEvent(
            title: finalTitle,
            startTime: startDate,
            endTime: endDate,
            durationMinutes: draftEventDuration,
            isAllDay: draftEventIsAllDay,
            hasMeetLink: draftEventType == "Task" ? false : draftEventHasMeet,
            description: finalDesc,
            location: draftEventLocation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : draftEventLocation,
            colorHex: draftEventColorHex,
            targetCalendarId: draftEventCalendarId.isEmpty ? nil : draftEventCalendarId,
            calendarName: draftEventCalendarName.isEmpty ? nil : draftEventCalendarName
        )
        
        MorphHaptics.levelChange()
        draftEventTitle = ""
        draftEventDescription = ""
        draftEventLocation = ""
        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
            isAddingGlassEvent = false
        }
    }
    
    private var calendarEmptyOrSignInCard: some View {
        VStack(spacing: 10) {
            Image(systemName: model.calendar.isSignedIn ? "checkmark.circle" : "calendar.badge.plus")
                .font(.system(size: 26, weight: .semibold))
                .foregroundColor(Color(hex: "#6ab7ff"))
            
            VStack(spacing: 4) {
                Text(model.calendar.isSignedIn ? "Schedule Clear" : "Connect Your Calendar")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(model.calendar.isSignedIn
                     ? "No events scheduled for this day."
                     : "Sign in with Google in your browser or sync Mac Calendar to view events.")
                    .font(.system(size: 11.5, weight: .regular, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            if !model.calendar.isSignedIn {
                HStack(spacing: 10) {
                    Button(action: {
                        MorphHaptics.levelChange()
                        model.calendar.signInWithGoogle()
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "safari")
                                .font(.system(size: 11, weight: .bold))
                            Text("Sign in with Google")
                                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.white))
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        MorphHaptics.levelChange()
                        model.calendar.syncWithSystemCalendar(requestPermissionIfNeeded: true)
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "applelogo")
                                .font(.system(size: 11, weight: .bold))
                            Text("Sync Mac Calendar")
                                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.16))
                                .overlay(Capsule().stroke(Color.white.opacity(0.35), lineWidth: 1))
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 14)
    }
    
    // MARK: - Music Panel View (460 x 384 pt)
    private var glassMusicView: some View {
        VStack(spacing: 8) {
            glassMusicHeaderView
            
            ZStack {
                switch model.glassMusicSubtab {
                case .playing:
                    glassMusicNowPlayingView
                case .library:
                    glassMusicLibraryView
                case .queue:
                    glassMusicQueueView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            if model.glassMusicSubtab != .playing {
                glassMusicMiniPlayerView
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 4)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var glassMusicHeaderView: some View {
        HStack(spacing: 8) {
            HStack(spacing: 2) {
                glassMusicSegmentButton(tab: .playing)
                glassMusicSegmentButton(tab: .library)
                glassMusicSegmentButton(tab: .queue)
            }
            .padding(2)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.08))
                    .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 0.8))
            )
            
            Spacer()
        }
        .frame(height: 32)
    }
    
    private func glassMusicSegmentButton(tab: GlassMusicSubtab) -> some View {
        let isSelected = model.glassMusicSubtab == tab
        return Button(action: {
            MorphHaptics.levelChange()
            withAnimation(.easeInOut(duration: 0.2)) {
                model.setGlassMusicSubtab(tab)
            }
        }) {
            Text(tab.title)
                .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                .foregroundColor(isSelected ? .white : Color.white.opacity(0.78))
                .padding(.horizontal, 12)
                .frame(height: 28)
                .background(
                    Group {
                        if isSelected {
                            Capsule()
                                .fill(Color.white.opacity(0.28))
                                .overlay(Capsule().stroke(Color.white.opacity(0.65), lineWidth: 1))
                                .shadow(color: Color(hex: "#ff7ab8").opacity(0.65), radius: 8, y: 1)
                        } else {
                            Color.clear
                        }
                    }
                )
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
    
    private var glassMusicServiceBadge: some View {
        Button(action: {
            MorphHaptics.levelChange()
            if !model.media.isSignedIn && !model.media.isBrowserConnected {
                model.media.openSignIn()
            } else {
                model.media.syncSessionFromBrowser()
            }
        }) {
            HStack(spacing: 7) {
                Circle()
                    .fill(Color(hex: "#ff7ab8"))
                    .frame(width: 8, height: 8)
                    .shadow(color: Color(hex: "#ff7ab8"), radius: 4)
                
                Text(model.media.sourceName.isEmpty ? "YouTube Music" : model.media.sourceName)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.12))
                    .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 0.8))
            )
        }
        .buttonStyle(.plain)
        .help("Music Service: YouTube Music. Click to sync or authenticate.")
    }
    
    private var glassMusicNowPlayingView: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 4)
            
            HStack(spacing: 16) {
                glassNowPlayingArtView
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(model.glassMusicTitle)
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            
                            Text(model.glassMusicArtist)
                                .font(.system(size: 12.5, weight: .regular, design: .rounded))
                                .foregroundColor(Color.white.opacity(0.66))
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        GlassIslandEqualizerView(isPlaying: model.isGlassMusicPlaying, height: 16, barColor: Color(hex: "#ff7ab8"))
                    }
                    
                    HStack(spacing: 8) {
                        Text(model.formattedGlassTrackCurrentTime)
                            .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                            .foregroundColor(Color.white.opacity(0.65))
                        
                        let currentSec = model.media.currentTime > 0 ? model.media.currentTime : Double(model.glassTrackCurrentSeconds)
                        let totalDur = max(1, model.media.duration > 0 ? model.media.duration : Double(model.currentGlassTrack?.duration ?? 180))
                        Slider(
                            value: Binding(
                                get: { currentSec },
                                set: { model.seekGlassMusic(to: Int($0)) }
                            ),
                            in: 0...totalDur
                        )
                        .accentColor(.white)
                        
                        Text(model.formattedGlassTrackDuration)
                            .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                            .foregroundColor(Color.white.opacity(0.65))
                    }
                    
                    HStack(spacing: 12) {
                        // Loop / Repeat button (left of Prev)
                        Button(action: {
                            MorphHaptics.levelChange()
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                model.media.toggleRepeat()
                            }
                        }) {
                            ZStack(alignment: .bottomTrailing) {
                                Image(systemName: model.media.repeatMode.iconName)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(model.media.repeatMode != .off ? .white : Color.white.opacity(0.45))
                                if model.media.repeatMode == .all {
                                    Circle()
                                        .fill(Color(hex: "#ff7ab8"))
                                        .frame(width: 5, height: 5)
                                        .offset(x: 2, y: 2)
                                }
                            }
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(model.media.repeatMode != .off
                                          ? Color.white.opacity(0.18)
                                          : Color.clear)
                                    .overlay(
                                        Circle().stroke(
                                            model.media.repeatMode != .off
                                                ? Color.white.opacity(0.35)
                                                : Color.clear,
                                            lineWidth: 0.8
                                        )
                                    )
                            )
                            .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help("Loop: \(model.media.repeatMode.hudTitle) (Click to cycle)")
                        .contextMenu {
                            Button(action: { model.media.setRepeatMode(.off) }) {
                                Label("Loop Off", systemImage: model.media.repeatMode == .off ? "checkmark" : "")
                            }
                            Button(action: { model.media.setRepeatMode(.all) }) {
                                Label("Loop All", systemImage: model.media.repeatMode == .all ? "checkmark" : "")
                            }
                            Button(action: { model.media.setRepeatMode(.one) }) {
                                Label("Loop Current Track", systemImage: model.media.repeatMode == .one ? "checkmark" : "")
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            MorphHaptics.levelChange()
                            model.prevGlassMusic()
                        }) {
                            Image(systemName: "backward.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            MorphHaptics.generic()
                            model.toggleGlassMusicPlay()
                        }) {
                            Image(systemName: model.isGlassMusicPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 48, height: 48)
                                .background(
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [Color.white.opacity(0.50), Color.white.opacity(0.24)],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                        .overlay(Circle().stroke(Color.white.opacity(0.65), lineWidth: 1))
                                        .shadow(color: Color(hex: "#ff7ab8").opacity(0.5), radius: 8, y: 3)
                                )
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            MorphHaptics.levelChange()
                            model.skipGlassMusic(1)
                        }) {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                        
                        // Shuffle button (right of Next, symmetric with Loop)
                        Button(action: {
                            MorphHaptics.levelChange()
                            model.media.toggleShuffle()
                        }) {
                            Image(systemName: "shuffle")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(model.media.isShuffle ? .white : Color.white.opacity(0.45))
                                .frame(width: 36, height: 36)
                                .background(
                                    Circle()
                                        .fill(model.media.isShuffle
                                              ? Color.white.opacity(0.18)
                                              : Color.clear)
                                        .overlay(
                                            Circle().stroke(
                                                model.media.isShuffle
                                                    ? Color.white.opacity(0.35)
                                                    : Color.clear,
                                                lineWidth: 0.8
                                            )
                                        )
                                )
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help(model.media.isShuffle ? "Shuffle On" : "Shuffle Off")
                    }
                }
            }
            .padding(.horizontal, 4)
            
            if !model.media.isSignedIn && !model.media.isBrowserConnected && model.media.trackTitle.isEmpty {
                HStack(spacing: 8) {
                    Button(action: {
                        MorphHaptics.levelChange()
                        model.media.openSignIn()
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "person.crop.circle.badge.plus")
                                .font(.system(size: 11, weight: .bold))
                            Text("Sign In")
                                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(Color.white.opacity(0.95))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.16))
                                .overlay(Capsule().stroke(Color.white.opacity(0.38), lineWidth: 0.9))
                        )
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        MorphHaptics.levelChange()
                        model.media.syncSessionFromBrowser()
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 11, weight: .bold))
                            Text("Sync Browser")
                                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 4)
            } else if (model.media.isSignedIn || model.media.isBrowserConnected) && model.media.trackTitle.isEmpty && !model.isGlassMusicPlaying {
                Button(action: {
                    MorphHaptics.levelChange()
                    model.toggleGlassMusicPlay()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text(model.media.isBrowserConnected ? "Play YouTube Music" : "Play Your Library")
                            .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color.white)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            
            Spacer(minLength: 4)
        }
    }
    
    private var glassNowPlayingArtView: some View {
        ZStack {
            if let artUrl = model.media.albumArtURL, let url = URL(string: artUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable()
                            .aspectRatio(contentMode: .fill)
                    default:
                        musicFallbackArtView
                    }
                }
                .frame(width: 112, height: 112)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            } else if let trackThumb = (model.glassTracks.indices.contains(model.glassTrackIndex) ? model.glassTracks[model.glassTrackIndex].thumbnailURL : nil), let url = URL(string: trackThumb) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable()
                            .aspectRatio(contentMode: .fill)
                    default:
                        musicFallbackArtView
                    }
                }
                .frame(width: 112, height: 112)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            } else {
                musicFallbackArtView
            }
        }
        .frame(width: 112, height: 112)
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.40), lineWidth: 1)
        )
        .shadow(
            color: Color(hex: "#ff7ab8").opacity(model.isGlassMusicPlaying ? 0.60 : 0.20),
            radius: model.isGlassMusicPlaying ? 16 : 6,
            y: 4
        )
    }
    
    private var glassMusicLibraryView: some View {
        VStack(spacing: 8) {
            // Search Bar (searches YouTube Music catalog + user library)
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isGlassMusicSearchFocused ? Color(hex: "#ff7ab8") : Color.white.opacity(0.70))
                
                TextField("Search songs, artists, albums", text: $model.glassMusicSearchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .focused($isGlassMusicSearchFocused)
                    .onAppear {
                        if model.shouldFocusGlassMusicSearch {
                            model.shouldFocusGlassMusicSearch = false
                            DispatchQueue.main.async {
                                isGlassMusicSearchFocused = true
                            }
                        }
                    }
                    .onChange(of: model.focusGlassMusicSearchRequestID) { _, _ in
                        if model.shouldFocusGlassMusicSearch {
                            model.shouldFocusGlassMusicSearch = false
                            DispatchQueue.main.async {
                                isGlassMusicSearchFocused = true
                            }
                        }
                    }
                    .onSubmit {
                        model.submitGlassMusicSearch()
                    }
                
                if model.media.isSearchingCatalog {
                    ProgressView()
                        .scaleEffect(0.55)
                        .frame(width: 14, height: 14)
                }
                
                if !model.glassMusicSearchText.isEmpty {
                    Button(action: {
                        model.glassMusicSearchText = ""
                        model.selectGlassPlaylist(nil)
                        model.media.clearCatalogSearch()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Color.white.opacity(0.60))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(
                Capsule()
                    .fill(Color.white.opacity(isGlassMusicSearchFocused ? 0.14 : 0.10))
                    .overlay(
                        Capsule().stroke(
                            isGlassMusicSearchFocused ? Color(hex: "#ff7ab8").opacity(0.55) : Color.white.opacity(0.24),
                            lineWidth: 0.8
                        )
                    )
            )
            .contentShape(Capsule())
            .onTapGesture {
                isGlassMusicSearchFocused = true
                if let ctrl = MorphController.shared, !MorphEnvironment.isTestingEnvironment {
                    NSApp.activate(ignoringOtherApps: true)
                    ctrl.panel.makeKeyAndOrderFront(nil)
                }
            }
            
            // Content: opened container (e.g. Artist / Album / Playlist) takes priority so Back returns to search results
            if let selectedPlaylist = model.glassSelectedPlaylist {
                glassPlaylistDetailView(playlist: selectedPlaylist)
            } else if !model.glassMusicSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                glassLibrarySearchResultsView
            } else {
                glassPlaylistGridView
            }
        }
    }
    
    private var glassLibrarySearchResultsView: some View {
        let trimmed = model.glassMusicSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let localTracks = model.glassFilteredLibraryTracks
        let catalogGroups = model.media.groupedSearchResults
        
        return Group {
            if !localTracks.isEmpty || !catalogGroups.isEmpty {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 5) {
                        if !localTracks.isEmpty {
                            glassSearchSectionHeader("IN YOUR LIBRARY")
                            ForEach(localTracks) { track in
                                glassTrackRow(track: track, isCurrentlyPlaying: isTrackActive(track)) {
                                    MorphHaptics.levelChange()
                                    model.playGlassLibraryTrack(track)
                                }
                            }
                        }
                        
                        if model.media.isSearchingCatalog && catalogGroups.isEmpty {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .frame(width: 14, height: 14)
                                Text("Searching YouTube Music...")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundColor(Color.white.opacity(0.65))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                        }
                        
                        ForEach(Array(catalogGroups.enumerated()), id: \.offset) { _, group in
                            glassSearchSectionHeader(group.kind.sectionTitle.uppercased())
                            ForEach(group.items) { result in
                                glassSearchResultRow(result)
                            }
                        }
                        
                        if catalogGroups.isEmpty, let err = model.media.catalogSearchError, !model.media.isSearchingCatalog {
                            VStack(spacing: 6) {
                                Text(err)
                                    .font(.system(size: 11.5, weight: .medium, design: .rounded))
                                    .foregroundColor(Color.white.opacity(0.60))
                                    .multilineTextAlignment(.center)
                                Button(action: {
                                    MorphHaptics.levelChange()
                                    model.submitGlassMusicSearch()
                                }) {
                                    Text("Search YouTube Music Again")
                                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 5)
                                        .background(Capsule().fill(Color.white.opacity(0.14)))
                                        .overlay(Capsule().stroke(Color.white.opacity(0.28), lineWidth: 0.8))
                                }
                                .buttonStyle(.plain)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                    }
                    .padding(.vertical, 2)
                }
            } else if model.media.isSearchingCatalog {
                VStack(spacing: 8) {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.85)
                    Text("Searching YouTube Music for \"\(trimmed)\"...")
                        .font(.system(size: 12.5, weight: .medium, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.68))
                        .lineLimit(1)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: model.media.isOffline ? "wifi.slash" : "magnifyingglass")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.40))
                    Text(model.media.isOffline
                         ? "Offline — no local matches for \"\(trimmed)\""
                         : (model.media.catalogSearchError ?? "No results on YouTube Music for \"\(trimmed)\""))
                        .font(.system(size: 12.5, weight: .medium, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.65))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                    
                    if !model.media.isOffline {
                        Button(action: {
                            MorphHaptics.levelChange()
                            model.submitGlassMusicSearch()
                        }) {
                            Text("Search Again")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(.black)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 5)
                                .background(Color.white)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
    
    private func glassSearchSectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .heavy, design: .rounded))
            .foregroundColor(Color.white.opacity(0.45))
            .tracking(1.2)
            .padding(.top, 4)
            .padding(.horizontal, 4)
    }
    
    private func isSearchResultActive(_ result: YTMSearchResult) -> Bool {
        guard result.kind == .song || result.kind == .video else { return false }
        let curTitle = model.glassMusicTitle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let resTitle = result.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return !curTitle.isEmpty && !resTitle.isEmpty && curTitle == resTitle
    }
    
    private func glassSearchResultRow(_ result: YTMSearchResult) -> some View {
        let isCurrentlyPlaying = isSearchResultActive(result)
        let isPlayable = (result.kind == .song || result.kind == .video)
        let subtitleText: String = {
            if !result.subtitle.isEmpty { return result.subtitle }
            switch result.kind {
            case .artist: return "Artist"
            case .album: return "Album"
            case .playlist: return "Playlist"
            case .video: return "Video"
            case .song: return "Song"
            }
        }()
        
        return Button(action: {
            MorphHaptics.levelChange()
            withAnimation(.easeInOut(duration: 0.2)) {
                model.openGlassSearchResult(result)
            }
        }) {
            HStack(spacing: 10) {
                glassCoverThumbnail(
                    url: result.thumbnailURL,
                    size: 34,
                    cornerRadius: result.kind == .artist ? 17 : 10,
                    fallbackIcon: result.kind.iconName
                )
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(result.title)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(subtitleText)
                        .font(.system(size: 11.5, weight: .regular, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.62))
                        .lineLimit(1)
                }
                
                Spacer()
                
                if isCurrentlyPlaying {
                    GlassIslandEqualizerView(isPlaying: model.isGlassMusicPlaying, height: 12, barColor: Color(hex: "#ff7ab8"))
                        .padding(.trailing, 4)
                } else {
                    Image(systemName: isPlayable ? "play.fill" : "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.55))
                        .padding(.trailing, 4)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 46)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isCurrentlyPlaying ? Color.white.opacity(0.18) : Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(
                                isCurrentlyPlaying ? Color(hex: "#ff7ab8").opacity(0.60) : Color.white.opacity(0.12),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .help(isPlayable ? "Play \(result.title)" : "Open \(result.title)")
    }
    
    private func glassPlaylistDetailView(playlist: YTMPlaylist) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Button(action: {
                    MorphHaptics.levelChange()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        model.selectGlassPlaylist(nil)
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color.white.opacity(0.12)))
                }
                .buttonStyle(.plain)
                .help("Back")
                
                glassCoverThumbnail(
                    url: playlist.thumbnailURL,
                    size: 36,
                    cornerRadius: playlist.kind == .artist ? 18 : 10,
                    fallbackIcon: playlist.kind == .artist ? "person.fill" : "music.note"
                )
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(playlist.title)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(model.media.isLoadingTracks && playlist.tracks.isEmpty
                         ? "Loading songs..."
                         : (playlist.tracks.isEmpty && !playlist.subtitle.isEmpty ? playlist.subtitle : "\(playlist.tracks.count) songs"))
                        .font(.system(size: 11.5, weight: .regular, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.62))
                        .lineLimit(1)
                }
                
                Spacer()
                
                Button(action: {
                    MorphHaptics.levelChange()
                    model.playGlassSelectedPlaylistAll(shuffle: false)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text("Play")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 12)
                    .frame(height: 30)
                    .background(Color.white)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    MorphHaptics.levelChange()
                    model.playGlassSelectedPlaylistAll(shuffle: true)
                }) {
                    Image(systemName: "shuffle")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color.white.opacity(0.14)))
                }
                .buttonStyle(.plain)
                .help("Shuffle play")
            }
            .frame(height: 36)
            
            if model.media.isLoadingTracks && playlist.tracks.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.85)
                    Text("Loading songs...")
                        .font(.system(size: 12.5, weight: .medium, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.65))
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else if playlist.tracks.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Text(model.media.tracksError ?? "No songs available in this \(playlist.kind == .artist ? "artist" : "playlist").")
                        .font(.system(size: 12.5, weight: .medium, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.65))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                    Button(action: {
                        MorphHaptics.levelChange()
                        model.media.loadTracksForSelectedPlaylist()
                    }) {
                        Text("Retry")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(.black)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 5)
                            .background(Color.white)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(playlist.tracks) { track in
                            glassTrackRow(track: track, isCurrentlyPlaying: isTrackActive(track)) {
                                MorphHaptics.levelChange()
                                model.playGlassLibraryTrack(track)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
    
    private var glassPlaylistGridView: some View {
        let playlists = model.media.playlists
        let quickPicks = model.media.quickPicks
        return Group {
            if playlists.isEmpty && quickPicks.isEmpty {
                VStack(spacing: 10) {
                    Spacer()
                    Image(systemName: "music.note.list")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.40))
                    Text(model.media.isSignedIn || model.media.isBrowserConnected ? "No playlists found in your YouTube Music library" : "Connect YouTube Music to browse your playlists")
                        .font(.system(size: 12.5, weight: .medium, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.65))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    
                    if !model.media.isSignedIn && !model.media.isBrowserConnected {
                        Button(action: {
                            MorphHaptics.levelChange()
                            model.media.openSignIn()
                        }) {
                            Text("Sign In")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(.black)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                                .background(Color.white)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        // ── Quick Picks shelf (YouTube Music style) ──────────────────
                        if !quickPicks.isEmpty {
                            glassQuickPicksShelf(picks: quickPicks)
                        }
                        
                        // ── Playlists grid ───────────────────────────────────────────
                        if !playlists.isEmpty {
                            HStack {
                                Text("YOUR LIBRARY")
                                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                                    .foregroundColor(Color.white.opacity(0.45))
                                    .tracking(1.2)
                                Spacer()
                            }
                            
                            LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
                                ForEach(playlists) { pl in
                                    Button(action: {
                                        MorphHaptics.levelChange()
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            model.selectGlassPlaylist(pl)
                                        }
                                    }) {
                                        HStack(spacing: 10) {
                                            glassCoverThumbnail(url: pl.thumbnailURL, size: 44, cornerRadius: 12)
                                            
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(pl.title)
                                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                                    .foregroundColor(.white)
                                                    .lineLimit(1)
                                                
                                                Text(pl.tracks.count > 0 ? "\(pl.tracks.count) songs" : (pl.subtitle.isEmpty ? "Playlist" : pl.subtitle))
                                                    .font(.system(size: 11.5, weight: .regular, design: .rounded))
                                                    .foregroundColor(Color.white.opacity(0.62))
                                                    .lineLimit(1)
                                            }
                                            Spacer()
                                        }
                                        .padding(.horizontal, 8)
                                        .frame(height: 56)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .fill(Color.white.opacity(0.09))
                                                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.20), lineWidth: 0.8))
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
    
    // MARK: - Glass Quick Picks Shelf (YouTube Music style)
    private func glassQuickPicksShelf(picks: [YTMPlaylistItem]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header row
            HStack(alignment: .center, spacing: 6) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Quick Picks")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("Picked for you")
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.55))
                }
                Spacer()
                Button(action: {
                    MorphHaptics.levelChange()
                    model.media.refreshQuickPicks()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.65))
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.white.opacity(0.10)))
                }
                .buttonStyle(.plain)
                .help("Refresh Quick Picks")
            }
            
            // Horizontal scrolling track cards
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(picks.prefix(12)) { track in
                        let isActive = model.media.trackTitle == track.title && (model.media.isPlaying || model.media.currentTime > 0)
                        Button(action: {
                            MorphHaptics.levelChange()
                            model.media.playQuickPick(track)
                        }) {
                            VStack(alignment: .leading, spacing: 6) {
                                ZStack(alignment: .bottomLeading) {
                                    glassCoverThumbnail(url: track.thumbnailURL, size: 90, cornerRadius: 14)
                                    if isActive {
                                        HStack(spacing: 2) {
                                            GlassIslandEqualizerView(isPlaying: model.media.isPlaying, height: 10, barColor: .white)
                                        }
                                        .padding(5)
                                        .background(Color.black.opacity(0.45))
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                        .padding(5)
                                    }
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(track.title.isEmpty ? "Unknown" : track.title)
                                        .font(.system(size: 11.5, weight: isActive ? .bold : .semibold, design: .rounded))
                                        .foregroundColor(isActive ? Color(hex: "#ff7ab8") : .white)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                    Text(track.artist.isEmpty ? "Artist" : track.artist)
                                        .font(.system(size: 10.5, weight: .regular, design: .rounded))
                                        .foregroundColor(Color.white.opacity(0.55))
                                        .lineLimit(1)
                                }
                            }
                            .frame(width: 90)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 1)
                .padding(.bottom, 2)
            }
        }
        .padding(.bottom, 4)
    }
    
    private var glassMusicQueueView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                Text("NOW PLAYING")
                    .font(.system(size: 10.5, weight: .bold, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.60))
                    .padding(.horizontal, 6)
                    .padding(.top, 2)
                
                let currentItem = YTMPlaylistItem(
                    id: "queue_now_playing",
                    title: model.glassMusicTitle,
                    artist: model.glassMusicArtist,
                    duration: model.formattedGlassTrackDuration,
                    isPlaying: model.isGlassMusicPlaying,
                    thumbnailURL: model.media.albumArtURL
                )
                glassTrackRow(track: currentItem, isCurrentlyPlaying: true) {
                    MorphHaptics.generic()
                    model.toggleGlassMusicPlay()
                }
                
                let upcoming = model.media.playlist.filter { !isTrackActive($0) }
                if !upcoming.isEmpty {
                    Text("UP NEXT · \(upcoming.count)")
                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.60))
                        .padding(.horizontal, 6)
                        .padding(.top, 6)
                    
                    LazyVStack(spacing: 3) {
                        ForEach(upcoming) { track in
                            glassTrackRow(track: track, isCurrentlyPlaying: false) {
                                MorphHaptics.levelChange()
                                model.media.playQueueTrack(track)
                            }
                        }
                    }
                } else if model.media.playlist.isEmpty && model.glassTracks.count > 1 {
                    let fallbackUpcoming = Array(model.glassTracks.dropFirst())
                    Text("UP NEXT · \(fallbackUpcoming.count)")
                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.60))
                        .padding(.horizontal, 6)
                        .padding(.top, 6)
                    
                    LazyVStack(spacing: 3) {
                        ForEach(fallbackUpcoming) { track in
                            let item = YTMPlaylistItem(
                                id: track.id.uuidString,
                                title: track.title,
                                artist: track.artist,
                                duration: String(format: "%d:%02d", track.duration / 60, track.duration % 60),
                                isPlaying: false,
                                videoId: track.videoId,
                                thumbnailURL: track.thumbnailURL
                            )
                            glassTrackRow(track: item, isCurrentlyPlaying: false) {
                                MorphHaptics.levelChange()
                                model.media.playQueueTrack(item)
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }
    
    private var glassMusicMiniPlayerView: some View {
        HStack(spacing: 10) {
            Button(action: {
                MorphHaptics.levelChange()
                withAnimation(.easeInOut(duration: 0.2)) {
                    model.setGlassMusicSubtab(.playing)
                }
            }) {
                HStack(spacing: 10) {
                    glassCoverThumbnail(url: model.media.albumArtURL, size: 36, cornerRadius: 11)
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text(model.glassMusicTitle)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Text(model.glassMusicArtist)
                            .font(.system(size: 11.5, weight: .regular, design: .rounded))
                            .foregroundColor(Color.white.opacity(0.62))
                            .lineLimit(1)
                    }
                    
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            
            Button(action: {
                MorphHaptics.generic()
                model.toggleGlassMusicPlay()
            }) {
                Image(systemName: model.isGlassMusicPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.26))
                            .overlay(Circle().stroke(Color.white.opacity(0.60), lineWidth: 1))
                            .shadow(color: Color(hex: "#ff7ab8").opacity(0.40), radius: 6)
                    )
            }
            .buttonStyle(.plain)
            
            Button(action: {
                MorphHaptics.levelChange()
                model.skipGlassMusic(1)
            }) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.white.opacity(0.12)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .frame(height: 50)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.12))
                .overlay(Capsule().stroke(Color.white.opacity(0.28), lineWidth: 0.9))
                .shadow(color: Color.black.opacity(0.35), radius: 8, y: 2)
        )
    }
    
    private func glassCoverThumbnail(url: String?, size: CGFloat, cornerRadius: CGFloat, fallbackIcon: String? = nil) -> some View {
        ZStack {
            if let urlStr = url, let imgUrl = URL(string: urlStr) {
                AsyncImage(url: imgUrl) { phase in
                    if let image = phase.image {
                        image.resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        fallbackGradientTile(size: size, cornerRadius: cornerRadius, fallbackIcon: fallbackIcon)
                    }
                }
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            } else {
                fallbackGradientTile(size: size, cornerRadius: cornerRadius, fallbackIcon: fallbackIcon)
            }
        }
        .frame(width: size, height: size)
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.30), lineWidth: 0.8)
        )
    }
    
    private func fallbackGradientTile(size: CGFloat, cornerRadius: CGFloat, fallbackIcon: String? = nil) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#ff5fa8"), Color(hex: "#6a5cff"), Color(hex: "#16d9c5")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            if let icon = fallbackIcon {
                Image(systemName: icon)
                    .font(.system(size: max(11, size * 0.38), weight: .bold))
                    .foregroundColor(.white.opacity(0.88))
            }
        }
        .frame(width: size, height: size)
    }
    
    private func glassTrackRow(track: YTMPlaylistItem, isCurrentlyPlaying: Bool, onSelect: @escaping () -> Void) -> some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                glassCoverThumbnail(url: track.thumbnailURL, size: 34, cornerRadius: 10)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(track.title)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(track.artist.isEmpty ? "Unknown Artist" : track.artist)
                        .font(.system(size: 11.5, weight: .regular, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.62))
                        .lineLimit(1)
                }
                
                Spacer()
                
                if isCurrentlyPlaying {
                    GlassIslandEqualizerView(isPlaying: model.isGlassMusicPlaying, height: 12, barColor: Color(hex: "#ff7ab8"))
                        .padding(.trailing, 4)
                } else if !track.duration.isEmpty {
                    Text(track.duration)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.70))
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 46)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isCurrentlyPlaying ? Color.white.opacity(0.18) : Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(
                                isCurrentlyPlaying ? Color(hex: "#ff7ab8").opacity(0.60) : Color.white.opacity(0.10),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    private func isTrackActive(_ track: YTMPlaylistItem) -> Bool {
        if track.isPlaying { return true }
        let curTitle = model.glassMusicTitle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let trTitle = track.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return !curTitle.isEmpty && !trTitle.isEmpty && curTitle == trTitle
    }
    
    private var musicFallbackArtView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#ff5fa8"), Color(hex: "#6a5cff"), Color(hex: "#16d9c5")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Image(systemName: "music.note")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white.opacity(0.85))
            
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.55), Color.clear],
                        center: .topLeading,
                        startRadius: 5,
                        endRadius: 70
                    )
                )
        }
        .frame(width: 112, height: 112)
    }
    
    // MARK: - Notes Panel View (460 x 284 pt)
    private var glassNotesView: some View {
        Group {
            if model.glassNotesMode == .list {
                VStack(spacing: 8) {
                    // Head: "3 notes" + "+ New"
                    HStack {
                        Text("\(model.glassNotes.count) \(model.glassNotes.count == 1 ? "note" : "notes")")
                            .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                            .tracking(1.2)
                            .foregroundColor(Color.white.opacity(0.62))
                        
                        Spacer()
                        
                        Button(action: {
                            MorphHaptics.levelChange()
                            model.addGlassNote()
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: "plus")
                                    .font(.system(size: 11, weight: .bold))
                                Text("New")
                                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.20))
                                    .overlay(Capsule().stroke(Color.white.opacity(0.40), lineWidth: 1))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(height: 28)
                    
                    // Notes List
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 6) {
                            ForEach(model.glassNotes) { note in
                                Button(action: {
                                    MorphHaptics.generic()
                                    model.openGlassNote(id: note.id)
                                }) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(note.title.isEmpty ? "Untitled" : note.title)
                                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                        
                                        Text(note.body.isEmpty ? "No text yet" : note.body)
                                            .font(.system(size: 12, weight: .regular, design: .rounded))
                                            .foregroundColor(Color.white.opacity(0.64))
                                            .lineLimit(1)
                                    }
                                    .padding(.horizontal, 14)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .frame(height: 50)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(
                                                LinearGradient(
                                                    colors: [Color.white.opacity(0.20), Color.white.opacity(0.08)],
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                )
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
                                            )
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            } else {
                // Edit Mode
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Button(action: {
                            MorphHaptics.generic()
                            model.closeGlassNote()
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 32, height: 32)
                                .background(Circle().fill(Color.white.opacity(0.14)))
                        }
                        .buttonStyle(.plain)
                        .help("Back to notes")
                        
                        TextField("Title", text: $model.glassEditTitle)
                            .textFieldStyle(.plain)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    
                    TextEditor(text: $model.glassEditBody)
                        .font(.system(size: 13.5, weight: .regular, design: .rounded))
                        .scrollContentBackground(.hidden)
                        .foregroundColor(.white)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.white.opacity(0.10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                                )
                        )
                }
            }
        }
        .padding(.horizontal, 4)
    }
    
    // MARK: - Reply Panel View (460 x 152 pt)
    private var glassReplyView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                if let icon = model.glassReplyDomainIcon, let hex = model.glassReplyDomainColorHex {
                    HStack(spacing: 4) {
                        Image(systemName: icon)
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundColor(Color(hex: hex))
                        Text(model.glassReplyDomainTitle.uppercased())
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(hex: hex))
                            .tracking(1.0)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2.5)
                    .background(Color(hex: hex).opacity(0.14))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color(hex: hex).opacity(0.35), lineWidth: 0.6))
                }
                
                Spacer()
            }
            
            Text(model.glassReplyQuery.isEmpty ? "What's on today?" : model.glassReplyQuery)
                .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
            
            if model.isGlassReplyLoading {
                VStack(alignment: .leading, spacing: 5) {
                    Capsule()
                        .fill(Color.white.opacity(0.20))
                        .frame(width: 200, height: 7)
                    Capsule()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 140, height: 7)
                }
                .padding(.top, 2)
            } else {
                Text(model.glassReplyAnswer)
                    .font(.system(size: 11.5, weight: .regular, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.85))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Interactive Quick Action Suggestions (when no direct action matches)
                if !model.glassReplyQuickActions.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(model.glassReplyQuickActions) { action in
                            Button(action: {
                                MorphHaptics.levelChange()
                                model.submitGlassIslandPrompt(action.command)
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: action.icon)
                                        .font(.system(size: 8.5, weight: .semibold))
                                    Text(action.title)
                                        .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color.white.opacity(0.12))
                                        .overlay(Capsule().stroke(Color.white.opacity(0.20), lineWidth: 0.6))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 3)
                }
                
                if let actionTitle = model.glassReplyActionTitle, let targetState = model.glassReplyTargetState {
                    Button(action: {
                        MorphHaptics.levelChange()
                        withAnimation(MorphUniversalAnimation.stateExpansion) {
                            model.setGlassIslandState(targetState)
                        }
                    }) {
                        HStack(spacing: 4) {
                            Text(actionTitle)
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 8, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3.5)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.14))
                                .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 0.6))
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var compactStageView: some View {
        glassIslandRootContentView
    }

    // MARK: - Stage Action Handlers & Dynamic Button Data
    private var primaryStageIcon: String {
        if let stage = model.activeIntermediaryStage {
            switch stage {
            case .home, .timer:
                return "flame.fill"
            case .music:
                return model.media.isPlaying ? "pause.fill" : "play.fill"
            case .calendar:
                return "video.fill"
            case .notes:
                return "pin.fill"
            case .answer:
                return "checkmark"
            }
        }
        switch model.selectedTab {
        case .timer:
            return "flame.fill"
        case .music:
            return model.media.isPlaying ? "pause.fill" : "play.fill"
        case .calendar:
            return "video.fill"
        case .notes:
            return "pin.fill"
        case .home, .profile:
            return "flame.fill"
        }
    }

    private var primaryStageTitle: String {
        if let stage = model.activeIntermediaryStage {
            switch stage {
            case .home, .timer:
                return "Start \(model.requestedTimerMinutes)m Focus"
            case .music:
                return model.media.isPlaying ? "Pause" : "Play"
            case .calendar:
                return "Join Call"
            case .notes:
                return "Pin to Notch"
            case .answer:
                return "Done"
            }
        }
        switch model.selectedTab {
        case .timer:
            return "Start \(model.requestedTimerMinutes)m Focus"
        case .music:
            return model.media.isPlaying ? "Pause" : "Play"
        case .calendar:
            return "Join Call"
        case .notes:
            return "Pin to Notch"
        case .home, .profile:
            return "Start \(model.requestedTimerMinutes)m Focus"
        }
    }

    private func handlePrimaryStageAction() {
        if let stage = model.activeIntermediaryStage {
            switch stage {
            case .home, .timer:
                model.commitIntermediaryTimer()
            case .music:
                model.commitIntermediaryMusic(play: !model.media.isPlaying)
            case .calendar:
                model.commitIntermediaryCalendarJoinCall()
            case .notes:
                model.commitIntermediaryNotesPin()
            case .answer:
                model.commitIntermediaryAnswerDone()
            }
            return
        }
        switch model.selectedTab {
        case .timer, .home, .profile:
            model.commitIntermediaryTimer()
        case .music:
            model.commitIntermediaryMusic(play: !model.media.isPlaying)
        case .calendar:
            model.commitIntermediaryCalendarJoinCall()
        case .notes:
            model.commitIntermediaryNotesPin()
        }
    }

    private var secondaryStageIcon1: String {
        if let stage = model.activeIntermediaryStage {
            switch stage {
            case .music:
                return "forward.fill"
            case .calendar:
                return "calendar"
            case .notes, .answer:
                return "doc.on.doc"
            case .home, .timer:
                return "music.note"
            }
        }
        switch model.selectedTab {
        case .music:
            return "forward.fill"
        case .calendar:
            return "calendar"
        case .notes:
            return "doc.on.doc"
        default:
            return "music.note"
        }
    }

    private var secondaryStageTitle1: String {
        if let stage = model.activeIntermediaryStage {
            switch stage {
            case .music:
                return "Next"
            case .calendar:
                return "Today"
            case .notes, .answer:
                return "Copy"
            case .home, .timer:
                return "Music"
            }
        }
        switch model.selectedTab {
        case .music:
            return "Next"
        case .calendar:
            return "Today"
        case .notes:
            return "Copy"
        default:
            return "Music"
        }
    }

    private func handleSecondaryStageAction1() {
        if let stage = model.activeIntermediaryStage {
            switch stage {
            case .music:
                model.media.nextTrack()
            case .calendar:
                model.openFeature(.calendar)
            case .notes:
                model.scratchpad.copyAll()
            case .answer:
                if case .answer(_, let head, let sub, _) = stage {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString("\(head)\n\(sub)", forType: .string)
                }
            case .home, .timer:
                model.presentIntermediaryMusic(action: .open)
            }
            return
        }
        switch model.selectedTab {
        case .music:
            model.media.nextTrack()
        case .calendar:
            model.openFeature(.calendar)
        case .notes:
            model.scratchpad.copyAll()
        default:
            model.presentIntermediaryMusic(action: .open)
        }
    }

    private var secondaryStageIcon2: String {
        if let stage = model.activeIntermediaryStage {
            switch stage {
            case .home, .timer, .music:
                return "note.text"
            case .calendar:
                return "flame"
            case .notes:
                return "trash"
            case .answer:
                return "arrow.up.forward.app"
            }
        }
        switch model.selectedTab {
        case .notes:
            return "trash"
        case .calendar:
            return "flame"
        default:
            return "note.text"
        }
    }

    private var secondaryStageTitle2: String {
        if let stage = model.activeIntermediaryStage {
            switch stage {
            case .home, .timer, .music:
                return "Notes"
            case .calendar:
                return "Focus"
            case .notes:
                return "Clear"
            case .answer:
                return "Deep View"
            }
        }
        switch model.selectedTab {
        case .notes:
            return "Clear"
        case .calendar:
            return "Focus"
        default:
            return "Notes"
        }
    }

    private func handleSecondaryStageAction2() {
        if let stage = model.activeIntermediaryStage {
            switch stage {
            case .home, .timer, .music:
                model.presentIntermediaryNote(action: .view)
            case .calendar:
                model.presentIntermediaryTimer(minutes: 25, title: "Focus Session")
            case .notes:
                model.scratchpad.clear()
            case .answer:
                if case .answer(let q, let h, let s, let i) = stage {
                    let aiResp = MorphSpotlightCommandParser.generateAIResponse(for: q, briefAnswer: "\(h) — \(s)", icon: i)
                    model.displayInBigUI(aiResponse: aiResp)
                }
            }
            return
        }
        switch model.selectedTab {
        case .notes:
            model.scratchpad.clear()
        case .calendar:
            model.presentIntermediaryTimer(minutes: 25, title: "Focus Session")
        default:
            model.presentIntermediaryNote(action: .view)
        }
    }

    // MARK: - 3. Expanded Island View (Adaptive: Glass Island or Full View)
    private var expandedView: some View {
        Group {
            if model.isGlassIslandEnabled {
                glassIslandRootContentView
            } else if model.isIntermediaryStageActive {
                compactStageView
            } else {
                fullExpandedView
            }
        }
    }

    private var fullExpandedView: some View {
        VStack(spacing: 6) {
            // Top Notch Row: Wings on Left/Right, Empty Center Blind Spot for Hardware Notch
            topNotchRow
                .frame(height: notchBlindHeight)
            
            // Main Feature Body: Sits completely BELOW the notch blind spot
            // The top tab bar has been removed as requested to maximize the liquid glass stage
            ZStack {
                if let aiResponse = model.activeAIResponse {
                    AIIntelligenceView(response: aiResponse, model: model)
                        .transition(.asymmetric(insertion: .opacity, removal: .opacity))
                } else if let contextFeature = model.activeContextFeature {
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
    
    // MARK: - Active Feature Breadcrumb Badge (Apple Liquid Glass)
    private var activeFeatureBreadcrumbBadge: some View {
        let (icon, label): (String, String) = {
            if model.activeAIResponse != nil {
                return ("sparkles", "Morph AI")
            }
            switch model.selectedTab {
            case .home:
                return ("sparkles", "Overview")
            case .timer:
                let title = model.customTimerTitle.isEmpty ? "Focus Flow" : model.customTimerTitle
                return ("timer", title)
            case .music:
                return ("music.note", "Now Playing")
            case .notes:
                return ("note.text", "Scratchpad")
            case .calendar:
                return ("calendar", "Today's Agenda")
            case .profile:
                return ("person.crop.circle", "Preferences")
            }
        }()
        
        return HStack(spacing: 4.5) {
            Image(systemName: icon)
                .font(.system(size: 8.5, weight: .bold))
                .foregroundColor(model.theme.textPrimary)
            
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(model.theme.textPrimary)
                .tracking(0.8)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3.5)
        .background(
            Capsule()
                .fill(Color.white.opacity(model.theme.isDark ? 0.08 : 0.14))
                .background(.ultraThinMaterial)
        )
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(model.theme.liquidGlassSpecularBorder, lineWidth: 0.75)
        )
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
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4.5)
                        .background(
                            Capsule()
                                .fill(model.theme.cardBackgroundElevated)
                                .background(.ultraThinMaterial)
                        )
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(model.theme.liquidGlassSpecularBorder, lineWidth: 0.75)
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
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(model.theme.cardBackground)
                                .background(.ultraThinMaterial)
                        )
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(model.theme.liquidGlassSpecularBorder, lineWidth: 0.75)
                        )
                    } else {
                        Text(contextFeature.rawValue)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(model.theme.textSecondary)
                            .lineLimit(1)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(model.theme.cardBackground)
                                    .background(.ultraThinMaterial)
                            )
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(model.theme.liquidGlassSpecularBorder, lineWidth: 0.75)
                            )
                    }
                } else {
                    // Profile Avatar Pill with Name & Live Status
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
                            
                            Circle()
                                .fill(Color.green)
                                .frame(width: 4, height: 4)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3.5)
                        .background(
                            Capsule()
                                .fill(model.theme.cardBackground)
                                .background(.ultraThinMaterial)
                        )
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(model.theme.liquidGlassSpecularBorder, lineWidth: 0.75)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Profile and Preferences")
                    .help("Profile & Preferences (⌘5 or ⌘,)")
                    
                    // Liquid Glass Active Feature Breadcrumb Badge
                    activeFeatureBreadcrumbBadge
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
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.08))
                                .background(.ultraThinMaterial)
                        )
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(model.theme.liquidGlassSpecularBorder, lineWidth: 0.5)
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
                    .padding(.horizontal, 7)
                    .frame(height: 22)
                    .background(
                        Capsule()
                            .fill(model.isCommandBarPresented ? model.theme.activePillBackground : model.theme.cardBackground)
                            .background(.ultraThinMaterial)
                    )
                    .clipShape(Capsule())
                    .overlay(
                        Group {
                            if model.isCommandBarPresented {
                                Capsule().stroke(model.theme.activeBorder, lineWidth: 0.75)
                            } else {
                                Capsule().stroke(model.theme.liquidGlassSpecularBorder, lineWidth: 0.75)
                            }
                        }
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
                        .background(
                            Circle()
                                .fill(model.theme.cardBackground)
                                .background(.ultraThinMaterial)
                        )
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(model.theme.liquidGlassSpecularBorder, lineWidth: 0.75)
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
                        .background(
                            Circle()
                                .fill(model.isPinned ? model.theme.cardBackgroundElevated : model.theme.cardBackground)
                                .background(.ultraThinMaterial)
                        )
                        .clipShape(Circle())
                        .overlay(
                        Group {
                            if model.isPinned {
                                Circle().stroke(model.theme.activeBorder, lineWidth: 0.75)
                            } else {
                                Circle().stroke(model.theme.liquidGlassSpecularBorder, lineWidth: 0.75)
                            }
                        }
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(model.isPinned ? "Unpin Island" : "Pin Island Open")
                .help(model.isPinned ? "Unpin Window (⌘P)" : "Pin Window Open (⌘P)")
                
                // Collapse / Dismiss to Stealth Button
                Button(action: {
                    MorphHaptics.levelChange()
                    if let ctrl = MorphController.shared {
                        ctrl.dismissToStealth()
                    } else {
                        withAnimation(MorphUniversalAnimation.stealthRetraction) {
                            model.resetTransientStateOnCollapse()
                        }
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(model.theme.textSecondary)
                        .frame(width: 22, height: 22)
                        .background(
                            Circle()
                                .fill(model.theme.cardBackground)
                                .background(.ultraThinMaterial)
                        )
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(model.theme.liquidGlassSpecularBorder, lineWidth: 0.75)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Collapse to Stealth")
                .help("Collapse to Stealth (Esc)")
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
        HStack(spacing: 5) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.18), lineWidth: 2)
                    .frame(width: 13.5, height: 13.5)
                
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
                    .frame(width: 13.5, height: 13.5)
            }
            
            Text(pomodoro.formattedTime)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
        }
        .padding(.leading, 10)
    }
}

private struct CompactPomodoroWingRight: View {
    @ObservedObject var pomodoro: PomodoroModel
    let model: NotchModel
    
    var body: some View {
        Button(action: {
            model.stopFocusTimer()
        }) {
            Image(systemName: "xmark")
                .font(.system(size: 8.5, weight: .bold))
                .foregroundColor(Color.white.opacity(0.70))
                .frame(width: 18, height: 18)
                .background(Color.white.opacity(0.14))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .help("Close / Stop Timer (⌘R)")
        .padding(.trailing, 10)
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
                    Text(media.offlineHUDMessage.isEmpty ? "Offline | Downloads Opened" : media.offlineHUDMessage)
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
            } else if media.showShuffleHUD {
                // Sleek Notch Shuffle / Random Next HUD Pill
                HStack(spacing: 3.5) {
                    Image(systemName: "shuffle")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(media.isShuffle ? Color.white : Color.white.opacity(0.5))
                    Text(media.isShuffle ? "Random Next On" : "Random Next Off")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.95))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2.5)
                .background(media.isShuffle ? Color.white.opacity(0.22) : Color.white.opacity(0.12))
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
            .help(media.isPlaying ? "Pause Music (F8, Space, ⌘⏎)" : "Play Music (F8, Space, ⌘⏎)")
            .accessibilityLabel(media.isPlaying ? "Pause Music" : "Play Music")
            
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
            .help("Next Track (F9, ⌘])")
            .accessibilityLabel("Next Track")
            
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
                    Text(media.offlineHUDMessage.isEmpty ? "Offline | Downloads Opened" : media.offlineHUDMessage)
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
            } else if media.showShuffleHUD {
                HStack(spacing: 3) {
                    Image(systemName: "shuffle")
                        .font(.system(size: 7.5, weight: .bold))
                        .foregroundColor(media.isShuffle ? Color.white : Color.white.opacity(0.5))
                    Text(media.isShuffle ? "Random Next On" : "Random Next Off")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.95))
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(media.isShuffle ? Color.white.opacity(0.22) : Color.white.opacity(0.12))
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
            .help(media.isPlaying ? "Pause Music (F8, Space, ⌘⏎)" : "Play Music (F8, Space, ⌘⏎)")
            .accessibilityLabel(media.isPlaying ? "Pause Music" : "Play Music")
            
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
            .help("Next Track (F9, ⌘])")
            .accessibilityLabel("Next Track")
            
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
                shortcutBadge: "F8 / ⌘⏎",
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
                shortcutBadge: "F9 / ⌘]",
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
                shortcutBadge: "F7 / ⌘[",
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

// MARK: - AI Intelligence Big UI Screen View
public struct AIIntelligenceView: View {
    public let response: MorphAIResponse
    @ObservedObject public var model: NotchModel
    @ObservedObject public var theme: MorphTheme = .shared
    @State private var isCopied: Bool = false
    
    public init(response: MorphAIResponse, model: NotchModel) {
        self.response = response
        self.model = model
    }
    
    public var body: some View {
        VStack(spacing: 8) {
            // Header Row: Morphy Mascot + Category Badge + Query Capsule + Dismiss Button
            HStack(spacing: 8) {
                MorphyMascotView(model: model, style: .restingStealth)
                    .frame(width: 22, height: 22)
                
                // Category Tag
                Text(response.category.uppercased())
                    .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                    .foregroundColor(theme.textTertiary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(theme.isDark ? 0.08 : 0.06))
                    .clipShape(Capsule())
                
                // Prompt Query Capsule
                HStack(spacing: 4) {
                    Image(systemName: "quote.opening")
                        .font(.system(size: 7.5, weight: .bold))
                        .foregroundColor(theme.textTertiary)
                    Text(response.query)
                        .font(.system(size: 10.5, weight: .medium, design: .rounded))
                        .foregroundColor(theme.textPrimary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 3.5)
                .background(Color.white.opacity(theme.isDark ? 0.06 : 0.04))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.5))
                
                Spacer(minLength: 0)
                
                // Dismiss Button
                Button(action: {
                    withAnimation(MorphUniversalAnimation.stateExpansion) {
                        model.activeAIResponse = nil
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundColor(theme.textSecondary)
                        .frame(width: 20, height: 20)
                        .background(Color.white.opacity(theme.isDark ? 0.10 : 0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Dismiss AI Response (Esc)")
            }
            .padding(.horizontal, 10)
            .padding(.top, 2)
            
            // Content Deck: Apple Liquid Glass Card
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 8) {
                    // Title
                    Text(response.title)
                        .font(.system(size: 13.5, weight: .bold, design: .rounded))
                        .foregroundColor(theme.textPrimary)
                    
                    // Summary Deck
                    Text(response.summary)
                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        .foregroundColor(theme.textSecondary)
                        .lineSpacing(2)
                    
                    // Detailed Content
                    Text(response.detailedContent)
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundColor(theme.textSecondary.opacity(0.95))
                        .lineSpacing(2.5)
                        .padding(.vertical, 2)
                    
                    // Key Points List
                    if !response.keyPoints.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("KEY INSIGHTS")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundColor(theme.textTertiary)
                            
                            ForEach(response.keyPoints, id: \.self) { point in
                                HStack(alignment: .top, spacing: 6) {
                                    Text("—")
                                        .font(.system(size: 9.5, weight: .bold))
                                        .foregroundColor(theme.textTertiary)
                                    Text(point)
                                        .font(.system(size: 10.5, weight: .medium, design: .rounded))
                                        .foregroundColor(theme.textPrimary)
                                }
                            }
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(theme.isDark ? 0.04 : 0.03))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                        )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(theme.liquidGlassCard)
                    .background(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(theme.isDark ? 0.22 : 0.40), Color.white.opacity(theme.isDark ? 0.08 : 0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
            
            // Bottom Action Bar: Save to Notes, Start Focus Timer, Copy
            HStack(spacing: 8) {
                // Save to Notes
                Button(action: {
                    MorphHaptics.levelChange()
                    let noteEntry = "[\(response.title)]\n\(response.detailedContent)"
                    if model.scratchpad.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        model.scratchpad.text = noteEntry
                    } else {
                        model.scratchpad.text += "\n\n" + noteEntry
                    }
                    model.activeAIResponse = nil
                    model.openFeature(.notes)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "note.text.badge.plus")
                            .font(.system(size: 9, weight: .semibold))
                        Text("Save to Notes")
                            .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(theme.textPrimary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4.5)
                    .background(Color.white.opacity(theme.isDark ? 0.12 : 0.10))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 0.5))
                }
                .buttonStyle(.plain)
                .help("Save explanation directly into Scratchpad Notes")
                
                // Start Focus Sprint
                Button(action: {
                    MorphHaptics.levelChange()
                    model.startFocusTimerInPill(minutes: 25, title: response.title, autoStart: true)
                    model.activeAIResponse = nil
                    model.openFeature(.timer)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 8.5, weight: .semibold))
                        Text("Focus on Topic")
                            .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(theme.isDark ? .black : .white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4.5)
                    .background(theme.isDark ? Color.white : Color.black)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("Launch a 25-minute Pomodoro focus sprint for this topic")
                
                Spacer(minLength: 0)
                
                // Copy to Clipboard
                Button(action: {
                    MorphHaptics.levelChange()
                    let pb = NSPasteboard.general
                    pb.clearContents()
                    pb.setString("\(response.title)\n\n\(response.summary)\n\n\(response.detailedContent)", forType: .string)
                    isCopied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        isCopied = false
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 8.5, weight: .semibold))
                        Text(isCopied ? "Copied" : "Copy")
                            .font(.system(size: 9.5, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(theme.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4.5)
                    .background(Color.white.opacity(theme.isDark ? 0.08 : 0.06))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("Copy AI answer to macOS clipboard")
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Glass Island Equalizer
struct GlassIslandEqualizerView: View {
    let isPlaying: Bool
    var height: CGFloat = 16
    var barColor: Color = Color(hex: "#ff7ab8")
    
    @State private var animate = false
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<4, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(barColor)
                    .frame(width: 3, height: barHeight(for: index))
            }
        }
        .frame(height: height, alignment: .bottom)
        .onAppear {
            if isPlaying {
                withAnimation(Animation.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    animate = true
                }
            }
        }
        .onChange(of: isPlaying) { _, playing in
            if playing {
                withAnimation(Animation.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    animate = true
                }
            } else {
                withAnimation(.easeOut(duration: 0.2)) {
                    animate = false
                }
            }
        }
    }
    
    private func barHeight(for index: Int) -> CGFloat {
        guard isPlaying else { return max(3, height * 0.25) }
        let fractions: [CGFloat] = animate
            ? [0.85, 0.40, 1.0, 0.60]
            : [0.30, 0.90, 0.45, 0.80]
        return max(3, height * fractions[index % fractions.count])
    }
}


