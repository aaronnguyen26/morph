import SwiftUI

public struct HomeView: View {
    @ObservedObject var model: NotchModel
    
    public var body: some View {
        HStack(spacing: 12) {
            // Feature 1: Focus Timer
            focusCard
            
            // Feature 2: Media Player
            musicCard
            
            // Feature 3: Scratchpad
            notesCard
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Focus Card
    private var focusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "timer")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                    Text("FOCUS")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .tracking(1.0)
                }
                
                Spacer()
                
                // Status Pill
                Text(model.pomodoro.isRunning ? "ACTIVE" : "READY")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.85))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(4)
            }
            
            // Large Time
            VStack(alignment: .leading, spacing: 2) {
                Text(model.pomodoro.formattedTime)
                    .font(.system(size: 24, weight: .heavy, design: .monospaced))
                    .foregroundColor(.white)
                
                Text(model.pomodoro.mode.rawValue)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.5))
            }
            
            Spacer()
            
            // Action Buttons
            HStack(spacing: 8) {
                Button(action: {
                    model.pomodoro.toggle()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: model.pomodoro.isRunning ? "pause.fill" : "play.fill")
                            .font(.system(size: 9))
                        Text(model.pomodoro.isRunning ? "Pause" : "Start")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(model.pomodoro.isRunning ? .white : .black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        model.pomodoro.isRunning
                            ? Color.white.opacity(0.2)
                            : Color.white
                    )
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button(action: {
                    model.openFeature(.timer)
                }) {
                    Text("Open →")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.75))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(white: 0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            model.openFeature(.timer)
        }
    }
    
    // MARK: - Music Card
    private var musicCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "music.note")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                    Text("MUSIC")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .tracking(1.0)
                }
                
                Spacer()
                
                // Live 3-Bar Equalizer in Crisp White
                HStack(alignment: .bottom, spacing: 2.5) {
                    ForEach(0..<3, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.white.opacity(0.85))
                            .frame(width: 2.5, height: max(3, 12 * model.media.visualizerBars[i]))
                    }
                }
                .frame(height: 12, alignment: .bottom)
            }
            
            // Track Info
            VStack(alignment: .leading, spacing: 2) {
                Text(model.media.trackTitle)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(model.media.artistName)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.5))
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Action Buttons
            HStack(spacing: 8) {
                Button(action: {
                    model.media.togglePlay()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: model.media.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 9))
                        Text(model.media.isPlaying ? "Pause" : "Play")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button(action: {
                    model.openFeature(.music)
                }) {
                    Text("Open →")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.75))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(white: 0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            model.openFeature(.music)
        }
    }
    
    // MARK: - Notes Card
    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "note.text")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                    Text("SCRATCHPAD")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .tracking(1.0)
                }
                
                Spacer()
                
                Text(model.scratchpad.text.isEmpty ? "EMPTY" : "\(model.scratchpad.wordCount) WORDS")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.7))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(4)
            }
            
            // Preview
            VStack(alignment: .leading, spacing: 2) {
                Text(model.scratchpad.text.isEmpty ? "Click to write quick thoughts, tasks, or links..." : model.scratchpad.text)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(model.scratchpad.text.isEmpty ? Color.white.opacity(0.4) : Color.white.opacity(0.85))
                    .lineLimit(3)
            }
            
            Spacer()
            
            // Action Buttons
            HStack(spacing: 8) {
                if !model.scratchpad.text.isEmpty {
                    Button(action: {
                        model.scratchpad.copyAll()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: model.scratchpad.showCopiedAlert ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 8.5))
                            Text(model.scratchpad.showCopiedAlert ? "Copied" : "Copy")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
                
                Button(action: {
                    model.openFeature(.notes)
                }) {
                    Text("Open →")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.75))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(white: 0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            model.openFeature(.notes)
        }
    }
}
