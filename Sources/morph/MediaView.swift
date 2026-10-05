import SwiftUI

public struct MediaView: View {
    @ObservedObject var media: MediaControllerModel
    var accentColor: Color
    
    public var body: some View {
        HStack(spacing: 14) {
            // Left: Album Artwork + Playback Controls
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.2, green: 0.1, blue: 0.35),
                                    Color(red: 0.1, green: 0.05, blue: 0.18)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(accentColor.opacity(0.3), lineWidth: 1)
                        )
                    
                    Image(systemName: "music.note")
                        .font(.system(size: 20))
                        .foregroundColor(accentColor)
                }
                
                // Playback mini controls
                HStack(spacing: 8) {
                    Button(action: {
                        media.previousTrack()
                    }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Color.white.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        media.togglePlay()
                    }) {
                        Image(systemName: media.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 22, height: 22)
                            .background(accentColor.opacity(0.3))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        media.nextTrack()
                    }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Color.white.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(width: 70)
            
            // Right: Track Metadata, Scrubber, Volume Slider
            VStack(alignment: .leading, spacing: 6) {
                // Title & Source Tag
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(media.trackTitle)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Text(media.artistName)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.55))
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Source Badge
                    HStack(spacing: 3) {
                        Image(systemName: "play.tv.fill")
                            .font(.system(size: 8))
                        Text(media.sourceName)
                            .font(.system(size: 8.5, weight: .semibold))
                    }
                    .foregroundColor(accentColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(accentColor.opacity(0.12))
                    .cornerRadius(4)
                }
                
                // Timeline Scrubber
                VStack(spacing: 2) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            // Track background
                            Capsule()
                                .fill(Color.white.opacity(0.15))
                                .frame(height: 4)
                            
                            // Elapsed progress
                            Capsule()
                                .fill(accentColor)
                                .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(media.progress))), height: 4)
                        }
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let fraction = Double(value.location.x / geo.size.width)
                                    media.seek(to: fraction)
                                }
                        )
                    }
                    .frame(height: 6)
                    
                    HStack {
                        Text(media.formattedCurrentTime)
                            .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                            .foregroundColor(Color.white.opacity(0.4))
                        
                        Spacer()
                        
                        Text(media.formattedDuration)
                            .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                            .foregroundColor(Color.white.opacity(0.4))
                    }
                }
                
                // Volume Slider with Mute Toggle
                HStack(spacing: 6) {
                    Button(action: {
                        media.toggleMute()
                    }) {
                        Image(systemName: media.isMuted ? "speaker.slash.fill" : (media.volume > 0.5 ? "speaker.wave.2.fill" : "speaker.wave.1.fill"))
                            .font(.system(size: 9))
                            .foregroundColor(media.isMuted ? .red : Color.white.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.15))
                                .frame(height: 3)
                            
                            Capsule()
                                .fill(media.isMuted ? Color.gray : accentColor.opacity(0.8))
                                .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(media.isMuted ? 0 : media.volume))), height: 3)
                        }
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let fraction = Double(value.location.x / geo.size.width)
                                    media.setVolume(fraction)
                                }
                        )
                    }
                    .frame(height: 4)
                    
                    Text("\(Int((media.isMuted ? 0 : media.volume) * 100))%")
                        .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.4))
                        .frame(width: 26, alignment: .trailing)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 2)
    }
}
