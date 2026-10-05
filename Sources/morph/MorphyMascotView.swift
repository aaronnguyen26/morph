import SwiftUI

public struct MorphyMouthShape: Shape {
    var isSinging: Bool
    var isFocused: Bool
    
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        if isSinging {
            // Cute singing circle mouth
            path.addEllipse(in: CGRect(x: rect.midX - 2.5, y: rect.midY - 2.5, width: 5, height: 5))
        } else if isFocused {
            // Confident focused small smile line
            path.move(to: CGPoint(x: rect.midX - 2.5, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.midX + 2.5, y: rect.midY))
        } else {
            // Cheerful curved smile
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.minY),
                control: CGPoint(x: rect.midX, y: rect.maxY)
            )
        }
        return path
    }
}

public struct MorphyMascotView: View {
    @ObservedObject var model: NotchModel
    
    @State private var isBlinking: Bool = false
    @State private var isFloating: Bool = false
    @State private var orbitRotation: Double = 0
    @State private var isWinking: Bool = false
    @State private var isExcited: Bool = false
    @State private var tapBounce: CGFloat = 0
    @State private var customReactionText: String? = nil
    
    // Timer for natural blinking
    private let blinkTimer = Timer.publish(every: 3.8, on: .main, in: .common).autoconnect()
    
    public init(model: NotchModel) {
        self.model = model
    }
    
    private var accentColor: Color {
        if model.pomodoro.isRunning && model.media.isPlaying {
            return Color(red: 0.35, green: 0.85, blue: 1.0)
        } else if model.pomodoro.isRunning {
            return Color(red: 0.65, green: 0.45, blue: 1.0)
        } else if model.media.isPlaying {
            return Color(red: 0.25, green: 0.88, blue: 0.98)
        } else {
            return Color(red: 0.9, green: 0.95, blue: 1.0)
        }
    }
    
    private var statusMessage: (title: String, subtitle: String) {
        if let reaction = customReactionText {
            return ("Morphy hyped!", reaction)
        }
        
        if model.pomodoro.isRunning && model.media.isPlaying {
            return ("Morphy locked in", "Focus & Music in perfect sync")
        } else if model.pomodoro.isRunning {
            return ("Morphy focused", "\(model.pomodoro.mode.rawValue) active • \(model.pomodoro.formattedTime)")
        } else if model.media.isPlaying {
            let track = model.media.trackTitle.isEmpty ? "Audio playing" : model.media.trackTitle
            return ("Morphy vibing", track)
        } else {
            return ("Morphy is ready", "Deep Focus & Ambient Space")
        }
    }
    
    public var body: some View {
        VStack(spacing: 8) {
            // MARK: - Morphy Floating Cyber Mascot Centerpiece
            ZStack {
                // Ambient Reactive Aura Glow
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                accentColor.opacity(isExcited ? 0.32 : 0.16),
                                accentColor.opacity(0.04),
                                Color.clear
                            ]),
                            center: .center,
                            startRadius: 8,
                            endRadius: 42
                        )
                    )
                    .frame(width: 84, height: 84)
                
                // Outer Orbit Tech Ring (Subtle dashed cyber orbit)
                Circle()
                    .stroke(
                        accentColor.opacity(0.18),
                        style: StrokeStyle(lineWidth: 1, dash: [4, 6])
                    )
                    .frame(width: 66, height: 66)
                    .rotationEffect(.degrees(orbitRotation))
                
                // Orbiting Cyber Spark Pips
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.75))
                        .frame(width: 3, height: 3)
                        .offset(x: 33, y: 0)
                    
                    Circle()
                        .fill(Color.white.opacity(0.6))
                        .frame(width: 2.2, height: 2.2)
                        .offset(x: -28, y: -16)
                    
                    Circle()
                        .fill(Color(red: 1.0, green: 0.5, blue: 0.8).opacity(0.65))
                        .frame(width: 2.5, height: 2.5)
                        .offset(x: -12, y: 30)
                }
                .rotationEffect(.degrees(orbitRotation * 0.75))
                
                // Robotic Cyber Antenna Ears (Tipped with glowing LEDs!)
                HStack(spacing: 24) {
                    // Left Antenna Ear
                    VStack(spacing: 0) {
                        Circle()
                            .fill(accentColor)
                            .frame(width: 4.5, height: 4.5)
                            .shadow(color: accentColor.opacity(0.9), radius: 3)
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.4), Color.white.opacity(0.15)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 2.5, height: 9)
                    }
                    .rotationEffect(.degrees(-26))
                    
                    // Right Antenna Ear
                    VStack(spacing: 0) {
                        Circle()
                            .fill(accentColor)
                            .frame(width: 4.5, height: 4.5)
                            .shadow(color: accentColor.opacity(0.9), radius: 3)
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.4), Color.white.opacity(0.15)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 2.5, height: 9)
                    }
                    .rotationEffect(.degrees(26))
                }
                .offset(y: -22)
                
                // Glass Pod Body (Glossy OLED Dark Sphere with Specular Sheen)
                ZStack {
                    // Dark Glass Orb Gradient
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(white: 0.18),
                                    Color(white: 0.08),
                                    Color.black
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 46, height: 46)
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.4),
                                            accentColor.opacity(0.2),
                                            Color.white.opacity(0.08)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: Color.black.opacity(0.8), radius: 8, x: 0, y: 4)
                    
                    // Top Glass Specular Reflection Highlight
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.26), Color.clear],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                        .frame(width: 38, height: 20)
                        .offset(y: -10)
                        .mask(Circle().frame(width: 44, height: 44))
                    
                    // Curved OLED Cyber Visor Screen
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(white: 0.03))
                        .frame(width: 34, height: 22)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                        )
                    
                    // Glowing Blush Cheeks
                    HStack(spacing: 18) {
                        Capsule()
                            .fill(Color(red: 1.0, green: 0.45, blue: 0.65).opacity(isExcited ? 0.9 : 0.45))
                            .frame(width: 4.5, height: 2.2)
                            .shadow(color: Color(red: 1.0, green: 0.45, blue: 0.65).opacity(isExcited ? 0.8 : 0.3), radius: 2)
                        
                        Capsule()
                            .fill(Color(red: 1.0, green: 0.45, blue: 0.65).opacity(isExcited ? 0.9 : 0.45))
                            .frame(width: 4.5, height: 2.2)
                            .shadow(color: Color(red: 1.0, green: 0.45, blue: 0.65).opacity(isExcited ? 0.8 : 0.3), radius: 2)
                    }
                    .offset(y: 4.5)
                    
                    // Expressive Digital Cyber Eyes
                    HStack(spacing: 7) {
                        // Left Eye
                        if isWinking {
                            Capsule()
                                .fill(Color.white)
                                .frame(width: 3.5, height: 1.5)
                        } else {
                            Capsule()
                                .fill(Color(red: 0.88, green: 0.98, blue: 1.0))
                                .frame(width: 3.5, height: isBlinking ? 1.2 : 8)
                                .shadow(color: accentColor.opacity(0.9), radius: 2.5)
                        }
                        
                        // Right Eye
                        Capsule()
                            .fill(Color(red: 0.88, green: 0.98, blue: 1.0))
                            .frame(width: 3.5, height: isBlinking ? 1.2 : 8)
                            .shadow(color: accentColor.opacity(0.9), radius: 2.5)
                    }
                    .offset(y: -1.5)
                    .animation(.easeInOut(duration: 0.12), value: isBlinking)
                    .animation(.easeInOut(duration: 0.15), value: isWinking)
                    
                    // Expressive Cyber Mouth
                    MorphyMouthShape(
                        isSinging: model.media.isPlaying,
                        isFocused: model.pomodoro.isRunning && !model.media.isPlaying
                    )
                    .stroke(
                        Color.white,
                        style: StrokeStyle(lineWidth: 1.3, lineCap: .round)
                    )
                    .frame(width: 7, height: 3.5)
                    .offset(y: 6.5)
                }
            }
            .offset(y: (isFloating ? -3 : 3) + tapBounce)
            .contentShape(Circle())
            .onTapGesture {
                handleTapInteraction()
            }
            .help("Click Morphy for a cheerful high-five!")
            
            // MARK: - Morphy Telemetry Status Dialogue Pill
            HStack(spacing: 6) {
                // Live Status Pulsing Dot
                Circle()
                    .fill(accentColor)
                    .frame(width: 5, height: 5)
                    .shadow(color: accentColor.opacity(0.85), radius: 3)
                
                Text(statusMessage.title)
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("•")
                    .font(.system(size: 8))
                    .foregroundColor(Color.white.opacity(0.35))
                
                Text(statusMessage.subtitle)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.75))
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 3.5)
            .background(
                Capsule()
                    .fill(Color(white: 0.08))
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
            )
            .contentShape(Capsule())
            .onTapGesture {
                handleTapInteraction()
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                isFloating = true
            }
            withAnimation(.linear(duration: 22).repeatForever(autoreverses: false)) {
                orbitRotation = 360
            }
        }
        .onReceive(blinkTimer) { _ in
            guard !isWinking else { return }
            withAnimation {
                isBlinking = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                withAnimation {
                    isBlinking = false
                }
            }
        }
    }
    
    private func handleTapInteraction() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.65)) {
            isWinking = true
            isExcited = true
            tapBounce = -7
            customReactionText = "Wheee! Morphy is hyped! ✨"
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                tapBounce = 0
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation {
                isWinking = false
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation {
                isExcited = false
                customReactionText = nil
            }
        }
    }
}
