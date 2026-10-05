import SwiftUI

public struct MediaView: View {
    @ObservedObject var media: MediaControllerModel
    
    @State private var isScrubbing: Bool = false
    @State private var scrubFraction: Double = 0.0
    @State private var isSearching: Bool = false
    @State private var searchQuery: String = ""
    @State private var isShowingPlaylist: Bool = false
    
    public init(media: MediaControllerModel) {
        self.media = media
    }
    
    private var effectiveProgress: Double {
        isScrubbing ? scrubFraction : media.progress
    }
    
    private var effectiveCurrentTime: String {
        isScrubbing ? media.formatTime(scrubFraction * media.duration) : media.formattedCurrentTime
    }
    
    public var body: some View {
        HStack(spacing: 16) {
            // MARK: - Left Deck: Album Art & Transport Suite
            VStack(spacing: 8) {
                // Album Art (Real thumbnail or dark glass fallback)
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(white: 0.12))
                        .frame(width: 76, height: 76)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.55), radius: 6, x: 0, y: 3)
                    
                    if let artURL = media.albumArtURL, let url = URL(string: artURL) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 76, height: 76)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            default:
                                defaultArtPlaceholder
                            }
                        }
                    } else {
                        defaultArtPlaceholder
                    }
                }
                
                // Transport Controls: Shuffle, Previous, Play/Pause, Next, Repeat
                HStack(spacing: 6) {
                    // Shuffle
                    Button(action: {
                        media.toggleShuffle()
                    }) {
                        Image(systemName: "shuffle")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundColor(media.isShuffle ? Color.white : Color.white.opacity(0.35))
                            .frame(width: 22, height: 22)
                            .background(media.isShuffle ? Color.white.opacity(0.2) : Color.white.opacity(0.06))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help(media.isShuffle ? "Shuffle On" : "Shuffle Off")
                    
                    // Previous Track
                    Button(action: {
                        media.previousTrack()
                    }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Color.white.opacity(0.85))
                            .frame(width: 22, height: 22)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Previous Track (⌘[ or ⌘←)")
                    
                    // Primary Play / Pause Button
                    Button(action: {
                        media.togglePlay()
                    }) {
                        Image(systemName: media.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.black)
                            .frame(width: 30, height: 30)
                            .background(Color.white)
                            .clipShape(Circle())
                            .shadow(color: Color.white.opacity(0.25), radius: 4, x: 0, y: 1)
                    }
                    .buttonStyle(.plain)
                    .help(media.isPlaying ? "Pause Music (⌘⏎)" : "Play Music (⌘⏎)")
                    
                    // Next Track
                    Button(action: {
                        media.nextTrack()
                    }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Color.white.opacity(0.85))
                            .frame(width: 22, height: 22)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Next Track (⌘] or ⌘→)")
                    
                    // Repeat (Cycles Off -> All -> One)
                    Button(action: {
                        media.toggleRepeat()
                    }) {
                        Image(systemName: media.repeatMode.iconName)
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundColor(media.repeatMode != .off ? Color.white : Color.white.opacity(0.35))
                            .frame(width: 22, height: 22)
                            .background(media.repeatMode != .off ? Color.white.opacity(0.2) : Color.white.opacity(0.06))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help(media.repeatMode.displayTitle)
                }
            }
            .frame(width: 148)
            
            // MARK: - Right Deck: Metadata / Playlist, Actions, Scrubber & Volume
            VStack(alignment: .leading, spacing: 9) {
                // Header Row: Track Metadata OR Quick Search + Action Suite
                HStack(alignment: .center, spacing: 8) {
                    if isSearching {
                        HStack(spacing: 5) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 10))
                                .foregroundColor(Color.white.opacity(0.6))
                            TextField("Search song or artist on YouTube Music...", text: $searchQuery)
                                .textFieldStyle(.plain)
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(.white)
                                .onSubmit {
                                    if !searchQuery.isEmpty {
                                        media.playSearch(searchQuery)
                                        isSearching = false
                                    }
                                }
                            Button(action: {
                                isSearching = false
                                searchQuery = ""
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(Color.white.opacity(0.5))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Capsule())
                    } else {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(media.trackTitle)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            
                            Text(media.artistName)
                                .font(.system(size: 10.5, weight: .medium))
                                .foregroundColor(Color.white.opacity(0.6))
                                .lineLimit(1)
                        }
                    }
                    
                    Spacer()
                    
                    // Playlist Queue Button
                    Button(action: {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                            isShowingPlaylist.toggle()
                        }
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "music.note.list")
                                .font(.system(size: 10))
                            if !media.playlist.isEmpty {
                                Text("\(media.playlist.count)")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                            }
                        }
                        .foregroundColor(isShowingPlaylist ? .black : Color.white.opacity(0.85))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(isShowingPlaylist ? Color.white : Color.white.opacity(0.12))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help(isShowingPlaylist ? "Hide Playlist Queue" : "View Playlist / Up Next Queue")
                    
                    // Search Button
                    Button(action: {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            isSearching.toggle()
                        }
                    }) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 10.5))
                            .foregroundColor(isSearching ? .white : Color.white.opacity(0.65))
                            .frame(width: 24, height: 24)
                            .background(isSearching ? Color.white.opacity(0.2) : Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Search YouTube Music")
                    
                    // Thumbs Up / Like
                    Button(action: {
                        media.toggleLike()
                    }) {
                        Image(systemName: media.isLiked ? "hand.thumbsup.fill" : "hand.thumbsup")
                            .font(.system(size: 10.5))
                            .foregroundColor(media.isLiked ? Color.white : Color.white.opacity(0.55))
                            .frame(width: 24, height: 24)
                            .background(media.isLiked ? Color.white.opacity(0.2) : Color.white.opacity(0.07))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help(media.isLiked ? "Liked (Click to unlike)" : "Like Track (⌘L)")
                    
                    // Thumbs Down / Dislike
                    Button(action: {
                        media.toggleDislike()
                    }) {
                        Image(systemName: media.isDisliked ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                            .font(.system(size: 10.5))
                            .foregroundColor(media.isDisliked ? Color.white : Color.white.opacity(0.55))
                            .frame(width: 24, height: 24)
                            .background(media.isDisliked ? Color.white.opacity(0.2) : Color.white.opacity(0.07))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help(media.isDisliked ? "Disliked (Click to undislike)" : "Dislike Track")
                    
                    // Dedicated Stop Button
                    Button(action: {
                        media.stop()
                    }) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundColor(Color.white.opacity(0.75))
                            .frame(width: 24, height: 24)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Stop Playback & Reset Position")
                    
                    // Web Player / Sign In Window Launcher
                    Button(action: {
                        media.openPlayerWindow()
                    }) {
                        HStack(spacing: 3.5) {
                            Image(systemName: "arrow.up.right.square")
                                .font(.system(size: 8.5))
                            Text("Web View")
                                .font(.system(size: 9, weight: .semibold))
                        }
                        .foregroundColor(Color.white.opacity(0.9))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("Open YouTube Music Window to Browse or Sign In")
                }
                
                if isShowingPlaylist {
                    // Inline Up Next / Playlist Queue Drawer
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text("UP NEXT")
                                .font(.system(size: 8, weight: .heavy, design: .rounded))
                                .foregroundColor(Color.white.opacity(0.45))
                            Spacer()
                            Text("\(media.playlist.count) tracks in queue")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundColor(Color.white.opacity(0.35))
                        }
                        
                        if media.playlist.isEmpty {
                            HStack {
                                Spacer()
                                Text("No upcoming queue loaded yet. Start a playlist or song in Web View.")
                                    .font(.system(size: 9.5, weight: .medium))
                                    .foregroundColor(Color.white.opacity(0.5))
                                Spacer()
                            }
                            .frame(height: 48)
                        } else {
                            ScrollView(.vertical, showsIndicators: false) {
                                VStack(spacing: 3) {
                                    ForEach(media.playlist) { item in
                                        Button(action: {
                                            media.playQueueTrack(item)
                                        }) {
                                            HStack(spacing: 6) {
                                                if item.isPlaying {
                                                    Image(systemName: "speaker.wave.2.fill")
                                                        .font(.system(size: 8))
                                                        .foregroundColor(Color.white)
                                                } else {
                                                    Image(systemName: "play.circle")
                                                        .font(.system(size: 8.5))
                                                        .foregroundColor(Color.white.opacity(0.4))
                                                }
                                                
                                                Text(item.title)
                                                    .font(.system(size: 9.5, weight: item.isPlaying ? .bold : .medium))
                                                    .foregroundColor(item.isPlaying ? .white : Color.white.opacity(0.85))
                                                    .lineLimit(1)
                                                
                                                if !item.artist.isEmpty {
                                                    Text("• \(item.artist)")
                                                        .font(.system(size: 8.5, weight: .regular))
                                                        .foregroundColor(Color.white.opacity(0.45))
                                                        .lineLimit(1)
                                                }
                                                
                                                Spacer()
                                                
                                                if !item.duration.isEmpty {
                                                    Text(item.duration)
                                                        .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                                                        .foregroundColor(Color.white.opacity(0.4))
                                                }
                                            }
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 3.5)
                                            .background(item.isPlaying ? Color.white.opacity(0.12) : Color.white.opacity(0.04))
                                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .frame(maxHeight: 62)
                        }
                    }
                    .padding(6)
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                } else {
                    // Timeline Scrubber
                    VStack(spacing: 4) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.15))
                                    .frame(height: 5)
                                
                                Capsule()
                                    .fill(Color.white)
                                    .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(effectiveProgress))), height: 5)
                            }
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        isScrubbing = true
                                        let fraction = max(0, min(1, Double(value.location.x / geo.size.width)))
                                        scrubFraction = fraction
                                    }
                                    .onEnded { value in
                                        let fraction = max(0, min(1, Double(value.location.x / geo.size.width)))
                                        media.seek(to: fraction)
                                        isScrubbing = false
                                    }
                            )
                        }
                        .frame(height: 8)
                        
                        HStack {
                            Text(effectiveCurrentTime)
                                .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                                .foregroundColor(Color.white.opacity(0.5))
                            
                            Spacer()
                            
                            // Live 3-bar mini visualizer
                            HStack(alignment: .bottom, spacing: 2.5) {
                                ForEach(0..<3, id: \.self) { i in
                                    RoundedRectangle(cornerRadius: 1)
                                        .fill(Color.white.opacity(0.8))
                                        .frame(width: 2.5, height: max(2.5, 10 * media.visualizerBars[i]))
                                }
                            }
                            .frame(height: 10, alignment: .bottom)
                            
                            Spacer()
                            
                            Text(media.formattedDuration)
                                .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                                .foregroundColor(Color.white.opacity(0.5))
                        }
                    }
                }
                
                // Bottom Row: Purposeful Volume Slider with Mute & Clean Status
                HStack(spacing: 8) {
                    // Mute / Volume Icon
                    Button(action: {
                        media.toggleMute()
                    }) {
                        Image(systemName: media.isMuted ? "speaker.slash.fill" : (media.volume > 0.5 ? "speaker.wave.2.fill" : "speaker.wave.1.fill"))
                            .font(.system(size: 10.5))
                            .foregroundColor(media.isMuted ? Color.white.opacity(0.4) : Color.white.opacity(0.85))
                            .frame(width: 18, height: 18)
                    }
                    .buttonStyle(.plain)
                    .help(media.isMuted ? "Unmute" : "Mute (⌘U)")
                    
                    // Volume Drag Bar
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
                                    let fraction = max(0, min(1, Double(value.location.x / geo.size.width)))
                                    media.setVolume(fraction)
                                }
                        )
                    }
                    .frame(width: 80, height: 6)
                    
                    // Volume Percentage
                    Text("\(Int((media.isMuted ? 0 : media.volume) * 100))%")
                        .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.45))
                    
                    Spacer()
                    
                    // Status Badge
                    HStack(spacing: 3.5) {
                        Circle()
                            .fill(media.isDirectEngineActive ? Color.green : (media.isBrowserConnected ? Color.blue : Color.orange))
                            .frame(width: 5, height: 5)
                        Text(media.isDirectEngineActive ? "Direct" : (media.isBrowserConnected ? "Browser" : "Ready"))
                            .font(.system(size: 8.5, weight: .semibold))
                            .foregroundColor(Color.white.opacity(0.65))
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Capsule())
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var defaultArtPlaceholder: some View {
        VStack(spacing: 4) {
            Image(systemName: "music.note")
                .font(.system(size: 26))
                .foregroundColor(Color.white.opacity(0.85))
        }
    }
}

