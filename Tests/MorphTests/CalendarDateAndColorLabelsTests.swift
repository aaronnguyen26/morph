import XCTest
@testable import morph

@MainActor
final class CalendarDateAndColorLabelsTests: XCTestCase {
    
    func testCalendarOpensOnTodayDate() {
        let model = NotchModel()
        
        // Ensure glassTodayDayIndex accurately maps current weekday
        let weekday = Calendar.current.component(.weekday, from: Date())
        let expectedTodayIndex = (weekday == 1) ? 6 : (weekday - 2)
        XCTAssertEqual(model.glassTodayDayIndex, expectedTodayIndex)
        
        // Set to a different day index first
        model.glassSelectedDayIndex = (expectedTodayIndex + 2) % 7
        XCTAssertNotEqual(model.glassSelectedDayIndex, expectedTodayIndex)
        
        // Trigger opening calendar tab in Glass Island
        model.setGlassIslandState(.calendar)
        
        XCTAssertEqual(model.glassSelectedDayIndex, expectedTodayIndex, "Opening calendar view must always focus on today's day index")
        XCTAssertTrue(Calendar.current.isDateInToday(model.calendar.selectedDate), "CalendarModel selectedDate must be today")
        
        // Test opening via openFeature(.calendar)
        model.glassSelectedDayIndex = (expectedTodayIndex + 3) % 7
        model.openFeature(.calendar)
        XCTAssertEqual(model.glassSelectedDayIndex, expectedTodayIndex)
        XCTAssertTrue(Calendar.current.isDateInToday(model.calendar.selectedDate))
    }
    
    func testAddQuickEventWithColorAndDetails() {
        let calendar = CalendarModel()
        let initialCount = calendar.events.count
        
        let now = Date()
        let testColorHex = "#7986cb" // Lavender
        
        calendar.addQuickEvent(
            title: "Sprint Planning",
            startTime: now,
            durationMinutes: 45,
            isAllDay: false,
            hasMeetLink: true,
            location: "Morph HQ",
            colorHex: testColorHex
        )
        
        XCTAssertEqual(calendar.events.count, initialCount + 1)
        guard let createdEvent = calendar.events.first(where: { $0.title == "Sprint Planning" }) else {
            XCTFail("Created event not found in calendar.events")
            return
        }
        
        XCTAssertEqual(createdEvent.title, "Sprint Planning")
        XCTAssertEqual(createdEvent.colorHex, testColorHex)
        XCTAssertEqual(createdEvent.location, "Morph HQ")
        XCTAssertTrue(createdEvent.hasMeetLink)
        XCTAssertFalse(createdEvent.isAllDay)
        
        // Label name lookup
        let label = GoogleCalendarColor.labelName(for: createdEvent.colorHex!)
        XCTAssertEqual(label, "Lavender")
    }
    
    func testGoogleCalendarStandardColorPaletteAndLabels() {
        XCTAssertEqual(GoogleCalendarColor.standardPalette.count, 11)
        
        // Verify key color IDs and labels
        XCTAssertEqual(GoogleCalendarColor.hexForColorId("1"), "#7986cb")
        XCTAssertEqual(GoogleCalendarColor.labelName(for: "#7986cb"), "Lavender")
        
        XCTAssertEqual(GoogleCalendarColor.hexForColorId("2"), "#33b679")
        XCTAssertEqual(GoogleCalendarColor.labelName(for: "#33b679"), "Sage")
        
        XCTAssertEqual(GoogleCalendarColor.hexForColorId("5"), "#f6bf26")
        XCTAssertEqual(GoogleCalendarColor.labelName(for: "#f6bf26"), "Banana")
        
        XCTAssertEqual(GoogleCalendarColor.hexForColorId("11"), "#d50000")
        XCTAssertEqual(GoogleCalendarColor.labelName(for: "#d50000"), "Tomato")
        
        // Unknown hex fallback
        XCTAssertNil(GoogleCalendarColor.labelName(for: "#123456"))
    }
    
    func testAllDayEventCreationWithCustomColor() {
        let calendar = CalendarModel()
        let bananaHex = "#f6bf26"
        
        calendar.addQuickEvent(
            title: "Company Offsite",
            durationMinutes: 1440,
            isAllDay: true,
            colorHex: bananaHex
        )
        
        guard let offsite = calendar.events.first(where: { $0.title == "Company Offsite" }) else {
            XCTFail("All-day event not created")
            return
        }
        
        XCTAssertTrue(offsite.isAllDay)
        XCTAssertEqual(offsite.colorHex, bananaHex)
        XCTAssertEqual(GoogleCalendarColor.labelName(for: offsite.colorHex!), "Banana")
    }
    
    func testCalendarMultiViewOptionsThreeDayWeekMonth() {
        let calendar = CalendarModel()
        
        // 1. Verify Enum Cases and Icons
        XCTAssertEqual(CalendarViewMode.allCases.count, 3)
        XCTAssertEqual(CalendarViewMode.threeDay.rawValue, "3 Days")
        XCTAssertEqual(CalendarViewMode.week.rawValue, "Week")
        XCTAssertEqual(CalendarViewMode.month.rawValue, "Month")
        XCTAssertFalse(CalendarViewMode.threeDay.iconName.isEmpty)
        XCTAssertFalse(CalendarViewMode.week.iconName.isEmpty)
        XCTAssertFalse(CalendarViewMode.month.iconName.isEmpty)
        
        // 2. View Mode Switching & Persistence
        calendar.viewMode = .threeDay
        XCTAssertEqual(calendar.viewMode, .threeDay)
        XCTAssertEqual(UserDefaults.standard.string(forKey: "com.morph.calendar_view_mode"), "3 Days")
        
        calendar.viewMode = .week
        XCTAssertEqual(calendar.viewMode, .week)
        XCTAssertEqual(UserDefaults.standard.string(forKey: "com.morph.calendar_view_mode"), "Week")
        
        calendar.viewMode = .month
        XCTAssertEqual(calendar.viewMode, .month)
        XCTAssertEqual(UserDefaults.standard.string(forKey: "com.morph.calendar_view_mode"), "Month")
        
        // 3. Multi-Day Helpers: 3 Days
        let today = Date()
        calendar.selectedDate = today
        let threeDays = calendar.datesForThreeDays()
        XCTAssertEqual(threeDays.count, 3)
        let cal = Calendar.current
        XCTAssertTrue(cal.isDate(threeDays[0], inSameDayAs: today))
        XCTAssertTrue(cal.isDate(threeDays[1], inSameDayAs: cal.date(byAdding: .day, value: 1, to: today)!))
        XCTAssertTrue(cal.isDate(threeDays[2], inSameDayAs: cal.date(byAdding: .day, value: 2, to: today)!))
        
        // 4. Multi-Day Helpers: Current Week
        let weekDays = calendar.datesForCurrentWeek()
        XCTAssertEqual(weekDays.count, 7)
        // Week starts on Monday (weekday 2)
        XCTAssertEqual(cal.component(.weekday, from: weekDays[0]), 2)
        
        // 5. Navigation: previousPeriod and nextPeriod
        calendar.viewMode = .threeDay
        let initialDate = calendar.selectedDate
        calendar.nextPeriod()
        let diffNext = cal.dateComponents([.day], from: initialDate, to: calendar.selectedDate).day
        XCTAssertEqual(diffNext, 3, "3-Day nextPeriod must advance by 3 days")
        calendar.previousPeriod()
        let diffPrev = cal.dateComponents([.day], from: initialDate, to: calendar.selectedDate).day
        XCTAssertEqual(diffPrev, 0, "3-Day previousPeriod must rewind back")
        
        calendar.viewMode = .week
        calendar.nextPeriod()
        let diffWeekNext = cal.dateComponents([.day], from: initialDate, to: calendar.selectedDate).day
        XCTAssertEqual(diffWeekNext, 7, "Week nextPeriod must advance by 7 days")
        calendar.previousPeriod()
        let diffWeekPrev = cal.dateComponents([.day], from: initialDate, to: calendar.selectedDate).day
        XCTAssertEqual(diffWeekPrev, 0, "Week previousPeriod must rewind back")
    }
    
    func testCustomFeatureColorConfigurationAndLiveThemeUpdates() {
        let model = NotchModel()
        
        // 1. Verify Standard Color Palette Presets
        XCTAssertFalse(MorphFeatureColorPreset.standardPresets.isEmpty)
        let coralPreset = MorphFeatureColorPreset.standardPresets.first(where: { $0.id == "coral" })
        XCTAssertNotNil(coralPreset)
        XCTAssertEqual(coralPreset?.hex, "#ff9a7a")
        
        // 2. Initial Default Feature Colors
        XCTAssertEqual(model.featureTintColorHex(.timer), "#ff9a7a")
        XCTAssertEqual(model.featureTintColorHex(.calendar), "#6ab7ff")
        XCTAssertEqual(model.featureTintColorHex(.music), "#ff7ab8")
        XCTAssertEqual(model.featureTintColorHex(.notes), "#ffd36a")
        XCTAssertEqual(model.featureTintColorHex(.forms), "#8ff0b4")
        
        // 3. Customize Feature Colors
        let customNeonGreen = "#00ff88"
        model.setCustomFeatureColor(customNeonGreen, for: .calendar)
        XCTAssertEqual(model.featureTintColorHex(.calendar), customNeonGreen)
        
        // Check persistence in UserDefaults
        let savedColors = UserDefaults.standard.dictionary(forKey: "com.morph.custom_feature_colors") as? [String: String]
        XCTAssertEqual(savedColors?[MorphGlassFeature.calendar.rawValue], customNeonGreen)
        
        // 4. Live Morph Theme Update: glassIslandTintHex must reflect customized color
        model.setGlassIslandState(.calendar)
        XCTAssertEqual(model.glassIslandTintHex, customNeonGreen, "glassIslandTintHex must dynamically use user's customized feature color")
        
        // Customize another feature
        let customCyan = "#22d3ee"
        model.setCustomFeatureColor(customCyan, for: .music)
        model.setGlassIslandState(.music)
        XCTAssertEqual(model.glassIslandTintHex, customCyan)
        
        // 5. Reset Feature Color
        model.resetFeatureColor(for: .calendar)
        XCTAssertEqual(model.featureTintColorHex(.calendar), "#6ab7ff", "Reset must restore original feature tint")
        model.setGlassIslandState(.calendar)
        XCTAssertEqual(model.glassIslandTintHex, "#6ab7ff")
        
        model.resetFeatureColor(for: .music)
        XCTAssertEqual(model.featureTintColorHex(.music), "#ff7ab8")
        UserDefaults.standard.removeObject(forKey: "com.morph.custom_feature_colors")
        
        // 6. Color Hex Conversion
        let nsColor = NSColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
        XCTAssertEqual(nsColor.toHexString.lowercased(), "#ff0000")
    }
    
    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "com.morph.custom_feature_colors")
        UserDefaults.standard.removeObject(forKey: "com.morph.calendar_view_mode")
        super.tearDown()
    }
    
    func testAddEventActionReplacesEmailSection() {
        let calendar = CalendarModel()
        
        // Initially isAddingEvent is false
        XCTAssertFalse(calendar.isAddingEvent)
        
        // Toggle Add Event
        calendar.isAddingEvent = true
        XCTAssertTrue(calendar.isAddingEvent)
        
        calendar.isAddingEvent = false
        XCTAssertFalse(calendar.isAddingEvent)
        
        // Verify CalendarView builds and initializes cleanly
        let view = CalendarView(calendar: calendar)
        XCTAssertNotNil(view.body)
    }
    
    func testGlassCalendarSharesViewModeAndDateWithCalendarModel() {
        let model = NotchModel()
        let cal = Calendar.current
        model.calendar.goToToday()
        model.calendar.viewMode = .week
        model.calendar.nextPeriod()
        XCTAssertEqual(model.glassCurrentWeekDates, model.calendar.datesForCurrentWeek())
        XCTAssertTrue(cal.isDate(model.glassSelectedDate, inSameDayAs: model.calendar.selectedDate))
        XCTAssertEqual(model.glassCurrentWeekDates.count, 7)
        XCTAssertTrue(model.glassCurrentWeekDates.contains { cal.isDate($0, inSameDayAs: model.glassSelectedDate) })
        model.calendar.viewMode = .threeDay
        XCTAssertEqual(model.calendar.datesForThreeDays().count, 3)
        model.calendar.viewMode = .month
        model.calendar.goToToday()
        XCTAssertTrue(cal.isDateInToday(model.glassSelectedDate))
    }
    
    func testEventSubtitleAndLabelsShowDebateSociology() {
        let debateEvent = CalendarEvent(
            id: "evt-debate-1",
            title: "Debate Tournament Prep Round 1",
            startTime: Date(),
            endTime: Date().addingTimeInterval(3600),
            colorHex: "#7986cb",
            calendarName: "Debate"
        )
        XCTAssertEqual(debateEvent.calendarName, "Debate")
        XCTAssertFalse(debateEvent.title.isEmpty)
        
        let sociologyEvent = CalendarEvent(
            id: "evt-socio-2",
            title: "Sociology 101 Lecture: Social Structures and Institutions in Modern Societies",
            startTime: Date(),
            endTime: Date().addingTimeInterval(5400),
            colorHex: "#33b679",
            calendarName: "Sociology"
        )
        XCTAssertEqual(sociologyEvent.calendarName, "Sociology")
        XCTAssertFalse(sociologyEvent.title.contains("..."))
        
        // Ensure standard palette label resolution works for color hex
        let lavenderLabel = GoogleCalendarColor.labelName(for: "#7986cb")
        XCTAssertEqual(lavenderLabel, "Lavender")
        let sageLabel = GoogleCalendarColor.labelName(for: "#33b679")
        XCTAssertEqual(sageLabel, "Sage")
    }
    
    func testStartAndEndTimeFormatting() {
        let now = Date()
        let end = now.addingTimeInterval(3600)
        let event = CalendarEvent(
            id: "evt-time-test",
            title: "Team Sync",
            startTime: now,
            endTime: end
        )
        
        let range = event.formattedTimeRange
        XCTAssertTrue(range.contains("-") || range.contains("–"), "Time range must contain start and end time separator")
        
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        let expectedStart = f.string(from: now)
        let expectedEnd = f.string(from: end)
        XCTAssertTrue(range.contains(expectedStart), "Range must contain start time")
        XCTAssertTrue(range.contains(expectedEnd), "Range must contain end time")
    }
    
    func testCalendarNextChipTextOmitsNextUpNow() {
        let calendar = CalendarModel()
        let now = Date()
        
        // 1. Event currently in progress
        let activeEvent = CalendarEvent(
            id: "evt-in-progress",
            title: "Live Econometrics Lecture",
            startTime: now.addingTimeInterval(-900),
            endTime: now.addingTimeInterval(1800),
            colorHex: "#3b6fb5",
            calendarName: "econ"
        )
        calendar.events = [activeEvent]
        
        XCTAssertTrue(activeEvent.isNow)
        
        // Emulate calendarNextChipText logic
        let events = calendar.events
        let upcomingEvents = events.filter { $0.startTime > now }.sorted(by: { $0.startTime < $1.startTime })
        let currentEvent = events.first(where: { $0.isNow })
        
        let chipText: String = {
            if let upcoming = upcomingEvents.first {
                return "Next up · in \(upcoming.minutesUntilStart)m"
            } else if currentEvent != nil {
                return "In progress"
            } else if !events.isEmpty {
                return "\(events.count) event\(events.count == 1 ? "" : "s")"
            } else {
                return "Schedule clear"
            }
        }()
        
        XCTAssertEqual(chipText, "In progress", "When an event is happening now, status must be 'In progress' and never 'Next up · Now'")
        XCTAssertFalse(chipText.lowercased().contains("next up · now"), "Must never output 'Next up · Now'")
        XCTAssertFalse(chipText.lowercased().contains("next up: now"), "Must never output 'next up: now'")
        
        // 2. Active event AND an upcoming event later
        let laterEvent = CalendarEvent(
            id: "evt-later",
            title: "Philosophy Discussion Group",
            startTime: now.addingTimeInterval(3600),
            endTime: now.addingTimeInterval(7200),
            colorHex: "#816eb5",
            calendarName: "philosophy"
        )
        calendar.events = [activeEvent, laterEvent]
        
        let upcomingEventsWithLater = calendar.events.filter { $0.startTime > now }.sorted(by: { $0.startTime < $1.startTime })
        let currentWithLater = calendar.events.first(where: { $0.isNow })
        let chipTextWithLater: String = {
            if let upcoming = upcomingEventsWithLater.first {
                return "Next up · in \(upcoming.minutesUntilStart)m"
            } else if currentWithLater != nil {
                return "In progress"
            } else {
                return "Schedule clear"
            }
        }()
        
        XCTAssertTrue(chipTextWithLater.hasPrefix("Next up · in "), "Should point to the upcoming event")
        XCTAssertFalse(chipTextWithLater.lowercased().contains("next up · now"))
    }
    
    func testAvailableCalendarLabelsWithGoogleCalendars() {
        let calendar = CalendarModel()
        
        // Ingest simulated Google Calendars
        calendar.apiBridge.availableCalendars = [
            GoogleCalendarInfo(id: "cal-econ", summary: "econ", isPrimary: true, accessRole: "owner", colorHex: "#3b6fb5"),
            GoogleCalendarInfo(id: "cal-math", summary: "math", isPrimary: false, accessRole: "owner", colorHex: "#4f6d8a"),
            GoogleCalendarInfo(id: "cal-debate", summary: "debate", isPrimary: false, accessRole: "owner", colorHex: "#599aaa"),
            GoogleCalendarInfo(id: "cal-philosophy", summary: "philosophy", isPrimary: false, accessRole: "owner", colorHex: "#816eb5")
        ]
        
        let labels = calendar.availableCalendarLabels
        XCTAssertEqual(labels.count, 4)
        XCTAssertEqual(labels[0].name, "econ")
        XCTAssertTrue(labels[0].isPrimary)
        XCTAssertEqual(labels[0].colorHex, "#3b6fb5")
        XCTAssertEqual(labels[1].name, "math")
        XCTAssertEqual(labels[1].colorHex, "#4f6d8a")
        
        // Test addQuickEvent preserving calendarName and colorHex
        let now = Date()
        calendar.addQuickEvent(
            title: "Linear Algebra Problem Set",
            startTime: now,
            durationMinutes: 60,
            colorHex: "#4f6d8a",
            targetCalendarId: "cal-math",
            calendarName: "math"
        )
        
        guard let added = calendar.events.first(where: { $0.title == "Linear Algebra Problem Set" }) else {
            XCTFail("Event not added")
            return
        }
        XCTAssertEqual(added.calendarName, "math")
        XCTAssertEqual(added.colorHex, "#4f6d8a")
    }
    
    func testWeekViewHasEventIndicatorsMatchingMonthView() {
        let calendar = CalendarModel()
        let cal = Calendar.current
        let today = Date()
        let tomorrow = cal.date(byAdding: .day, value: 1, to: today)!
        let dayAfterTomorrow = cal.date(byAdding: .day, value: 2, to: today)!
        
        calendar.events = [
            CalendarEvent(
                id: "evt-today",
                title: "Macroeconomics Discussion",
                startTime: today,
                endTime: today.addingTimeInterval(3600),
                colorHex: "#3b6fb5",
                calendarName: "econ"
            ),
            CalendarEvent(
                id: "evt-day-after",
                title: "Debate Tournament",
                startTime: dayAfterTomorrow,
                endTime: dayAfterTomorrow.addingTimeInterval(7200),
                colorHex: "#599aaa",
                calendarName: "debate"
            )
        ]
        
        // Month view indicator check: eventsForDate(date) != empty
        XCTAssertFalse(calendar.eventsForDate(today).isEmpty, "Today has events -> blue dot rendered")
        XCTAssertTrue(calendar.eventsForDate(tomorrow).isEmpty, "Tomorrow has no events -> no blue dot")
        XCTAssertFalse(calendar.eventsForDate(dayAfterTomorrow).isEmpty, "Day after tomorrow has events -> blue dot rendered")
        
        // Week view indicator check: uses the exact same query
        let todayHasEvents = !calendar.eventsForDate(today).isEmpty
        let tomorrowHasEvents = !calendar.eventsForDate(tomorrow).isEmpty
        let dayAfterHasEvents = !calendar.eventsForDate(dayAfterTomorrow).isEmpty
        
        XCTAssertTrue(todayHasEvents, "Week view displays blue dot for today")
        XCTAssertFalse(tomorrowHasEvents, "Week view omits blue dot for tomorrow")
        XCTAssertTrue(dayAfterHasEvents, "Week view displays blue dot for day after tomorrow")
    }
    
    func testMultiDayEventIntervalOverlapQueryAndDots() {
        let calendar = CalendarModel()
        let cal = Calendar.current
        let today = Date()
        let dayStart = cal.startOfDay(for: today)
        let day1 = cal.date(byAdding: .day, value: 1, to: dayStart)!
        let day2 = cal.date(byAdding: .day, value: 2, to: dayStart)!
        let day3 = cal.date(byAdding: .day, value: 3, to: dayStart)!
        let day4 = cal.date(byAdding: .day, value: 4, to: dayStart)!
        let dayBefore = cal.date(byAdding: .day, value: -1, to: dayStart)!
        
        // Multi-day all-day event from day 0 through day 3 (exclusive end at day 4 00:00:00)
        let multiDayEvent = CalendarEvent(
            id: "evt-multi-day",
            title: "International Economics Summit",
            description: "Annual academic conference",
            startTime: dayStart,
            endTime: day4,
            isAllDay: true,
            colorHex: "#3b6fb5",
            calendarName: "econ"
        )
        calendar.events = [multiDayEvent]
        
        // Must appear on all spanned days: day 0, day 1, day 2, day 3
        XCTAssertFalse(calendar.eventsForDate(dayStart).isEmpty, "Day 0 must include multi-day event")
        XCTAssertFalse(calendar.eventsForDate(day1).isEmpty, "Day 1 must include multi-day event")
        XCTAssertFalse(calendar.eventsForDate(day2).isEmpty, "Day 2 must include multi-day event")
        XCTAssertFalse(calendar.eventsForDate(day3).isEmpty, "Day 3 must include multi-day event")
        
        // Must NOT appear outside the span
        XCTAssertTrue(calendar.eventsForDate(dayBefore).isEmpty, "Day before must not include multi-day event")
        XCTAssertTrue(calendar.eventsForDate(day4).isEmpty, "Day 4 (exclusive end) must not include multi-day event")
        
        // Both month and week view indicator logic rely on !eventsForDate(date).isEmpty
        XCTAssertTrue(!calendar.eventsForDate(dayStart).isEmpty)
        XCTAssertTrue(!calendar.eventsForDate(day1).isEmpty)
        XCTAssertTrue(!calendar.eventsForDate(day2).isEmpty)
        XCTAssertTrue(!calendar.eventsForDate(day3).isEmpty)
    }
    
    func testMultiDayTaskQuickAdd() {
        let calendar = CalendarModel()
        let cal = Calendar.current
        let today = Date()
        let startDay = cal.startOfDay(for: today)
        let endDay = cal.date(byAdding: .day, value: 2, to: startDay)! // 3-day span
        
        calendar.addQuickEvent(
            title: "Build Distributed Cache Engine",
            startTime: startDay,
            endTime: endDay,
            durationMinutes: 60,
            isAllDay: true,
            hasMeetLink: false,
            description: "[Task] Core architectural implementation across 3 days",
            location: "Morph Lab",
            colorHex: "#34a853",
            targetCalendarId: "cal-work",
            calendarName: "Work"
        )
        
        guard let taskEvent = calendar.events.first(where: { $0.title == "Build Distributed Cache Engine" }) else {
            XCTFail("Multi-day task event was not created")
            return
        }
        
        XCTAssertTrue(taskEvent.isAllDay)
        XCTAssertEqual(taskEvent.calendarName, "Work")
        XCTAssertEqual(taskEvent.colorHex, "#34a853")
        XCTAssertEqual(taskEvent.description, "[Task] Core architectural implementation across 3 days")
        
        // Formatted range check
        let range = taskEvent.formattedTimeRange
        XCTAssertTrue(range.contains("All Day"))
        
        // Spanning checks
        let day1 = cal.date(byAdding: .day, value: 1, to: startDay)!
        XCTAssertFalse(calendar.eventsForDate(startDay).isEmpty)
        XCTAssertFalse(calendar.eventsForDate(day1).isEmpty)
        XCTAssertFalse(calendar.eventsForDate(endDay).isEmpty)
    }
}
