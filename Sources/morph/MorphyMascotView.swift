import SwiftUI

public struct MorphyMouthShape: Shape {
    var isSinging: Bool
    var isFocused: Bool
    
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

/// Living Orbital Dots Mascot ("Morphy Core")
/// Inspired by OpenAI Voice Mode dynamic orbital constellation and Meta AI Muse living fluid core.
/// Strictly monochromatic: Deep Obsidian, Frosted Glass, Silver, and Crisp White.
public struct MorphyMascotView: View {
    @ObservedObject var model: NotchModel
    
    @State private var outerRotation: Double = 0
    @State private var innerRotation: Double = 0
    @State private var coreScale: CGFloat = 1.0
    @State private var isPulsing: Bool = false
    @State private var isHovered: Bool = false
    @State private var tapImpulse: CGFloat = 0
    
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
            // Ambient Radiant Glow Falloff (Meta Muse Aura)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            model.theme.isDark
                                ? Color.white.opacity(isHovered ? 0.20 : (isFocusing || isPlayingMedia || isInCall ? 0.14 : 0.08))
                                : Color.black.opacity(isHovered ? 0.12 : (isFocusing || isPlayingMedia || isInCall ? 0.08 : 0.04)),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 8,
                        endRadius: 42
                    )
                )
                .frame(width: 84, height: 84)
            
            // Outer Concentric Track (Dashed Specular Track)
            Circle()
                .stroke(
                    model.theme.isDark
                        ? Color.white.opacity(isFocusing ? 0.22 : 0.12)
                        : Color.black.opacity(isFocusing ? 0.16 : 0.08),
                    style: StrokeStyle(lineWidth: 1, dash: isFocusing ? [5, 3] : [3, 5])
                )
                .frame(width: 58, height: 58)
                .rotationEffect(.degrees(outerRotation))
            
            // Secondary Inset Track (Solid Hairline / Deep-Focus Orbital Ring Highlight)
            Circle()
                .stroke(
                    model.theme.isDark
                        ? Color.white.opacity(isFocusing ? 0.28 : (isInCall ? 0.18 : 0.08))
                        : Color.black.opacity(isFocusing ? 0.20 : (isInCall ? 0.12 : 0.05)),
                    lineWidth: isFocusing ? 1.25 : 0.75
                )
                .frame(width: 44, height: 44)
            
            // Steady Deep-Focus Orbital Progress Ring Highlight when Pomodoro is running
            if isFocusing {
                Circle()
                    .trim(from: 0, to: CGFloat(max(0.08, model.pomodoro.progress)))
                    .stroke(
                        model.theme.textPrimary.opacity(0.65),
                        style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 44, height: 44)
            }
            
            // Outer Orbiting Constellation Dots (OpenAI Voice Mode Inspiration)
            ZStack {
                // Dot 1 (Lead Specular Dot)
                Circle()
                    .fill(model.theme.textPrimary)
                    .frame(width: isFocusing ? 5.0 : 4.5, height: isFocusing ? 5.0 : 4.5)
                    .shadow(color: model.theme.textPrimary.opacity(0.6), radius: 3)
                    .offset(x: 29, y: 0)
                
                // Dot 2 (Harmonic Orbit Dot)
                Circle()
                    .fill(model.theme.textPrimary.opacity(isFocusing ? 0.80 : 0.65))
                    .frame(width: 3.2, height: 3.2)
                    .offset(x: -25, y: -14)
                
                // Dot 3 (Fine Orbit Pip)
                Circle()
                    .fill(model.theme.textPrimary.opacity(isFocusing ? 0.55 : 0.40))
                    .frame(width: 2.5, height: 2.5)
                    .offset(x: -12, y: 26)
            }
            .rotationEffect(.degrees(outerRotation))
            
            // Counter-Orbiting Inner Constellation Dots
            ZStack {
                Circle()
                    .fill(model.theme.textPrimary.opacity(0.85))
                    .frame(width: 3.5, height: 3.5)
                    .offset(x: 0, y: -22)
                
                Circle()
                    .fill(model.theme.textPrimary.opacity(0.50))
                    .frame(width: 2.5, height: 2.5)
                    .offset(x: 19, y: 11)
                
                Circle()
                    .fill(model.theme.textPrimary.opacity(0.35))
                    .frame(width: 2.2, height: 2.2)
                    .offset(x: -19, y: 11)
            }
            .rotationEffect(.degrees(innerRotation))
            
            // Living Morphic Center Core (Meta AI Muse Breathing Orb)
            ZStack {
                // Base Fluid Sphere with Specular Rim
                Circle()
                    .fill(
                        LinearGradient(
                            colors: model.theme.isDark
                                ? [Color(white: 0.24), Color(white: 0.10), Color(white: 0.04)]
                                : [Color(white: 0.98), Color(white: 0.90), Color(white: 0.82)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 28, height: 28)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: model.theme.isDark
                                        ? [Color.white.opacity(isFocusing ? 0.72 : 0.5), Color.white.opacity(0.1)]
                                        : [Color.black.opacity(isFocusing ? 0.35 : 0.2), Color.black.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: isFocusing ? 1.25 : 1
                            )
                    )
                    .shadow(
                        color: model.theme.isDark ? Color.black.opacity(0.8) : Color.black.opacity(0.15),
                        radius: 6,
                        x: 0,
                        y: 3
                    )
                
                // Specular Core Glint
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(model.theme.isDark ? 0.35 : 0.6), Color.clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                    .frame(width: 22, height: 12)
                    .offset(y: -6)
                    .mask(Circle().frame(width: 26, height: 26))
                
                // OpenAI Living Harmonic 3-Dot Voice / Focus Cluster inside the Core
                HStack(spacing: isFocusing ? 2.5 : 3) {
                    Circle()
                        .fill(model.theme.textPrimary.opacity(isFocusing ? 0.95 : 0.85))
                        .frame(width: isInCall ? 3.2 : 2.8, height: isInCall && isPulsing ? 5.2 : 2.8)
                    Capsule()
                        .fill(model.theme.textPrimary)
                        .frame(
                            width: isFocusing ? 5.5 : (isPlayingMedia ? 4.2 : 3.4),
                            height: isFocusing ? 2.8 : (isPlayingMedia || isInCall ? 4.6 : 3.4)
                        )
                        .scaleEffect(isPulsing ? (isFocusing ? 1.06 : 1.15) : 0.88)
                    Circle()
                        .fill(model.theme.textPrimary.opacity(isFocusing ? 0.95 : 0.85))
                        .frame(width: isInCall ? 3.2 : 2.8, height: isInCall && isPulsing ? 5.2 : 2.8)
                }
            }
            .scaleEffect((coreScale + tapImpulse) * (isPlayingMedia || isInCall ? 1.06 : (isFocusing ? 1.03 : 1.0)))
        }
        .frame(width: 68, height: 68)
        .contentShape(Circle())
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovered = hovering
            }
        }
        .onTapGesture {
            triggerMascotImpulse()
        }
        .help("Morphy Core • Living Dynamic Companion")
        .onAppear {
            withAnimation(.linear(duration: 18).repeatForever(autoreverses: false)) {
                outerRotation = 360
            }
            withAnimation(.linear(duration: 24).repeatForever(autoreverses: false)) {
                innerRotation = -360
            }
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
                coreScale = 1.05
                isPulsing = true
            }
        }
    }
    
    private func triggerMascotImpulse() {
        MorphHaptics.generic()
        withAnimation(.spring(response: 0.22, dampingFraction: 0.55)) {
            tapImpulse = 0.18
            outerRotation += 45
            innerRotation -= 45
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                tapImpulse = 0
            }
        }
    }
}
