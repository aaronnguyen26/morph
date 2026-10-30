import SwiftUI

public struct MediaView: View {
    @ObservedObject var media: MediaControllerModel
    public var model: NotchModel?
    
    @State private var isScrubbing: Bool = false
    @State private var scrubFraction: Double = 0.0
    @State private var isSearching: Bool = false
    @State private var searchQuery: String = ""
    @FocusState private var playlistSearchFocused: Bool
    @FocusState private var songSearchFocused: Bool
    
    public init(media: MediaControllerModel, model: NotchModel? = nil) {
        self.media = media
        self.model = model
    }
    
    private var effectiveProgress: Double {
        isScrubbing ? scrubFraction : media.progress
    }
    
    private var effectiveCurrentTime: String {
        isScrubbing ? media.formatTime(scrubFraction * media.duration) : media.formattedCurrentTime
    }
    
    public var body: some View {
        HStack(alignment: .top, spacing: 10) {
            nowPlayingDeck
                .frame(width: 262)
            
            playlistBrowserDeck
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
    
    // MARK: - Left Deck (Now Playing Engine)
    private var nowPlayingDeck: some View {
        VStack(alignment: .leading, spacing: 5) {
            nowPlayingHeaderRow
            
            // Integrated Upcoming Calendar Sync Banner (if meeting within 30m)
            if let nextEvent = model?.calendar.nextUpcomingEvent {
                let diffSeconds = nextEvent.startTime.timeIntervalSince(Date())
                let minutes = Int(ceil(diffSeconds / 60.0))
                if minutes >= 0 && minutes <= 30 {
                    upcomingMeetingIntegrationBanner(event: nextEvent, minutes: minutes)
                }
            }
            
            albumArtAndMetadataRow
            
            if isSearching {
                songSearchBar
            }
            
            timelineScrubberRow
            transportControlsRow
            volumeControlRow
        }
        .padding(7)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(white: 0.07))
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
    
    // Calendar Integration Pill within Mini Player Deck
    private func upcomingMeetingIntegrationBanner(event: CalendarEvent, minutes: Int) -> some View {
        HStack(spacing: 4.5) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(Color(red: 1.0, green: 0.85, blue: 0.4))
            
            Text("In \(minutes)m: \(event.title)")
                .font(.system(size: 8, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
            
            Spacer(minLength: 2)
            
            Button(action: {
                if media.isPlaying {
                    media.pause()
                }
                if let controller = model?.meetingController {
                    _ = controller.openMeetLink(event: event, inApp: true)
                } else if let link = event.meetLink, !link.isEmpty {
                    model?.calendar.engine.openMeet(link: link)
                }
            }) {
                HStack(spacing: 2) {
                    Text("Join")
                        .font(.system(size: 7, weight: .bold))
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 5.5, weight: .bold))
                }
                .foregroundColor(.black)
                .padding(.horizontal, 4.5)
                .padding(.vertical, 1.5)
                .background(Color.white)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .help("Join Google Meet (Music auto-pauses)")
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 2.5)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
        )
    }
    
    // Left Deck Header (Symmetrical to hubTopNavigationBar on the Right)
    private var nowPlayingHeaderRow: some View {
        HStack(spacing: 4) {
            HStack(spacing: 3) {
                Image(systemName: media.isOffline ? "wifi.slash" : "waveform")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundColor(media.isOffline ? Color(red: 1.0, green: 0.72, blue: 0.2) : (media.isPlaying ? .white : Color.white.opacity(0.6)))
                
                Text(media.isOffline ? "Offline Mode" : "Now Playing")
                    .font(.system(size: 8.5, weight: .heavy, design: .rounded))
                    .foregroundColor(media.isOffline ? Color(red: 1.0, green: 0.85, blue: 0.4) : .white)
                    .lineLimit(1)
            }
            .fixedSize(horizontal: true, vertical: false)
            
            Spacer(minLength: 4)
            
            trackActionPills
        }
        .padding(.bottom, 1)
    }
    
    // Song Search Bar
    private var songSearchBar: some View {
        HStack(spacing: 4) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 8))
                .foregroundColor(Color.white.opacity(0.6))
            
            TextField("Search song or artist...", text: $searchQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 8.5, weight: .medium, design: .rounded))
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
                        .font(.system(size: 8))
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
                    .font(.system(size: 7.5, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1.5)
                    .background(Color.white)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2.5)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
    
    // 1. Album Art & Metadata
    private var albumArtAndMetadataRow: some View {
        HStack(spacing: 8) {
            albumArtSquircle
            
            VStack(alignment: .leading, spacing: 2) {
                Text(media.trackTitle.isEmpty ? "No Track Selected" : media.trackTitle)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(media.trackTitle.isEmpty ? Color.white.opacity(0.6) : .white)
                    .lineLimit(1)
                
                Text(media.artistName.isEmpty ? "YouTube Music" : media.artistName)
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.6))
                    .lineLimit(1)
                
                HStack(spacing: 3.5) {
                    Image(systemName: media.isOffline ? "arrow.down.circle.fill" : "antenna.radiowaves.left.and.right")
                        .font(.system(size: 6.5))
                        .foregroundColor(media.isOffline ? Color(red: 1.0, green: 0.72, blue: 0.2) : Color.white.opacity(0.5))
                    
                    Text(media.isOffline ? "Cached Offline" : (media.isSignedIn ? "YouTube Music Premium" : "Direct Stream"))
                        .font(.system(size: 7, weight: .medium, design: .rounded))
                        .foregroundColor(media.isOffline ? Color(red: 1.0, green: 0.85, blue: 0.4) : Color.white.opacity(0.45))
                        .lineLimit(1)
                }
                .padding(.top, 1)
            }
            
            Spacer(minLength: 0)
        }
    }
    
    private var albumArtSquircle: some View {
        let size: CGFloat = isSearching ? 34 : 46
        return ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(white: 0.12))
                .frame(width: size, height: size)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.5), radius: 4, x: 0, y: 1.5)
            
            if let artURL = media.albumArtURL, let url = URL(string: artURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: size, height: size)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    default:
                        defaultArtPlaceholder
                    }
                }
            } else {
                defaultArtPlaceholder
            }
        }
        .frame(width: size, height: size)
    }
    
    private var trackActionPills: some View {
        HStack(spacing: 3.5) {
            Button(action: {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    isSearching.toggle()
                }
            }) {
                Image(systemName: isSearching ? "xmark.circle.fill" : "magnifyingglass")
                    .font(.system(size: 7.5))
                    .foregroundColor(isSearching ? Color.white : Color.white.opacity(0.7))
                    .frame(width: 17, height: 17)
                    .background(isSearching ? Color.white.opacity(0.25) : Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help(isSearching ? "Close Search" : "Search YouTube Music Songs")
            
            Button(action: {
                media.toggleLike()
            }) {
                Image(systemName: media.isLiked ? "hand.thumbsup.fill" : "hand.thumbsup")
                    .font(.system(size: 7.5))
                    .foregroundColor(media.isLiked ? Color.white : Color.white.opacity(0.55))
                    .frame(width: 17, height: 17)
                    .background(media.isLiked ? Color.white.opacity(0.2) : Color.white.opacity(0.07))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help(media.isLiked ? "Liked (Click to unlike)" : "Like Track (⌘L)")
            
            Button(action: {
                media.toggleDislike()
            }) {
                Image(systemName: media.isDisliked ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                    .font(.system(size: 7.5))
                    .foregroundColor(media.isDisliked ? Color.white : Color.white.opacity(0.55))
                    .frame(width: 17, height: 17)
                    .background(media.isDisliked ? Color.white.opacity(0.2) : Color.white.opacity(0.07))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help(media.isDisliked ? "Disliked" : "Dislike Track")
            
            if !media.isSignedIn {
                Button(action: {
                    media.openSignIn()
                }) {
                    HStack(spacing: 2) {
                        Image(systemName: "safari")
                            .font(.system(size: 6.5))
                        Text("Sign In")
                            .font(.system(size: 7, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 4.5)
                    .padding(.vertical, 1.5)
                    .background(Color.white.opacity(0.14))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("Sign in to YouTube Music via your browser")
            } else {
                Button(action: {
                    media.openInBrowser()
                }) {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 6.5))
                        Text("Browser")
                            .font(.system(size: 7, weight: .medium))
                    }
                    .foregroundColor(Color.white.opacity(0.85))
                    .padding(.horizontal, 4.5)
                    .padding(.vertical, 1.5)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("Open YouTube Music in System Browser")
            }
        }
    }
    
    // 2. Timeline Scrubber
    private var timelineScrubberRow: some View {
        VStack(spacing: 2) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.14))
                        .frame(height: 3)
                    
                    Capsule()
                        .fill(Color.white)
                        .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(effectiveProgress))), height: 3)
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
            .frame(height: 5)
            
            HStack {
                Text(effectiveCurrentTime)
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.5))
                
                Spacer()
                
                // Live 3-bar mini visualizer
                HStack(alignment: .bottom, spacing: 1.5) {
                    ForEach(0..<3, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 0.5)
                            .fill(Color.white.opacity(0.8))
                            .frame(width: 1.8, height: max(2, 7 * media.visualizerBars[i]))
                    }
                }
                .frame(height: 7, alignment: .bottom)
                
                Spacer()
                
                Text(media.formattedDuration)
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.5))
            }
        }
    }
    
    // 3. Transport Controls (Dead-Center Symmetrical Alignment)
    private var transportControlsRow: some View {
        HStack(spacing: 7) {
            Spacer(minLength: 0)
            
            Button(action: {
                media.toggleShuffle()
            }) {
                Image(systemName: "shuffle")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundColor(media.isShuffle ? Color.white : Color.white.opacity(0.35))
                    .frame(width: 19, height: 19)
                    .background(media.isShuffle ? Color.white.opacity(0.2) : Color.white.opacity(0.06))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help(media.isShuffle ? "Shuffle On" : "Shuffle Off")
            
            Button(action: {
                media.previousTrack()
            }) {
                Image(systemName: "backward.fill")
                    .font(.system(size: 8.5, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.85))
                    .frame(width: 21, height: 21)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Previous Track (⌘[ or ⌘←)")
            
            Button(action: {
                media.togglePlay()
            }) {
                Image(systemName: media.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundColor(.black)
                    .frame(width: 28, height: 28)
                    .background(Color.white)
                    .clipShape(Circle())
                    .shadow(color: Color.white.opacity(0.25), radius: 3, x: 0, y: 1)
            }
            .buttonStyle(.plain)
            .help(media.isPlaying ? "Pause Music (⌘⏎)" : "Play Music (⌘⏎)")
            
            Button(action: {
                media.nextTrack()
            }) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 8.5, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.85))
                    .frame(width: 21, height: 21)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Next Track (⌘] or ⌘→)")
            
            Button(action: {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                    media.toggleRepeat()
                }
            }) {
                Image(systemName: media.repeatMode.iconName)
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundColor(media.repeatMode != .off ? Color.white : Color.white.opacity(0.35))
                    .frame(width: 19, height: 19)
                    .background(media.repeatMode != .off ? Color.white.opacity(0.2) : Color.white.opacity(0.06))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help(media.repeatMode.displayTitle)
            
            Button(action: {
                media.stop()
            }) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.65))
                    .frame(width: 19, height: 19)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Stop Playback")
            
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
    
    // 4. Volume Control Row (Clean & Monochromatic)
    private var volumeControlRow: some View {
        HStack(spacing: 6) {
            Button(action: {
                media.toggleMute()
            }) {
                Image(systemName: media.isMuted ? "speaker.slash.fill" : (media.volume > 0.5 ? "speaker.wave.2.fill" : "speaker.wave.1.fill"))
                    .font(.system(size: 9))
                    .foregroundColor(media.isMuted ? Color.white.opacity(0.4) : Color.white.opacity(0.85))
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.plain)
            .help(media.isMuted ? "Unmute (⌘U)" : "Mute (⌘U)")
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.14))
                        .frame(height: 3)
                    
                    Capsule()
                        .fill(media.isMuted ? Color.white.opacity(0.3) : Color.white)
                        .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(media.isMuted ? 0 : media.volume))), height: 3)
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
            .frame(height: 5)
            
            Text("\(Int((media.isMuted ? 0 : media.volume) * 100))%")
                .font(.system(size: 7.5, weight: .medium, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.45))
        }
    }
    
    // MARK: - Right Deck: YouTube Music Flexible Hub (326 pt)
    private var playlistBrowserDeck: some View {
        VStack(alignment: .leading, spacing: 4) {
            hubTopNavigationBar
            
            if media.selectedPlaylist != nil && media.rightDeckSection == .playlists {
                // STEP 2: SONGS IN CHOSEN PLAYLIST
                playlistDetailDeck(playlist: media.selectedPlaylist!)
            } else {
                switch media.rightDeckSection {
                case .home:
                    hubHomeDeck
                case .playlists:
                    playlistsSelectionDeck
                case .queue:
                    playlistDetailDeck(playlist: media.nowPlayingQueuePlaylist)
                case .downloads:
                    downloadsDeck
                case .search:
                    hubSearchDeck
                }
            }
        }
        .padding(7)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(white: 0.07))
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
    
    // MARK: - YouTube Music Hub Top Bar
    private var hubTopNavigationBar: some View {
        HStack(spacing: 3) {
            // YTM Brand Icon & Badge
            HStack(spacing: 3) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundColor(.red)
                Text("Music")
                    .font(.system(size: 8.5, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                if media.isOffline {
                    HStack(spacing: 2) {
                        Image(systemName: "wifi.slash")
                            .font(.system(size: 6, weight: .bold))
                        Text("OFFLINE")
                            .font(.system(size: 6, weight: .heavy, design: .monospaced))
                    }
                    .foregroundColor(Color(red: 1.0, green: 0.72, blue: 0.2))
                    .padding(.horizontal, 3.5)
                    .padding(.vertical, 1)
                    .background(Color(red: 1.0, green: 0.72, blue: 0.2).opacity(0.18))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(Color(red: 1.0, green: 0.72, blue: 0.2).opacity(0.4), lineWidth: 0.5)
                    )
                }
            }
            .fixedSize(horizontal: true, vertical: false)
            .padding(.trailing, 2)
            
            Spacer(minLength: 4)
            
            // Section Switcher Pills
            HStack(spacing: 2.5) {
                ForEach(media.availableRightDeckSections, id: \.self) { section in
                    let isSelected = (media.rightDeckSection == section && (section != .playlists || media.selectedPlaylist == nil))
                    Button(action: {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            media.switchRightDeck(to: section)
                        }
                    }) {
                        HStack(spacing: 2) {
                            Image(systemName: section.iconName)
                                .font(.system(size: 6.5, weight: .bold))
                            Text(section.title)
                                .font(.system(size: 7.5, weight: isSelected ? .bold : .medium))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        .foregroundColor(isSelected ? .black : Color.white.opacity(0.68))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(isSelected ? Color.white : Color.white.opacity(0.06))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.bottom, 1)
    }
    
    // MARK: - Hub Home Deck (Algorithmic Quick Picks & Discovery)
    private var hubHomeDeck: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header Row
            HStack(spacing: 4) {
                HStack(spacing: 3) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.85))
                    Text("Quick Picks")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                
                Text("• Recommended")
                    .font(.system(size: 7, weight: .regular))
                    .foregroundColor(Color.white.opacity(0.45))
                    .lineLimit(1)
                
                Spacer(minLength: 4)
                
                Button(action: {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        media.refreshQuickPicks()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 7.5, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.65))
                        .frame(width: 16, height: 16)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Refresh Quick Picks recommendations")
            }
            .padding(.horizontal, 2)
            
            // List of Quick Picks
            if media.isLoadingQuickPicks && media.quickPicks.isEmpty {
                VStack(spacing: 4) {
                    Spacer(minLength: 8)
                    ProgressView()
                        .scaleEffect(0.6)
                        .colorScheme(.dark)
                    Text("Loading recommendations...")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.6))
                    Spacer(minLength: 8)
                }
                .frame(maxWidth: .infinity, maxHeight: 104)
            } else if media.quickPicks.isEmpty {
                VStack(spacing: 4) {
                    Spacer(minLength: 8)
                    Image(systemName: "sparkles")
                        .font(.system(size: 12))
                        .foregroundColor(Color.white.opacity(0.35))
                    Text("No recommendations found")
                        .font(.system(size: 8.5, weight: .bold, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.8))
                    Text("Listen to music to seed your algorithm or click Refresh.")
                        .font(.system(size: 7, weight: .regular))
                        .foregroundColor(Color.white.opacity(0.45))
                        .multilineTextAlignment(.center)
                    Button(action: { media.refreshQuickPicks() }) {
                        Text("Refresh Picks")
                            .font(.system(size: 7.5, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2.5)
                            .background(Color.white)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    Spacer(minLength: 8)
                }
                .frame(maxWidth: .infinity, maxHeight: 104)
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(spacing: 2.5) {
                        ForEach(media.quickPicks) { track in
                            quickPickDetailedRow(track: track)
                        }
                    }
                    .padding(.trailing, 2)
                }
                .frame(maxHeight: 104)
            }
        }
    }
    
    private func quickPickDetailedRow(track: YTMPlaylistItem) -> some View {
        let isCurrent = media.isSongCurrent(track, in: media.quickPicks)
        let isPaused = media.isSongPausedCurrent(track, in: media.quickPicks)
        let isActive = isCurrent || isPaused
        let titleWeight: Font.Weight = isActive ? .bold : .medium
        let titleColor = isActive ? Color.white : Color.white.opacity(0.9)
        let artistColor = isActive ? Color.white.opacity(0.7) : Color.white.opacity(0.45)
        let durationColor = isActive ? Color.white.opacity(0.8) : Color.white.opacity(0.35)
        let bgOpacity: Double = isCurrent ? 0.14 : (isPaused ? 0.08 : 0.03)
        let strokeColor = isCurrent ? Color.white.opacity(0.2) : (isPaused ? Color.white.opacity(0.12) : Color.white.opacity(0.05))
        
        return Button(action: {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                media.playQuickPick(track, startRadio: true)
            }
        }) {
            HStack(spacing: 7) {
                // Artwork thumbnail with squircle
                artworkThumb(url: track.thumbnailURL, size: 24, fallbackIcon: "music.note")
                
                // Track metadata
                VStack(alignment: .leading, spacing: 1) {
                    Text(track.title)
                        .font(.system(size: 9.5, weight: titleWeight, design: .rounded))
                        .foregroundColor(titleColor)
                        .lineLimit(1)
                    
                    Text(track.artist.isEmpty ? "YouTube Music" : track.artist)
                        .font(.system(size: 8, weight: .regular))
                        .foregroundColor(artistColor)
                        .lineLimit(1)
                }
                
                Spacer(minLength: 4)
                
                // Duration
                if !track.duration.isEmpty {
                    Text(track.duration)
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundColor(durationColor)
                }
                
                // Active visualizer or Start Radio action pill
                if isCurrent {
                    HStack(alignment: .bottom, spacing: 1.2) {
                        ForEach(0..<3, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 0.5)
                                .fill(Color.white)
                                .frame(width: 1.8, height: max(2, 8 * media.visualizerBars[i]))
                        }
                    }
                    .frame(width: 14, height: 10, alignment: .bottom)
                    .padding(.horizontal, 2)
                } else if isPaused {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 8))
                        .foregroundColor(Color.white.opacity(0.85))
                        .padding(.horizontal, 2)
                } else {
                    HStack(spacing: 2.5) {
                        Image(systemName: "radiowaves.right")
                            .font(.system(size: 7, weight: .bold))
                        Text("Radio")
                            .font(.system(size: 7.5, weight: .semibold))
                    }
                    .foregroundColor(Color.white.opacity(0.7))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2.5)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3.5)
            .background(Color.white.opacity(bgOpacity))
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(strokeColor, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .help("Start algorithm radio based on \(track.title)")
    }
    
    // MARK: - Downloads & Offline Deck
    private var downloadsDeck: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header Row
            HStack(spacing: 4) {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                    Text("YouTube Music Offline")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                
                Text("• \(media.downloadedTracks.count) songs ready")
                    .font(.system(size: 7, weight: .regular))
                    .foregroundColor(Color.white.opacity(0.45))
                    .lineLimit(1)
                
                Spacer(minLength: 4)
            }
            
            // Reassurance / Zero-Latency Banner
            HStack(spacing: 4) {
                Image(systemName: "bolt.shield.fill")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(.white.opacity(0.8))
                
                Text("Offline Cache • Zero-latency playback from your YouTube Music")
                    .font(.system(size: 7, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.72))
                    .lineLimit(1)
                
                Spacer(minLength: 2)
            }
            .padding(.horizontal, 5)
            .padding(.vertical, 2.5)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            
            if media.downloadedTracks.isEmpty {
                VStack(spacing: 4) {
                    Spacer(minLength: 8)
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 13))
                        .foregroundColor(Color.white.opacity(0.35))
                    Text("No YouTube Music songs cached yet")
                        .font(.system(size: 8.5, weight: .bold, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.8))
                    Text("Play songs while connected to Wi-Fi to automatically cache them for offline listening.")
                        .font(.system(size: 7, weight: .regular))
                        .foregroundColor(Color.white.opacity(0.45))
                        .multilineTextAlignment(.center)
                    Spacer(minLength: 8)
                }
                .frame(maxWidth: .infinity, maxHeight: 96)
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(spacing: 2.5) {
                        ForEach(media.downloadedTracks) { track in
                            downloadedTrackRow(track: track)
                        }
                    }
                    .padding(.trailing, 2)
                }
                .frame(maxHeight: 96)
            }
        }
    }
    
    private func downloadedTrackRow(track: YTMPlaylistItem) -> some View {
        let isCurrent = media.isPlaying && media.trackTitle == track.title
        let isPaused = !media.isPlaying && media.trackTitle == track.title && media.currentTime > 0
        let isActive = isCurrent || isPaused
        let titleWeight: Font.Weight = isActive ? .bold : .medium
        let titleColor = isActive ? Color.white : Color.white.opacity(0.9)
        let artistColor = isActive ? Color.white.opacity(0.7) : Color.white.opacity(0.45)
        let durationColor = isActive ? Color.white.opacity(0.8) : Color.white.opacity(0.35)
        let bgOpacity: Double = isCurrent ? 0.14 : (isPaused ? 0.08 : 0.03)
        let strokeColor = isCurrent ? Color.white.opacity(0.2) : (isPaused ? Color.white.opacity(0.12) : Color.white.opacity(0.05))
        
        return Button(action: {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                media.playDownloadedTrack(track)
            }
        }) {
            HStack(spacing: 6) {
                // Artwork thumbnail
                artworkThumb(url: track.thumbnailURL, size: 22, fallbackIcon: "music.note")
                
                // Track metadata
                VStack(alignment: .leading, spacing: 1) {
                    Text(track.title)
                        .font(.system(size: 9, weight: titleWeight, design: .rounded))
                        .foregroundColor(titleColor)
                        .lineLimit(1)
                    
                    Text(track.artist.isEmpty ? "YouTube Music" : track.artist)
                        .font(.system(size: 7.5, weight: .regular))
                        .foregroundColor(artistColor)
                        .lineLimit(1)
                }
                
                Spacer(minLength: 4)
                
                // Duration
                if !track.duration.isEmpty {
                    Text(track.duration)
                        .font(.system(size: 7.5, weight: .medium, design: .monospaced))
                        .foregroundColor(durationColor)
                }
                
                // Active visualizer or play status
                if isCurrent {
                    HStack(alignment: .bottom, spacing: 1.2) {
                        ForEach(0..<3, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 0.5)
                                .fill(Color.white)
                                .frame(width: 1.8, height: max(2, 7 * media.visualizerBars[i]))
                        }
                    }
                    .frame(width: 12, height: 8, alignment: .bottom)
                    .padding(.horizontal, 2)
                } else if isPaused {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 7.5))
                        .foregroundColor(Color.white.opacity(0.75))
                        .padding(.horizontal, 2)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3.5)
            .background(Color.white.opacity(bgOpacity))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(strokeColor, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Hub Dedicated Search Deck
    private var hubSearchDeck: some View {
        VStack(alignment: .leading, spacing: 5) {
            playlistsSearchBar
            catalogSearchDeck
        }
    }
    
    // MARK: - Step 1: Choose a Playlist
    private var playlistsSelectionDeck: some View {
        VStack(alignment: .leading, spacing: 6) {
            playlistsHeaderRow
            
            if media.isSearchingPlaylists {
                playlistsSearchBar
            }
            
            if media.isSearchingPlaylists && !media.playlistSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                catalogSearchDeck
            } else if media.isLoadingPlaylists {
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
                .frame(maxWidth: .infinity, maxHeight: media.isSearchingPlaylists ? 84 : 104)
            } else if media.playlists.isEmpty {
                VStack(spacing: 6) {
                    Spacer(minLength: 10)
                    Image(systemName: "music.note.list")
                        .font(.system(size: 16))
                        .foregroundColor(Color.white.opacity(0.35))
                    Text(media.isSignedIn ? "No Custom Playlists Found" : "Connect YouTube Music")
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.9))
                    Text(media.libraryError
                         ?? (media.isSignedIn
                             ? "You are signed in! Create playlists on YouTube Music or click Sync to refresh."
                             : "Sign in to YouTube Music via your browser. Once signed in, you can close that browser tab and stream music directly inside Morph."))
                        .font(.system(size: 8, weight: .regular))
                        .foregroundColor(Color.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 10)
                    
                    if let statusMsg = media.browserAuthStatusMessage {
                        Text(statusMsg)
                            .font(.system(size: 7.5, weight: .medium))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    
                    HStack(spacing: 6) {
                        if !media.isSignedIn {
                            Button(action: {
                                media.openSignIn()
                            }) {
                                HStack(spacing: 3) {
                                    Image(systemName: "safari")
                                        .font(.system(size: 8.5))
                                    Text("Sign In in Browser")
                                        .font(.system(size: 8.5, weight: .bold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3.5)
                                .background(Color.white.opacity(0.14))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .help("Opens Google / YouTube Music sign-in tab in your browser")
                            
                            Button(action: {
                                media.syncSessionFromBrowser()
                            }) {
                                HStack(spacing: 3) {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.system(size: 8))
                                    Text("Sync Session")
                                        .font(.system(size: 8.5, weight: .medium))
                                }
                                .foregroundColor(Color.white.opacity(0.85))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3.5)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .help("Detects signed-in YouTube Music tab in Chrome/Safari and syncs session")
                        } else {
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
                    }
                    .padding(.top, 2)
                    
                    Spacer(minLength: 8)
                }
                .frame(maxWidth: .infinity, maxHeight: media.isSearchingPlaylists ? 84 : 104)
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
                .frame(maxHeight: media.isSearchingPlaylists ? 84 : 104)
            }
        }
    }
    
    private var playlistsHeaderRow: some View {
        HStack(spacing: 5) {
            Button(action: {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                    media.openHubHome()
                }
            }) {
                HStack(spacing: 2) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 8, weight: .bold))
                    Text("Hub")
                        .font(.system(size: 8.5, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2.5)
                .background(Color.white.opacity(0.12))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .help("Back to Music Hub")
            
            Text("PLAYLISTS")
                .font(.system(size: 9, weight: .heavy, design: .rounded))
                .foregroundColor(Color.white.opacity(0.85))
                .tracking(0.5)
            
            Text("\(media.filteredPlaylists.count)")
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
            
            TextField("Search songs, artists, albums...", text: $media.playlistSearchQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 9.5, weight: .medium, design: .rounded))
                .foregroundColor(.white)
                .focused($playlistSearchFocused)
                .onAppear { playlistSearchFocused = true }
                .onSubmit {
                    let q = media.playlistSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !q.isEmpty {
                        media.runCatalogSearch(q)
                    }
                }
            
            if media.isSearchingCatalog {
                ProgressView()
                    .scaleEffect(0.4)
                    .frame(width: 10, height: 10)
                    .colorScheme(.dark)
            } else if !media.playlistSearchQuery.isEmpty {
                Button(action: { media.clearPlaylistSearch() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 8.5))
                        .foregroundColor(Color.white.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3.5)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
    
    // MARK: - YouTube Music style search results (library matches + Songs / Artists / Albums / Playlists)
    private var catalogSearchDeck: some View {
        ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(alignment: .leading, spacing: 3) {
                let local = media.filteredPlaylists
                if !local.isEmpty {
                    searchSectionHeader("In your library")
                    ForEach(local.prefix(4)) { playlist in
                        playlistCardRow(playlist: playlist)
                    }
                }
                
                if media.isSearchingCatalog && media.searchResults.isEmpty {
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.5)
                            .frame(width: 12, height: 12)
                            .colorScheme(.dark)
                        Text("Searching YouTube Music...")
                            .font(.system(size: 8.5, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.55))
                    }
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                } else if media.searchResults.isEmpty, let err = media.catalogSearchError {
                    Text(err)
                        .font(.system(size: 8.5, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                }
                
                ForEach(Array(media.groupedSearchResults.enumerated()), id: \.offset) { _, group in
                    searchSectionHeader(group.kind.sectionTitle)
                    ForEach(group.items) { result in
                        searchResultRow(result)
                    }
                }
            }
            .padding(.trailing, 2)
        }
        .frame(maxHeight: 100)
    }
    
    private func searchSectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 7.5, weight: .heavy, design: .rounded))
            .tracking(0.6)
            .foregroundColor(Color.white.opacity(0.4))
            .padding(.top, 3)
            .padding(.leading, 2)
    }
    
    private func searchResultRow(_ result: YTMSearchResult) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                media.openSearchResult(result)
            }
        }) {
            HStack(spacing: 8) {
                artworkThumb(url: result.thumbnailURL, size: 26, circle: result.kind == .artist, fallbackIcon: result.kind.iconName)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(result.title)
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    if !result.subtitle.isEmpty {
                        Text(result.subtitle)
                            .font(.system(size: 8, weight: .regular))
                            .foregroundColor(Color.white.opacity(0.45))
                            .lineLimit(1)
                    }
                }
                
                Spacer(minLength: 4)
                
                Image(systemName: (result.kind == .song || result.kind == .video) ? "play.fill" : "chevron.right")
                    .font(.system(size: 7.5, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.35))
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3.5)
            .background(Color.white.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .help(result.kind == .song || result.kind == .video ? "Play \(result.title)" : "Open \(result.title)")
    }
    
    private func artworkThumb(url: String?, size: CGFloat, circle: Bool = false, fallbackIcon: String) -> some View {
        let shape = RoundedRectangle(cornerRadius: circle ? size / 2 : 6, style: .continuous)
        return ZStack {
            shape
                .fill(Color.white.opacity(0.08))
                .frame(width: size, height: size)
            if let url = url, let u = URL(string: url) {
                AsyncImage(url: u) { phase in
                    if case .success(let img) = phase {
                        img.resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: size, height: size)
                            .clipShape(shape)
                    } else {
                        Image(systemName: fallbackIcon)
                            .font(.system(size: size * 0.38, weight: .bold))
                            .foregroundColor(Color.white.opacity(0.6))
                    }
                }
            } else {
                Image(systemName: fallbackIcon)
                    .font(.system(size: size * 0.38, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.6))
            }
        }
        .frame(width: size, height: size)
    }
    
    private var nowPlayingQueueCardRow: some View {
        Button(action: {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                media.openQueueSection()
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
                    
                    Text(playlist.subtitle.isEmpty ? (playlist.tracks.isEmpty ? "Playlist" : "\(playlist.tracks.count) tracks") : playlist.subtitle)
                        .font(.system(size: 8, weight: .regular))
                        .foregroundColor(Color.white.opacity(0.45))
                        .lineLimit(1)
                }
                
                Spacer(minLength: 4)
                
                HStack(spacing: 4) {
                    if !playlist.tracks.isEmpty {
                        Text("\(playlist.tracks.count)")
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .foregroundColor(Color.white.opacity(0.4))
                    }
                    
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
                    songsEmptyState(playlist: playlist)
                } else {
                    LazyVStack(spacing: 3) {
                        ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                            songItemRow(index: index, song: song, in: songs)
                        }
                        
                        if media.isLoadingTracks {
                            HStack(spacing: 5) {
                                ProgressView().scaleEffect(0.45).frame(width: 10, height: 10).colorScheme(.dark)
                                Text("Loading more...")
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundColor(Color.white.opacity(0.45))
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(.trailing, 2)
                }
            }
            .frame(maxHeight: media.isSearchingSongs ? 84 : 104)
        }
    }
    
    @ViewBuilder
    private func songsEmptyState(playlist: YTMPlaylist) -> some View {
        let query = media.songSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        VStack(spacing: 5) {
            Spacer(minLength: 10)
            if media.isLoadingTracks && playlist.tracks.isEmpty {
                ProgressView()
                    .scaleEffect(0.7)
                    .colorScheme(.dark)
                Text("Loading songs from YouTube Music...")
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.6))
            } else if !query.isEmpty && !playlist.tracks.isEmpty {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundColor(Color.white.opacity(0.3))
                Text("No songs match \"\(query)\"")
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.5))
                Button(action: {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                        media.searchYouTubeMusic(for: query)
                    }
                }) {
                    Text("Search YouTube Music")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.white)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 14))
                    .foregroundColor(Color.white.opacity(0.3))
                Text(media.tracksError ?? "No songs found in this playlist")
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                if playlist.id != "pl_queue" {
                    HStack(spacing: 6) {
                        Button(action: { media.loadTracksForSelectedPlaylist() }) {
                            HStack(spacing: 3) {
                                Image(systemName: "arrow.clockwise").font(.system(size: 8))
                                Text("Retry").font(.system(size: 8.5, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.14))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        
                        if !media.isSignedIn {
                            Button(action: {
                                media.openSignIn()
                            }) {
                                HStack(spacing: 3) {
                                    Image(systemName: "safari").font(.system(size: 8))
                                    Text("Sign In").font(.system(size: 8.5, weight: .semibold))
                                }
                                .foregroundColor(.black)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.white)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .help("Sign in to YouTube Music via browser tab")
                        }
                    }
                }
            }
            Spacer(minLength: 10)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func playlistDetailHeaderRow(playlist: YTMPlaylist) -> some View {
        HStack(spacing: 5) {
            // Back Button
            Button(action: {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                    if media.rightDeckSection == .queue || playlist.id == "pl_queue" {
                        media.backFromQueue()
                    } else {
                        media.backToPlaylists()
                    }
                }
            }) {
                HStack(spacing: 2) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 8, weight: .bold))
                    Text(media.rightDeckSection == .queue || playlist.id == "pl_queue" ? "Back" : "Playlists")
                        .font(.system(size: 8.5, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2.5)
                .background(Color.white.opacity(0.12))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .help(media.rightDeckSection == .queue || playlist.id == "pl_queue" ? "Back to Previous View" : "Back to Playlist Selection")
            
            Text(playlist.title)
                .font(.system(size: 9, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
            
            if !playlist.tracks.isEmpty {
                Text("\(playlist.tracks.count)")
                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.5))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1.5)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
            }
            
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
            
            TextField("Search in this playlist...", text: $media.songSearchQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 9.5, weight: .medium, design: .rounded))
                .foregroundColor(.white)
                .focused($songSearchFocused)
                .onAppear { songSearchFocused = true }
                .onSubmit {
                    if let pl = media.selectedPlaylist, let first = media.filteredSongs(for: pl).first {
                        media.playSongInSelectedPlaylist(first)
                    }
                }
            
            if !media.songSearchQuery.isEmpty {
                Button(action: { media.songSearchQuery = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 8.5))
                        .foregroundColor(Color.white.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3.5)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
    
    private func songItemRow(index: Int, song: YTMPlaylistItem, in songs: [YTMPlaylistItem]) -> some View {
        let isCurrentSong = media.isSongCurrent(song, in: songs)
        let isPausedSong = media.isSongPausedCurrent(song, in: songs)
        return Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                media.playSongInSelectedPlaylist(song)
            }
        }) {
            HStack(spacing: 7) {
                // Play State / Index Indicator (artwork when YouTube provides it)
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
                    } else if isPausedSong {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 7.5))
                            .foregroundColor(Color.white.opacity(0.85))
                            .frame(width: 14)
                    } else if let thumb = song.thumbnailURL {
                        artworkThumb(url: thumb, size: 20, fallbackIcon: "music.note")
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
                        .font(.system(size: 9.5, weight: (isCurrentSong || isPausedSong) ? .bold : .medium, design: .rounded))
                        .foregroundColor((isCurrentSong || isPausedSong) ? .white : Color.white.opacity(0.85))
                        .lineLimit(1)
                    
                    if !song.artist.isEmpty {
                        Text(song.artist)
                            .font(.system(size: 8, weight: .regular))
                            .foregroundColor((isCurrentSong || isPausedSong) ? Color.white.opacity(0.7) : Color.white.opacity(0.45))
                            .lineLimit(1)
                    }
                }
                
                Spacer(minLength: 4)
                
                // Track Duration
                if !song.duration.isEmpty {
                    Text(song.duration)
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundColor((isCurrentSong || isPausedSong) ? Color.white.opacity(0.8) : Color.white.opacity(0.35))
                }
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(isCurrentSong ? Color.white.opacity(0.14) : (isPausedSong ? Color.white.opacity(0.08) : Color.white.opacity(0.03)))
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(isCurrentSong ? Color.white.opacity(0.2) : (isPausedSong ? Color.white.opacity(0.12) : Color.clear), lineWidth: 0.5)
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
