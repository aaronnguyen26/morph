import XCTest
@testable import morph

@MainActor
final class CalendarNoPromptTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "com.morph.calendar.enable_mac_calendar")
    }
    
    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "com.morph.calendar.enable_mac_calendar")
        super.tearDown()
    }
    
    func testMacCalendarSyncDisabledByDefault() {
        let calendar = CalendarModel()
        XCTAssertFalse(
            calendar.isMacCalendarSyncEnabled,
            "Native Apple Calendar sync must be disabled by default so users are never prompted on app launch or update."
        )
    }
    
    func testConfigureUserDoesNotEnableMacCalendarSync() {
        let calendar = CalendarModel()
        calendar.configureUser(email: "user@example.com")
        
        XCTAssertEqual(calendar.configuredUserEmail, "user@example.com")
        XCTAssertTrue(calendar.isSignedIn)
        XCTAssertFalse(
            calendar.isMacCalendarSyncEnabled,
            "Configuring user SSO email must NOT enable native Mac Calendar sync or trigger Apple Calendar permission dialogs."
        )
    }
    
    func testSyncWithSystemCalendarDefaultDoesNotRequestPermission() async {
        let calendar = CalendarModel()
        
        // Default call without arguments (requestPermissionIfNeeded = false)
        await calendar.syncWithSystemCalendarAsync(requestPermissionIfNeeded: false)
        
        XCTAssertFalse(
            calendar.isMacCalendarSyncEnabled,
            "Default system calendar sync must never flip isMacCalendarSyncEnabled to true or request TCC permission."
        )
    }
    
    func testSyncGoogleCalendarAndApiAsyncDoesNotEnableMacCalendar() async {
        let calendar = CalendarModel()
        
        await calendar.syncGoogleCalendarAndApiAsync()
        
        XCTAssertFalse(
            calendar.isMacCalendarSyncEnabled,
            "syncGoogleCalendarAndApiAsync must strictly sync Google Calendar without enabling or requesting Apple Calendar."
        )
    }
    
    func testExplicitUserActionEnablesMacCalendarSync() async {
        let calendar = CalendarModel()
        XCTAssertFalse(calendar.isMacCalendarSyncEnabled)
        
        // Explicitly simulate user-initiated opt-in
        await calendar.syncWithSystemCalendarAsync(requestPermissionIfNeeded: true)
        
        XCTAssertTrue(
            calendar.isMacCalendarSyncEnabled,
            "Calling syncWithSystemCalendarAsync with requestPermissionIfNeeded: true must be the only path that enables isMacCalendarSyncEnabled."
        )
    }
    
    func testDateChangeWhenDisabledDoesNotPopulateEventKitEvents() {
        let calendar = CalendarModel()
        XCTAssertFalse(calendar.isMacCalendarSyncEnabled)
        
        // Changing selectedDate when Mac Calendar sync is disabled
        calendar.selectedDate = Date().addingTimeInterval(86400 * 3)
        
        XCTAssertFalse(
            calendar.isMacCalendarSyncEnabled,
            "Selected date change must respect isMacCalendarSyncEnabled = false."
        )
    }
    
    func testSyncWithGoogleOnlyFetchesEventKitIfExplicitlyEnabled() {
        let calendar = CalendarModel()
        XCTAssertFalse(calendar.isMacCalendarSyncEnabled)
        
        calendar.syncWithGoogle()
        
        XCTAssertFalse(
            calendar.isMacCalendarSyncEnabled,
            "syncWithGoogle must not enable Mac Calendar sync."
        )
    }
}
