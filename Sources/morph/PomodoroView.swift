import SwiftUI

public struct PomodoroView: View {
    @ObservedObject var pomodoro: PomodoroModel
    var accentColor: Color
    
    public var body: some View {
        HStack(spacing: 16) {
            // Left: Circular Progress Dial
            ZStack {
                // Background Track
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 5)
                    .frame(width: 82, height: 82)
                
                // Progress Arc
                Circle()
                    .trim(from: 0, to: CGFloat(pomodoro.progress))
                    .stroke(
                        accentColor,
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 82, height: 82)
                    .animation(.linear(duration: 1.0), value: pomodoro.progress)
                
                // Inner Content
                VStack(spacing: 2) {
                    Image(systemName: pomodoro.mode.iconName)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(accentColor)
                    
                    Text(pomodoro.formattedTime)
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    
                    Text(pomodoro.mode.rawValue)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.5))
                }
            }
            .frame(width: 86, height: 86)
            
            // Right: Controls & Presets
            VStack(alignment: .leading, spacing: 8) {
                // Top row: Mode Pills
                HStack(spacing: 6) {
                    ForEach(PomodoroMode.allCases) { mode in
                        Button(action: {
                            pomodoro.switchMode(mode)
                        }) {
                            Text(mode.rawValue)
                                .font(.system(size: 9.5, weight: pomodoro.mode == mode ? .bold : .medium))
                                .foregroundColor(pomodoro.mode == mode ? .white : Color.white.opacity(0.5))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(
                                    pomodoro.mode == mode
                                        ? accentColor.opacity(0.25)
                                        : Color.white.opacity(0.06)
                                )
                                .cornerRadius(5)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Spacer()
                    
                    // Sessions Counter
                    HStack(spacing: 3) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 9))
                            .foregroundColor(accentColor)
                        Text("\(pomodoro.completedSessionsCount)")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(5)
                }
                
                // Middle row: Play/Pause & Reset Buttons
                HStack(spacing: 8) {
                    Button(action: {
                        pomodoro.toggle()
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: pomodoro.isRunning ? "pause.fill" : "play.fill")
                                .font(.system(size: 11, weight: .bold))
                            Text(pomodoro.isRunning ? "Pause" : "Start Focus")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(pomodoro.isRunning ? .white : .black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 5)
                        .background(
                            pomodoro.isRunning
                                ? Color.white.opacity(0.18)
                                : accentColor
                        )
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        pomodoro.reset()
                    }) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.7))
                            .padding(6)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .help("Reset Timer")
                    
                    Spacer()
                    
                    // Quick Interval Presets
                    HStack(spacing: 4) {
                        presetButton(label: "25m", minutes: 25)
                        presetButton(label: "15m", minutes: 15)
                        presetButton(label: "5m", minutes: 5)
                        presetButton(label: "1m", minutes: 1) // Quick test preset
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 2)
    }
    
    private func presetButton(label: String, minutes: Int) -> some View {
        Button(action: {
            pomodoro.setCustomDuration(minutes: minutes)
        }) {
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(Color.white.opacity(0.6))
                .padding(.horizontal, 5)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.06))
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }
}
