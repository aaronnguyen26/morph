import SwiftUI

public struct MediaView: View {
    @ObservedObject var media: MediaControllerModel
    @ObservedObject public var calendar: CalendarModel
    @ObservedObject public var theme: MorphTheme = .shared
    public var model: NotchModel?
    
    @State private var isScrubbing: Bool = false
    @State private var scrubFraction: Double = 0.0
    @State private var isHoveringTimeline: Bool = false
    @State private var isHoveringVolume: Bool = false
    @State private var isScrubbingVolume: Bool = false
    @State private var isSearching: Bool = false
    @State private var searchQuery: String = ""
    @FocusState private var playlistSearchFocused: Bool
    @FocusState private var songSearchFocused: Bool
    
    public init(media: MediaControllerModel, model: NotchModel? = nil, calendar: CalendarModel? = nil, theme: MorphTheme? = nil) {
        self.media = media
        self.model = model
        self.calendar = calendar ?? model?.calendar ?? CalendarModel()
        self.theme = theme ?? .shared
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
        VStack(alignment: .leading, spacing: 4.5) {
            nowPlayingHeaderRow
            
            // Integrated Calendar Sync Banner within Mini Player
            if let nextEvent = calendar.nextUpcomingEvent {
                let diffSeconds = nextEvent.startTime.timeIntervalSince(Date())
                let minutes = Int(ceil(diffSeconds / 60.0))
                if minutes >= -15 && minutes <= 30 {
                    upcomingMeetingIntegrationBanner(event: nextEvent, minutes: max(0, minutes))
                } else {
                    calendarScheduleStrip(event: nextEvent)
                }
            } else if model != nil && !calendar.isSignedIn {
                connectCalendarMiniStrip
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
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(theme.liquidGlassCard)
                .background(.ultraThinMaterial)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(theme.liquidGlassSpecularBorder, lineWidth: 1)
        )
    }
    
    // Calendar Integration Pill within Mini Player Deck (Urgent <= 30m)
    private func upcomingMeetingIntegrationBanner(event: CalendarEvent, minutes: Int) -> some View {
        HStack(spacing: 4.5) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(theme.textPrimary)
            
            Text(minutes <= 0 ? "Now: \(event.title)" : "In \(minutes)m: \(event.title)")
                .font(.system(size: 8, weight: .semibold, design: .rounded))
                .foregroundColor(theme.textPrimary)
                .lineLimit(1)
            
            Spacer(minLength: 2)
            
            Button(action: {
                if media.isPlaying {
                    media.pause()
                }
                if let controller = model?.meetingController {
                    _ = controller.openMeetLink(event: event, inApp: true)
                } else if let link = event.meetLink, !link.isEmpty {
                    calendar.engine.openMeet(link: link)
                } else {
                    model?.openFeature(.calendar)
                }
            }) {
                HStack(spacing: 2) {
                    Text(event.hasMeetLink ? "Join" : "View")
                        .font(.system(size: 7, weight: .bold))
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 5.5, weight: .bold))
                }
                .foregroundColor(theme.activePillText)
                .padding(.horizontal, 5)
                .padding(.vertical, 1.5)
                .background(theme.activePillBackground)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .help("Join Meeting (Music auto-pauses)")
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2.5)
        .background(theme.cardBackgroundElevated)
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .stroke(theme.hairlineBorder, lineWidth: 0.5)
        )
    }
    
    // Compact Calendar Schedule Strip within Mini Player (Upcoming later today)
    private func calendarScheduleStrip(event: CalendarEvent) -> some View {
        let formatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "h:mm a"
            return f
        }()
        return HStack(spacing: 4) {
            Image(systemName: "calendar")
                .font(.system(size: 7.5, weight: .semibold))
                .foregroundColor(theme.textSecondary)
            
            Text("\(formatter.string(from: event.startTime)) — \(event.title)")
                .font(.system(size: 7.5, weight: .medium, design: .rounded))
                .foregroundColor(theme.textSecondary)
                .lineLimit(1)
            
            Spacer(minLength: 2)
            
            Button(action: {
                if event.hasMeetLink {
                    if media.isPlaying { media.pause() }
                    if let controller = model?.meetingController {
                        _ = controller.openMeetLink(event: event, inApp: true)
                    } else if let link = event.meetLink {
                        calendar.engine.openMeet(link: link)
                    }
                } else {
                    model?.openFeature(.calendar)
                }
            }) {
                Text(event.hasMeetLink ? "Join" : "Agenda")
                    .font(.system(size: 6.5, weight: .bold))
                    .foregroundColor(theme.textPrimary)
                    .padding(.horizontal, 4.5)
                    .padding(.vertical, 1)
                    .background(theme.cardBackgroundElevated)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
    
    // Compact Connect Calendar Prompt in Mini Player
    private var connectCalendarMiniStrip: some View {
        HStack(spacing: 4) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 7.5, weight: .semibold))
                .foregroundColor(theme.textTertiary)
            Text("Calendar not synced")
                .font(.system(size: 7.5, weight: .medium, design: .rounded))
                .foregroundColor(theme.textTertiary)
                .lineLimit(1)
            Spacer(minLength: 2)
            Button(action: {
                if let model = model {
                    model.openFeature(.calendar)
                } else {
                    calendar.signInWithGoogle()
                }
            }) {
                Text("Connect")
                    .font(.system(size: 6.5, weight: .bold))
                    .foregroundColor(theme.textPrimary)
                    .padding(.horizontal, 4.5)
                    .padding(.vertical, 1)
                    .background(theme.cardBackgroundElevated)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(theme.cardBackgroundSubtle)
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
    
    // Left Deck Header (Symmetrical to hubTopNavigationBar on the Right)
    private var nowPlayingHeaderRow: some View {
        HStack(spacing: 4) {
            HStack(spacing: 3) {
                Image(systemName: media.isOffline ? "wifi.slash" : "waveform")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundColor(media.isOffline ? theme.textSecondary : (media.isPlaying ? theme.textPrimary : theme.textSecondary))
                
                Text(media.isOffline ? "Offline Mode" : "Now Playing")
                    .font(.system(size: 8.5, weight: .heavy, design: .rounded))
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(1)
                
                if media.repeatMode != .off {
                    Button(action: {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                            media.toggleRepeat()
                        }
                    }) {
                        HStack(spacing: 2) {
                            Image(systemName: media.repeatMode.iconName)
                                .font(.system(size: 6.5, weight: .bold))
                            Text(media.repeatMode == .one ? "Loop 1" : "Loop All")
                                .font(.system(size: 6.5, weight: .bold))
                        }
                        .foregroundColor(theme.activePillText)
                        .padding(.horizontal, 4.5)
                        .padding(.vertical, 1.5)
                        .background(theme.activePillBackground)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("Loop Active: \(media.repeatMode.hudTitle). Click to cycle, right-click for options.")
                    .contextMenu {
                        Button(action: { media.setRepeatMode(.off) }) {
                            Label("Loop Off", systemImage: media.repeatMode == .off ? "checkmark" : "")
                        }
                        Button(action: { media.setRepeatMode(.all) }) {
                            Label("Loop All (Playlist & Queue)", systemImage: media.repeatMode == .all ? "checkmark" : "")
                        }
                        Button(action: { media.setRepeatMode(.one) }) {
                            Label("Loop Current Track", systemImage: media.repeatMode == .one ? "checkmark" : "")
                        }
                    }
                }
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
                .foregroundColor(theme.textSecondary)
            
            TextField("Search song or artist...", text: $searchQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 8.5, weight: .medium, design: .rounded))
                .foregroundColor(theme.textPrimary)
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
                        .foregroundColor(theme.textTertiary)
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
                    .foregroundColor(theme.activePillText)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1.5)
                    .background(theme.activePillBackground)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2.5)
        .background(theme.surfaceInset)
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .stroke(theme.hairlineBorder, lineWidth: 0.5)
        )
    }
    
    // 1. Album Art & Metadata
    private var albumArtAndMetadataRow: some View {
        HStack(spacing: 8) {
            albumArtSquircle
            
            VStack(alignment: .leading, spacing: 2) {
                Text(media.trackTitle.isEmpty ? "No Track Selected" : media.trackTitle)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(media.trackTitle.isEmpty ? theme.textTertiary : theme.textPrimary)
                    .lineLimit(1)
                
                Text(media.artistName.isEmpty ? "YouTube Music" : media.artistName)
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundColor(theme.textSecondary)
                    .lineLimit(1)
                
                HStack(spacing: 3.5) {
                    Image(systemName: media.isOffline ? "arrow.down.circle.fill" : "antenna.radiowaves.left.and.right")
                        .font(.system(size: 6.5))
                        .foregroundColor(media.isOffline ? theme.textSecondary : theme.textTertiary)
                    
                    Text(media.isOffline ? "Cached Offline" : (media.isSignedIn ? "YouTube Music Premium" : "Direct Stream"))
                        .font(.system(size: 7, weight: .medium, design: .rounded))
                        .foregroundColor(media.isOffline ? theme.textSecondary : theme.textTertiary)
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
                .fill(theme.cardBackgroundElevated)
                .frame(width: size, height: size)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(theme.hairlineBorder, lineWidth: 1)
                )
                .shadow(color: theme.windowShadow.opacity(0.45), radius: 4, x: 0, y: 1.5)
            
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
                    .foregroundColor(isSearching ? theme.textPrimary : theme.textSecondary)
                    .frame(width: 17, height: 17)
                    .background(isSearching ? theme.cardBackgroundElevated : theme.cardBackground)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help(isSearching ? "Close Search (Esc)" : "Search YouTube Music Songs (/)")
            .accessibilityLabel(isSearching ? "Close Search" : "Search YouTube Music Songs")
            .accessibilityHint("Shortcut: Slash (/) to search, Escape to dismiss.")
            
            Button(action: {
                media.toggleLike()
            }) {
                Image(systemName: media.isLiked ? "hand.thumbsup.fill" : "hand.thumbsup")
                    .font(.system(size: 7.5))
                    .foregroundColor(media.isLiked ? theme.textPrimary : theme.textSecondary)
                    .frame(width: 17, height: 17)
                    .background(media.isLiked ? theme.cardBackgroundElevated : theme.cardBackground)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help(media.isLiked ? "Liked (Click to unlike, + or ⌘L)" : "Like Track (+ or ⌘L)")
            .accessibilityLabel(media.isLiked ? "Remove Like" : "Like Track")
            .accessibilityHint("Shortcut: Plus (+) or Command+L to favorite.")
            
            Button(action: {
                media.toggleDislike()
            }) {
                Image(systemName: media.isDisliked ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                    .font(.system(size: 7.5))
                    .foregroundColor(media.isDisliked ? theme.textPrimary : theme.textSecondary)
                    .frame(width: 17, height: 17)
                    .background(media.isDisliked ? theme.cardBackgroundElevated : theme.cardBackground)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help(media.isDisliked ? "Disliked (Click to remove, -)" : "Dislike Track (-)")
            .accessibilityLabel(media.isDisliked ? "Remove Dislike" : "Dislike Track")
            .accessibilityHint("Shortcut: Minus (-).")
            
            if !media.isSignedIn {
                Button(action: {
                    media.openSignIn()
                }) {
                    HStack(spacing: 2.5) {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.system(size: 7, weight: .bold))
                        Text("Sign In")
                            .font(.system(size: 7.5, weight: .bold))
                    }
                    .foregroundColor(theme.activePillText)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(theme.activePillBackground)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("Sign in to your YouTube Music account")
            } else {
                Button(action: {
                    media.openPlayerWindow()
                }) {
                    HStack(spacing: 2) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 6.5))
                        Text("Synced")
                            .font(.system(size: 7, weight: .semibold))
                    }
                    .foregroundColor(theme.textPrimary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1.5)
                    .background(theme.cardBackgroundElevated)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("Open YouTube Music Engine Window")
            }
        }
    }
    
    // 2. Timeline Scrubber
    private var timelineScrubberRow: some View {
        let activeBar = isHoveringTimeline || isScrubbing
        let barHeight: CGFloat = activeBar ? 5 : 3
        return VStack(spacing: 2) {
            GeometryReader { geo in
                let fillWidth = max(0, min(geo.size.width, geo.size.width * CGFloat(effectiveProgress)))
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(theme.dialTrack)
                        .frame(height: barHeight)
                    
                    Capsule()
                        .fill(theme.focusAccent)
                        .frame(width: fillWidth, height: barHeight)
                    
                    if activeBar {
                        Circle()
                            .fill(theme.focusAccent)
                            .frame(width: 7, height: 7)
                            .offset(x: max(0, min(geo.size.width - 7, fillWidth - 3.5)))
                    }
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isHoveringTimeline = hovering
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !isScrubbing {
                                isScrubbing = true
                                MorphHaptics.alignment()
                            }
                            let fraction = max(0, min(1, Double(value.location.x / geo.size.width)))
                            scrubFraction = fraction
                        }
                        .onEnded { value in
                            let fraction = max(0, min(1, Double(value.location.x / geo.size.width)))
                            media.seek(to: fraction)
                            isScrubbing = false
                            MorphHaptics.alignment()
                        }
                )
            }
            .frame(height: 8)
            
            HStack {
                Text(effectiveCurrentTime)
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundColor(theme.textTertiary)
                
                Spacer()
                
                // Live 3-bar mini visualizer
                HStack(alignment: .bottom, spacing: 1.5) {
                    ForEach(0..<3, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 0.5)
                            .fill(theme.textPrimary)
                            .frame(width: 1.8, height: max(2, 7 * media.visualizerBars[i]))
                    }
                }
                .frame(height: 7, alignment: .bottom)
                
                Spacer()
                
                Text(media.formattedDuration)
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundColor(theme.textTertiary)
            }
        }
    }
    
    // 3. Transport Controls (Dead-Center Symmetrical Alignment)
    private var transportControlsRow: some View {
        HStack(spacing: 7) {
            Spacer(minLength: 0)
            
            Button(action: {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                    media.toggleShuffle()
                }
            }) {
                ZStack(alignment: .bottomTrailing) {
                    Image(systemName: "shuffle")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundColor(media.isShuffle ? theme.textPrimary : theme.textTertiary)
                    
                    if media.isShuffle {
                        Circle()
                            .fill(theme.focusAccent)
                            .frame(width: 3.5, height: 3.5)
                            .offset(x: 1, y: 1)
                    }
                }
                .frame(width: 19, height: 19)
                .background(media.isShuffle ? theme.cardBackgroundElevated : theme.cardBackground)
                .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help(media.isShuffle ? "Random Next On / Shuffle (S)" : "Random Next Off / Shuffle (S)")
            .accessibilityLabel("Shuffle and Random Next")
            .accessibilityHint("Shortcut: S. Toggles random shuffle playback.")
            
            Button(action: {
                media.previousTrack()
            }) {
                Image(systemName: "backward.fill")
                    .font(.system(size: 8.5, weight: .semibold))
                    .foregroundColor(theme.textPrimary)
                    .frame(width: 21, height: 21)
                    .background(theme.cardBackgroundElevated)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Previous Track (F7, ⇧P, ⌘[, ⌘←)")
            .accessibilityLabel("Previous Track")
            .accessibilityHint("Shortcut: F7, Shift+P, Command+[, or Command+Left Arrow. Returns to the previous track.")
            
            Button(action: {
                media.togglePlay()
            }) {
                Image(systemName: media.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundColor(theme.activePillText)
                    .frame(width: 28, height: 28)
                    .background(theme.activePillBackground)
                    .clipShape(Circle())
                    .shadow(color: theme.isDark ? Color.white.opacity(0.25) : Color.black.opacity(0.15), radius: 3, x: 0, y: 1)
            }
            .buttonStyle(.plain)
            .help(media.isPlaying ? "Pause Music (F8, Space, K, ⌘⏎)" : "Play Music (F8, Space, K, ⌘⏎)")
            .accessibilityLabel(media.isPlaying ? "Pause Music" : "Play Music")
            .accessibilityHint("Shortcut: F8, Space, K, or Command+Return. Toggles music playback.")
            
            Button(action: {
                media.nextTrack()
            }) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 8.5, weight: .semibold))
                    .foregroundColor(theme.textPrimary)
                    .frame(width: 21, height: 21)
                    .background(theme.cardBackgroundElevated)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help(media.isShuffle ? "Random Next Track (F9, ⇧N, ⌘], ⌘→)" : "Next Track (F9, ⇧N, ⌘], ⌘→)")
            .accessibilityLabel("Next Track")
            .accessibilityHint("Shortcut: F9, Shift+N, Command+], or Command+Right Arrow. Skips to next track.")
            
            Button(action: {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                    media.toggleRepeat()
                }
            }) {
                ZStack(alignment: .bottomTrailing) {
                    Image(systemName: media.repeatMode.iconName)
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundColor(media.repeatMode != .off ? theme.textPrimary : theme.textTertiary)
                    
                    if media.repeatMode == .all {
                        Circle()
                            .fill(theme.focusAccent)
                            .frame(width: 3.5, height: 3.5)
                            .offset(x: 1, y: 1)
                    }
                }
                .frame(width: 19, height: 19)
                .background(media.repeatMode != .off ? theme.cardBackgroundElevated : theme.cardBackground)
                .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Loop: \(media.repeatMode.hudTitle) (R, ⌘⇧R - Click to cycle, right-click to choose)")
            .accessibilityLabel("Loop Mode: \(media.repeatMode.hudTitle)")
            .accessibilityHint("Shortcut: R or Command+Shift+R. Cycles between loop off, loop playlist, and loop single track.")
            .contextMenu {
                Button(action: { media.setRepeatMode(.off) }) {
                    Label("Loop Off", systemImage: media.repeatMode == .off ? "checkmark" : "")
                }
                Button(action: { media.setRepeatMode(.all) }) {
                    Label("Loop All (Playlist & Queue)", systemImage: media.repeatMode == .all ? "checkmark" : "")
                }
                Button(action: { media.setRepeatMode(.one) }) {
                    Label("Loop Current Track", systemImage: media.repeatMode == .one ? "checkmark" : "")
                }
            }
            
            Button(action: {
                media.stop()
            }) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(theme.textTertiary)
                    .frame(width: 19, height: 19)
                    .background(theme.cardBackground)
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
        let activeVolumeBar = isHoveringVolume || isScrubbingVolume
        let barHeight: CGFloat = activeVolumeBar ? 5 : 3
        let effectiveVolume = media.isMuted ? 0 : media.volume
        return HStack(spacing: 6) {
            Button(action: {
                media.toggleMute()
            }) {
                Image(systemName: media.isMuted ? "speaker.slash.fill" : (media.volume > 0.5 ? "speaker.wave.2.fill" : "speaker.wave.1.fill"))
                    .font(.system(size: 9))
                    .foregroundColor(media.isMuted ? theme.textTertiary : theme.textSecondary)
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.plain)
            .help(media.isMuted ? "Unmute (⌘U)" : "Mute (⌘U)")
            
            GeometryReader { geo in
                let fillWidth = max(0, min(geo.size.width, geo.size.width * CGFloat(effectiveVolume)))
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(theme.dialTrack)
                        .frame(height: barHeight)
                    
                    Capsule()
                        .fill(media.isMuted ? theme.textTertiary : theme.focusAccent)
                        .frame(width: fillWidth, height: barHeight)
                    
                    if activeVolumeBar {
                        Circle()
                            .fill(media.isMuted ? theme.textTertiary : theme.focusAccent)
                            .frame(width: 7, height: 7)
                            .offset(x: max(0, min(geo.size.width - 7, fillWidth - 3.5)))
                    }
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isHoveringVolume = hovering
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !isScrubbingVolume {
                                isScrubbingVolume = true
                                MorphHaptics.alignment()
                            }
                            let fraction = max(0, min(1, Double(value.location.x / geo.size.width)))
                            media.setVolume(fraction)
                        }
                        .onEnded { value in
                            let fraction = max(0, min(1, Double(value.location.x / geo.size.width)))
                            media.setVolume(fraction)
                            isScrubbingVolume = false
                            MorphHaptics.alignment()
                        }
                )
            }
            .frame(height: 8)
            
            Text("\(Int(effectiveVolume * 100))%")
                .font(.system(size: 7.5, weight: .medium, design: .monospaced))
                .foregroundColor(theme.textTertiary)
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
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(theme.liquidGlassCard)
                .background(.ultraThinMaterial)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(theme.liquidGlassSpecularBorder, lineWidth: 1)
        )
    }
    
    // MARK: - YouTube Music Hub Top Bar
    private var hubTopNavigationBar: some View {
        HStack(spacing: 3) {
            // YTM Brand Icon & Badge
            HStack(spacing: 3) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundColor(theme.textPrimary)
                Text("Music")
                    .font(.system(size: 8.5, weight: .heavy, design: .rounded))
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(1)
                
                if media.isOffline {
                    HStack(spacing: 2) {
                        Image(systemName: "wifi.slash")
                            .font(.system(size: 6, weight: .bold))
                        Text("OFFLINE")
                            .font(.system(size: 6, weight: .heavy, design: .monospaced))
                    }
                    .foregroundColor(theme.textSecondary)
                    .padding(.horizontal, 3.5)
                    .padding(.vertical, 1)
                    .background(theme.badgeBackground)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(theme.activeBorder, lineWidth: 0.5)
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
                        .foregroundColor(isSelected ? theme.activePillText : theme.textSecondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(isSelected ? theme.activePillBackground : theme.cardBackground)
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
            if !media.isSignedIn {
                HStack(spacing: 5) {
                    Image(systemName: "person.crop.circle.badge.exclamationmark")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundColor(theme.textPrimary)
                    Text("Sign in to sync your YouTube Music playlists & mixes")
                        .font(.system(size: 7.5, weight: .medium, design: .rounded))
                        .foregroundColor(theme.textSecondary)
                        .lineLimit(1)
                    Spacer(minLength: 2)
                    Button(action: {
                        media.openSignIn()
                    }) {
                        Text("Sign In")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(theme.activePillText)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(theme.activePillBackground)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("Sign in to YouTube Music in Morph")
                    
                    Button(action: {
                        media.syncSessionFromBrowser()
                    }) {
                        Text("Sync")
                            .font(.system(size: 7, weight: .semibold))
                            .foregroundColor(theme.textPrimary)
                            .padding(.horizontal, 5.5)
                            .padding(.vertical, 2)
                            .background(theme.cardBackgroundElevated)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("Sync existing YouTube Music session from browser")
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(theme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(theme.hairlineBorder, lineWidth: 0.5)
                )
            }
            
            // Header Row
            HStack(spacing: 4) {
                HStack(spacing: 3) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(theme.textPrimary)
                    Text("Quick Picks")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(theme.textPrimary)
                        .lineLimit(1)
                }
                
                Text(media.isSignedIn ? "Personalized" : "Recommended")
                    .font(.system(size: 7, weight: .regular))
                    .foregroundColor(theme.textTertiary)
                    .lineLimit(1)
                
                Spacer(minLength: 4)
                
                Button(action: {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        media.refreshQuickPicks()
                        if media.isSignedIn {
                            media.refreshPlaylists()
                        }
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 7.5, weight: .bold))
                        .foregroundColor(theme.textSecondary)
                        .frame(width: 16, height: 16)
                        .background(theme.cardBackgroundElevated)
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
                    Text("Loading recommendations...")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(theme.textSecondary)
                    Spacer(minLength: 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if media.quickPicks.isEmpty {
                VStack(spacing: 4) {
                    Spacer(minLength: 8)
                    Image(systemName: "sparkles")
                        .font(.system(size: 12))
                        .foregroundColor(theme.textTertiary)
                    Text("No recommendations found")
                        .font(.system(size: 8.5, weight: .bold, design: .rounded))
                        .foregroundColor(theme.textPrimary)
                    Text("Listen to music to seed your algorithm or click Refresh.")
                        .font(.system(size: 7, weight: .regular))
                        .foregroundColor(theme.textSecondary)
                        .multilineTextAlignment(.center)
                    Button(action: { media.refreshQuickPicks() }) {
                        Text("Refresh Picks")
                            .font(.system(size: 7.5, weight: .bold))
                            .foregroundColor(theme.activePillText)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2.5)
                            .background(theme.activePillBackground)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    Spacer(minLength: 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(spacing: 2.5) {
                        ForEach(media.quickPicks) { track in
                            quickPickDetailedRow(track: track)
                        }
                    }
                    .padding(.trailing, 2)
                }
                .frame(maxHeight: .infinity)
            }
        }
    }
    
    private func quickPickDetailedRow(track: YTMPlaylistItem) -> some View {
        let isCurrent = media.isSongCurrent(track, in: media.quickPicks)
        let isPaused = media.isSongPausedCurrent(track, in: media.quickPicks)
        let isActive = isCurrent || isPaused
        let titleWeight: Font.Weight = isActive ? .bold : .medium
        let titleColor = theme.textPrimary
        let artistColor = isActive ? theme.textSecondary : theme.textTertiary
        let durationColor = theme.textTertiary
        let strokeColor = isCurrent ? theme.activeBorder : (isPaused ? theme.hairlineBorder : Color.clear)
        let bgColor = isCurrent ? theme.cardBackgroundElevated : (isPaused ? theme.cardBackground : theme.cardBackgroundSubtle)
        
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
                                .fill(theme.textPrimary)
                                .frame(width: 1.8, height: max(2, 8 * media.visualizerBars[i]))
                        }
                    }
                    .frame(width: 14, height: 10, alignment: .bottom)
                    .padding(.horizontal, 2)
                } else if isPaused {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 8))
                        .foregroundColor(theme.textPrimary)
                        .padding(.horizontal, 2)
                } else {
                    HStack(spacing: 2.5) {
                        Image(systemName: "radiowaves.right")
                            .font(.system(size: 7, weight: .bold))
                        Text("Radio")
                            .font(.system(size: 7.5, weight: .semibold))
                    }
                    .foregroundColor(theme.textSecondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2.5)
                    .background(theme.cardBackgroundElevated)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(theme.hairlineBorder, lineWidth: 0.5)
                    )
                }
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3.5)
            .background(bgColor)
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
                        .foregroundColor(theme.textPrimary)
                    Text("YouTube Music Offline")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(theme.textPrimary)
                        .lineLimit(1)
                }
                
                Text("• \(media.downloadedTracks.count) cached tracks")
                    .font(.system(size: 7, weight: .regular))
                    .foregroundColor(theme.textTertiary)
                    .lineLimit(1)
                
                Spacer(minLength: 4)
            }
            
            // Reassurance / Zero-Latency Banner
            HStack(spacing: 4) {
                Image(systemName: "bolt.shield.fill")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(theme.textSecondary)
                
                Text("Offline Cache • Zero-latency playback from your YouTube Music")
                    .font(.system(size: 7, weight: .medium))
                    .foregroundColor(theme.textSecondary)
                    .lineLimit(1)
                
                Spacer(minLength: 2)
            }
            .padding(.horizontal, 5)
            .padding(.vertical, 2.5)
            .background(theme.cardBackgroundSubtle)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            
            if media.downloadedTracks.isEmpty {
                VStack(spacing: 4) {
                    Spacer(minLength: 8)
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 13))
                        .foregroundColor(theme.textTertiary)
                    Text("No YouTube Music songs cached yet")
                        .font(.system(size: 8.5, weight: .bold, design: .rounded))
                        .foregroundColor(theme.textPrimary)
                    Text("Play songs while connected to Wi-Fi to automatically cache them for offline listening.")
                        .font(.system(size: 7, weight: .regular))
                        .foregroundColor(theme.textSecondary)
                        .multilineTextAlignment(.center)
                    Spacer(minLength: 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(spacing: 2.5) {
                        ForEach(media.downloadedTracks) { track in
                            downloadedTrackRow(track: track)
                        }
                    }
                    .padding(.trailing, 2)
                }
                .frame(maxHeight: .infinity)
            }
        }
    }
    
    private func downloadedTrackRow(track: YTMPlaylistItem) -> some View {
        let isCurrent = media.isPlaying && media.trackTitle == track.title
        let isPaused = !media.isPlaying && media.trackTitle == track.title && media.currentTime > 0
        let isActive = isCurrent || isPaused
        let titleWeight: Font.Weight = isActive ? .bold : .medium
        let titleColor = theme.textPrimary
        let artistColor = isActive ? theme.textSecondary : theme.textTertiary
        let durationColor = theme.textTertiary
        let strokeColor = isCurrent ? theme.activeBorder : (isPaused ? theme.hairlineBorder : Color.clear)
        let bgColor = isCurrent ? theme.cardBackgroundElevated : (isPaused ? theme.cardBackground : theme.cardBackgroundSubtle)
        
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
                                .fill(theme.textPrimary)
                                .frame(width: 1.8, height: max(2, 7 * media.visualizerBars[i]))
                        }
                    }
                    .frame(width: 12, height: 8, alignment: .bottom)
                    .padding(.horizontal, 2)
                } else if isPaused {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 7.5))
                        .foregroundColor(theme.textPrimary)
                        .padding(.horizontal, 2)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3.5)
            .background(bgColor)
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
                    Text("Syncing your YouTube Music playlists...")
                        .font(.system(size: 8.5, weight: .medium))
                        .foregroundColor(theme.textSecondary)
                    Spacer(minLength: 12)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if media.playlists.isEmpty {
                VStack(spacing: 5) {
                    Spacer(minLength: 6)
                    Image(systemName: "music.note.list")
                        .font(.system(size: 14))
                        .foregroundColor(theme.textTertiary)
                    Text(media.isSignedIn ? "No Custom Playlists Found" : "Connect YouTube Music")
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .foregroundColor(theme.textPrimary)
                    Text(media.libraryError
                         ?? (media.isSignedIn
                             ? "You are signed in! Create playlists on YouTube Music or click Sync to refresh."
                             : "Sign in to YouTube Music to load your playlists, liked songs, and mixes directly inside Morph."))
                        .font(.system(size: 7.5, weight: .regular))
                        .foregroundColor(theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 10)
                    
                    if let statusMsg = media.browserAuthStatusMessage {
                        Text(statusMsg)
                            .font(.system(size: 7, weight: .medium))
                            .foregroundColor(theme.textPrimary)
                            .multilineTextAlignment(.center)
                            .lineLimit(1)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(theme.cardBackgroundElevated)
                            .clipShape(Capsule())
                    }
                    
                    HStack(spacing: 5) {
                        if !media.isSignedIn {
                            Button(action: {
                                media.openSignIn()
                            }) {
                                HStack(spacing: 3) {
                                    Image(systemName: "person.crop.circle.badge.plus")
                                        .font(.system(size: 8))
                                    Text("Sign In")
                                        .font(.system(size: 8, weight: .bold))
                                }
                                .foregroundColor(theme.activePillText)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(theme.activePillBackground)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .help("Sign in to YouTube Music directly in Morph")
                            
                            Button(action: {
                                media.openSignInInBrowser()
                            }) {
                                HStack(spacing: 3) {
                                    Image(systemName: "safari")
                                        .font(.system(size: 8))
                                    Text("Browser")
                                        .font(.system(size: 8, weight: .medium))
                                }
                                .foregroundColor(theme.textPrimary)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(theme.cardBackgroundElevated)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .help("Opens Google / YouTube Music sign-in tab in your browser")
                            
                            Button(action: {
                                media.syncSessionFromBrowser()
                            }) {
                                HStack(spacing: 3) {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.system(size: 7.5))
                                    Text("Sync")
                                        .font(.system(size: 8, weight: .medium))
                                }
                                .foregroundColor(theme.textPrimary)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(theme.cardBackgroundElevated)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .help("Detects signed-in YouTube Music tab in Chrome/Safari and syncs session")
                        } else {
                            Button(action: {
                                media.refreshPlaylists()
                                media.refreshQuickPicks()
                            }) {
                                HStack(spacing: 3) {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 8))
                                    Text("Sync Library")
                                        .font(.system(size: 8.5, weight: .bold))
                                }
                                .foregroundColor(theme.activePillText)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3.5)
                                .background(theme.activePillBackground)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 2)
                    
                    Spacer(minLength: 6)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(spacing: 4) {
                        // Quick Entry: Algorithmic Quick Picks recommendations
                        quickPicksPlaylistCardRow
                        
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
                .frame(maxHeight: .infinity)
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
                .foregroundColor(theme.textPrimary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2.5)
                .background(theme.cardBackgroundElevated)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .help("Back to Music Hub")
            
            Text("PLAYLISTS")
                .font(.system(size: 9, weight: .heavy, design: .rounded))
                .foregroundColor(theme.textPrimary)
                .tracking(0.5)
            
            Text("\(media.filteredPlaylists.count)")
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .foregroundColor(theme.textSecondary)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(theme.cardBackground)
                .clipShape(Capsule())
            
            Spacer()
            
            // Refresh Button
            Button(action: {
                media.refreshPlaylists()
            }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 8.5))
                    .foregroundColor(theme.textSecondary)
                    .frame(width: 18, height: 18)
                    .background(theme.cardBackground)
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
                    .foregroundColor(media.isSearchingPlaylists ? theme.textPrimary : theme.textSecondary)
                    .frame(width: 18, height: 18)
                    .background(media.isSearchingPlaylists ? theme.cardBackgroundElevated : theme.cardBackground)
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
                .foregroundColor(theme.textSecondary)
            
            TextField("Search songs, artists, albums...", text: $media.playlistSearchQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 9.5, weight: .medium, design: .rounded))
                .foregroundColor(theme.textPrimary)
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
            } else if !media.playlistSearchQuery.isEmpty {
                Button(action: { media.clearPlaylistSearch() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 8.5))
                        .foregroundColor(theme.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3.5)
        .background(theme.surfaceInset)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(theme.hairlineBorder, lineWidth: 0.5)
        )
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
                        Text("Searching YouTube Music...")
                            .font(.system(size: 8.5, weight: .medium))
                            .foregroundColor(theme.textSecondary)
                    }
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                } else if media.searchResults.isEmpty, let err = media.catalogSearchError {
                    Text(err)
                        .font(.system(size: 8.5, weight: .medium))
                        .foregroundColor(theme.textSecondary)
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
        .frame(maxHeight: .infinity)
    }
    
    private func searchSectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 7.5, weight: .heavy, design: .rounded))
            .tracking(0.6)
            .foregroundColor(theme.textTertiary)
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
                        .foregroundColor(theme.textPrimary)
                        .lineLimit(1)
                    if !result.subtitle.isEmpty {
                        Text(result.subtitle)
                            .font(.system(size: 8, weight: .regular))
                            .foregroundColor(theme.textSecondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer(minLength: 4)
                
                Image(systemName: (result.kind == .song || result.kind == .video) ? "play.fill" : "chevron.right")
                    .font(.system(size: 7.5, weight: .bold))
                    .foregroundColor(theme.textTertiary)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3.5)
            .background(theme.cardBackgroundSubtle)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(theme.hairlineBorder, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .help(result.kind == .song || result.kind == .video ? "Play \(result.title)" : "Open \(result.title)")
    }
    
    private func artworkThumb(url: String?, size: CGFloat, circle: Bool = false, fallbackIcon: String) -> some View {
        let shape = RoundedRectangle(cornerRadius: circle ? size / 2 : 6, style: .continuous)
        return ZStack {
            shape
                .fill(theme.cardBackground)
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
                            .foregroundColor(theme.textSecondary)
                    }
                }
            } else {
                Image(systemName: fallbackIcon)
                    .font(.system(size: size * 0.38, weight: .bold))
                    .foregroundColor(theme.textSecondary)
            }
        }
        .frame(width: size, height: size)
    }
    
    private var quickPicksPlaylistCardRow: some View {
        Button(action: {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                media.openQuickPicksPlaylist()
            }
        }) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(theme.cardBackgroundElevated)
                        .frame(width: 26, height: 26)
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(theme.textPrimary)
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    Text("Quick Picks")
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .foregroundColor(theme.textPrimary)
                        .lineLimit(1)
                    
                    Text("\(media.quickPicks.count) recommendations • Start radio")
                        .font(.system(size: 8, weight: .regular))
                        .foregroundColor(theme.textSecondary)
                        .lineLimit(1)
                }
                
                Spacer(minLength: 4)
                
                HStack(spacing: 4) {
                    Text("\(media.quickPicks.count)")
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundColor(theme.textTertiary)
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(theme.textTertiary)
                }
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(theme.cardBackgroundSubtle)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(theme.hairlineBorder, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .help("Open Quick Picks recommendations")
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
                        .fill(theme.cardBackgroundElevated)
                        .frame(width: 26, height: 26)
                    Image(systemName: "waveform")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(theme.textPrimary)
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    Text("Now Playing Queue")
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .foregroundColor(theme.textPrimary)
                        .lineLimit(1)
                    
                    Text("\(media.effectivePlaylist.count) tracks in live queue")
                        .font(.system(size: 8, weight: .regular))
                        .foregroundColor(theme.textSecondary)
                        .lineLimit(1)
                }
                
                Spacer(minLength: 4)
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(theme.textTertiary)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(theme.hairlineBorder, lineWidth: 0.5)
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
                        .foregroundColor(theme.textPrimary)
                        .lineLimit(1)
                    
                    Text(playlist.subtitle.isEmpty ? (playlist.tracks.isEmpty ? "Playlist" : "\(playlist.tracks.count) tracks") : playlist.subtitle)
                        .font(.system(size: 8, weight: .regular))
                        .foregroundColor(theme.textSecondary)
                        .lineLimit(1)
                }
                
                Spacer(minLength: 4)
                
                HStack(spacing: 4) {
                    if !playlist.tracks.isEmpty {
                        Text("\(playlist.tracks.count)")
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .foregroundColor(theme.textTertiary)
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(theme.textTertiary)
                }
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(theme.cardBackgroundSubtle)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(theme.hairlineBorder, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .help("Open \(playlist.title)")
    }
    
    private func playlistIconBadge(for playlist: YTMPlaylist) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(theme.cardBackground)
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
        let isMix = playlist.id == "pl_supermix" || playlist.id == "pl_quickpicks" || playlist.title.lowercased().contains("mix") || playlist.title.lowercased().contains("quick pick")
        let iconName = isLiked ? "heart.fill" : (isMix ? "sparkles" : "music.note.list")
        return Image(systemName: iconName)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(isLiked ? theme.textPrimary : theme.textSecondary)
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
                                ProgressView().scaleEffect(0.45).frame(width: 10, height: 10)
                                Text("Loading more...")
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundColor(theme.textTertiary)
                            }
                            .padding(.vertical, 4)
                        }
                        
                        // Algorithmic Quick Picks recommendation shelf inside playlist (Native YouTube Music style)
                        if playlist.id != "pl_quickpicks" && !media.quickPicks.isEmpty {
                            playlistQuickPicksShelf(for: playlist)
                        }
                    }
                    .padding(.trailing, 2)
                }
            }
            .frame(maxHeight: .infinity)
        }
    }
    
    private func playlistQuickPicksShelf(for playlist: YTMPlaylist) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                HStack(spacing: 3) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 7.5, weight: .bold))
                        .foregroundColor(theme.textPrimary)
                    Text("Quick Picks")
                        .font(.system(size: 8.5, weight: .bold, design: .rounded))
                        .foregroundColor(theme.textPrimary)
                        .lineLimit(1)
                }
                
                Text("• Suggestions based on this playlist")
                    .font(.system(size: 7, weight: .regular))
                    .foregroundColor(theme.textTertiary)
                    .lineLimit(1)
                
                Spacer(minLength: 4)
                
                Button(action: {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        media.refreshQuickPicks()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(theme.textSecondary)
                        .frame(width: 14, height: 14)
                        .background(theme.cardBackgroundElevated)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Refresh Quick Picks suggestions")
            }
            .padding(.horizontal, 4)
            .padding(.top, 6)
            .padding(.bottom, 2)
            
            ForEach(media.quickPicks.prefix(5)) { pick in
                quickPickDetailedRow(track: pick)
            }
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
                Text("Loading songs from YouTube Music...")
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundColor(theme.textSecondary)
            } else if !query.isEmpty && !playlist.tracks.isEmpty {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundColor(theme.textTertiary)
                Text("No songs match \"\(query)\"")
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundColor(theme.textSecondary)
                Button(action: {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                        media.searchYouTubeMusic(for: query)
                    }
                }) {
                    Text("Search YouTube Music")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundColor(theme.activePillText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(theme.activePillBackground)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 14))
                    .foregroundColor(theme.textTertiary)
                Text(media.tracksError ?? "No songs found in this playlist")
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundColor(theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                if playlist.id != "pl_queue" {
                    HStack(spacing: 6) {
                        Button(action: { media.loadTracksForSelectedPlaylist() }) {
                            HStack(spacing: 3) {
                                Image(systemName: "arrow.clockwise").font(.system(size: 8))
                                Text("Retry").font(.system(size: 8.5, weight: .semibold))
                            }
                            .foregroundColor(theme.textPrimary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(theme.cardBackgroundElevated)
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
                                .foregroundColor(theme.activePillText)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(theme.activePillBackground)
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
                .foregroundColor(theme.textPrimary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2.5)
                .background(theme.cardBackgroundElevated)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .help(media.rightDeckSection == .queue || playlist.id == "pl_queue" ? "Back to Previous View" : "Back to Playlist Selection")
            
            Text(playlist.title)
                .font(.system(size: 9, weight: .heavy, design: .rounded))
                .foregroundColor(theme.textPrimary)
                .lineLimit(1)
            
            if !playlist.tracks.isEmpty {
                Text("\(playlist.tracks.count)")
                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                    .foregroundColor(theme.textSecondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1.5)
                    .background(theme.cardBackground)
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
                .foregroundColor(theme.activePillText)
                .padding(.horizontal, 6)
                .padding(.vertical, 2.5)
                .background(theme.activePillBackground)
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
                    .foregroundColor(media.isSearchingSongs ? theme.textPrimary : theme.textSecondary)
                    .frame(width: 18, height: 18)
                    .background(media.isSearchingSongs ? theme.cardBackgroundElevated : theme.cardBackground)
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
                .foregroundColor(theme.textSecondary)
            
            TextField("Search in this playlist...", text: $media.songSearchQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 9.5, weight: .medium, design: .rounded))
                .foregroundColor(theme.textPrimary)
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
                        .foregroundColor(theme.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3.5)
        .background(theme.surfaceInset)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(theme.hairlineBorder, lineWidth: 0.5)
        )
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
                                    .fill(theme.textPrimary)
                                    .frame(width: 1.8, height: max(2, 8 * media.visualizerBars[barIdx]))
                            }
                        }
                        .frame(width: 14, height: 10, alignment: .bottom)
                    } else if isPausedSong {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 7.5))
                            .foregroundColor(theme.textPrimary)
                            .frame(width: 14)
                    } else if let thumb = song.thumbnailURL {
                        artworkThumb(url: thumb, size: 20, fallbackIcon: "music.note")
                    } else {
                        Text("\(index + 1)")
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .foregroundColor(theme.textTertiary)
                            .frame(width: 14)
                    }
                }
                
                // Title & Artist
                VStack(alignment: .leading, spacing: 1) {
                    Text(song.title)
                        .font(.system(size: 9.5, weight: (isCurrentSong || isPausedSong) ? .bold : .medium, design: .rounded))
                        .foregroundColor(theme.textPrimary)
                        .lineLimit(1)
                    
                    if !song.artist.isEmpty {
                        Text(song.artist)
                            .font(.system(size: 8, weight: .regular))
                            .foregroundColor((isCurrentSong || isPausedSong) ? theme.textSecondary : theme.textTertiary)
                            .lineLimit(1)
                    }
                }
                
                Spacer(minLength: 4)
                
                // Track Duration & Quick Actions
                HStack(spacing: 4) {
                    Button(action: {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                            media.playNext(song)
                        }
                    }) {
                        Image(systemName: "text.line.first.and.arrowtriangle.forward")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(theme.textTertiary)
                            .frame(width: 14, height: 14)
                            .background(theme.cardBackgroundElevated.opacity(0.6))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Play Next")

                    if !song.duration.isEmpty {
                        Text(song.duration)
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .foregroundColor(theme.textTertiary)
                    }
                }
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(isCurrentSong ? theme.cardBackgroundElevated : (isPausedSong ? theme.cardBackground : theme.cardBackgroundSubtle))
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(isCurrentSong ? theme.activeBorder : (isPausedSong ? theme.hairlineBorder : Color.clear), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .help("Play \(song.title)")
        .contextMenu {
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    media.playSongInSelectedPlaylist(song)
                }
            }) {
                Label("Play Now", systemImage: "play.fill")
            }
            Button(action: {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                    media.playNext(song)
                }
            }) {
                Label("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward")
            }
        }
    }
    
    private var defaultArtPlaceholder: some View {
        VStack(spacing: 2) {
            Image(systemName: "music.note")
                .font(.system(size: 20))
                .foregroundColor(theme.textSecondary)
        }
    }
}
