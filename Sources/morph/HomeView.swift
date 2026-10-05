import SwiftUI

public struct HomeView: View {
    @ObservedObject var model: NotchModel
    
    public init(model: NotchModel) {
        self.model = model
    }
    
    public var body: some View {
        VStack(spacing: 8) {
            // Mascot Morphy Companion from Stitch Design
            MorphyMascotView(model: model)
                .padding(.top, 1)
            
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
            HStack(alignment: .center) {
                HStack(spacing: 4.5) {
                    Image(systemName: "timer")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(model.pomodoro.isRunning ? Color(red: 0.65, green: 0.45, blue: 1.0) : Color.white.opacity(0.85))
                    Text("FOCUS")
                        .font(.system(size: 9.5, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .tracking(0.9)
                }
                
                Spacer()
                
                // Status Pill
                Text(model.pomodoro.isRunning ? "ACTIVE" : "READY")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(model.pomodoro.isRunning ? Color(red: 0.7, green: 0.5, blue: 1.0) : Color.white.opacity(0.65))
                    .padding(.horizontal, 5.5)
                    .padding(.vertical, 2)
                    .background(
                        model.pomodoro.isRunning
                            ? Color(red: 0.65, green: 0.45, blue: 1.0).opacity(0.18)
                            : Color.white.opacity(0.08)
                    )
                    .clipShape(Capsule())
            }
            
            // Time & Mode
            VStack(alignment: .leading, spacing: 1) {
                Text(model.pomodoro.formattedTime)
                    .font(.system(size: 20, weight: .heavy, design: .monospaced))
                    .foregroundColor(.white)
                
                Text(model.pomodoro.mode.rawValue.uppercased())
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.5))
                    .tracking(0.6)
            }
            
            Spacer(minLength: 2)
            
            // Action Buttons
            HStack(spacing: 6) {
                Button(action: {
                    model.pomodoro.toggle()
                }) {
                    HStack(spacing: 3.5) {
                        Image(systemName: model.pomodoro.isRunning ? "pause.fill" : "play.fill")
                            .font(.system(size: 8))
                        Text(model.pomodoro.isRunning ? "Pause" : "Start")
                            .font(.system(size: 9.5, weight: .bold))
                    }
                    .foregroundColor(model.pomodoro.isRunning ? .white : .black)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4.5)
                    .background(
                        model.pomodoro.isRunning
                            ? Color.white.opacity(0.18)
                            : Color.white
                    )
                    .clipShape(Capsule())
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
        .padding(11)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(white: 0.055))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
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
            HStack(alignment: .center) {
                HStack(spacing: 4.5) {
                    Image(systemName: "music.note")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(model.media.isPlaying ? Color(red: 0.35, green: 0.85, blue: 1.0) : Color.white.opacity(0.85))
                    Text("MUSIC")
                        .font(.system(size: 9.5, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .tracking(0.9)
                }
                
                Spacer()
                
                // Live 3-Bar Equalizer
                HStack(alignment: .bottom, spacing: 2) {
                    ForEach(0..<3, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(
                                model.media.isPlaying
                                    ? Color(red: 0.35, green: 0.85, blue: 1.0)
                                    : Color.white.opacity(0.4)
                            )
                            .frame(width: 2, height: max(3, 10 * model.media.visualizerBars[i]))
                            .animation(.easeOut(duration: 0.1), value: model.media.visualizerBars[i])
                    }
                }
                .frame(height: 10, alignment: .bottom)
            }
            
            // Track Info
            HStack(spacing: 8) {
                if let art = model.media.albumArtURL, let url = URL(string: art) {
                    AsyncImage(url: url) { phase in
                        if let img = phase.image {
                            img.resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 28, height: 28)
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        } else {
                            defaultAlbumArtPlaceholder
                        }
                    }
                } else {
                    defaultAlbumArtPlaceholder
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(model.media.trackTitle.isEmpty ? "YouTube Music" : model.media.trackTitle)
                        .font(.system(size: 12.5, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(model.media.artistName.isEmpty ? "Ready to play" : model.media.artistName)
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.55))
                        .lineLimit(1)
                }
            }
            
            Spacer(minLength: 2)
            
            // Action Buttons
            HStack(spacing: 6) {
                Button(action: {
                    model.media.togglePlay()
                }) {
                    HStack(spacing: 3.5) {
                        Image(systemName: model.media.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 8))
                        Text(model.media.isPlaying ? "Pause" : "Play")
                            .font(.system(size: 9.5, weight: .bold))
                    }
                    .foregroundColor(model.media.isPlaying ? .white : .black)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4.5)
                    .background(
                        model.media.isPlaying
                            ? Color.white.opacity(0.18)
                            : Color.white
                    )
                    .clipShape(Capsule())
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
        .padding(11)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(white: 0.055))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            model.openFeature(.music)
        }
    }
    
    private var defaultAlbumArtPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(white: 0.12))
                .frame(width: 28, height: 28)
            Image(systemName: "music.note")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Color.white.opacity(0.65))
        }
    }
    
    // MARK: - Notes Card
    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            HStack(alignment: .center) {
                HStack(spacing: 4.5) {
                    Image(systemName: "note.text")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.85))
                    Text("NOTES")
                        .font(.system(size: 9.5, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .tracking(0.9)
                }
                
                Spacer()
                
                Text(model.scratchpad.text.isEmpty ? "EMPTY" : "\(model.scratchpad.wordCount)W")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.7))
                    .padding(.horizontal, 5.5)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
            }
            
            // Preview
            VStack(alignment: .leading, spacing: 1) {
                Text(model.scratchpad.text.isEmpty ? "Stash quick thoughts, links, and scratch notes..." : model.scratchpad.text)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(model.scratchpad.text.isEmpty ? Color.white.opacity(0.4) : Color.white.opacity(0.88))
                    .lineLimit(2)
            }
            
            Spacer(minLength: 2)
            
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
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4.5)
                        .background(Color.white.opacity(0.18))
                        .clipShape(Capsule())
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
        .padding(11)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(white: 0.055))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            model.openFeature(.notes)
        }
    }
}
