import SwiftUI

public struct PomodoroView: View {
    @ObservedObject var pomodoro: PomodoroModel
    
    public var body: some View {
        HStack(spacing: 24) {
            // Left: Circular Progress Dial
            ZStack {
                // Background Track
                Circle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 6)
                    .frame(width: 104, height: 104)
                
                // Progress Arc
                Circle()
                    .trim(from: 0, to: CGFloat(pomodoro.progress))
                    .stroke(
                        Color.white,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 104, height: 104)
                    .animation(.linear(duration: 1.0), value: pomodoro.progress)
                
                // Inner Content
                VStack(spacing: 3) {
                    Image(systemName: pomodoro.mode.iconName)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(pomodoro.formattedTime)
                        .font(.system(size: 19, weight: .heavy, design: .monospaced))
                        .foregroundColor(.white)
                    
                    Text(pomodoro.mode.rawValue.uppercased())
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.5))
                        .tracking(0.8)
                }
            }
            .frame(width: 110, height: 110)
            
            // Right: Controls & Presets
            VStack(alignment: .leading, spacing: 12) {
                // Mode Selector Pills
                HStack(spacing: 8) {
                    ForEach(PomodoroMode.allCases) { mode in
                        Button(action: {
                            pomodoro.switchMode(mode)
                        }) {
                            Text(mode.rawValue)
                                .font(.system(size: 10.5, weight: pomodoro.mode == mode ? .bold : .medium))
                                .foregroundColor(pomodoro.mode == mode ? .black : Color.white.opacity(0.6))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4.5)
                                .background(
                                    pomodoro.mode == mode
                                        ? Color.white
                                        : Color.white.opacity(0.08)
                                )
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Spacer()
                    
                    // Completed Sessions Badge
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                        Text("\(pomodoro.completedSessionsCount)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(Color.white.opacity(0.75))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(6)
                }
                
                // Play/Pause & Reset Row
                HStack(spacing: 10) {
                    Button(action: {
                        pomodoro.toggle()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: pomodoro.isRunning ? "pause.fill" : "play.fill")
                                .font(.system(size: 11, weight: .bold))
                            Text(pomodoro.isRunning ? "Pause Session" : "Start Focus")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundColor(pomodoro.isRunning ? .white : .black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(
                            pomodoro.isRunning
                                ? Color.white.opacity(0.2)
                                : Color.white
                        )
                        .cornerRadius(7)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        pomodoro.reset()
                    }) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.75))
                            .padding(8)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(7)
                    }
                    .buttonStyle(.plain)
                    .help("Reset Timer")
                    
                    Spacer()
                    
                    // Duration Presets
                    HStack(spacing: 6) {
                        presetButton(label: "25m", minutes: 25)
                        presetButton(label: "15m", minutes: 15)
                        presetButton(label: "5m", minutes: 5)
                        presetButton(label: "1m", minutes: 1)
                    }
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func presetButton(label: String, minutes: Int) -> some View {
        Button(action: {
            pomodoro.setCustomDuration(minutes: minutes)
        }) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Color.white.opacity(0.7))
                .padding(.horizontal, 7)
                .padding(.vertical, 4.5)
                .background(Color.white.opacity(0.08))
                .cornerRadius(5)
        }
        .buttonStyle(.plain)
    }
}
