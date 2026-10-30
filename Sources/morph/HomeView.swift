import SwiftUI

/// Home Screen V4: Apple-grade Ambient Cockpit
/// Displays Glance telemetry on the left, Morphy Core living companion in the center,
/// and fast-launch action capsules on the right.
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
    
    private var formattedTodayDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: Date())
    }
    
    private var meetingsTodayCount: Int {
        let calendar = Calendar.current
        let todayEvents = model.calendar.events.filter { event in
            calendar.isDateInToday(event.startTime)
        }
        return todayEvents.isEmpty ? model.calendar.events.count : todayEvents.count
    }
    
    private var nextMeetingSummary: String {
        if let next = model.calendar.nextUpcomingEvent {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return "Next: \(formatter.string(from: next.startTime))"
        } else if meetingsTodayCount > 0 {
            return "All caught up"
        } else {
            return "Schedule clear"
        }
    }
    
    private var contextualSubtitle: String {
        if model.pomodoro.isRunning {
            return "Focus block in progress • \(model.pomodoro.formattedTime)"
        } else if model.media.isPlaying {
            return "Now playing • \(model.media.trackTitle.isEmpty ? "YouTube Music" : model.media.trackTitle)"
        } else if model.meetingController.isInCall {
            return "In meeting • \(model.meetingController.formattedCallDuration)"
        } else {
            return "Ready for your first focus session"
        }
    }
    
    public var body: some View {
        HStack(alignment: .center, spacing: 14) {
            // MARK: - Left Flank (GLANCE Telemetry)
            leftGlanceFlank
                .frame(width: 145, alignment: .leading)
            
            // MARK: - Centerpiece Companion Hero (Living Morphy Core)
            centerCompanionHero
                .frame(maxWidth: .infinity, alignment: .center)
            
            // MARK: - Right Flank (LAUNCH Actions)
            rightLaunchFlank
                .frame(width: 150, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Left Flank: Glance Telemetry
    private var leftGlanceFlank: some View {
        Button(action: {
            model.openFeature(.calendar)
        }) {
            VStack(alignment: .leading, spacing: 3.5) {
                Text("GLANCE")
                    .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                    .foregroundColor(model.theme.textTertiary)
                    .tracking(1.2)
                
                Text(formattedTodayDate)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(model.theme.textPrimary)
                    .lineLimit(1)
                
                Text(meetingsTodayCount > 0 ? "\(meetingsTodayCount) \(meetingsTodayCount == 1 ? "meeting" : "meetings") today" : "No meetings today")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundColor(model.theme.textSecondary)
                    .lineLimit(1)
                
                Text(nextMeetingSummary)
                    .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                    .foregroundColor(model.theme.textTertiary)
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Open Calendar (⌘6)")
    }
    
    // MARK: - Center Companion & Greeting
    private var centerCompanionHero: some View {
        VStack(spacing: 4) {
            // Living Orbital Mascot
            MorphyMascotView(model: model)
                .frame(height: 60)
            
            // Personalized Greeting
            Button(action: {
                model.openFeature(.profile)
            }) {
                Text("\(greetingText), \(model.supabase.currentUser.firstName)")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(model.theme.textPrimary)
                    .lineLimit(1)
            }
            .buttonStyle(.plain)
            .help("Open Profile (⌘5)")
            
            // Dynamic Context Subtitle
            Text(contextualSubtitle)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(model.theme.textTertiary)
                .lineLimit(1)
        }
    }
    
    // MARK: - Right Flank: Launch Actions
    private var rightLaunchFlank: some View {
        VStack(alignment: .trailing, spacing: 5) {
            Text("LAUNCH")
                .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                .foregroundColor(model.theme.textTertiary)
                .tracking(1.2)
                .padding(.trailing, 4)
            
            // Focus Session Action Capsule
            HStack(spacing: 5) {
                Button(action: { model.openFeature(.timer) }) {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 8))
                        Text("Focus Session")
                            .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    }
                }
                .buttonStyle(.plain)
                
                Spacer(minLength: 2)
                
                Button(action: {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                        model.pomodoro.toggle()
                    }
                }) {
                    Text(model.pomodoro.isRunning ? model.pomodoro.formattedTime : "25m")
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .foregroundColor(model.pomodoro.isRunning ? model.theme.textPrimary : model.theme.textTertiary)
                }
                .buttonStyle(.plain)
                .help(model.pomodoro.isRunning ? "Pause Focus Timer" : "Start Focus Timer")
            }
            .foregroundColor(model.theme.textPrimary)
            .padding(.horizontal, 9)
            .padding(.vertical, 4.5)
            .frame(width: 146)
            .background(model.pomodoro.isRunning ? model.theme.cardBackgroundElevated : model.theme.cardBackground)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(model.theme.hairlineBorder, lineWidth: 0.5)
            )
            .help("Launch Focus Session (⌘2)")
            
            // YouTube Music Action Capsule
            HStack(spacing: 5) {
                Button(action: { model.openFeature(.music) }) {
                    HStack(spacing: 4) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 8))
                        Text("YouTube Music")
                            .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    }
                }
                .buttonStyle(.plain)
                
                Spacer(minLength: 2)
                
                Button(action: {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                        model.media.togglePlay()
                    }
                }) {
                    Text(model.media.isPlaying ? "Playing" : "Play")
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .foregroundColor(model.media.isPlaying ? model.theme.textPrimary : model.theme.textTertiary)
                }
                .buttonStyle(.plain)
                .help(model.media.isPlaying ? "Pause Music" : "Play Music")
            }
            .foregroundColor(model.theme.textPrimary)
            .padding(.horizontal, 9)
            .padding(.vertical, 4.5)
            .frame(width: 146)
            .background(model.media.isPlaying ? model.theme.cardBackgroundElevated : model.theme.cardBackground)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(model.theme.hairlineBorder, lineWidth: 0.5)
            )
            .help("Launch YouTube Music (⌘3)")
            
            // Scratchpad Action Capsule
            Button(action: {
                model.openFeature(.notes)
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "note.text")
                        .font(.system(size: 8))
                    Text("Scratchpad")
                        .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    Spacer(minLength: 2)
                    Text("Write")
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .foregroundColor(model.theme.textTertiary)
                }
                .foregroundColor(model.theme.textPrimary)
                .padding(.horizontal, 9)
                .padding(.vertical, 4.5)
                .frame(width: 146)
                .background(model.theme.cardBackground)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(model.theme.hairlineBorder, lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)
            .help("Open Scratchpad (⌘4)")
        }
    }
}
