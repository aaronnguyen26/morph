import SwiftUI

public struct MorphyMascotView: View {
    @ObservedObject var model: NotchModel
    
    @State private var isBlinking: Bool = false
    @State private var isFloating: Bool = false
    @State private var orbitRotation: Double = 0
    @State private var isWinking: Bool = false
    
    // Timer for natural blinking
    private let blinkTimer = Timer.publish(every: 4.2, on: .main, in: .common).autoconnect()
    
    public init(model: NotchModel) {
        self.model = model
    }
    
    private var statusMessage: (title: String, subtitle: String) {
        if model.pomodoro.isRunning && model.media.isPlaying {
            return ("Morphy locked in", "Focus & Music in sync")
        } else if model.pomodoro.isRunning {
            return ("Morphy in sync", "Focus active • \(model.pomodoro.formattedTime)")
        } else if model.media.isPlaying {
            return ("Morphy vibing", model.media.trackTitle.isEmpty ? "Playing Audio" : model.media.trackTitle)
        } else {
            return ("Morphy is ready", "Deep Focus & Productivity Hub")
        }
    }
    
    public var body: some View {
        VStack(spacing: 8) {
            // MARK: - Morphy Floating Orb Mascot
            ZStack {
                // Outer Orbit Glow Ring (Subtle monochrome dashed orbit)
                Circle()
                    .stroke(
                        Color.white.opacity(0.12),
                        style: StrokeStyle(lineWidth: 1, dash: [3, 5])
                    )
                    .frame(width: 58, height: 58)
                    .rotationEffect(.degrees(orbitRotation))
                
                // Ambient Radial Glow
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.14),
                                Color.white.opacity(0.03),
                                Color.clear
                            ]),
                            center: .center,
                            startRadius: 8,
                            endRadius: 32
                        )
                    )
                    .frame(width: 64, height: 64)
                
                // Glass Orb Body
                ZStack {
                    // Dark Glass Orb Gradient
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(white: 0.16),
                                    Color(white: 0.06),
                                    Color.black
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.35),
                                            Color.white.opacity(0.08)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: Color.black.opacity(0.8), radius: 6, x: 0, y: 3)
                    
                    // Glass Sheen Reflection
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.22), Color.clear],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                        .frame(width: 38, height: 20)
                        .offset(y: -9)
                        .mask(Circle().frame(width: 42, height: 42))
                    
                    // Expressive Digital Pill Eyes
                    HStack(spacing: 5) {
                        // Left Eye
                        Capsule()
                            .fill(Color.white)
                            .frame(width: 3.5, height: isBlinking || isWinking ? 1 : 8.5)
                            .shadow(color: Color.white.opacity(0.8), radius: 2)
                        
                        // Right Eye
                        Capsule()
                            .fill(Color.white)
                            .frame(width: 3.5, height: isBlinking ? 1 : 8.5)
                            .shadow(color: Color.white.opacity(0.8), radius: 2)
                    }
                    .animation(.easeInOut(duration: 0.12), value: isBlinking)
                    .animation(.easeInOut(duration: 0.15), value: isWinking)
                }
            }
            .offset(y: isFloating ? -3 : 3)
            .onTapGesture {
                // Interactive wink reaction when clicked
                withAnimation {
                    isWinking = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    withAnimation {
                        isWinking = false
                    }
                }
            }
            
            // MARK: - Morphy Telemetry Status Pill
            HStack(spacing: 6) {
                // Live status pulsing dot
                Circle()
                    .fill(model.isCompactActive ? Color.white : Color.white.opacity(0.5))
                    .frame(width: 5, height: 5)
                    .shadow(color: model.isCompactActive ? Color.white.opacity(0.8) : Color.clear, radius: 3)
                
                Text(statusMessage.title)
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("•")
                    .font(.system(size: 8))
                    .foregroundColor(Color.white.opacity(0.35))
                
                Text(statusMessage.subtitle)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.7))
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
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                isFloating = true
            }
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
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
}
