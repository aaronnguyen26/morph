import SwiftUI

public struct MediaView: View {
    @ObservedObject var media: MediaControllerModel
    
    public init(media: MediaControllerModel) {
        self.media = media
    }
    
    public var body: some View {
        HStack(spacing: 16) {
            // Left: Album Art & Mini Transport
            VStack(spacing: 8) {
                // Album Art (Real thumbnail or dark glass fallback)
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(white: 0.1))
                        .frame(width: 68, height: 68)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.white.opacity(0.14), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.5), radius: 6, x: 0, y: 3)
                    
                    if let artURL = media.albumArtURL, let url = URL(string: artURL) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 68, height: 68)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            default:
                                defaultArtPlaceholder
                            }
                        }
                    } else {
                        defaultArtPlaceholder
                    }
                }
                
                // Playback Controls (Prev, Play/Pause, Next)
                HStack(spacing: 8) {
                    Button(action: {
                        media.previousTrack()
                    }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 11))
                            .foregroundColor(Color.white.opacity(0.75))
                            .frame(width: 22, height: 22)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        media.togglePlay()
                    }) {
                        Image(systemName: media.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.black)
                            .frame(width: 28, height: 28)
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
                            .frame(width: 22, height: 22)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(width: 84)
            
            // Right: Metadata, Live Equalizer, Scrubber, Volume & Web View Trigger
            VStack(alignment: .leading, spacing: 8) {
                // Track & Source Header
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 1.5) {
                        Text(media.trackTitle)
                            .font(.system(size: 14.5, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Text(media.artistName)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.55))
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Like Button
                    Button(action: {
                        media.toggleLike()
                    }) {
                        Image(systemName: media.isLiked ? "heart.fill" : "heart")
                            .font(.system(size: 11))
                            .foregroundColor(media.isLiked ? Color.white : Color.white.opacity(0.4))
                            .frame(width: 24, height: 24)
                            .background(Color.white.opacity(0.06))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Like Track on YouTube Music")
                    
                    // Web Player / Sign In Window Trigger
                    Button(action: {
                        media.openPlayerWindow()
                    }) {
                        HStack(spacing: 3.5) {
                            Image(systemName: "arrow.up.right.square")
                                .font(.system(size: 9))
                            Text("Web View")
                                .font(.system(size: 9.5, weight: .semibold))
                        }
                        .foregroundColor(Color.white.opacity(0.85))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3.5)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("Open YouTube Music to Sign In or Browse Playlists")
                }
                
                // Timeline Scrubber
                VStack(spacing: 3.5) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.14))
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
                    .frame(height: 7)
                    
                    HStack {
                        Text(media.formattedCurrentTime)
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(Color.white.opacity(0.45))
                        
                        Spacer()
                        
                        // Live 3-bar mini visualizer
                        HStack(alignment: .bottom, spacing: 2) {
                            ForEach(0..<3, id: \.self) { i in
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(Color.white.opacity(0.75))
                                    .frame(width: 2, height: max(2.5, 9 * media.visualizerBars[i]))
                            }
                        }
                        .frame(height: 9, alignment: .bottom)
                        
                        Spacer()
                        
                        Text(media.formattedDuration)
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
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
                                .fill(Color.white.opacity(0.14))
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
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.45))
                        .frame(width: 28, alignment: .trailing)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var defaultArtPlaceholder: some View {
        VStack(spacing: 4) {
            Image(systemName: "music.note")
                .font(.system(size: 24))
                .foregroundColor(Color.white.opacity(0.85))
        }
    }
}
