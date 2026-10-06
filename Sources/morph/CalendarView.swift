import SwiftUI

public struct CalendarView: View {
    @ObservedObject var calendar: CalendarModel
    @State private var newEventTitle: String = ""
    @State private var isAddingEvent: Bool = false
    
    public init(calendar: CalendarModel) {
        self.calendar = calendar
    }
    
    public var body: some View {
        HStack(spacing: 12) {
            // Left Deck: Month Calendar & Google Calendar Status (265 pt)
            leftMonthDeck
                .frame(width: 265)
            
            // Right Deck: Chrono Agendas & Meet Dispatch (345 pt)
            rightAgendaDeck
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Left Deck (Mini Month Grid & Countdown)
    private var leftMonthDeck: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Month Header
            HStack {
                Text(monthYearString(for: calendar.displayedMonth))
                    .font(.system(size: 11.5, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Button(action: { calendar.previousMonth() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(Color.white.opacity(0.6))
                            .frame(width: 18, height: 18)
                            .background(Color.white.opacity(0.06))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { calendar.goToToday() }) {
                        Text("Today")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2.5)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { calendar.nextMonth() }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(Color.white.opacity(0.6))
                            .frame(width: 18, height: 18)
                            .background(Color.white.opacity(0.06))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Day of Week Header (M T W T F S S)
            HStack(spacing: 0) {
                ForEach(["M", "T", "W", "T", "F", "S", "S"], id: \.self) { day in
                    Text(day)
                        .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.35))
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 1)
            
            // 7-Column Calendar Grid
            calendarGrid
            
            Spacer(minLength: 2)
            
            // Urgent Event Countdown Pill
            if let next = calendar.nextUpcomingEvent {
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 7.5))
                        .foregroundColor(Color.cyan)
                    Text("In \(next.minutesUntilStart)m: \(next.title)")
                        .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            
            // Google Calendar Sync Pill (SSO synced from profile email)
            HStack(spacing: 5) {
                Circle()
                    .fill(calendar.isSignedIn ? Color.green : Color.orange)
                    .frame(width: 4.5, height: 4.5)
                if let email = calendar.configuredUserEmail, !email.isEmpty {
                    Text(email)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.65))
                        .lineLimit(1)
                } else {
                    Text(calendar.isSignedIn ? "Google Calendar Connected" : "Connecting Account...")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.55))
                }
                
                Spacer()
                
                Button(action: { calendar.syncWithGoogle() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 7.5))
                        .foregroundColor(Color.white.opacity(0.6))
                        .rotationEffect(.degrees(calendar.isSyncing ? 360 : 0))
                        .animation(calendar.isSyncing ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default, value: calendar.isSyncing)
                }
                .buttonStyle(.plain)
                .help("Sync Google Calendar")
            }
            .padding(.top, 1)
        }
        .padding(9)
        .background(Color(white: 0.07))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
    
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
                                .font(.system(size: 8.5, weight: isToday ? .bold : .medium))
                                .foregroundColor(isSelected ? .black : (isToday ? .cyan : .white))
                            
                            if hasEvents {
                                Circle()
                                    .fill(isSelected ? Color.black : Color.white.opacity(0.8))
                                    .frame(width: 2.2, height: 2.2)
                            } else {
                                Color.clear.frame(width: 2.2, height: 2.2)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 19)
                        .background(isSelected ? Color.white : (isToday ? Color.cyan.opacity(0.15) : Color.clear))
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    }
                    .buttonStyle(.plain)
                } else {
                    Color.clear.frame(height: 19)
                }
            }
        }
    }
    
    // MARK: - Right Deck (Chrono Agenda List)
    private var rightAgendaDeck: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Agenda Header
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundColor(.white)
                
                Text("CHRONO AGENDAS")
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.85))
                
                Text("\(calendar.eventsForSelectedDate.count) upcoming")
                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.5))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
                
                Spacer()
                
                Button(action: { isAddingEvent.toggle() }) {
                    HStack(spacing: 3) {
                        Image(systemName: "plus")
                            .font(.system(size: 7.5, weight: .bold))
                        Text("New")
                            .font(.system(size: 8, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                
                Button(action: { calendar.openGoogleCalendar() }) {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 8.5))
                        .foregroundColor(Color.white.opacity(0.6))
                        .frame(width: 18, height: 18)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Open Google Calendar Web")
            }
            
            if isAddingEvent {
                quickAddEventBar
            }
            
            // Events List
            let dayEvents = calendar.eventsForSelectedDate
            if dayEvents.isEmpty {
                VStack(spacing: 4) {
                    Spacer(minLength: 12)
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 16))
                        .foregroundColor(Color.white.opacity(0.3))
                    Text("No events scheduled for this day")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.5))
                    Spacer(minLength: 12)
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
                .frame(maxHeight: isAddingEvent ? 120 : 145)
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
    
    private var quickAddEventBar: some View {
        HStack(spacing: 5) {
            TextField("Event title...", text: $newEventTitle)
                .textFieldStyle(.plain)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.white)
                .onSubmit {
                    if !newEventTitle.isEmpty {
                        calendar.addQuickEvent(title: newEventTitle)
                        newEventTitle = ""
                        isAddingEvent = false
                    }
                }
            
            Button(action: {
                if !newEventTitle.isEmpty {
                    calendar.addQuickEvent(title: newEventTitle)
                    newEventTitle = ""
                    isAddingEvent = false
                }
            }) {
                Text("Add")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(Color.white)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3.5)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
    
    private func eventCardRow(event: CalendarEvent) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                // Time Range Chip
                Text(event.formattedTimeRange)
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.cyan)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.cyan.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                
                if event.isStartingSoon {
                    Text("STARTING SOON")
                        .font(.system(size: 7, weight: .heavy, design: .rounded))
                        .foregroundColor(.black)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1.5)
                        .background(Color.yellow)
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
                .stroke(event.isStartingSoon ? Color.cyan.opacity(0.3) : Color.white.opacity(0.06), lineWidth: 0.5)
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
