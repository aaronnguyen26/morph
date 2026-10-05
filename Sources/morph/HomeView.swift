import SwiftUI

public struct HomeView: View {
    @ObservedObject var model: NotchModel
    
    public init(model: NotchModel) {
        self.model = model
    }
    
    public var body: some View {
        VStack(spacing: 10) {
            // Mascot Morphy Companion from Stitch Design
            MorphyMascotView(model: model)
                .padding(.top, 2)
            
            // Bento 3-Feature Cards (Focus, Music, Scratchpad)
            HStack(spacing: 10) {
                focusCard
                musicCard
                notesCard
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Focus Card
    private var focusCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "timer")
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundColor(.white)
                    Text("FOCUS")
                        .font(.system(size: 9.5, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .tracking(0.8)
                }
                
                Spacer()
                
                // Status Pill
                Text(model.pomodoro.isRunning ? "ACTIVE" : "READY")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.85))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(4)
            }
            
            // Time & Mode
            VStack(alignment: .leading, spacing: 1) {
                Text(model.pomodoro.formattedTime)
                    .font(.system(size: 21, weight: .heavy, design: .monospaced))
                    .foregroundColor(.white)
                
                Text(model.pomodoro.mode.rawValue)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.5))
            }
            
            Spacer(minLength: 4)
            
            // Action Buttons
            HStack(spacing: 6) {
                Button(action: {
                    model.pomodoro.toggle()
                }) {
                    HStack(spacing: 3.5) {
                        Image(systemName: model.pomodoro.isRunning ? "pause.fill" : "play.fill")
                            .font(.system(size: 8.5))
                        Text(model.pomodoro.isRunning ? "Pause" : "Start")
                            .font(.system(size: 9.5, weight: .bold))
                    }
                    .foregroundColor(model.pomodoro.isRunning ? .white : .black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4.5)
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
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.75))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
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
        VStack(alignment: .leading, spacing: 6) {
            // Header
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "music.note")
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundColor(.white)
                    Text("MUSIC")
                        .font(.system(size: 9.5, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .tracking(0.8)
                }
                
                Spacer()
                
                // Live 3-Bar Equalizer in Crisp White
                HStack(alignment: .bottom, spacing: 2) {
                    ForEach(0..<3, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.white.opacity(0.85))
                            .frame(width: 2, height: max(3, 10 * model.media.visualizerBars[i]))
                    }
                }
                .frame(height: 10, alignment: .bottom)
            }
            
            // Track Info
            VStack(alignment: .leading, spacing: 1) {
                Text(model.media.trackTitle.isEmpty ? "YouTube Music" : model.media.trackTitle)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(model.media.artistName.isEmpty ? "Ready to play" : model.media.artistName)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.5))
                    .lineLimit(1)
            }
            
            Spacer(minLength: 4)
            
            // Action Buttons
            HStack(spacing: 6) {
                Button(action: {
                    model.media.togglePlay()
                }) {
                    HStack(spacing: 3.5) {
                        Image(systemName: model.media.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 8.5))
                        Text(model.media.isPlaying ? "Pause" : "Play")
                            .font(.system(size: 9.5, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4.5)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button(action: {
                    model.openFeature(.music)
                }) {
                    Text("Open →")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.75))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
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
        VStack(alignment: .leading, spacing: 6) {
            // Header
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "note.text")
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundColor(.white)
                    Text("NOTES")
                        .font(.system(size: 9.5, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .tracking(0.8)
                }
                
                Spacer()
                
                Text(model.scratchpad.text.isEmpty ? "EMPTY" : "\(model.scratchpad.wordCount)W")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.7))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(4)
            }
            
            // Preview
            VStack(alignment: .leading, spacing: 1) {
                Text(model.scratchpad.text.isEmpty ? "Stash quick thoughts, links, and scratch notes..." : model.scratchpad.text)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(model.scratchpad.text.isEmpty ? Color.white.opacity(0.4) : Color.white.opacity(0.85))
                    .lineLimit(2)
            }
            
            Spacer(minLength: 4)
            
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
                                .font(.system(size: 9.5, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4.5)
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
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.75))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
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
