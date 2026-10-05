import SwiftUI

public struct HomeView: View {
    @ObservedObject var model: NotchModel
    
    public var body: some View {
        VStack(spacing: 8) {
            // Three Feature Cards
            HStack(spacing: 8) {
                // Feature 1: Pomodoro Focus Timer
                focusCard
                
                // Feature 2: YouTube Music Player
                musicCard
                
                // Feature 3: Quick Scratchpad Notepad
                notesCard
            }
            .frame(maxHeight: .infinity)
        }
        .padding(.horizontal, 10)
        .padding(.top, 2)
        .padding(.bottom, 6)
    }
    
    // MARK: - Focus Card
    private var focusCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Card Header
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "timer")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color(red: 0.20, green: 0.90, blue: 0.55))
                    Text("FOCUS")
                        .font(.system(size: 9.5, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .tracking(0.8)
                }
                
                Spacer()
                
                // Status Pill
                Text(model.pomodoro.isRunning ? "ACTIVE" : "READY")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(Color(red: 0.20, green: 0.90, blue: 0.55))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color(red: 0.20, green: 0.90, blue: 0.55).opacity(0.15))
                    .cornerRadius(4)
            }
            
            // Main Timer Display
            VStack(alignment: .leading, spacing: 1) {
                Text(model.pomodoro.formattedTime)
                    .font(.system(size: 18, weight: .heavy, design: .monospaced))
                    .foregroundColor(.white)
                
                Text(model.pomodoro.mode.rawValue)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.5))
            }
            
            Spacer()
            
            // Action Buttons
            HStack(spacing: 6) {
                Button(action: {
                    model.pomodoro.toggle()
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: model.pomodoro.isRunning ? "pause.fill" : "play.fill")
                            .font(.system(size: 8.5))
                        Text(model.pomodoro.isRunning ? "Pause" : "Start")
                            .font(.system(size: 9.5, weight: .bold))
                    }
                    .foregroundColor(model.pomodoro.isRunning ? .white : .black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        model.pomodoro.isRunning
                            ? Color.white.opacity(0.2)
                            : Color(red: 0.20, green: 0.90, blue: 0.55)
                    )
                    .cornerRadius(5)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button(action: {
                    model.openFeature(.timer)
                }) {
                    Text("Open →")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(Color(red: 0.20, green: 0.90, blue: 0.55))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color(red: 0.20, green: 0.90, blue: 0.55).opacity(0.25), lineWidth: 1)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            model.openFeature(.timer)
        }
    }
    
    // MARK: - Music Card
    private var musicCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Card Header
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "music.note")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color(red: 0.15, green: 0.85, blue: 1.0))
                    Text("MUSIC")
                        .font(.system(size: 9.5, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .tracking(0.8)
                }
                
                Spacer()
                
                // Live 3-Bar Equalizer
                HStack(alignment: .bottom, spacing: 2) {
                    ForEach(0..<3, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color(red: 0.15, green: 0.85, blue: 1.0))
                            .frame(width: 2, height: max(3, 11 * model.media.visualizerBars[i]))
                    }
                }
                .frame(height: 11, alignment: .bottom)
            }
            
            // Track Info Display
            VStack(alignment: .leading, spacing: 1) {
                Text(model.media.trackTitle)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(model.media.artistName)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.5))
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Action Buttons
            HStack(spacing: 6) {
                Button(action: {
                    model.media.togglePlay()
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: model.media.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 8.5))
                        Text(model.media.isPlaying ? "Pause" : "Play")
                            .font(.system(size: 9.5, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(red: 0.15, green: 0.85, blue: 1.0).opacity(0.3))
                    .cornerRadius(5)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button(action: {
                    model.openFeature(.music)
                }) {
                    Text("Open →")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(Color(red: 0.15, green: 0.85, blue: 1.0))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color(red: 0.15, green: 0.85, blue: 1.0).opacity(0.25), lineWidth: 1)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            model.openFeature(.music)
        }
    }
    
    // MARK: - Notes Card
    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Card Header
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "note.text")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color(red: 1.0, green: 0.65, blue: 0.20))
                    Text("SCRATCHPAD")
                        .font(.system(size: 9.5, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .tracking(0.8)
                }
                
                Spacer()
                
                Text(model.scratchpad.text.isEmpty ? "EMPTY" : "\(model.scratchpad.wordCount)W")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(Color(red: 1.0, green: 0.65, blue: 0.20))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color(red: 1.0, green: 0.65, blue: 0.20).opacity(0.15))
                    .cornerRadius(4)
            }
            
            // Note Snippet Display
            VStack(alignment: .leading, spacing: 1) {
                Text(model.scratchpad.text.isEmpty ? "Click to write thoughts, links, or quick tasks..." : model.scratchpad.text)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(model.scratchpad.text.isEmpty ? Color.white.opacity(0.4) : Color.white.opacity(0.85))
                    .lineLimit(2)
            }
            
            Spacer()
            
            // Action Buttons
            HStack(spacing: 6) {
                if !model.scratchpad.text.isEmpty {
                    Button(action: {
                        model.scratchpad.copyAll()
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: model.scratchpad.showCopiedAlert ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 8))
                            Text(model.scratchpad.showCopiedAlert ? "Copied" : "Copy")
                                .font(.system(size: 9, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
                
                Button(action: {
                    model.openFeature(.notes)
                }) {
                    Text("Open →")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(Color(red: 1.0, green: 0.65, blue: 0.20))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color(red: 1.0, green: 0.65, blue: 0.20).opacity(0.25), lineWidth: 1)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            model.openFeature(.notes)
        }
    }
}
