import SwiftUI
import WebKit

public struct CalendarView: View {
    @ObservedObject var calendar: CalendarModel
    @State private var newEventTitle: String = ""
    @State private var newEventDurationMinutes: Int = 30
    @State private var newEventHour: Int = 14
    @State private var newEventHasMeet: Bool = true
    @State private var newEventLocation: String = ""
    @State private var selectedCalendarId: String = "primary"
    @State private var isSubmittingEvent: Bool = false
    @State private var showNotificationSettings: Bool = false
    @State private var deletingEventID: String? = nil
    
    public init(calendar: CalendarModel) {
        self.calendar = calendar
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
    
    // MARK: - Left Deck (Mini Month Grid, Urgency Bar & Notification Hub)
    private var leftMonthDeck: some View {
        VStack(alignment: .leading, spacing: 5) {
            // Month Header with Seamless Jump & Nav Buttons
            HStack(spacing: 4) {
                Text(monthYearString(for: calendar.displayedMonth))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Spacer()
                
                HStack(spacing: 3) {
                    Button(action: { calendar.previousMonth() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 7.5, weight: .bold))
                            .foregroundColor(Color.white.opacity(0.7))
                            .frame(width: 20, height: 20)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Previous Month")
                    
                    Button(action: { calendar.goToToday() }) {
                        Text("Today")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.white)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("Jump to Today")
                    
                    Button(action: { calendar.nextMonth() }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 7.5, weight: .bold))
                            .foregroundColor(Color.white.opacity(0.7))
                            .frame(width: 20, height: 20)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Next Month")
                }
            }
            
            // Day of Week Header (M T W T F S S)
            HStack(spacing: 0) {
                ForEach(["M", "T", "W", "T", "F", "S", "S"], id: \.self) { day in
                    Text(day)
                        .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.4))
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 1)
            
            // 7-Column Calendar Grid with Broad Touch Targets
            calendarGrid
            
            Spacer(minLength: 2)
            
            // Upcoming Meeting Countdown / Live Dynamic Status Pill
            if let next = calendar.nextUpcomingEvent {
                HStack(spacing: 5) {
                    Image(systemName: next.isStartingSoon ? "bell.badge.fill" : "calendar.badge.clock")
                        .font(.system(size: 7.5))
                        .foregroundColor(next.isStartingSoon ? .white : Color.white.opacity(0.7))
                    
                    Text(next.minutesUntilStart == 0 ? "Now: \(next.title)" : "In \(next.minutesUntilStart)m: \(next.title)")
                        .font(.system(size: 8, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Spacer(minLength: 2)
                    
                    if let meet = next.meetLink {
                        Button(action: { calendar.engine.openMeet(link: meet) }) {
                            Text("Join")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(Color.white)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .help("Join Google Meet Now")
                    }
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3.5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(next.isStartingSoon ? 0.12 : 0.06))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color.white.opacity(next.isStartingSoon ? 0.25 : 0.08), lineWidth: 0.5)
                )
            }
            
            // Seamless Multi-Action Bar (Notification Toggle & Lead Time, Sync, Browser)
            VStack(spacing: 4) {
                // Row 1: Account status & Instant Sync
                HStack(spacing: 5) {
                    Circle()
                        .fill(calendar.isSignedIn ? Color.white : Color.white.opacity(0.35))
                        .frame(width: 4.5, height: 4.5)
                    
                    if let email = calendar.configuredUserEmail, !email.isEmpty {
                        Text(email)
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.85))
                            .lineLimit(1)
                    } else {
                        Text(calendar.isSignedIn ? "Google Calendar" : "Calendar Sync")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.75))
                    }
                    
                    Spacer()
                    
                    // Notification Bell Quick-Toggle
                    Button(action: { calendar.toggleNotifications() }) {
                        HStack(spacing: 2) {
                            Image(systemName: calendar.notificationsEnabled ? "bell.fill" : "bell.slash")
                                .font(.system(size: 7))
                            Text("\(calendar.notificationLeadMinutes)m")
                                .font(.system(size: 7, weight: .bold, design: .monospaced))
                        }
                        .foregroundColor(calendar.notificationsEnabled ? .white : Color.white.opacity(0.4))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(calendar.notificationsEnabled ? 0.14 : 0.05))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help(calendar.notificationsEnabled ? "Alerts enabled \(calendar.notificationLeadMinutes)m before. Tap to toggle." : "Alerts muted. Tap to enable.")
                    
                    // Instant Manual Refresh Button
                    Button(action: { calendar.syncWithGoogle() }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 7.5, weight: .bold))
                            .foregroundColor(Color.white.opacity(0.75))
                            .frame(width: 18, height: 18)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                            .rotationEffect(.degrees(calendar.isSyncing ? 360 : 0))
                            .animation(calendar.isSyncing ? Animation.linear(duration: 0.9).repeatForever(autoreverses: false) : .default, value: calendar.isSyncing)
                    }
                    .buttonStyle(.plain)
                    .help("Sync Calendar Events Now")
                }
                
                // Row 2: Direct Action Capsules (Alert Lead Time & Sign In / Google Web)
                HStack(spacing: 4) {
                    // Alert Lead Time Selector
                    Button(action: { calendar.cycleNotificationLeadMinutes() }) {
                        HStack(spacing: 2) {
                            Image(systemName: "timer")
                                .font(.system(size: 6.5))
                            Text("\(calendar.notificationLeadMinutes)m lead")
                                .font(.system(size: 7, weight: .semibold))
                        }
                        .foregroundColor(Color.white.opacity(0.8))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("Cycle Notification Lead Time (5m, 10m, 15m, 30m)")
                    
                    Spacer()
                    
                    // Single Sign In / Open Google Calendar Tab Button
                    Button(action: {
                        if calendar.isSignedIn {
                            calendar.openGoogleCalendarInBrowser()
                        } else {
                            calendar.signInWithGoogle()
                        }
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: calendar.isSignedIn ? "arrow.up.right" : "globe")
                                .font(.system(size: 6.5, weight: .bold))
                            Text(calendar.isSignedIn ? "Google" : "Sign In")
                                .font(.system(size: 7.5, weight: .bold))
                        }
                        .foregroundColor(calendar.isSignedIn ? .white : .black)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(calendar.isSignedIn ? Color.white.opacity(0.16) : Color.white)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help(calendar.isSignedIn ? "Open Google Calendar in Browser (reusing tab)" : "Sign in to Google Account")
                }
            }
            .padding(.top, 1)
        }
        .padding(9)
        .frame(maxHeight: .infinity)
        .background(Color(white: 0.07))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
    
    // MARK: - Calendar Grid
    private var calendarGrid: some View {
        let days = generateDaysInMonth(for: calendar.displayedMonth)
        let cal = Calendar.current
        
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 2) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, date in
                if let date = date {
                    let isSelected = cal.isDate(date, inSameDayAs: calendar.selectedDate)
                    let isToday = cal.isDateInToday(date)
                    let hasEvents = !calendar.eventsForDate(date).isEmpty
                    
                    Button(action: {
                        calendar.selectedDate = date
                    }) {
                        VStack(spacing: 1) {
                            Text("\(cal.component(.day, from: date))")
                                .font(.system(size: 8.5, weight: (isToday || isSelected) ? .bold : .medium))
                                .foregroundColor(isSelected ? .black : (isToday ? .white : Color.white.opacity(0.85)))
                            
                            if hasEvents {
                                Circle()
                                    .fill(isSelected ? Color.black : Color.white.opacity(0.8))
                                    .frame(width: 2.2, height: 2.2)
                            } else {
                                Color.clear.frame(width: 2.2, height: 2.2)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .frame(height: 22)
                        .contentShape(Rectangle())
                        .background(isSelected ? Color.white : (isToday ? Color.white.opacity(0.18) : Color.clear))
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    }
                    .buttonStyle(.plain)
                } else {
                    Color.clear
                        .frame(height: 22)
                }
            }
        }
    }
    
    // MARK: - Right Deck (Agenda List / Dedicated Add Event View)
    private var rightAgendaDeck: some View {
        VStack(alignment: .leading, spacing: 5) {
            // Header - Perfectly leveled with Month Header
            HStack(spacing: 5) {
                Text(calendar.isAddingEvent ? "NEW EVENT" : "AGENDA")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .fixedSize()
                
                if calendar.isSignedIn {
                    if !calendar.isAddingEvent {
                        Text("\(calendar.eventsForSelectedDate.count)")
                            .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                            .foregroundColor(Color.white.opacity(0.6))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1.5)
                            .background(Color.white.opacity(0.08))
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
                        .foregroundColor(.white)
                        .padding(.horizontal, calendar.isAddingEvent ? 7 : 0)
                        .frame(height: 20)
                        .frame(minWidth: 20)
                        .background(Color.white.opacity(calendar.isAddingEvent ? 0.14 : 0.12))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help(calendar.isAddingEvent ? "Cancel adding event" : "Create New Event in Google Calendar")
                    
                    // Open Google Calendar in Browser (Tab-reusing)
                    Button(action: { calendar.openGoogleCalendarInBrowser() }) {
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 8))
                            .foregroundColor(Color.white.opacity(0.85))
                            .frame(width: 20, height: 20)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Open Google Calendar in Browser")
                } else {
                    Spacer()
                    
                    Text("Not Connected")
                        .font(.system(size: 7.5, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.45))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Capsule())
                }
            }
            
            // Content Body: Clean Sign-In Card when signed out vs Add Event Form OR Agenda List when signed in
            if !calendar.isSignedIn {
                VStack(spacing: 8) {
                    Spacer(minLength: 12)
                    
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 24))
                        .foregroundColor(Color.white.opacity(0.75))
                    
                    VStack(spacing: 3) {
                        Text("Connect Your Google Calendar")
                            .font(.system(size: 10.5, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("Sign in with your Google account in your browser to view upcoming agendas and sync your schedule in Morph.")
                            .font(.system(size: 8.5, weight: .regular))
                            .foregroundColor(Color.white.opacity(0.5))
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
                            .foregroundColor(.black)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 5.5)
                            .background(Color.white)
                            .clipShape(Capsule())
                            .shadow(color: Color.black.opacity(0.25), radius: 2, y: 1)
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
                    VStack(spacing: 5) {
                        Spacer(minLength: 8)
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 18))
                            .foregroundColor(Color.white.opacity(0.3))
                        
                        if let email = calendar.configuredUserEmail, !email.isEmpty {
                            Text(calendar.events.isEmpty ? "No events found for \(email)" : "No events scheduled for this day")
                                .font(.system(size: 8.5, weight: .medium))
                                .foregroundColor(Color.white.opacity(0.55))
                        } else {
                            Text(calendar.events.isEmpty ? "No Google Calendar events loaded" : "No events scheduled for this day")
                                .font(.system(size: 8.5, weight: .medium))
                                .foregroundColor(Color.white.opacity(0.55))
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
                                .foregroundColor(.black)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3.5)
                                .background(Color.white)
                                .clipShape(Capsule())
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
                                .foregroundColor(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3.5)
                                .background(Color.white.opacity(0.12))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .help("Open Google Calendar in Browser")
                        }
                        .padding(.top, 2)
                        
                        Spacer(minLength: 8)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView(.vertical, showsIndicators: true) {
                        LazyVStack(spacing: 5) {
                            ForEach(dayEvents) { event in
                                eventCardRow(event: event)
                            }
                        }
                        .padding(.trailing, 2)
                    }
                    .frame(maxHeight: 145)
                }
            }
            
            Spacer(minLength: 0)
        }
        .padding(9)
        .frame(maxHeight: .infinity)
        .background(Color(white: 0.07))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
    
    // MARK: - Dedicated Full Add Event Canvas
    private var fullAddEventView: some View {
        VStack(alignment: .leading, spacing: 5) {
            addEventHeaderRow
            addEventTitleRow
            addEventTimeDurationRow
            addEventLocationRow
            Spacer(minLength: 2)
            addEventActionRow
        }
        .padding(6)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
        )
    }
    
    // MARK: - Add Event Form Subcomponents
    private var addEventHeaderRow: some View {
        HStack(spacing: 4) {
            Image(systemName: "calendar")
                .font(.system(size: 7))
                .foregroundColor(Color.white.opacity(0.7))
            
            let df: DateFormatter = {
                let f = DateFormatter()
                f.dateFormat = "EEE, MMM d, yyyy"
                return f
            }()
            Text(df.string(from: calendar.selectedDate))
                .font(.system(size: 7.5, weight: .semibold, design: .rounded))
                .foregroundColor(Color.white.opacity(0.85))
            
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
                    HStack(spacing: 2.5) {
                        Circle()
                            .fill(Color.blue.opacity(0.8))
                            .frame(width: 4, height: 4)
                        Text(currentSummary)
                            .font(.system(size: 6.8, weight: .medium))
                            .lineLimit(1)
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 5))
                            .foregroundColor(Color.white.opacity(0.5))
                    }
                    .foregroundColor(Color.white.opacity(0.85))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1.5)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("Click to cycle target Google Calendar")
            } else {
                Text(formatHourDisplay(newEventHour))
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 4.5)
                    .padding(.vertical, 1.5)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2.5)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
    
    private var addEventTitleRow: some View {
        HStack(spacing: 5) {
            Image(systemName: "pencil.line")
                .font(.system(size: 7.5))
                .foregroundColor(Color.white.opacity(0.6))
            
            TextField("Event title", text: $newEventTitle)
                .textFieldStyle(.plain)
                .font(.system(size: 8.5, weight: .medium))
                .foregroundColor(.white)
            
            if !newEventTitle.isEmpty {
                Button(action: { newEventTitle = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 6.5))
                        .foregroundColor(Color.white.opacity(0.45))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3.5)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 0.6)
        )
    }
    
    private var addEventTimeDurationRow: some View {
        HStack(spacing: 4) {
            // Stepper Hour Control
            HStack(spacing: 2) {
                Button(action: {
                    newEventHour = newEventHour > 0 ? newEventHour - 1 : 23
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 6, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.7))
                        .frame(width: 14, height: 14)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Previous hour")
                
                HStack(spacing: 2) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 6))
                        .foregroundColor(Color.white.opacity(0.7))
                    Text(formatHourDisplay(newEventHour))
                        .font(.system(size: 7.2, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 3)
                
                Button(action: {
                    newEventHour = newEventHour < 23 ? newEventHour + 1 : 0
                }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 6, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.7))
                        .frame(width: 14, height: 14)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Next hour")
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(Color.white.opacity(0.09))
            .clipShape(Capsule())
            
            Spacer()
            
            // Duration Chips
            HStack(spacing: 2.5) {
                ForEach([15, 30, 45, 60], id: \.self) { duration in
                    Button(action: { newEventDurationMinutes = duration }) {
                        Text("\(duration)m")
                            .font(.system(size: 6.8, weight: newEventDurationMinutes == duration ? .bold : .medium))
                            .foregroundColor(newEventDurationMinutes == duration ? .black : Color.white.opacity(0.7))
                            .padding(.horizontal, 4.5)
                            .padding(.vertical, 2)
                            .background(newEventDurationMinutes == duration ? Color.white : Color.white.opacity(0.08))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    private var addEventLocationRow: some View {
        HStack(spacing: 4) {
            HStack(spacing: 3) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 6.5))
                    .foregroundColor(Color.white.opacity(0.55))
                
                TextField("Location (optional)", text: $newEventLocation)
                    .textFieldStyle(.plain)
                    .font(.system(size: 7.2, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 5)
            .padding(.vertical, 3)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            
            // Google Meet Toggle
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
                .foregroundColor(newEventHasMeet ? .black : Color.white.opacity(0.7))
                .padding(.horizontal, 5)
                .padding(.vertical, 3)
                .background(newEventHasMeet ? Color.white : Color.white.opacity(0.10))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .help(newEventHasMeet ? "Google Meet conference attached" : "Attach Google Meet")
        }
    }
    
    private var addEventActionRow: some View {
        HStack(spacing: 6) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.18)) {
                    calendar.isAddingEvent = false
                }
            }) {
                Text("Discard")
                    .font(.system(size: 7.2, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.6))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            Button(action: submitNewEvent) {
                HStack(spacing: 3) {
                    if isSubmittingEvent {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .black))
                            .scaleEffect(0.5)
                            .frame(width: 7, height: 7)
                    } else {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 7, weight: .bold))
                    }
                    
                    Text(isSubmittingEvent ? "Saving..." : "Add to Calendar")
                        .font(.system(size: 7.2, weight: .bold))
                }
                .foregroundColor(.black)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(newEventTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.white.opacity(0.25) : Color.white)
                .clipShape(Capsule())
                .shadow(color: Color.black.opacity(0.2), radius: 2, y: 1)
            }
            .buttonStyle(.plain)
            .disabled(newEventTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmittingEvent)
            .help("Save event to Google Calendar")
        }
    }
    
    private func formatHourDisplay(_ hour: Int) -> String {
        let period = hour >= 12 ? "PM" : "AM"
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return "\(displayHour):00 \(period)"
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
        
        calendar.addQuickEvent(
            title: title,
            durationMinutes: newEventDurationMinutes,
            startHour: newEventHour,
            startMinute: 0,
            addMeetLink: newEventHasMeet,
            description: "Scheduled via Morph for \(dateString)",
            location: loc.isEmpty ? nil : loc,
            targetCalendarId: selectedCalendarId
        )
        
        // Reset inputs and close creation drawer after a brief feedback animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isSubmittingEvent = false
            newEventTitle = ""
            newEventLocation = ""
            withAnimation(.easeInOut(duration: 0.18)) {
                calendar.isAddingEvent = false
            }
        }
    }
    
    private func eventCardRow(event: CalendarEvent) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                // Time Range Chip
                Text(event.formattedTimeRange)
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                
                if event.isStartingSoon {
                    Text("STARTING SOON")
                        .font(.system(size: 7, weight: .heavy, design: .rounded))
                        .foregroundColor(.black)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(Color.white)
                        .clipShape(Capsule())
                }
                
                Spacer()
                
                if let meet = event.meetLink {
                    Button(action: {
                        calendar.engine.openMeet(link: meet)
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "video.fill")
                                .font(.system(size: 7))
                            Text("Meet ↗")
                                .font(.system(size: 8, weight: .bold))
                        }
                        .foregroundColor(.black)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("Join Google Meet")
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
                                .background(Color.white.opacity(0.25))
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
                                .foregroundColor(Color.white.opacity(0.6))
                                .frame(width: 16, height: 16)
                                .background(Color.white.opacity(0.08))
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
                            .font(.system(size: 7, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.4))
                            .frame(width: 16, height: 16)
                            .background(Color.white.opacity(0.06))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Delete event from calendar")
                }
            }
            
            Text(event.title)
                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                .foregroundColor(.white)
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
                        .foregroundColor(Color.white.opacity(0.45))
                    }
                    
                    if !event.description.isEmpty {
                        Text(event.description)
                            .font(.system(size: 7.5, weight: .regular))
                            .foregroundColor(Color.white.opacity(0.4))
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4.5)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(event.isStartingSoon ? Color.white.opacity(0.3) : Color.white.opacity(0.06), lineWidth: 0.5)
        )
    }
    
    // MARK: - Helpers
    private func monthYearString(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: date)
    }
    
    private func generateDaysInMonth(for date: Date) -> [Date?] {
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


