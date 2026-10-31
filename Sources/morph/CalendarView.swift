import SwiftUI
import WebKit

public struct CalendarView: View {
    @ObservedObject var calendar: CalendarModel
    @ObservedObject public var theme: MorphTheme = .shared
    @State private var newEventTitle: String = ""
    @State private var newEventDurationMinutes: Int = 30
    @State private var newEventHour: Int = 14
    @State private var newEventMinute: Int = 0
    @State private var newEventIsAllDay: Bool = false
    @State private var newEventHasMeet: Bool = true
    @State private var newEventLocation: String = ""
    @State private var selectedCalendarId: String = "primary"
    @State private var isSubmittingEvent: Bool = false
    @State private var showNotificationSettings: Bool = false
    @State private var deletingEventID: String? = nil
    @State private var hoveredDay: Date? = nil
    public var meetingController: MeetingFlightControllerModel?
    public var onTakeCall: ((CalendarEvent) -> Void)?
    
    public init(
        calendar: CalendarModel,
        meetingController: MeetingFlightControllerModel? = nil,
        theme: MorphTheme? = nil,
        onTakeCall: ((CalendarEvent) -> Void)? = nil
    ) {
        self.calendar = calendar
        self.meetingController = meetingController
        self.theme = theme ?? .shared
        self.onTakeCall = onTakeCall
    }
    
    private func resolvedMeetingURL(for event: CalendarEvent) -> URL? {
        if let link = event.meetLink?.trimmingCharacters(in: .whitespacesAndNewlines),
           let url = URL(string: link), url.scheme != nil {
            return url
        }
        if let loc = event.location {
            let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
            let matches = detector?.matches(in: loc, options: [], range: NSRange(location: 0, length: loc.utf16.count))
            for match in matches ?? [] {
                if let u = match.url { return u }
            }
        }
        if !event.description.isEmpty {
            let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
            let matches = detector?.matches(in: event.description, options: [], range: NSRange(location: 0, length: event.description.utf16.count))
            for match in matches ?? [] {
                if let u = match.url { return u }
            }
        }
        return nil
    }
    
    private func triggerTakeCall(event: CalendarEvent) {
        if let onTakeCall = onTakeCall {
            onTakeCall(event)
            return
        }
        if let controller = meetingController {
            _ = controller.openMeetLink(event: event, inApp: true)
            return
        }
        if let url = resolvedMeetingURL(for: event) {
            calendar.engine.openMeet(link: url.absoluteString)
        }
    }
    
    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Left Deck: Month Calendar & Intelligent Sync Hub (265 pt)
            leftMonthDeck
                .frame(width: 265)
                .frame(maxHeight: .infinity)
            
            // Right Deck: Agenda & Fast Action Hub (345 pt)
            rightAgendaDeck
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Left Deck (Full Month Grid & Status Footer)
    private var leftMonthDeck: some View {
        VStack(alignment: .leading, spacing: 3) {
            // Month Header with Nav Buttons
            HStack(spacing: 4) {
                Text(monthYearString(for: calendar.displayedMonth))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(theme.textPrimary)
                
                Spacer()
                
                HStack(spacing: 3) {
                    Button(action: { calendar.previousMonth() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(theme.textSecondary)
                            .frame(width: 18, height: 18)
                            .background(theme.cardBackgroundElevated)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Previous Month")
                    
                    Button(action: { calendar.goToToday() }) {
                        Text("Today")
                            .font(.system(size: 7.5, weight: .bold))
                            .foregroundColor(theme.activePillText)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(theme.activePillBackground)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("Jump to Today")
                    
                    Button(action: { calendar.nextMonth() }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(theme.textSecondary)
                            .frame(width: 18, height: 18)
                            .background(theme.cardBackgroundElevated)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Next Month")
                }
            }
            .padding(.bottom, 1)
            
            // Day of Week Header (M T W T F S S)
            let weekdays = ["M", "T", "W", "T", "F", "S", "S"]
            HStack(spacing: 0) {
                ForEach(Array(weekdays.enumerated()), id: \.offset) { _, day in
                    Text(day)
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundColor(theme.textTertiary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 0.5)
            
            // 7-Column Full Month Calendar Grid (All 6 rows 100% visible)
            calendarGrid
            
            Spacer(minLength: 0)
            
            // Footer: User Email / Status, Selected Day Count & Quick Sync
            HStack(spacing: 4) {
                if let email = calendar.configuredUserEmail, !email.isEmpty {
                    Text(email)
                        .font(.system(size: 7, weight: .medium))
                        .foregroundColor(theme.textTertiary)
                        .lineLimit(1)
                } else {
                    Text(calendar.isSignedIn ? "Google Calendar" : "Local Calendar")
                        .font(.system(size: 7, weight: .medium))
                        .foregroundColor(theme.textTertiary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                let count = calendar.eventsForSelectedDate.count
                Text(count == 0 ? "No events" : "\(count) \(count == 1 ? "event" : "events")")
                    .font(.system(size: 7, weight: .medium, design: .monospaced))
                    .foregroundColor(theme.textTertiary)
                
                Button(action: { calendar.syncWithGoogle() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(theme.textSecondary)
                        .rotationEffect(.degrees(calendar.isSyncing ? 360 : 0))
                        .animation(calendar.isSyncing ? Animation.linear(duration: 0.9).repeatForever(autoreverses: false) : .default, value: calendar.isSyncing)
                }
                .buttonStyle(.plain)
                .help("Sync Calendar Events Now")
            }
            .padding(.top, 1)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .frame(maxHeight: .infinity)
        .background(theme.canvasSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(theme.hairlineBorder, lineWidth: 1)
        )
    }
    
    // MARK: - Calendar Grid
    private var calendarGrid: some View {
        let days = generateDaysInMonth(for: calendar.displayedMonth)
        let cal = Calendar.current
        
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 1.5), count: 7), spacing: 1.5) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, date in
                if let date = date {
                    let isSelected = cal.isDate(date, inSameDayAs: calendar.selectedDate)
                    let isToday = cal.isDateInToday(date)
                    let isHovered = hoveredDay.map { cal.isDate($0, inSameDayAs: date) } ?? false
                    let hasEvents = !calendar.eventsForDate(date).isEmpty
                    
                    Button(action: {
                        calendar.selectedDate = date
                    }) {
                        VStack(spacing: 0.5) {
                            Text("\(cal.component(.day, from: date))")
                                .font(.system(size: 8, weight: (isToday || isSelected) ? .bold : .medium))
                                .foregroundColor(isSelected ? theme.activePillText : (isToday ? theme.focusAccent : theme.textPrimary))
                            
                            if hasEvents {
                                Circle()
                                    .fill(isSelected ? theme.activePillText : (isToday ? theme.focusAccent : theme.textSecondary))
                                    .frame(width: 2.5, height: 2.5)
                            } else {
                                Color.clear.frame(width: 2.5, height: 2.5)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 16.5)
                        .contentShape(Rectangle())
                        .background(
                            isSelected
                                ? theme.activePillBackground
                                : (isToday
                                    ? theme.focusAccent.opacity(theme.isDark ? 0.18 : 0.12)
                                    : (isHovered ? theme.cardBackgroundElevated : Color.clear))
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 3.5, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                                .stroke(isToday && !isSelected ? theme.activeBorder : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        hoveredDay = hovering ? date : (hoveredDay == date ? nil : hoveredDay)
                    }
                } else {
                    Color.clear
                        .frame(height: 16.5)
                }
            }
        }
    }
    
    // MARK: - Right Deck (Agenda List / Dedicated Add Event View)
    private var rightAgendaDeck: some View {
        VStack(alignment: .leading, spacing: 5) {
            // Header - Perfectly leveled with Month Header
            HStack(spacing: 5) {
                Text(calendar.isAddingEvent ? "NEW EVENT" : agendaHeaderTitle(for: calendar.selectedDate))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(1)
                    .fixedSize()
                
                if calendar.isSignedIn {
                    if !calendar.isAddingEvent {
                        Text("\(calendar.eventsForSelectedDate.count)")
                            .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                            .foregroundColor(theme.textTertiary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1.5)
                            .background(theme.cardBackgroundElevated)
                            .clipShape(Capsule())
                    }
                    
                    Spacer()
                    
                    // Quick-Add / Cancel Button
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            calendar.isAddingEvent.toggle()
                            if calendar.isAddingEvent && selectedCalendarId == "primary", let first = calendar.apiBridge.availableCalendars.first(where: { $0.isPrimary }) {
                                selectedCalendarId = first.id
                            }
                        }
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: calendar.isAddingEvent ? "xmark" : "plus")
                                .font(.system(size: 7.5, weight: .bold))
                            if calendar.isAddingEvent {
                                Text("Cancel")
                                    .font(.system(size: 7.5, weight: .semibold))
                            }
                        }
                        .foregroundColor(theme.textPrimary)
                        .padding(.horizontal, calendar.isAddingEvent ? 7 : 0)
                        .frame(height: 20)
                        .frame(minWidth: 20)
                        .background(theme.cardBackgroundElevated)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help(calendar.isAddingEvent ? "Cancel adding event" : "Create New Event in Google Calendar")
                    
                    // Open Google Calendar in Browser (Tab-reusing)
                    Button(action: { calendar.openGoogleCalendarInBrowser() }) {
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 8))
                            .foregroundColor(theme.textSecondary)
                            .frame(width: 20, height: 20)
                            .background(theme.cardBackgroundElevated)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Open Google Calendar in Browser")
                } else {
                    Spacer()
                    
                    Text("Not Connected")
                        .font(.system(size: 7.5, weight: .semibold))
                        .foregroundColor(theme.textTertiary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(theme.cardBackgroundSubtle)
                        .clipShape(Capsule())
                }
            }
            
            // Content Body: Clean Sign-In Card when signed out vs Add Event Form OR Agenda List when signed in
            if !calendar.isSignedIn {
                VStack(spacing: 8) {
                    Spacer(minLength: 12)
                    
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 24))
                        .foregroundColor(theme.textTertiary)
                    
                    VStack(spacing: 3) {
                        Text("Connect Your Google Calendar")
                            .font(.system(size: 10.5, weight: .bold, design: .rounded))
                            .foregroundColor(theme.textPrimary)
                        
                        Text("Sign in with your Google account in your browser to view upcoming agendas and sync your schedule in Morph.")
                            .font(.system(size: 8.5, weight: .regular))
                            .foregroundColor(theme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }
                    
                    VStack(spacing: 6) {
                        Button(action: {
                            calendar.signInWithGoogle()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "person.crop.circle.badge.plus")
                                    .font(.system(size: 9, weight: .bold))
                                Text("Sign In with Google")
                                    .font(.system(size: 9.5, weight: .bold))
                            }
                            .foregroundColor(theme.activePillText)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 5.5)
                            .background(theme.activePillBackground)
                            .clipShape(Capsule())
                            .shadow(color: theme.windowShadow.opacity(0.25), radius: 2, y: 1)
                        }
                        .buttonStyle(.plain)
                        .help("Sign in to Google in your browser")
                    }
                    .padding(.top, 4)
                    
                    Spacer(minLength: 12)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if calendar.isAddingEvent {
                // Dedicated Full Add Event Canvas
                fullAddEventView
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            } else {
                // Events List for Signed In User
                let dayEvents = calendar.eventsForSelectedDate
                if dayEvents.isEmpty {
                    VStack(spacing: 3.5) {
                        Spacer(minLength: 2)
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 15))
                            .foregroundColor(theme.textTertiary)
                        
                        if let email = calendar.configuredUserEmail, !email.isEmpty {
                            Text(calendar.events.isEmpty ? "No events found for \(email)" : "No events scheduled for this day")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundColor(theme.textSecondary)
                        } else {
                            Text(calendar.events.isEmpty ? "No Google Calendar events loaded" : "No events scheduled for this day")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundColor(theme.textSecondary)
                        }
                        
                        HStack(spacing: 6) {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    calendar.isAddingEvent = true
                                    if selectedCalendarId == "primary", let first = calendar.apiBridge.availableCalendars.first(where: { $0.isPrimary }) {
                                        selectedCalendarId = first.id
                                    }
                                }
                            }) {
                                HStack(spacing: 3) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 7, weight: .bold))
                                    Text("Add Event")
                                        .font(.system(size: 7.5, weight: .bold))
                                }
                                .foregroundColor(theme.activePillText)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2.5)
                                .background(theme.activePillBackground)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule().stroke(theme.hairlineBorder, lineWidth: 0.5)
                                )
                            }
                            .buttonStyle(.plain)
                            .help("Quickly create a new event in Google Calendar")
                            
                            Button(action: { calendar.openGoogleCalendarInBrowser() }) {
                                HStack(spacing: 3) {
                                    Image(systemName: "arrow.up.right")
                                        .font(.system(size: 6.5, weight: .bold))
                                    Text("Open Google")
                                        .font(.system(size: 7.5, weight: .semibold))
                                }
                                .foregroundColor(theme.textPrimary)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2.5)
                                .background(theme.cardBackgroundElevated)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule().stroke(theme.hairlineBorder, lineWidth: 0.5)
                                )
                            }
                            .buttonStyle(.plain)
                            .help("Open Google Calendar in Browser")
                        }
                        .padding(.top, 1)
                        
                        Spacer(minLength: 4)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView(.vertical, showsIndicators: true) {
                        LazyVStack(spacing: 4) {
                            ForEach(dayEvents) { event in
                                eventCardRow(event: event)
                            }
                        }
                        .padding(.trailing, 2)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .frame(maxHeight: .infinity)
        .background(theme.canvasSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(theme.hairlineBorder, lineWidth: 1)
        )
    }
    
    // MARK: - Dedicated Full Add Event Canvas
    private var fullAddEventView: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header with Selected Date & Google Calendar target cycler
            addEventHeaderRow
            
            // Mode Selector: Timed Meeting vs All-Day / Deadline
            addEventTypeSelectorRow
            
            // Event Title Input
            addEventTitleRow
            
            // Dynamic Time/Duration Row OR All-Day / Deadline Preset Row
            if newEventIsAllDay {
                addEventAllDayRow
            } else {
                addEventTimeDurationRow
            }
            
            // Location & Google Meet Row
            addEventLocationRow
            
            Spacer(minLength: 4)
            
            // Primary Action Buttons (Discard / Add to Calendar)
            addEventActionRow
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.cardBackgroundSubtle)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(theme.hairlineBorder, lineWidth: 0.8)
        )
    }
    
    // MARK: - Add Event Form Subcomponents
    private var addEventHeaderRow: some View {
        HStack(spacing: 5) {
            HStack(spacing: 3.5) {
                Image(systemName: "calendar")
                    .font(.system(size: 8))
                    .foregroundColor(theme.textSecondary)
                
                let df: DateFormatter = {
                    let f = DateFormatter()
                    f.dateFormat = "EEE, MMM d, yyyy"
                    return f
                }()
                Text(df.string(from: calendar.selectedDate))
                    .font(.system(size: 8, weight: .semibold, design: .rounded))
                    .foregroundColor(theme.textPrimary)
            }
            
            Spacer()
            
            let writableCals = calendar.apiBridge.availableCalendars.filter { $0.accessRole == "owner" || $0.accessRole == "writer" }
            if writableCals.count > 1 {
                let currentSummary = writableCals.first(where: { $0.id == selectedCalendarId })?.summary ?? "Primary"
                Button(action: {
                    if let currentIndex = writableCals.firstIndex(where: { $0.id == selectedCalendarId }) {
                        let nextIndex = (currentIndex + 1) % writableCals.count
                        selectedCalendarId = writableCals[nextIndex].id
                    } else if let first = writableCals.first {
                        selectedCalendarId = first.id
                    }
                }) {
                    HStack(spacing: 3) {
                        Text(currentSummary)
                            .font(.system(size: 7, weight: .medium))
                            .lineLimit(1)
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 5.5))
                            .foregroundColor(theme.textTertiary)
                    }
                    .foregroundColor(theme.textPrimary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(theme.cardBackground)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("Click to switch target Google Calendar")
            } else {
                HStack(spacing: 3) {
                    Text(newEventIsAllDay ? "All-Day" : formatTimeDisplay(hour: newEventHour, minute: newEventMinute))
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundColor(theme.textPrimary)
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(theme.cardBackgroundElevated)
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3.5)
        .background(theme.cardBackgroundSubtle)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
    
    private var addEventTypeSelectorRow: some View {
        HStack(spacing: 4) {
            Button(action: {
                withAnimation(.spring(response: 0.22, dampingFraction: 0.8)) {
                    newEventIsAllDay = false
                }
            }) {
                HStack(spacing: 3) {
                    Image(systemName: "clock")
                        .font(.system(size: 7, weight: .bold))
                    Text("Timed Event")
                        .font(.system(size: 7.2, weight: !newEventIsAllDay ? .bold : .medium))
                }
                .foregroundColor(!newEventIsAllDay ? theme.activePillText : theme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 3)
                .background(!newEventIsAllDay ? theme.activePillBackground : theme.cardBackgroundSubtle)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            
            Button(action: {
                withAnimation(.spring(response: 0.22, dampingFraction: 0.8)) {
                    newEventIsAllDay = true
                }
            }) {
                HStack(spacing: 3) {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 6.5, weight: .bold))
                    Text("All Day / Deadline")
                        .font(.system(size: 7.2, weight: newEventIsAllDay ? .bold : .medium))
                }
                .foregroundColor(newEventIsAllDay ? theme.activePillText : theme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 3)
                .background(newEventIsAllDay ? theme.activePillBackground : theme.cardBackgroundSubtle)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(2)
        .background(theme.cardBackgroundSubtle)
        .clipShape(Capsule())
    }
    
    private var addEventTitleRow: some View {
        HStack(spacing: 5) {
            Image(systemName: newEventIsAllDay ? "target" : "pencil.line")
                .font(.system(size: 8))
                .foregroundColor(newEventIsAllDay ? theme.textPrimary : theme.textSecondary)
            
            TextField(newEventIsAllDay ? "Deadline / all-day event title..." : "Event title...", text: $newEventTitle)
                .textFieldStyle(.plain)
                .font(.system(size: 8.8, weight: .medium))
                .foregroundColor(theme.textPrimary)
                .onSubmit {
                    submitNewEvent()
                }
            
            if !newEventTitle.isEmpty {
                Button(action: { newEventTitle = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 7))
                        .foregroundColor(theme.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(theme.surfaceInset)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(theme.hairlineBorder, lineWidth: 0.6)
        )
    }
    
    private var addEventAllDayRow: some View {
        HStack(spacing: 4) {
            HStack(spacing: 3) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 7.5))
                    .foregroundColor(theme.badgeText)
                Text("Full Day Focus")
                    .font(.system(size: 7.2, weight: .semibold))
                    .foregroundColor(theme.badgeText)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(theme.badgeBackground)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(theme.activeBorder, lineWidth: 0.5)
            )
            
            Spacer()
            
            // Quick Deadline Template Badges
            HStack(spacing: 3) {
                Button(action: {
                    if !newEventTitle.contains("[Deadline]") {
                        newEventTitle = "[Deadline] " + newEventTitle
                    }
                }) {
                    Text("+ Deadline")
                        .font(.system(size: 6.8, weight: .bold))
                        .foregroundColor(theme.textPrimary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2.5)
                        .background(theme.cardBackground)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    if !newEventTitle.contains("[Goal]") {
                        newEventTitle = "[Goal] " + newEventTitle
                    }
                }) {
                    Text("+ Goal")
                        .font(.system(size: 6.8, weight: .bold))
                        .foregroundColor(theme.textPrimary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2.5)
                        .background(theme.cardBackground)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 2)
    }
    
    private var addEventTimeDurationRow: some View {
        HStack(spacing: 5) {
            // Stepper 30-Minute Granularity Control
            HStack(spacing: 2) {
                Button(action: {
                    rewindTimeByHalfHour()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 6.5, weight: .bold))
                        .foregroundColor(theme.textPrimary)
                        .frame(width: 17, height: 17)
                        .background(theme.cardBackgroundElevated)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Previous 30 minutes")
                
                Button(action: {
                    advanceTimeByHalfHour()
                }) {
                    HStack(spacing: 2.5) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 6.5))
                            .foregroundColor(theme.textSecondary)
                        Text(formatTimeDisplay(hour: newEventHour, minute: newEventMinute))
                            .font(.system(size: 7.2, weight: .bold, design: .monospaced))
                            .foregroundColor(theme.textPrimary)
                    }
                    .padding(.horizontal, 4)
                    .frame(height: 17)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Tap to advance by 30 minutes or use chevrons")
                
                Button(action: {
                    advanceTimeByHalfHour()
                }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 6.5, weight: .bold))
                        .foregroundColor(theme.textPrimary)
                        .frame(width: 17, height: 17)
                        .background(theme.cardBackgroundElevated)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Next 30 minutes")
            }
            .padding(.horizontal, 3)
            .padding(.vertical, 2)
            .background(theme.cardBackground)
            .clipShape(Capsule())
            
            Spacer()
            
            // Duration Chips (15m, 30m, 45m, 1h, 2h)
            HStack(spacing: 2.5) {
                ForEach([15, 30, 45, 60, 120], id: \.self) { duration in
                    Button(action: { newEventDurationMinutes = duration }) {
                        Text(duration >= 60 ? "\(duration / 60)h" : "\(duration)m")
                            .font(.system(size: 7, weight: newEventDurationMinutes == duration ? .bold : .medium))
                            .foregroundColor(newEventDurationMinutes == duration ? theme.activePillText : theme.textSecondary)
                            .padding(.horizontal, 4.5)
                            .frame(height: 17)
                            .background(newEventDurationMinutes == duration ? theme.activePillBackground : theme.cardBackground)
                            .clipShape(Capsule())
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("Set duration to \(duration) minutes")
                }
            }
        }
    }
    
    private var addEventLocationRow: some View {
        HStack(spacing: 4) {
            HStack(spacing: 3) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 6.8))
                    .foregroundColor(theme.textSecondary)
                
                TextField(newEventIsAllDay ? "Notes / details (optional)" : "Location (optional)", text: $newEventLocation)
                    .textFieldStyle(.plain)
                    .font(.system(size: 7.2, weight: .medium))
                    .foregroundColor(theme.textPrimary)
                    .onSubmit {
                        submitNewEvent()
                    }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3.5)
            .background(theme.surfaceInset)
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(theme.hairlineBorder, lineWidth: 0.5)
            )
            
            // Google Meet Toggle (Only relevant for timed meetings)
            if !newEventIsAllDay {
                Button(action: {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        newEventHasMeet.toggle()
                    }
                }) {
                    HStack(spacing: 2.5) {
                        Image(systemName: newEventHasMeet ? "video.fill" : "video")
                            .font(.system(size: 6))
                        Text("Meet")
                            .font(.system(size: 6.8, weight: .bold))
                    }
                    .foregroundColor(newEventHasMeet ? theme.activePillText : theme.textSecondary)
                    .padding(.horizontal, 5.5)
                    .padding(.vertical, 3.5)
                    .background(newEventHasMeet ? theme.activePillBackground : theme.cardBackground)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help(newEventHasMeet ? "Google Meet conference attached" : "Attach Google Meet")
            }
        }
    }
    
    private var addEventActionRow: some View {
        HStack(spacing: 6) {
            Button(action: {
                newEventTitle = ""
                newEventLocation = ""
                newEventIsAllDay = false
                newEventDurationMinutes = 30
                newEventMinute = 0
                withAnimation(.easeInOut(duration: 0.18)) {
                    calendar.isAddingEvent = false
                }
            }) {
                Text("Discard")
                    .font(.system(size: 7.5, weight: .medium))
                    .foregroundColor(theme.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3.5)
                    .background(theme.cardBackground)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            let isTitleEmpty = newEventTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            Button(action: submitNewEvent) {
                HStack(spacing: 3.5) {
                    if isSubmittingEvent {
                        ProgressView()
                            .scaleEffect(0.5)
                            .frame(width: 7, height: 7)
                    } else {
                        Image(systemName: newEventIsAllDay ? "flag.checkered" : "plus.circle.fill")
                            .font(.system(size: 7.5, weight: .bold))
                    }
                    
                    Text(isSubmittingEvent ? "Saving..." : (newEventIsAllDay ? "Add Deadline" : "Add to Calendar"))
                        .font(.system(size: 7.5, weight: .bold))
                }
                .foregroundColor(isTitleEmpty ? theme.textTertiary : theme.activePillText)
                .padding(.horizontal, 9)
                .padding(.vertical, 3.5)
                .background(isTitleEmpty ? theme.cardBackgroundElevated : theme.activePillBackground)
                .clipShape(Capsule())
                .shadow(color: theme.windowShadow.opacity(0.2), radius: 2, y: 1)
            }
            .buttonStyle(.plain)
            .disabled(isTitleEmpty || isSubmittingEvent)
            .help(newEventIsAllDay ? "Save all-day event or deadline" : "Save event to Google Calendar")
        }
    }
    
    private func advanceTimeByHalfHour() {
        if newEventMinute == 0 {
            newEventMinute = 30
        } else {
            newEventMinute = 0
            newEventHour = (newEventHour + 1) % 24
        }
        MorphHaptics.alignment()
    }
    
    private func rewindTimeByHalfHour() {
        if newEventMinute == 30 {
            newEventMinute = 0
        } else {
            newEventMinute = 30
            newEventHour = newEventHour > 0 ? newEventHour - 1 : 23
        }
        MorphHaptics.alignment()
    }
    
    private func formatTimeDisplay(hour: Int, minute: Int) -> String {
        let period = hour >= 12 ? "PM" : "AM"
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return String(format: "%d:%02d %@", displayHour, minute, period)
    }
    
    private func formatHourDisplay(_ hour: Int) -> String {
        formatTimeDisplay(hour: hour, minute: 0)
    }
    
    private func submitNewEvent() {
        let title = newEventTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, !isSubmittingEvent else { return }
        
        isSubmittingEvent = true
        let loc = newEventLocation.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        let dateString = formatter.string(from: calendar.selectedDate)
        
        let desc = newEventIsAllDay 
            ? "Deadline / All-Day Goal scheduled via Morph for \(dateString)"
            : "Scheduled via Morph for \(dateString)"
            
        calendar.addQuickEvent(
            title: title,
            durationMinutes: newEventDurationMinutes,
            startHour: newEventIsAllDay ? nil : newEventHour,
            startMinute: newEventMinute,
            isAllDay: newEventIsAllDay,
            addMeetLink: newEventIsAllDay ? false : newEventHasMeet,
            description: desc,
            location: loc.isEmpty ? nil : loc,
            targetCalendarId: selectedCalendarId
        )
        
        // Reset inputs and close creation drawer after a brief feedback animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isSubmittingEvent = false
            newEventTitle = ""
            newEventLocation = ""
            newEventIsAllDay = false
            newEventDurationMinutes = 30
            newEventMinute = 0
            withAnimation(.easeInOut(duration: 0.18)) {
                calendar.isAddingEvent = false
            }
        }
    }
    
    private func eventCardRow(event: CalendarEvent) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                // Time Range Chip
                if event.isAllDay {
                    HStack(spacing: 2.5) {
                        Image(systemName: "flag.fill")
                            .font(.system(size: 6))
                        Text(event.title.localizedCaseInsensitiveContains("deadline") ? "DEADLINE" : "ALL DAY")
                            .font(.system(size: 7.5, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(theme.badgeText)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(theme.badgeBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(theme.activeBorder, lineWidth: 0.5)
                    )
                } else {
                    Text(event.formattedTimeRange)
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(theme.textPrimary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(theme.cardBackgroundElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                }
                
                if event.isStartingSoon && !event.isAllDay {
                    Text("STARTING SOON")
                        .font(.system(size: 7, weight: .heavy, design: .rounded))
                        .foregroundColor(theme.activePillText)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(theme.activePillBackground)
                        .clipShape(Capsule())
                }
                
                Spacer()
                
                if let callURL = resolvedMeetingURL(for: event) {
                    let service = MeetingService.detect(url: callURL)
                    Button(action: {
                        triggerTakeCall(event: event)
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: service.iconName)
                                .font(.system(size: 7))
                            Text("Take Call")
                                .font(.system(size: 8, weight: .bold))
                        }
                        .foregroundColor(theme.activePillText)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(theme.activePillBackground)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("Take \(service.rawValue) call directly in Morph")
                }
                
                // Delete event button / confirmation
                if deletingEventID == event.id {
                    HStack(spacing: 3) {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.16)) {
                                calendar.deleteEvent(id: event.id)
                                deletingEventID = nil
                            }
                        }) {
                            Text("Delete")
                                .font(.system(size: 7.5, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.red.opacity(0.85))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .help("Confirm delete from calendar")
                        
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.16)) {
                                deletingEventID = nil
                            }
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 6.5, weight: .bold))
                                .foregroundColor(theme.textSecondary)
                                .frame(width: 16, height: 16)
                                .background(theme.cardBackgroundElevated)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help("Cancel")
                    }
                } else {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.16)) {
                            deletingEventID = event.id
                        }
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 7.5, weight: .medium))
                            .foregroundColor(theme.textTertiary)
                            .frame(width: 20, height: 20)
                            .background(theme.cardBackgroundElevated)
                            .clipShape(Circle())
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Delete event from calendar")
                }
            }
            
            Text(event.title)
                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                .foregroundColor(theme.textPrimary)
                .lineLimit(1)
            
            if !event.description.isEmpty || event.location != nil {
                HStack(spacing: 4) {
                    if let loc = event.location {
                        HStack(spacing: 2) {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.system(size: 7))
                            Text(loc)
                                .font(.system(size: 7.5, weight: .regular))
                        }
                        .foregroundColor(theme.textTertiary)
                    }
                    
                    if !event.description.isEmpty {
                        Text(event.description)
                            .font(.system(size: 7.5, weight: .regular))
                            .foregroundColor(theme.textTertiary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4.5)
        .background(theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(event.isStartingSoon ? theme.activeBorder : theme.hairlineBorder, lineWidth: 0.5)
        )
    }
    
    // MARK: - Helpers
    private func agendaHeaderTitle(for date: Date) -> String {
        let cal = Calendar.current
        let f = DateFormatter()
        if cal.isDateInToday(date) {
            f.dateFormat = "MMM d"
            return "TODAY • \(f.string(from: date).uppercased())"
        } else {
            f.dateFormat = "EEE, MMM d"
            return f.string(from: date).uppercased()
        }
    }
    
    private func monthYearString(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: date)
    }
    
    public func generateDaysInMonth(for date: Date) -> [Date?] {
        let cal = Calendar.current
        guard let range = cal.range(of: .day, in: .month, for: date),
              let firstDay = cal.date(from: cal.dateComponents([.year, .month], from: date)) else {
            return []
        }
        
        let firstWeekday = cal.component(.weekday, from: firstDay) // 1 = Sunday, 2 = Monday
        let prefixEmpty = (firstWeekday + 5) % 7 // Align Monday as index 0
        
        var days: [Date?] = Array(repeating: nil, count: prefixEmpty)
        for d in range {
            if let dayDate = cal.date(byAdding: .day, value: d - 1, to: firstDay) {
                days.append(dayDate)
            }
        }
        return days
    }
}


