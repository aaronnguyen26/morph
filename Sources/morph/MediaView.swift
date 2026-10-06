import SwiftUI

public struct MediaView: View {
    @ObservedObject var media: MediaControllerModel
    
    @State private var isScrubbing: Bool = false
    @State private var scrubFraction: Double = 0.0
    @State private var isSearching: Bool = false
    @State private var searchQuery: String = ""
    
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
        HStack(spacing: 12) {
            nowPlayingDeck
                .frame(width: 272)
            
            playlistBrowserDeck
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Left Deck (Now Playing Engine)
    private var nowPlayingDeck: some View {
        VStack(alignment: .leading, spacing: 7) {
            albumArtAndMetadataRow
            
            if isSearching {
                songSearchBar
            }
            
            timelineScrubberRow
            transportControlsRow
            volumeControlRow
        }
    }
    
    // Song Search Bar
    private var songSearchBar: some View {
        HStack(spacing: 5) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 8.5))
                .foregroundColor(Color.white.opacity(0.6))
            
            TextField("Search song or artist...", text: $searchQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 9.5, weight: .medium, design: .rounded))
                .foregroundColor(.white)
                .onSubmit {
                    let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        media.playSearch(trimmed)
                    }
                }
            
            if !searchQuery.isEmpty {
                Button(action: {
                    searchQuery = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 8.5))
                        .foregroundColor(Color.white.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
            
            Button(action: {
                let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    media.playSearch(trimmed)
                }
            }) {
                Text("Search")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.white)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3.5)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
        )
    }
    
    // 1. Album Art & Metadata
    private var albumArtAndMetadataRow: some View {
        HStack(spacing: 10) {
            albumArtSquircle
            
            VStack(alignment: .leading, spacing: 3) {
                Text(media.trackTitle)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(media.artistName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.6))
                    .lineLimit(1)
                
                trackActionPills
                    .padding(.top, 1)
            }
        }
    }
    
    private var albumArtSquircle: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(white: 0.12))
                .frame(width: 56, height: 56)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.55), radius: 5, x: 0, y: 2)
            
            if let artURL = media.albumArtURL, let url = URL(string: artURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    default:
                        defaultArtPlaceholder
                    }
                }
            } else {
                defaultArtPlaceholder
            }
        }
    }
    
    private var trackActionPills: some View {
        HStack(spacing: 5) {
            Button(action: {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    isSearching.toggle()
                }
            }) {
                Image(systemName: isSearching ? "xmark.circle.fill" : "magnifyingglass")
                    .font(.system(size: 9))
                    .foregroundColor(isSearching ? Color.white : Color.white.opacity(0.7))
                    .frame(width: 20, height: 20)
                    .background(isSearching ? Color.white.opacity(0.25) : Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help(isSearching ? "Close Search" : "Search YouTube Music Songs")
            
            Button(action: {
                media.toggleLike()
            }) {
                Image(systemName: media.isLiked ? "hand.thumbsup.fill" : "hand.thumbsup")
                    .font(.system(size: 9.5))
                    .foregroundColor(media.isLiked ? Color.white : Color.white.opacity(0.55))
                    .frame(width: 20, height: 20)
                    .background(media.isLiked ? Color.white.opacity(0.2) : Color.white.opacity(0.07))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help(media.isLiked ? "Liked (Click to unlike)" : "Like Track (⌘L)")
            
            Button(action: {
                media.toggleDislike()
            }) {
                Image(systemName: media.isDisliked ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                    .font(.system(size: 9.5))
                    .foregroundColor(media.isDisliked ? Color.white : Color.white.opacity(0.55))
                    .frame(width: 20, height: 20)
                    .background(media.isDisliked ? Color.white.opacity(0.2) : Color.white.opacity(0.07))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help(media.isDisliked ? "Disliked" : "Dislike Track")
            
            Button(action: {
                media.openPlayerWindow()
            }) {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 8))
                    Text("Web View")
                        .font(.system(size: 8.5, weight: .medium))
                }
                .foregroundColor(Color.white.opacity(0.85))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.08))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .help("Open YouTube Music Web Window")
        }
    }
    
    // 2. Timeline Scrubber
    private var timelineScrubberRow: some View {
        VStack(spacing: 3) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.14))
                        .frame(height: 4)
                    
                    Capsule()
                        .fill(Color.white)
                        .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(effectiveProgress))), height: 4)
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
            .frame(height: 6)
            
            HStack {
                Text(effectiveCurrentTime)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.5))
                
                Spacer()
                
                // Live 3-bar mini visualizer
                HStack(alignment: .bottom, spacing: 2) {
                    ForEach(0..<3, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.white.opacity(0.8))
                            .frame(width: 2.2, height: max(2.5, 9 * media.visualizerBars[i]))
                    }
                }
                .frame(height: 9, alignment: .bottom)
                
                Spacer()
                
                Text(media.formattedDuration)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.5))
            }
        }
    }
    
    // 3. Transport Controls
    private var transportControlsRow: some View {
        HStack(spacing: 8) {
            Button(action: {
                media.toggleShuffle()
            }) {
                Image(systemName: "shuffle")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(media.isShuffle ? Color.white : Color.white.opacity(0.35))
                    .frame(width: 22, height: 22)
                    .background(media.isShuffle ? Color.white.opacity(0.2) : Color.white.opacity(0.06))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help(media.isShuffle ? "Shuffle On" : "Shuffle Off")
            
            Button(action: {
                media.previousTrack()
            }) {
                Image(systemName: "backward.fill")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.85))
                    .frame(width: 24, height: 24)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Previous Track (⌘[ or ⌘←)")
            
            Button(action: {
                media.togglePlay()
            }) {
                Image(systemName: media.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.black)
                    .frame(width: 30, height: 30)
                    .background(Color.white)
                    .clipShape(Circle())
                    .shadow(color: Color.white.opacity(0.25), radius: 4, x: 0, y: 1)
            }
            .buttonStyle(.plain)
            .help(media.isPlaying ? "Pause Music (⌘⏎)" : "Play Music (⌘⏎)")
            
            Button(action: {
                media.nextTrack()
            }) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.85))
                    .frame(width: 24, height: 24)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Next Track (⌘] or ⌘→)")
            
            Button(action: {
                media.toggleRepeat()
            }) {
                Image(systemName: media.repeatMode.iconName)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(media.repeatMode != .off ? Color.white : Color.white.opacity(0.35))
                    .frame(width: 22, height: 22)
                    .background(media.repeatMode != .off ? Color.white.opacity(0.2) : Color.white.opacity(0.06))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help(media.repeatMode.displayTitle)
            
            Button(action: {
                media.stop()
            }) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.65))
                    .frame(width: 22, height: 22)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Stop Playback")
        }
    }
    
    // 4. Volume Control Row (Clean & Monochromatic)
    private var volumeControlRow: some View {
        HStack(spacing: 8) {
            Button(action: {
                media.toggleMute()
            }) {
                Image(systemName: media.isMuted ? "speaker.slash.fill" : (media.volume > 0.5 ? "speaker.wave.2.fill" : "speaker.wave.1.fill"))
                    .font(.system(size: 10))
                    .foregroundColor(media.isMuted ? Color.white.opacity(0.4) : Color.white.opacity(0.85))
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
            .help(media.isMuted ? "Unmute (⌘U)" : "Mute (⌘U)")
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.14))
                        .frame(height: 3.5)
                    
                    Capsule()
                        .fill(media.isMuted ? Color.white.opacity(0.3) : Color.white)
                        .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(media.isMuted ? 0 : media.volume))), height: 3.5)
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
            .frame(height: 6)
            
            Text("\(Int((media.isMuted ? 0 : media.volume) * 100))%")
                .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.45))
        }
    }
    
    // MARK: - Right Deck: Two-Step Playlist & Song Picker (328 pt)
    private var playlistBrowserDeck: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let currentPlaylist = media.selectedPlaylist {
                // STEP 2: SONGS IN CHOSEN PLAYLIST
                playlistDetailDeck(playlist: currentPlaylist)
            } else {
                // STEP 1: CHOOSE A PLAYLIST
                playlistsSelectionDeck
            }
        }
        .padding(9)
        .background(Color(white: 0.07))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
    
    // MARK: - Step 1: Choose a Playlist
    private var playlistsSelectionDeck: some View {
        VStack(alignment: .leading, spacing: 6) {
            playlistsHeaderRow
            
            if media.isSearchingPlaylists {
                playlistsSearchBar
            }
            
            if media.isLoadingPlaylists {
                VStack(spacing: 8) {
                    Spacer(minLength: 12)
                    ProgressView()
                        .scaleEffect(0.7)
                        .colorScheme(.dark)
                    Text("Syncing your YouTube Music playlists...")
                        .font(.system(size: 8.5, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.6))
                    Spacer(minLength: 12)
                }
                .frame(maxWidth: .infinity, maxHeight: media.isSearchingPlaylists ? 116 : 138)
            } else if media.playlists.isEmpty {
                VStack(spacing: 6) {
                    Spacer(minLength: 10)
                    Image(systemName: "music.note.list")
                        .font(.system(size: 16))
                        .foregroundColor(Color.white.opacity(0.35))
                    Text(media.isSignedIn ? "No Custom Playlists Found" : "No YouTube Music Playlists Found")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.85))
                    Text(media.isSignedIn
                         ? "You are signed in! Create playlists on YouTube Music or click Sync to refresh."
                         : "Sign in once to YouTube Music to access all your playlists and music.")
                        .font(.system(size: 8, weight: .regular))
                        .foregroundColor(Color.white.opacity(0.45))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                    
                    HStack(spacing: 6) {
                        if !media.isSignedIn {
                            Button(action: {
                                media.openPlayerWindow()
                            }) {
                                HStack(spacing: 3) {
                                    Image(systemName: "person.crop.circle.badge.plus")
                                        .font(.system(size: 8.5))
                                    Text("Sign In")
                                        .font(.system(size: 8.5, weight: .bold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3.5)
                                .background(Color.white.opacity(0.14))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                        
                        Button(action: {
                            media.refreshPlaylists()
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 8))
                                Text("Sync Library")
                                    .font(.system(size: 8.5, weight: .medium))
                            }
                            .foregroundColor(media.isSignedIn ? .white : Color.white.opacity(0.8))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3.5)
                            .background(media.isSignedIn ? Color.white.opacity(0.16) : Color.white.opacity(0.08))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 2)
                    
                    Spacer(minLength: 8)
                }
                .frame(maxWidth: .infinity, maxHeight: media.isSearchingPlaylists ? 116 : 138)
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(spacing: 4) {
                        // Quick Entry: Now Playing Live Queue (only if queue has real items)
                        if !media.effectivePlaylist.isEmpty {
                            nowPlayingQueueCardRow
                        }
                        
                        // List of Real Available Playlists
                        ForEach(media.filteredPlaylists) { playlist in
                            playlistCardRow(playlist: playlist)
                        }
                    }
                    .padding(.trailing, 2)
                }
                .frame(maxHeight: media.isSearchingPlaylists ? 116 : 138)
            }
        }
    }
    
    private var playlistsHeaderRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "square.stack.fill")
                .font(.system(size: 9.5, weight: .bold))
                .foregroundColor(.white)
            
            Text("CHOOSE PLAYLIST")
                .font(.system(size: 9, weight: .heavy, design: .rounded))
                .foregroundColor(Color.white.opacity(0.85))
                .tracking(0.5)
            
            Text("\(media.filteredPlaylists.count) playlists")
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.5))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.08))
                .clipShape(Capsule())
            
            Spacer()
            
            // Refresh Button
            Button(action: {
                media.refreshPlaylists()
            }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 8.5))
                    .foregroundColor(Color.white.opacity(0.6))
                    .frame(width: 18, height: 18)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Refresh Playlists from YouTube Music")
            
            // Search Toggle Button
            Button(action: {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    media.isSearchingPlaylists.toggle()
                    if !media.isSearchingPlaylists {
                        media.playlistSearchQuery = ""
                    }
                }
            }) {
                Image(systemName: media.isSearchingPlaylists ? "xmark.circle.fill" : "magnifyingglass")
                    .font(.system(size: 9))
                    .foregroundColor(media.isSearchingPlaylists ? .white : Color.white.opacity(0.6))
                    .frame(width: 18, height: 18)
                    .background(media.isSearchingPlaylists ? Color.white.opacity(0.18) : Color.white.opacity(0.06))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help(media.isSearchingPlaylists ? "Close Search" : "Search Playlists")
        }
    }
    
    private var playlistsSearchBar: some View {
        HStack(spacing: 5) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 8.5))
                .foregroundColor(Color.white.opacity(0.5))
            
            TextField("Search playlists...", text: $media.playlistSearchQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 9.5, weight: .medium, design: .rounded))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3.5)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
    
    private var nowPlayingQueueCardRow: some View {
        Button(action: {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                media.selectPlaylist(media.nowPlayingQueuePlaylist)
            }
        }) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 26, height: 26)
                    Image(systemName: "waveform")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    Text("Now Playing Queue")
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text("\(media.effectivePlaylist.count) tracks in live queue")
                        .font(.system(size: 8, weight: .regular))
                        .foregroundColor(Color.white.opacity(0.5))
                        .lineLimit(1)
                }
                
                Spacer(minLength: 4)
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.35))
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .help("Open Live Queue")
    }
    
    private func playlistCardRow(playlist: YTMPlaylist) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                media.selectPlaylist(playlist)
            }
        }) {
            HStack(spacing: 8) {
                // Playlist Icon / Artwork Badge
                playlistIconBadge(for: playlist)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(playlist.title)
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(playlist.subtitle.isEmpty ? "\(playlist.tracks.count) tracks" : playlist.subtitle)
                        .font(.system(size: 8, weight: .regular))
                        .foregroundColor(Color.white.opacity(0.45))
                        .lineLimit(1)
                }
                
                Spacer(minLength: 4)
                
                HStack(spacing: 4) {
                    Text("\(playlist.tracks.count)")
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.4))
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.35))
                }
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .help("Open \(playlist.title)")
    }
    
    private func playlistIconBadge(for playlist: YTMPlaylist) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .frame(width: 26, height: 26)
            
            if let thumb = playlist.thumbnailURL, let url = URL(string: thumb) {
                AsyncImage(url: url) { phase in
                    if case .success(let img) = phase {
                        img
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 26, height: 26)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    } else {
                        playlistFallbackIcon(for: playlist)
                    }
                }
            } else {
                playlistFallbackIcon(for: playlist)
            }
        }
    }
    
    private func playlistFallbackIcon(for playlist: YTMPlaylist) -> some View {
        let isLiked = playlist.id == "pl_liked" || playlist.title.lowercased().contains("liked")
        let isMix = playlist.id == "pl_supermix" || playlist.title.lowercased().contains("mix")
        let iconName = isLiked ? "heart.fill" : (isMix ? "sparkles" : "music.note.list")
        return Image(systemName: iconName)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(isLiked ? Color.white : Color.white.opacity(0.8))
    }
    
    // MARK: - Step 2: Songs in Chosen Playlist
    private func playlistDetailDeck(playlist: YTMPlaylist) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            playlistDetailHeaderRow(playlist: playlist)
            
            if media.isSearchingSongs {
                songsSearchBar
            }
            
            ScrollView(.vertical, showsIndicators: true) {
                let songs = media.filteredSongs(for: playlist)
                if songs.isEmpty {
                    VStack(spacing: 4) {
                        Spacer(minLength: 12)
                        Image(systemName: "music.note")
                            .font(.system(size: 14))
                            .foregroundColor(Color.white.opacity(0.3))
                        Text("No songs found in this playlist")
                            .font(.system(size: 8.5, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.45))
                        Spacer(minLength: 12)
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    LazyVStack(spacing: 3) {
                        ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                            songItemRow(index: index, song: song)
                        }
                    }
                    .padding(.trailing, 2)
                }
            }
            .frame(maxHeight: media.isSearchingSongs ? 116 : 138)
        }
    }
    
    private func playlistDetailHeaderRow(playlist: YTMPlaylist) -> some View {
        HStack(spacing: 5) {
            // Back to Playlists Button
            Button(action: {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                    media.backToPlaylists()
                }
            }) {
                HStack(spacing: 2) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 8, weight: .bold))
                    Text("Playlists")
                        .font(.system(size: 8.5, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2.5)
                .background(Color.white.opacity(0.12))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .help("Back to Playlist Selection")
            
            Text(playlist.title)
                .font(.system(size: 9, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
            
            Spacer()
            
            // Play All Button
            Button(action: {
                media.playEntireSelectedPlaylist()
            }) {
                HStack(spacing: 3) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 7.5))
                    Text("Play")
                        .font(.system(size: 8, weight: .bold))
                }
                .foregroundColor(.black)
                .padding(.horizontal, 6)
                .padding(.vertical, 2.5)
                .background(Color.white)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .help("Play All in Playlist")
            
            // Search button for songs
            Button(action: {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    media.isSearchingSongs.toggle()
                    if !media.isSearchingSongs {
                        media.songSearchQuery = ""
                    }
                }
            }) {
                Image(systemName: media.isSearchingSongs ? "xmark.circle.fill" : "magnifyingglass")
                    .font(.system(size: 9))
                    .foregroundColor(media.isSearchingSongs ? .white : Color.white.opacity(0.6))
                    .frame(width: 18, height: 18)
                    .background(media.isSearchingSongs ? Color.white.opacity(0.18) : Color.white.opacity(0.06))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help(media.isSearchingSongs ? "Close Search" : "Search Songs in Playlist")
        }
    }
    
    private var songsSearchBar: some View {
        HStack(spacing: 5) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 8.5))
                .foregroundColor(Color.white.opacity(0.5))
            
            TextField("Search songs in playlist...", text: $media.songSearchQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 9.5, weight: .medium, design: .rounded))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3.5)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
    
    private func songItemRow(index: Int, song: YTMPlaylistItem) -> some View {
        let isCurrentSong = song.isPlaying || (song.title == media.trackTitle && media.isPlaying)
        return Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                media.playSongInSelectedPlaylist(song)
            }
        }) {
            HStack(spacing: 7) {
                // Play State / Index Indicator
                ZStack {
                    if isCurrentSong {
                        HStack(alignment: .bottom, spacing: 1.2) {
                            ForEach(0..<3, id: \.self) { barIdx in
                                RoundedRectangle(cornerRadius: 0.5)
                                    .fill(Color.white)
                                    .frame(width: 1.8, height: max(2, 8 * media.visualizerBars[barIdx]))
                            }
                        }
                        .frame(width: 14, height: 10, alignment: .bottom)
                    } else {
                        Text("\(index + 1)")
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .foregroundColor(Color.white.opacity(0.35))
                            .frame(width: 14)
                    }
                }
                
                // Title & Artist
                VStack(alignment: .leading, spacing: 1) {
                    Text(song.title)
                        .font(.system(size: 9.5, weight: isCurrentSong ? .bold : .medium, design: .rounded))
                        .foregroundColor(isCurrentSong ? .white : Color.white.opacity(0.85))
                        .lineLimit(1)
                    
                    if !song.artist.isEmpty {
                        Text(song.artist)
                            .font(.system(size: 8, weight: .regular))
                            .foregroundColor(Color.white.opacity(0.45))
                            .lineLimit(1)
                    }
                }
                
                Spacer(minLength: 4)
                
                // Track Duration
                if !song.duration.isEmpty {
                    Text(song.duration)
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundColor(isCurrentSong ? Color.white.opacity(0.8) : Color.white.opacity(0.35))
                }
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(isCurrentSong ? Color.white.opacity(0.14) : Color.white.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(isCurrentSong ? Color.white.opacity(0.2) : Color.clear, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .help("Play \(song.title)")
    }
    
    private var defaultArtPlaceholder: some View {
        VStack(spacing: 2) {
            Image(systemName: "music.note")
                .font(.system(size: 20))
                .foregroundColor(Color.white.opacity(0.85))
        }
    }
}
