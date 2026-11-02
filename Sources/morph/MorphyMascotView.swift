import SwiftUI
import AppKit

// MARK: - Legacy MorphyMouthShape (Preserved for API & Test Compatibility)
public struct MorphyMouthShape: Shape {
    public var isSinging: Bool
    public var isFocused: Bool
    
    public init(isSinging: Bool = false, isFocused: Bool = false) {
        self.isSinging = isSinging
        self.isFocused = isFocused
    }
    
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        if isSinging {
            path.addEllipse(in: CGRect(x: rect.midX - 2.5, y: rect.midY - 2.5, width: 5, height: 5))
        } else if isFocused {
            path.move(to: CGPoint(x: rect.midX - 2.5, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.midX + 2.5, y: rect.midY))
        } else {
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.minY),
                control: CGPoint(x: rect.midX, y: rect.maxY)
            )
        }
        return path
    }
}

// MARK: - Mascot Styles
public enum MorphyMascotStyle: Equatable, Sendable {
    case hero           // Expanded Home companion (height ~56-64pt), full 3D cursor-tracking parallax
    case restingStealth // Resting Dynamic Island stealth notch (height ~24pt), subtle ambient float
    case spotlightPill  // Lengthened spotlight typing pill (height ~20pt), lively active animated companion
    case compact        // Compact secondary HUD panels (height ~34pt)
}

// MARK: - Official Mascot Asset Loader
@MainActor
public enum MorphMascotAssetLoader {
    private static var cache: [String: NSImage] = [:]
    
    public static func image(named name: String) -> NSImage? {
        if let cached = cache[name] {
            return cached
        }
        
        let extensions = ["png", "jpg", "jpeg"]
        
        // 1. Bundle.main root & Mascot subdirectory
        for ext in extensions {
            if let url = Bundle.main.url(forResource: name, withExtension: ext),
               let img = NSImage(contentsOf: url) {
                cache[name] = img
                return img
            }
            if let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Mascot"),
               let img = NSImage(contentsOf: url) {
                cache[name] = img
                return img
            }
        }
        
        // 2. Bundle.main.resourceURL
        if let resURL = Bundle.main.resourceURL {
            for ext in extensions {
                let fileURL = resURL.appendingPathComponent("Mascot/\(name).\(ext)")
                if FileManager.default.fileExists(atPath: fileURL.path),
                   let img = NSImage(contentsOf: fileURL) {
                    cache[name] = img
                    return img
                }
                let rootURL = resURL.appendingPathComponent("\(name).\(ext)")
                if FileManager.default.fileExists(atPath: rootURL.path),
                   let img = NSImage(contentsOf: rootURL) {
                    cache[name] = img
                    return img
                }
            }
        }
        
        // 3. Local filesystem relative paths (for SPM swift run / swift test / dev builds)
        let localCandidates = [
            "Resources/Mascot/\(name).png",
            "Resources/\(name).png",
            "../Resources/Mascot/\(name).png",
            "../../Resources/Mascot/\(name).png",
            "/Applications/Morph.app/Contents/Resources/Mascot/\(name).png"
        ]
        for path in localCandidates {
            if FileManager.default.fileExists(atPath: path),
               let img = NSImage(contentsOfFile: path) {
                cache[name] = img
                return img
            }
        }
        
        return nil
    }
    
    public static var officialMascotFull: NSImage? {
        image(named: "official_morph_mascot_full")
    }
    
    public static var officialMascotBody: NSImage? {
        image(named: "official_morph_mascot_body")
    }
    
    public static var officialMascotHalo: NSImage? {
        image(named: "official_morph_mascot_halo")
    }
}

/// Morphy: The Official 3D Living Ambient Companion for Morph
/// Rendered using multi-layer 3D volumetric composition:
/// - Floating chrome torus halo ring with independent anti-gravity bobbing, pitch, and specular shimmer
/// - Glossy obsidian teardrop body with porcelain face, dark reflective puppy eyes, and metallic silver cuffs
/// - Interactive 3D cursor-tracking parallax (look-at effect on X, Y, and Z axes)
/// - Ambient breathing volume dynamics & height-reactive ground ambient occlusion shadow
/// - Periodic soulful eye blinks and interactive 3D squash & stretch bounce with haptic feedback
/// - 100% pure neutral monochrome (#000000, #FFFFFF, #8E8E93, specular highlights), 0 bullet dots
public struct MorphyMascotView: View {
    @ObservedObject var model: NotchModel
    public var style: MorphyMascotStyle
    
    // Ambient breathing & dynamics
    @State private var isBreathing: Bool = false
    @State private var haloBobbing: Bool = false
    @State private var isBlinking: Bool = false
    @State private var isHovered: Bool = false
    @State private var shimmerOffset: CGFloat = -1.0
    
    // Interactive 3D cursor-tracking parallax
    @State private var cursorOffset: CGPoint = .zero
    
    // Interactive 3D tap physics
    @State private var tapBounce: CGFloat = 0.0
    @State private var tapSquish: CGFloat = 1.0
    @State private var musicNoteOffset: CGFloat = 0.0
    @State private var typingHop: CGFloat = 0.0
    
    // Periodic blinking timer
    @State private var blinkTimer: Timer? = nil
    
    public init(model: NotchModel, style: MorphyMascotStyle = .hero) {
        self.model = model
        self.style = style
    }
    
    private var isFocusing: Bool {
        model.pomodoro.isRunning
    }
    
    private var isPlayingMedia: Bool {
        model.media.isPlaying
    }
    
    private var baseHeight: CGFloat {
        switch style {
        case .hero:
            return 56.0
        case .restingStealth:
            return 24.0
        case .spotlightPill:
            return 20.0
        case .compact:
            return 32.0
        }
    }
    
    private var baseWidth: CGFloat {
        baseHeight * (623.0 / 757.0) // Aspect ratio of official mascot: ~0.823
    }
    
    // 3D Parallax angles
    private var effectiveBodyYaw: Double {
        if style == .hero {
            return Double(cursorOffset.x) * 14.0
        } else if style == .spotlightPill {
            // Eager curious glance toward the typing input field (to the right)
            return 5.0 + (isHovered ? Double(cursorOffset.x) * 8.0 : 0) + (isBreathing ? 1.5 : -1.5)
        } else if style == .restingStealth && isHovered {
            return Double(cursorOffset.x) * 6.0
        }
        return isBreathing ? 1.5 : -1.5
    }
    
    private var effectiveBodyPitch: Double {
        if style == .hero {
            return Double(-cursorOffset.y) * 10.0 + (isBreathing ? 2.0 : -2.0)
        } else if style == .spotlightPill {
            return (isBreathing ? 3.0 : -2.0) + (isHovered ? Double(-cursorOffset.y) * 6.0 : 0)
        } else if style == .restingStealth {
            return isHovered ? -4.5 : (isBreathing ? 1.0 : -1.0)
        }
        return isBreathing ? 2.0 : -2.0
    }
    
    private var effectiveBodyRoll: Double {
        if style == .hero {
            return Double(cursorOffset.x) * 3.5 + (isBreathing ? -1.0 : 1.0)
        } else if style == .spotlightPill {
            return (isBreathing ? -1.5 : 1.5) + (haloBobbing ? 1.0 : -1.0)
        }
        return isBreathing ? -0.8 : 0.8
    }
    
    private var effectiveHaloYaw: Double {
        if style == .spotlightPill {
            return effectiveBodyYaw * 1.4 + (haloBobbing ? 2.5 : -2.5)
        }
        return effectiveBodyYaw * 1.35
    }
    
    private var effectiveHaloPitch: Double {
        if style == .spotlightPill {
            return effectiveBodyPitch * 1.5 + (haloBobbing ? 5.0 : -5.0)
        }
        return effectiveBodyPitch * 1.45 + (haloBobbing ? 2.5 : -2.5)
    }
    
    private var haloParallaxX: CGFloat {
        if style == .spotlightPill {
            return (isHovered ? cursorOffset.x * 2.0 : 0)
        }
        return (style == .hero ? cursorOffset.x * 4.0 : (isHovered ? cursorOffset.x * 1.5 : 0))
    }
    
    private var haloParallaxY: CGFloat {
        if style == .spotlightPill {
            return (isHovered ? -1.2 : 0)
        }
        return (style == .hero ? -cursorOffset.y * 3.0 : (isHovered ? -1.5 : 0))
    }
    
    private var bodyFloatOffset: CGFloat {
        switch style {
        case .hero:
            return isBreathing ? -2.8 : 2.2
        case .spotlightPill:
            return (isBreathing ? -1.8 : 1.6) + typingHop
        case .restingStealth:
            return isBreathing ? -1.0 : 1.0
        case .compact:
            return isBreathing ? -1.6 : 1.4
        }
    }
    
    private var haloFloatOffset: CGFloat {
        switch style {
        case .hero:
            return (haloBobbing ? -3.6 : 1.8) + (isFocusing ? -1.5 : 0)
        case .spotlightPill:
            return (haloBobbing ? -2.6 : 2.0) + (typingHop * 0.8)
        case .restingStealth:
            return (haloBobbing ? -1.5 : 1.2) + (isHovered ? -1.2 : 0)
        case .compact:
            return haloBobbing ? -2.2 : 1.4
        }
    }
    
    public var body: some View {
        let H = baseHeight
        let W = baseWidth
        
        // Exact proportional dimensions derived from high-resolution neural segmentation
        let bodyH = H * (669.0 / 757.0)
        let bodyW = W * (622.0 / 623.0)
        let bodyY = H * ((88.0 + 757.0) / 2.0 - 757.0 / 2.0) / 757.0 // +5.8%
        
        let haloH = H * (69.0 / 757.0)
        let haloW = W * (235.0 / 623.0)
        let haloY = H * (69.0 / 2.0 - 757.0 / 2.0) / 757.0 // -45.4%
        let haloX = -W * (13.5 / 623.0) // -2.1% natural 3D perspective shift
        
        ZStack {
            // MARK: - 1. Soft Ambient Ground Shadow (Height & Breathing Reactive)
            Ellipse()
                .fill(Color.black.opacity(model.theme.isDark ? 0.65 : 0.28))
                .frame(width: bodyW * (isBreathing ? 0.72 : 0.88),
                       height: max(bodyH * 0.16 * (isBreathing ? 0.80 : 1.05), 3.0))
                .offset(y: (H / 2.0) + (style == .restingStealth ? 1.0 : 3.0))
                .opacity(isBreathing ? 0.32 : 0.58)
                .blur(radius: style == .hero ? 3.0 : 1.2)
            
            // MARK: - 2. Multi-layer 3D Mascot Composition
            if let bodyImg = MorphMascotAssetLoader.officialMascotBody,
               let haloImg = MorphMascotAssetLoader.officialMascotHalo {
                
                // --- Layer A: 3D Body ---
                ZStack {
                    Image(nsImage: bodyImg)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: bodyW, height: bodyH)
                    
                    // Liquid-glass specular light shimmer sheen across obsidian hood
                    if style == .hero {
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color.white.opacity(isFocusing ? 0.22 : 0.10),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .frame(width: bodyW * 0.9, height: bodyH * 0.6)
                        .offset(x: shimmerOffset * bodyW * 0.6, y: -bodyH * 0.15)
                        .mask(
                            Image(nsImage: bodyImg)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        )
                        .allowsHitTesting(false)
                    }
                    
                    // Soulful periodic eye blink overlay
                    if isBlinking {
                        eyeBlinkLidOverlay(bodyW: bodyW, bodyH: bodyH)
                    }
                }
                .scaleEffect(x: tapSquish * (isBreathing ? 1.018 : 0.982),
                             y: (2.0 - tapSquish) * (isBreathing ? 0.982 : 1.018))
                .offset(y: bodyY + bodyFloatOffset + tapBounce)
                .rotation3DEffect(.degrees(effectiveBodyPitch), axis: (x: 1, y: 0, z: 0), anchor: .center, perspective: 0.8)
                .rotation3DEffect(.degrees(effectiveBodyYaw), axis: (x: 0, y: 1, z: 0), anchor: .center, perspective: 0.8)
                .rotation3DEffect(.degrees(effectiveBodyRoll), axis: (x: 0, y: 0, z: 1), anchor: .center)
                
                // --- Layer B: Detached 3D Floating Chrome Halo ---
                ZStack {
                    Image(nsImage: haloImg)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: haloW, height: haloH)
                    
                    // Subtle focus glow around halo in focus mode
                    if isFocusing {
                        Image(nsImage: haloImg)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: haloW + 3, height: haloH + 2)
                            .blur(radius: 2)
                            .opacity(haloBobbing ? 0.65 : 0.35)
                    }
                }
                .offset(
                    x: haloX + haloParallaxX,
                    y: haloY + haloFloatOffset + (tapBounce * 1.35) + haloParallaxY
                )
                .rotation3DEffect(.degrees(effectiveHaloPitch), axis: (x: 1, y: 0, z: 0), anchor: .center, perspective: 0.8)
                .rotation3DEffect(.degrees(effectiveHaloYaw), axis: (x: 0, y: 1, z: 0), anchor: .center, perspective: 0.8)
                .rotation3DEffect(.degrees(effectiveBodyRoll * 1.2), axis: (x: 0, y: 0, z: 1), anchor: .center)
                .shadow(
                    color: Color.white.opacity(isFocusing ? 0.50 : (model.theme.isDark ? 0.20 : 0.10)),
                    radius: isFocusing ? 4 : 1.5,
                    x: 0,
                    y: 1
                )
                
            } else if let fullImg = MorphMascotAssetLoader.officialMascotFull {
                // High-fidelity full composite fallback with 3D rotation & floating
                Image(nsImage: fullImg)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: W, height: H)
                    .scaleEffect(x: tapSquish * (isBreathing ? 1.015 : 0.985),
                                 y: (2.0 - tapSquish) * (isBreathing ? 0.985 : 1.015))
                    .offset(y: bodyFloatOffset + tapBounce)
                    .rotation3DEffect(.degrees(effectiveBodyPitch), axis: (x: 1, y: 0, z: 0), anchor: .center, perspective: 0.8)
                    .rotation3DEffect(.degrees(effectiveBodyYaw), axis: (x: 0, y: 1, z: 0), anchor: .center, perspective: 0.8)
                    .rotation3DEffect(.degrees(effectiveBodyRoll), axis: (x: 0, y: 0, z: 1), anchor: .center)
                
            } else {
                // Procedural vector squircle fallback (ensures isolated tests never crash without bundle)
                proceduralMascotFallback(W: W, H: H)
            }
            
            // MARK: - 3. Music Vibing Note (In Music mode)
            if isPlayingMedia && style == .hero {
                Text("♫")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(model.theme.textPrimary.opacity(0.85))
                    .offset(x: (W / 2.0) + 4, y: -(H / 2.0) + musicNoteOffset)
                    .opacity(isBreathing ? 0.95 : 0.35)
            }
        }
        .frame(width: max(W + (style == .spotlightPill ? 4 : 12), style == .spotlightPill ? 20 : 28),
               height: max(H + (style == .spotlightPill ? 4 : 8), style == .spotlightPill ? 20 : 28))
        .contentShape(Rectangle())
        .onContinuousHover { phase in
            switch phase {
            case .active(let location):
                let w = max(W + (style == .spotlightPill ? 4 : 12), style == .spotlightPill ? 20 : 28)
                let h = max(H + (style == .spotlightPill ? 4 : 8), style == .spotlightPill ? 20 : 28)
                let normX = max(min((location.x - (w / 2.0)) / (w / 2.0), 1.0), -1.0)
                let normY = max(min((location.y - (h / 2.0)) / (h / 2.0), 1.0), -1.0)
                withAnimation(.easeOut(duration: 0.16)) {
                    cursorOffset = CGPoint(x: normX, y: normY)
                    isHovered = true
                }
            case .ended:
                withAnimation(.spring(response: 0.40, dampingFraction: 0.72)) {
                    cursorOffset = .zero
                    isHovered = false
                }
            }
        }
        .onTapGesture {
            triggerTapBounce()
            if style == .restingStealth {
                handleRestingStealthTap()
            }
        }
        .onChange(of: model.spotlightQuery) { _, _ in
            if style == .spotlightPill {
                withAnimation(.spring(response: 0.12, dampingFraction: 0.35)) {
                    typingHop = -3.5
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.55)) {
                        typingHop = 0.0
                    }
                }
            }
        }
        .help(style == .restingStealth ? "Morph — Click to Spotlight" : (style == .spotlightPill ? "Morphy — Active Companion" : "Morphy — Your Living Companion"))
        .onAppear {
            startBreathingAnimation()
            startBlinkTimer()
        }
        .onDisappear {
            blinkTimer?.invalidate()
            blinkTimer = nil
        }
    }
    
    // MARK: - Eye Blink Overlay
    @ViewBuilder
    private func eyeBlinkLidOverlay(bodyW: CGFloat, bodyH: CGFloat) -> some View {
        // Natural curved dark eyelids that close over the eyes
        HStack(spacing: bodyW * 0.22) {
            Capsule()
                .fill(Color(white: 0.15))
                .frame(width: max(bodyW * 0.13, 3), height: max(bodyH * 0.05, 1.5))
            Capsule()
                .fill(Color(white: 0.15))
                .frame(width: max(bodyW * 0.13, 3), height: max(bodyH * 0.05, 1.5))
        }
        .offset(x: -bodyW * 0.02, y: -bodyH * 0.08)
    }
    
    // MARK: - Procedural Fallback (For test environments without asset files)
    @ViewBuilder
    private func proceduralMascotFallback(W: CGFloat, H: CGFloat) -> some View {
        ZStack {
            // Obsidian droplet squircle
            RoundedRectangle(cornerRadius: H * 0.40, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: model.theme.isDark
                            ? [Color(white: 0.22), Color(white: 0.11), Color(white: 0.04)]
                            : [Color(white: 0.98), Color(white: 0.88), Color(white: 0.80)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: W, height: H * 0.88)
            
            // White porcelain face
            Ellipse()
                .fill(Color.white)
                .frame(width: W * 0.68, height: H * 0.55)
                .offset(y: H * 0.04)
            
            // Eyes
            HStack(spacing: W * 0.20) {
                Circle().fill(Color.black).frame(width: W * 0.12, height: W * 0.12)
                Circle().fill(Color.black).frame(width: W * 0.12, height: W * 0.12)
            }
            .offset(y: -H * 0.02)
            
            // Halo ring
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [Color.white, Color(white: 0.70)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: max(H * 0.04, 1.2)
                )
                .frame(width: W * 0.45, height: H * 0.14)
                .offset(y: -H * 0.46)
        }
    }
    
    // MARK: - Animations & Timers
    private func startBreathingAnimation() {
        let breatheDuration = (style == .spotlightPill) ? 1.35 : 2.8
        let haloDuration = (style == .spotlightPill) ? 1.05 : 2.2
        withAnimation(
            .easeInOut(duration: breatheDuration)
            .repeatForever(autoreverses: true)
        ) {
            isBreathing = true
            musicNoteOffset = -6
            shimmerOffset = 1.0
        }
        
        withAnimation(
            .easeInOut(duration: haloDuration)
            .repeatForever(autoreverses: true)
        ) {
            haloBobbing = true
        }
    }
    
    private func startBlinkTimer() {
        blinkTimer?.invalidate()
        let interval = (style == .spotlightPill) ? 2.8 : 4.2
        blinkTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            Task { @MainActor in
                withAnimation(.easeInOut(duration: 0.10)) {
                    isBlinking = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                    withAnimation(.easeInOut(duration: 0.10)) {
                        isBlinking = false
                    }
                }
            }
        }
    }
    
    private func triggerTapBounce() {
        MorphHaptics.generic()
        withAnimation(.spring(response: 0.20, dampingFraction: 0.42)) {
            tapBounce = -(baseHeight * 0.16)
            tapSquish = 0.88
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.62)) {
                tapBounce = 0
                tapSquish = 1.0
            }
        }
    }
    
    private func handleRestingStealthTap() {
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
