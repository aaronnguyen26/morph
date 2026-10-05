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
            Text("\(greetingText), \(model.supabase.currentUser.firstName)")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            // 3. Ultra-Clean Minimalist Action Pills (Pure Monochrome Luxury)
            HStack(spacing: 8) {
                // Focus Toggle Pill
                Button(action: {
                    model.pomodoro.toggle()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: model.pomodoro.isRunning ? "pause.fill" : "flame.fill")
                            .font(.system(size: 8.5))
                            .foregroundColor(.white)
                        Text(model.pomodoro.isRunning ? "Pause (\(model.pomodoro.formattedTime))" : "Start 25m Focus")
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
                .help("Start/Pause Focus (⌘⏎ or ⌘2)")
                
                // Music Toggle Pill
                Button(action: {
                    model.media.togglePlay()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: model.media.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 8.5))
                            .foregroundColor(.white)
                        Text(model.media.isPlaying ? "Pause Music" : "Play Music")
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
                .help("Play/Pause Music (⌘⏎ or ⌘3)")
                
                // Notes Pill
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
            }
            
            Spacer(minLength: 4)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
