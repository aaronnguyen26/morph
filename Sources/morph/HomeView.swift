import SwiftUI

public struct HomeView: View {
    @ObservedObject var model: NotchModel
    
    public init(model: NotchModel) {
        self.model = model
    }
    
    // Greeting based on current hour
    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 {
            return "Good morning"
        } else if hour < 17 {
            return "Good afternoon"
        } else {
            return "Good evening"
        }
    }
    
    public var body: some View {
        VStack(spacing: 8) {
            Spacer(minLength: 4)
            
            // 1. Centerpiece Companion Hero: Morphy Mascot (Pure Monochrome, Scaled to 3/4)
            MorphyMascotView(model: model)
                .scaleEffect(0.82)
                .frame(height: 54)
            
            // 2. Minimalist Clean Greeting (No unsolicited metrics/chips)
            Button(action: {
                model.openFeature(.profile)
            }) {
                Text("\(greetingText), \(model.supabase.currentUser.firstName)")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)
            .help("Open Profile (⌘5)")
            
            // 3. Ultra-Clean Minimalist Action Pills (Pure Monochrome Luxury)
            HStack(spacing: 8) {
                // Focus Feature Pill
                Button(action: {
                    model.openFeature(.timer)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: model.pomodoro.isRunning ? "timer" : "flame.fill")
                            .font(.system(size: 8.5))
                            .foregroundColor(.white)
                        Text(model.pomodoro.isRunning ? "Focus (\(model.pomodoro.formattedTime))" : "Focus")
                            .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        model.pomodoro.isRunning
                            ? Color.white.opacity(0.18)
                            : Color.white.opacity(0.08)
                    )
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.14), lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
                .help("Open Focus Timer (⌘2)")
                
                // Music Feature Pill
                Button(action: {
                    model.openFeature(.music)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: model.media.isPlaying ? "waveform" : "play.circle.fill")
                            .font(.system(size: 8.5))
                            .foregroundColor(.white)
                        Text(model.media.isPlaying ? "Music Playing" : "Music")
                            .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        model.media.isPlaying
                            ? Color.white.opacity(0.18)
                            : Color.white.opacity(0.08)
                    )
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.14), lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
                .help("Open Music (⌘3)")
                
                // Notes Feature Pill
                Button(action: {
                    model.openFeature(.notes)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 8.5))
                            .foregroundColor(.white)
                        Text(model.scratchpad.text.isEmpty ? "Notes" : "Notes (\(model.scratchpad.wordCount)w)")
                            .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.14), lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
                .help("Open Notes (⌘4)")
                
                // Calendar Feature Pill
                Button(action: {
                    model.openFeature(.calendar)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 8.5))
                            .foregroundColor(.white)
                        if let next = model.calendar.nextUpcomingEvent, next.isStartingSoon {
                            Text("In \(next.minutesUntilStart)m")
                                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                                .foregroundColor(.cyan)
                        } else {
                            Text("Calendar")
                                .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                        }
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        model.calendar.showNotchAlert
                            ? Color.cyan.opacity(0.18)
                            : Color.white.opacity(0.08)
                    )
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(model.calendar.showNotchAlert ? Color.cyan.opacity(0.3) : Color.white.opacity(0.14), lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
                .help("Open Calendar (⌘6)")
                
                // Profile Feature Pill
                Button(action: {
                    model.openFeature(.profile)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "person.crop.circle")
                            .font(.system(size: 8.5))
                            .foregroundColor(.white)
                        Text("Profile")
                            .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.14), lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
                .help("Open Profile (⌘5)")
            }
            
            Spacer(minLength: 4)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
