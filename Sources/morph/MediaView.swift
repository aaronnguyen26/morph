import SwiftUI

public struct MediaView: View {
    @ObservedObject var media: MediaControllerModel
    
    public var body: some View {
        HStack(spacing: 20) {
            // Left: Album Art & Mini Transport
            VStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(white: 0.1))
                        .frame(width: 64, height: 64)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                    
                    Image(systemName: "music.note")
                        .font(.system(size: 26))
                        .foregroundColor(.white)
                }
                
                // Playback Controls
                HStack(spacing: 10) {
                    Button(action: {
                        media.previousTrack()
                    }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 11))
                            .foregroundColor(Color.white.opacity(0.75))
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        media.togglePlay()
                    }) {
                        Image(systemName: media.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.black)
                            .frame(width: 26, height: 26)
                            .background(Color.white)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        media.nextTrack()
                    }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 11))
                            .foregroundColor(Color.white.opacity(0.75))
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(width: 80)
            
            // Right: Metadata, Scrubber, Volume
            VStack(alignment: .leading, spacing: 10) {
                // Track & Source Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(media.trackTitle)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Text(media.artistName)
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.55))
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Source Tag
                    HStack(spacing: 4) {
                        Image(systemName: "play.tv.fill")
                            .font(.system(size: 9))
                        Text(media.sourceName)
                            .font(.system(size: 9.5, weight: .semibold))
                    }
                    .foregroundColor(Color.white.opacity(0.8))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3.5)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(5)
                }
                
                // Timeline Scrubber
                VStack(spacing: 4) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.15))
                                .frame(height: 5)
                            
                            Capsule()
                                .fill(Color.white)
                                .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(media.progress))), height: 5)
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
                    .frame(height: 8)
                    
                    HStack {
                        Text(media.formattedCurrentTime)
                            .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                            .foregroundColor(Color.white.opacity(0.45))
                        
                        Spacer()
                        
                        Text(media.formattedDuration)
                            .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                            .foregroundColor(Color.white.opacity(0.45))
                    }
                }
                
                // Volume Slider with Mute
                HStack(spacing: 8) {
                    Button(action: {
                        media.toggleMute()
                    }) {
                        Image(systemName: media.isMuted ? "speaker.slash.fill" : (media.volume > 0.5 ? "speaker.wave.2.fill" : "speaker.wave.1.fill"))
                            .font(.system(size: 10))
                            .foregroundColor(media.isMuted ? Color.white.opacity(0.4) : Color.white.opacity(0.75))
                    }
                    .buttonStyle(.plain)
                    
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.15))
                                .frame(height: 4)
                            
                            Capsule()
                                .fill(media.isMuted ? Color.white.opacity(0.3) : Color.white)
                                .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(media.isMuted ? 0 : media.volume))), height: 4)
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
                    .frame(height: 6)
                    
                    Text("\(Int((media.isMuted ? 0 : media.volume) * 100))%")
                        .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.45))
                        .frame(width: 30, alignment: .trailing)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
