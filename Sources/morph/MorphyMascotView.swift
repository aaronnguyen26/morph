import SwiftUI

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

/// Morphy Mascot: The Living Ambient Companion for Morph
/// Designed strictly following Apple Human Interface Guidelines:
/// - Organic liquid-glass obsidian droplet squircle body with specular titanium rim
/// - Expressive personality with dynamic blinking eyes, warm smile, and soft blush
/// - State-adaptive accessories: AirPods Max-inspired studio focus headphones in Focus mode,
///   vibing singing expression with musical notes in Music mode, and attentive companion in Calls
/// - 100% pure neutral monochrome (#000000, #FFFFFF, #8E8E93), zero bullet points
public struct MorphyMascotView: View {
    @ObservedObject var model: NotchModel
    
    // Ambient breathing & dynamics
    @State private var isBreathing: Bool = false
    @State private var isBlinking: Bool = false
    @State private var isHovered: Bool = false
    @State private var tapBounce: CGFloat = 0.0
    @State private var tapSquish: CGFloat = 1.0
    @State private var musicNoteOffset: CGFloat = 0.0
    
    // Periodic blinking timer
    @State private var blinkTimer: Timer? = nil
    
    public init(model: NotchModel) {
        self.model = model
    }
    
    private var isFocusing: Bool {
        model.pomodoro.isRunning
    }
    
    private var isPlayingMedia: Bool {
        model.media.isPlaying
    }
    
    private var isInCall: Bool {
        model.meetingController.isInCall
    }
    
    public var body: some View {
        ZStack {
            // MARK: - 1. Soft Ambient Ground Shadow
            Ellipse()
                .fill(Color.black.opacity(model.theme.isDark ? 0.65 : 0.20))
                .frame(width: 44, height: 10)
                .offset(y: 26)
                .scaleEffect(isBreathing ? 0.92 : 1.04)
            
            // MARK: - 2. Studio Focus Headphones (Headband behind body)
            if isFocusing {
                focusHeadbandArc
            }
            
            // MARK: - 3. Mascot Droplet Body
            ZStack {
                // Base Obsidian Droplet Squircle
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: model.theme.isDark
                                ? [Color(white: 0.22), Color(white: 0.11), Color(white: 0.04)]
                                : [Color(white: 0.98), Color(white: 0.88), Color(white: 0.80)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 46, height: 44)
                    .overlay(
                        // Hairline Specular Titanium Rim
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: model.theme.isDark
                                        ? [Color.white.opacity(isFocusing ? 0.70 : 0.45), Color.white.opacity(0.10)]
                                        : [Color.black.opacity(isFocusing ? 0.35 : 0.22), Color.black.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: isFocusing ? 1.25 : 1.0
                            )
                    )
                    .shadow(
                        color: model.theme.isDark ? Color.black.opacity(0.8) : Color.black.opacity(0.18),
                        radius: 8,
                        x: 0,
                        y: 4
                    )
                
                // Top Liquid Glass Forehead Highlight
                Ellipse()
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(model.theme.isDark ? 0.38 : 0.65), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 32, height: 13)
                    .offset(y: -12)
                
                // MARK: - 4. Expressive Face
                mascotFaceView
            }
            .scaleEffect(x: tapSquish, y: (isBreathing ? 1.03 : 0.98) * (2.0 - tapSquish))
            .offset(y: (isBreathing ? -2.5 : 2.0) + tapBounce)
            .rotationEffect(.degrees(isHovered ? 3.5 : 0))
            
            // MARK: - 5. Studio Focus Headphone Ear-Cups (In front of body sides)
            if isFocusing {
                focusEarCupsView
                    .offset(y: (isBreathing ? -2.5 : 2.0) + tapBounce)
            }
            
            // MARK: - 6. Music Vibing Floating Note
            if isPlayingMedia {
                Text("♫")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(model.theme.textPrimary.opacity(0.85))
                    .offset(x: 24, y: -24 + musicNoteOffset)
                    .opacity(isBreathing ? 0.95 : 0.35)
            }
        }
        .frame(width: 68, height: 60)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.spring(response: 0.28, dampingFraction: 0.65)) {
                isHovered = hovering
            }
        }
        .onTapGesture {
            triggerTapBounce()
        }
        .help("Morphy — Your Living Companion")
        .onAppear {
            startBreathingAnimation()
            startBlinkTimer()
        }
        .onDisappear {
            blinkTimer?.invalidate()
            blinkTimer = nil
        }
    }
    
    // MARK: - Mascot Face
    @ViewBuilder
    private var mascotFaceView: some View {
        VStack(spacing: 3.5) {
            // Eyes Row
            HStack(spacing: 12) {
                mascotEye(isLeft: true)
                mascotEye(isLeft: false)
            }
            .offset(y: -1)
            
            // Mouth & Cheeks Row
            ZStack {
                // Soft Blush Cheeks
                HStack(spacing: 24) {
                    Circle()
                        .fill(Color.white.opacity(model.theme.isDark ? 0.12 : 0.08))
                        .frame(width: 6, height: 6)
                    Circle()
                        .fill(Color.white.opacity(model.theme.isDark ? 0.12 : 0.08))
                        .frame(width: 6, height: 6)
                }
                
                // Adaptive Mouth
                mascotMouth
            }
        }
        .offset(y: 1.5)
    }
    
    // MARK: - Adaptive Eyes
    @ViewBuilder
    private func mascotEye(isLeft: Bool) -> some View {
        if isBlinking {
            // Blinking closed eye line
            Rectangle()
                .fill(model.theme.textPrimary)
                .frame(width: 6, height: 1.5)
                .clipShape(Capsule())
        } else if isFocusing {
            // Confident focused squint
            HStack(spacing: 0) {
                Capsule()
                    .fill(model.theme.textPrimary)
                    .frame(width: 6, height: 2.2)
                    .rotationEffect(.degrees(isLeft ? 8 : -8))
            }
        } else if isPlayingMedia {
            // Joyful vibing arc eyes (^ ^)
            Image(systemName: "chevron.up")
                .font(.system(size: 6.5, weight: .black))
                .foregroundColor(model.theme.textPrimary)
        } else {
            // Wide curious open eyes with specular highlight twinkle
            ZStack(alignment: .topTrailing) {
                Capsule()
                    .fill(model.theme.textPrimary)
                    .frame(width: 5.5, height: 9.5)
                
                // Specular eye glint
                Circle()
                    .fill(Color.white)
                    .frame(width: 2.2, height: 2.2)
                    .offset(x: -0.6, y: 1.2)
            }
        }
    }
    
    // MARK: - Adaptive Mouth
    @ViewBuilder
    private var mascotMouth: some View {
        if isPlayingMedia {
            // Singing mouth (small open oval)
            Circle()
                .fill(model.theme.textPrimary)
                .frame(width: 4.5, height: 5.5)
        } else if isFocusing {
            // Confident small focus smile
            Capsule()
                .fill(model.theme.textPrimary)
                .frame(width: 5, height: 1.8)
        } else {
            // Warm curved gentle smile arc
            Image(systemName: "chevron.down")
                .font(.system(size: 6, weight: .bold))
                .foregroundColor(model.theme.textPrimary.opacity(0.90))
                .scaleEffect(x: 1.3, y: 0.7)
        }
    }
    
    // MARK: - Focus Headphones (Headband)
    private var focusHeadbandArc: some View {
        Circle()
            .trim(from: 0.52, to: 0.98)
            .stroke(
                LinearGradient(
                    colors: [Color.white.opacity(0.85), Color.white.opacity(0.35)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
            )
            .frame(width: 54, height: 54)
            .offset(y: -9)
    }
    
    // MARK: - Focus Headphones (Ear-Cups)
    private var focusEarCupsView: some View {
        HStack {
            // Left Ear-Cup
            earCupView
            Spacer()
            // Right Ear-Cup
            earCupView
        }
        .frame(width: 58)
    }
    
    private var earCupView: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color(white: 0.30), Color(white: 0.12)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 6, height: 16)
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(Color.white.opacity(0.50), lineWidth: 0.75)
            )
            .shadow(color: Color.black.opacity(0.5), radius: 2)
    }
    
    // MARK: - Animations & Timers
    private func startBreathingAnimation() {
        withAnimation(
            .easeInOut(duration: 2.8)
            .repeatForever(autoreverses: true)
        ) {
            isBreathing = true
            musicNoteOffset = -6
        }
    }
    
    private func startBlinkTimer() {
        blinkTimer?.invalidate()
        blinkTimer = Timer.scheduledTimer(withTimeInterval: 4.2, repeats: true) { _ in
            Task { @MainActor in
                withAnimation(.easeInOut(duration: 0.10)) {
                    isBlinking = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.easeInOut(duration: 0.10)) {
                        isBlinking = false
                    }
                }
            }
        }
    }
    
    private func triggerTapBounce() {
        MorphHaptics.generic()
        withAnimation(.spring(response: 0.22, dampingFraction: 0.45)) {
            tapBounce = -9
            tapSquish = 0.88
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.65)) {
                tapBounce = 0
                tapSquish = 1.0
            }
        }
    }
}
