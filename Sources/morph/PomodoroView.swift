import SwiftUI

public struct PomodoroView: View {
    @ObservedObject var pomodoro: PomodoroModel
    @State private var showingCustomInput: Bool = false
    @State private var customMinutesText: String = ""
    
    public var body: some View {
        HStack(spacing: 16) {
            // Left: Circular Progress Dial
            circularDial
            
            // Right: Controls & Presets
            VStack(alignment: .leading, spacing: 7) {
                // Row 1: Mode Selector Tabs & Streak Badge
                modeSelectorRow
                
                // Row 2: Action Row & Quick Delta Increments
                actionRow
                
                // Row 3: Custom Presets & Tactile Stepper
                customDurationRow
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Left Dial
    private var circularDial: some View {
        ZStack {
            // Background Track
            Circle()
                .stroke(Color.white.opacity(0.10), lineWidth: 5.5)
                .frame(width: 96, height: 96)
            
            // Progress Arc
            Circle()
                .trim(from: 0, to: CGFloat(pomodoro.progress))
                .stroke(
                    Color.white,
                    style: StrokeStyle(lineWidth: 5.5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 96, height: 96)
                .animation(.linear(duration: 1.0), value: pomodoro.progress)
            
            // Inner Content
            VStack(spacing: 2) {
                Image(systemName: pomodoro.mode.iconName)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                
                Text(pomodoro.formattedTime)
                    .font(.system(size: 18, weight: .heavy, design: .monospaced))
                    .foregroundColor(.white)
                
                Text(pomodoro.mode.rawValue.uppercased())
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.55))
                    .tracking(0.6)
                
                let prefMinutes = Int(pomodoro.preferredDuration(for: pomodoro.mode) / 60)
                Text("Pref: \(prefMinutes)m")
                    .font(.system(size: 7.5, weight: .medium, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.35))
            }
        }
        .frame(width: 102, height: 102)
    }
    
    // MARK: - Row 1: Mode Selector
    private var modeSelectorRow: some View {
        HStack(spacing: 6) {
            // Mode Selector Pills
            HStack(spacing: 4) {
                ForEach(PomodoroMode.allCases) { mode in
                    Button(action: {
                        pomodoro.switchMode(mode)
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: mode.iconName)
                                .font(.system(size: 8))
                            Text(mode.rawValue)
                                .font(.system(size: 10, weight: pomodoro.mode == mode ? .bold : .medium))
                        }
                        .foregroundColor(pomodoro.mode == mode ? .black : Color.white.opacity(0.65))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3.5)
                        .background(
                            pomodoro.mode == mode
                                ? Color.white
                                : Color.white.opacity(0.08)
                        )
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .help("Switch to \(mode.rawValue) (Preferred: \(Int(pomodoro.preferredDuration(for: mode) / 60))m)")
                }
            }
            
            Spacer()
            
            // Completed Sessions Streak Badge
            HStack(spacing: 3) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 9))
                    .foregroundColor(pomodoro.completedSessionsCount > 0 ? .orange : Color.white.opacity(0.5))
                Text("\(pomodoro.completedSessionsCount)")
                    .font(.system(size: 10.5, weight: .bold, design: .rounded))
                Text("done")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.45))
            }
            .foregroundColor(Color.white.opacity(0.8))
            .padding(.horizontal, 7)
            .padding(.vertical, 3.5)
            .background(Color.white.opacity(0.08))
            .cornerRadius(6)
        }
    }
    
    // MARK: - Row 2: Action Row & Quick Delta Increments
    private var actionRow: some View {
        HStack(spacing: 8) {
            // Play / Pause Capsule Button
            Button(action: {
                pomodoro.toggle()
            }) {
                HStack(spacing: 5) {
                    Image(systemName: pomodoro.isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text(pomodoro.isRunning ? "Pause Session" : "Start Focus")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(pomodoro.isRunning ? .white : .black)
                .padding(.horizontal, 13)
                .padding(.vertical, 5)
                .background(
                    pomodoro.isRunning
                        ? Color.white.opacity(0.2)
                        : Color.white
                )
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .help("Start/Pause Focus (⌘⏎)")
            
            // Reset Button
            Button(action: {
                pomodoro.reset()
            }) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.75))
                    .frame(width: 24, height: 24)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .help("Reset Timer (⌘⇧R)")
            
            Spacer()
            
            // Quick Delta Adjustments (-5m, -1m, +1m, +5m)
            HStack(spacing: 3) {
                deltaButton(label: "-5m", delta: -5)
                deltaButton(label: "-1m", delta: -1)
                deltaButton(label: "+1m", delta: 1)
                deltaButton(label: "+5m", delta: 5)
            }
        }
    }
    
    private func deltaButton(label: String, delta: Int) -> some View {
        Button(action: {
            pomodoro.adjustTime(deltaMinutes: delta)
        }) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.75))
                .padding(.horizontal, 5)
                .padding(.vertical, 3.5)
                .background(Color.white.opacity(0.07))
                .cornerRadius(5)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
        .help("Adjust remaining time by \(delta > 0 ? "+\(delta)" : "\(delta)") min")
    }
    
    // MARK: - Row 3: Presets & Custom Duration Stepper
    private var customDurationRow: some View {
        HStack(spacing: 5) {
            // Mode-specific Presets
            HStack(spacing: 3) {
                ForEach(pomodoro.currentPresets, id: \.self) { minutes in
                    let isCurrent = (pomodoro.currentMinutes == minutes)
                    Button(action: {
                        pomodoro.setCustomDuration(minutes: minutes, saveAsPreference: false)
                    }) {
                        Text("\(minutes)m")
                            .font(.system(size: 9.5, weight: isCurrent ? .bold : .medium))
                            .foregroundColor(isCurrent ? .black : Color.white.opacity(0.7))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3.5)
                            .background(isCurrent ? Color.white : Color.white.opacity(0.07))
                            .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                    .help("Set duration to \(minutes) minutes")
                }
            }
            
            // Separator divider
            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 1, height: 16)
                .padding(.horizontal, 1)
            
            // Tactile Stepper: [-] [ XXm ] [+]
            HStack(spacing: 2) {
                // Decrement
                Button(action: {
                    let next = max(1, pomodoro.currentMinutes - 1)
                    pomodoro.setCustomDuration(minutes: next, saveAsPreference: false)
                }) {
                    Image(systemName: "minus")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.8))
                        .frame(width: 18, height: 20)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .help("Decrease duration by 1m")
                
                // Editable / Display Pill
                Button(action: {
                    showingCustomInput.toggle()
                    customMinutesText = "\(pomodoro.currentMinutes)"
                }) {
                    HStack(spacing: 1) {
                        Text("\(pomodoro.currentMinutes)")
                            .font(.system(size: 9.5, weight: .heavy, design: .monospaced))
                        Text("m")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundColor(Color.white.opacity(0.5))
                    }
                    .foregroundColor(.white)
                    .frame(minWidth: 32)
                    .padding(.vertical, 2.5)
                    .background(Color.white.opacity(0.12))
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .help("Click to manually enter custom minutes")
                .popover(isPresented: $showingCustomInput) {
                    customMinutePopover
                }
                
                // Increment
                Button(action: {
                    let next = min(180, pomodoro.currentMinutes + 1)
                    pomodoro.setCustomDuration(minutes: next, saveAsPreference: false)
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.8))
                        .frame(width: 18, height: 20)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .help("Increase duration by 1m")
            }
            
            // Save as Mode Preference Button
            let isCurrentPref = (pomodoro.currentMinutes == Int(pomodoro.preferredDuration(for: pomodoro.mode) / 60))
            Button(action: {
                pomodoro.setPreferredDuration(minutes: pomodoro.currentMinutes, for: pomodoro.mode)
            }) {
                HStack(spacing: 2) {
                    Image(systemName: isCurrentPref ? "checkmark" : "pin.fill")
                        .font(.system(size: 7, weight: .bold))
                    Text(isCurrentPref ? "Saved" : "Save")
                        .font(.system(size: 8.5, weight: .bold))
                }
                .foregroundColor(isCurrentPref ? Color.green.opacity(0.9) : Color.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 3)
                .background(isCurrentPref ? Color.green.opacity(0.15) : Color.white.opacity(0.14))
                .cornerRadius(4)
            }
            .buttonStyle(.plain)
            .help(isCurrentPref ? "Current duration is saved as your preference for \(pomodoro.mode.rawValue)" : "Save \(pomodoro.currentMinutes)m as your default preference for \(pomodoro.mode.rawValue)")
            
            // Restore default icon if modified from factory standard
            if pomodoro.isUsingCustomPreference(for: pomodoro.mode) {
                Button(action: {
                    pomodoro.restoreDefaultDuration(for: pomodoro.mode)
                }) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 7.5, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.5))
                        .frame(width: 18, height: 18)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .help("Reset \(pomodoro.mode.rawValue) preference to default (\(Int(pomodoro.mode.defaultDuration / 60))m)")
            }
        }
    }
    
    // MARK: - Popover for Manual Minute Entry
    private var customMinutePopover: some View {
        VStack(spacing: 8) {
            Text("Set Custom \(pomodoro.mode.rawValue) Time")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
            
            HStack(spacing: 4) {
                TextField("Minutes", text: $customMinutesText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(5)
                    .frame(width: 60)
                    .background(Color.white.opacity(0.12))
                    .cornerRadius(6)
                    .multilineTextAlignment(.center)
                
                Text("min")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.6))
            }
            
            HStack(spacing: 6) {
                Button("Apply") {
                    if let mins = Int(customMinutesText), mins > 0 {
                        pomodoro.setCustomDuration(minutes: mins, saveAsPreference: false)
                    }
                    showingCustomInput = false
                }
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.black)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.white)
                .cornerRadius(5)
                .buttonStyle(.plain)
                
                Button("Save as Pref") {
                    if let mins = Int(customMinutesText), mins > 0 {
                        pomodoro.setPreferredDuration(minutes: mins, for: pomodoro.mode)
                    }
                    showingCustomInput = false
                }
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.2))
                .cornerRadius(5)
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(Color(white: 0.12))
        .cornerRadius(10)
    }
}
