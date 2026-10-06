import Foundation
import WebKit
import Cocoa
import Combine
import SwiftUI

@MainActor
public final class GoogleCalendarEngine: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
    public static let shared = GoogleCalendarEngine()
    
    @Published public var isSyncing: Bool = false
    @Published public var isSignedIn: Bool = false
    @Published public var lastSyncDate: Date?
    @Published public var rawEvents: [CalendarEvent] = []
    @Published public var configuredUserEmail: String?
    @Published public var isCalendarWindowVisible: Bool = false
    @Published public var currentURLString: String = "https://calendar.google.com/calendar/r"
    
    public private(set) var webView: WKWebView!
    private var calendarWindow: NSWindow?
    private var windowDelegate: CalendarWindowDelegate?
    private var syncTimer: AnyCancellable?
    
    private let kHandlerName = "morphCalendarBridge"
    private let kCalendarURL = "https://calendar.google.com/calendar/r"
    private let kCustomUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
    
    public override init() {
        super.init()
        setupWebView()
        setupPeriodicSync()
    }
    
    private func setupWebView() {
        let contentController = WKUserContentController()
        contentController.add(self, name: kHandlerName)
        
        // 1. Injected at Document Start: Chrome Stealth Fingerprint for Google
        let stealthScript = WKUserScript(
            source: chromeStealthJavaScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        contentController.addUserScript(stealthScript)
        
        // 2. Injected at Document End: Google Calendar Event Observer & Extractor
        let extractorScript = WKUserScript(
            source: calendarExtractorJavaScript,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        )
        contentController.addUserScript(extractorScript)
        
        let config = WKWebViewConfiguration()
        config.userContentController = contentController
        config.websiteDataStore = WKWebsiteDataStore.default() // Shared persistent cookie store with Google/YouTube
        
        let preferences = WKPreferences()
        preferences.javaScriptCanOpenWindowsAutomatically = true
        config.preferences = preferences
        
        self.webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 1080, height: 720), configuration: config)
        self.webView.customUserAgent = kCustomUserAgent
        self.webView.navigationDelegate = self
        self.webView.uiDelegate = self
        
        // Host in window so webView.window != nil (prevents WebKit background throttling)
        _ = ensureCalendarWindow()
        
        // Initial load
        refresh()
    }
    
    private func setupPeriodicSync() {
        // Automatically sync every 3 minutes
        syncTimer = Timer.publish(every: 180, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refresh()
            }
    }
    
    public func configureAccount(email: String) {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanEmail.isEmpty, cleanEmail.contains("@") else { return }
        
        if self.configuredUserEmail == cleanEmail && self.isSignedIn {
            return
        }
        
        self.configuredUserEmail = cleanEmail
        self.isSignedIn = true
        self.rawEvents = [] // Reset previous events for clean account fetch
        
        let escapedEmail = cleanEmail.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cleanEmail
        let ssoURLString = "https://accounts.google.com/AccountChooser?Email=\(escapedEmail)&continue=https%3A%2F%2Fcalendar.google.com%2Fcalendar%2Fr"
        
        isSyncing = true
        if let url = URL(string: ssoURLString) {
            currentURLString = url.absoluteString
            webView.load(URLRequest(url: url))
        }
    }
    
    public func clearAccount() {
        self.configuredUserEmail = nil
        self.isSignedIn = false
        self.rawEvents = []
        self.isSyncing = false
    }
    
    public func refresh() {
        isSyncing = true
        
        // First try triggering extraction directly if already on calendar page
        if let current = webView.url?.absoluteString, current.contains("calendar.google.com") {
            webView.evaluateJavaScript("if (typeof window.morphExtractCalendar === 'function') { window.morphExtractCalendar(); }") { [weak self] _, _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    self?.isSyncing = false
                }
            }
            return
        }
        
        if let email = configuredUserEmail, !email.isEmpty {
            let escapedEmail = email.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? email
            let ssoURLString = "https://accounts.google.com/AccountChooser?Email=\(escapedEmail)&continue=https%3A%2F%2Fcalendar.google.com%2Fcalendar%2Fr"
            if let url = URL(string: ssoURLString) {
                currentURLString = url.absoluteString
                webView.load(URLRequest(url: url))
                return
            }
        }
        
        if let url = URL(string: kCalendarURL) {
            currentURLString = url.absoluteString
            webView.load(URLRequest(url: url))
        }
    }
    
    public func loadGoogleSignIn() {
        var signInURL = "https://accounts.google.com/ServiceLogin?service=cl&continue=https%3A%2F%2Fcalendar.google.com%2Fcalendar%2Fr"
        if let email = configuredUserEmail, !email.isEmpty {
            let escaped = email.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? email
            signInURL = "https://accounts.google.com/AccountChooser?Email=\(escaped)&continue=https%3A%2F%2Fcalendar.google.com%2Fcalendar%2Fr"
        }
        if let url = URL(string: signInURL) {
            currentURLString = url.absoluteString
            webView.load(URLRequest(url: url))
        }
        showCalendarWindow()
    }
    
    public func goBack() {
        if webView.canGoBack {
            webView.goBack()
        }
    }
    
    public func goForward() {
        if webView.canGoForward {
            webView.goForward()
        }
    }
    
    public func reload() {
        webView.reload()
    }
    
    public func clearCookiesAndCache() {
        let dataStore = WKWebsiteDataStore.default()
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        let dateFrom = Date(timeIntervalSince1970: 0)
        dataStore.removeData(ofTypes: types, modifiedSince: dateFrom) { [weak self] in
            DispatchQueue.main.async {
                self?.loadGoogleSignIn()
            }
        }
    }
    
    public func openGoogleCalendarInBrowser() {
        if let email = configuredUserEmail, !email.isEmpty {
            let escapedEmail = email.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? email
            let ssoURLString = "https://accounts.google.com/AccountChooser?Email=\(escapedEmail)&continue=https%3A%2F%2Fcalendar.google.com%2Fcalendar%2Fr"
            if let url = URL(string: ssoURLString) {
                NSWorkspace.shared.open(url)
                return
            }
        }
        if let url = URL(string: kCalendarURL) {
            NSWorkspace.shared.open(url)
        }
    }
    
    public func openMeet(link: String) {
        if let url = URL(string: link) {
            NSWorkspace.shared.open(url)
        }
    }
    
    // MARK: - Dedicated Calendar Window
    @discardableResult
    public func ensureCalendarWindow() -> NSWindow {
        if let win = calendarWindow {
            return win
        }
        let win = NSWindow(
            contentRect: NSRect(x: 120, y: 120, width: 1100, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        win.title = "Google Calendar — Morph Engine"
        win.titlebarAppearsTransparent = false
        win.isReleasedWhenClosed = false
        win.backgroundColor = NSColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
        
        let delegate = CalendarWindowDelegate { [weak self] in
            self?.isCalendarWindowVisible = false
        }
        self.windowDelegate = delegate
        win.delegate = delegate
        
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 1100, height: 760))
        container.autoresizingMask = [.width, .height]
        
        let toolbarHeight: CGFloat = 70
        let toolbarView = NSHostingView(rootView: CalendarWindowToolbarView(engine: self))
        toolbarView.frame = NSRect(x: 0, y: 760 - toolbarHeight, width: 1100, height: toolbarHeight)
        toolbarView.autoresizingMask = [.width, .minYMargin]
        
        self.webView.frame = NSRect(x: 0, y: 0, width: 1100, height: 760 - toolbarHeight)
        self.webView.autoresizingMask = [.width, .height]
        
        container.addSubview(self.webView)
        container.addSubview(toolbarView)
        
        win.contentView = container
        win.center()
        self.calendarWindow = win
        return win
    }
    
    public func showCalendarWindow() {
        let win = ensureCalendarWindow()
        if let email = configuredUserEmail, !email.isEmpty {
            win.title = "Google Calendar — Morph (\(email))"
        } else {
            win.title = "Google Calendar — Morph Engine"
        }
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.isCalendarWindowVisible = true
    }
    
    public func hideCalendarWindow() {
        calendarWindow?.orderOut(nil)
        self.isCalendarWindowVisible = false
    }
    
    // MARK: - Navigation Delegate
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if let urlStr = webView.url?.absoluteString {
            self.currentURLString = urlStr
        }
        self.isSyncing = false
        // Trigger extraction after page load settles
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.webView.evaluateJavaScript("if (typeof window.morphExtractCalendar === 'function') { window.morphExtractCalendar(); }")
        }
    }
    
    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        self.isSyncing = false
    }
    
    // MARK: - WKUIDelegate (Google OAuth Popups)
    public func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if navigationAction.targetFrame == nil || !navigationAction.targetFrame!.isMainFrame {
            webView.load(navigationAction.request)
        }
        return nil
    }
    
    public func webViewDidClose(_ webView: WKWebView) {
        refresh()
    }
    
    // MARK: - Script Message Handler
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == kHandlerName, let dict = message.body as? [String: Any] else { return }
        parseIncomingPayload(dict)
    }
    
    public func parseIncomingPayload(_ dict: [String: Any]) {
        if let signedIn = dict["isSignedIn"] as? Bool {
            self.isSignedIn = signedIn
        }
        
        if let emailFromPage = dict["accountEmail"] as? String, !emailFromPage.isEmpty {
            // Verify and track matched account email
            if self.configuredUserEmail == nil {
                self.configuredUserEmail = emailFromPage
            }
        }
        
        if let eventsArray = dict["events"] as? [[String: Any]] {

            var parsedList: [CalendarEvent] = []
            let now = Date()
            let cal = Calendar.current
            
            for item in eventsArray {
                guard let title = item["title"] as? String, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
                let id = (item["id"] as? String) ?? UUID().uuidString
                let desc = (item["description"] as? String) ?? ""
                let meetLink = item["meetLink"] as? String
                let loc = item["location"] as? String
                let attendees = (item["attendees"] as? [String]) ?? []
                let isAllDay = (item["isAllDay"] as? Bool) ?? false
                
                var start = now.addingTimeInterval(3600)
                var end = start.addingTimeInterval(1800)
                
                if let startMs = item["startTimeMs"] as? Double, startMs > 0 {
                    start = Date(timeIntervalSince1970: startMs / 1000.0)
                } else if let timeStr = item["timeText"] as? String, !timeStr.isEmpty {
                    // Try parsing simple time like "10:30am" or "2:00 PM"
                    let df = DateFormatter()
                    df.dateFormat = "h:mma"
                    df.locale = Locale(identifier: "en_US_POSIX")
                    let cleanTime = timeStr.replacingOccurrences(of: " ", with: "").uppercased()
                    if let parsedTime = df.date(from: cleanTime) {
                        let comp = cal.dateComponents([.hour, .minute], from: parsedTime)
                        if let combined = cal.date(bySettingHour: comp.hour ?? 12, minute: comp.minute ?? 0, second: 0, of: now) {
                            start = combined
                        }
                    }
                }
                
                if let endMs = item["endTimeMs"] as? Double, endMs > 0 {
                    end = Date(timeIntervalSince1970: endMs / 1000.0)
                } else {
                    end = start.addingTimeInterval(1800)
                }
                
                let event = CalendarEvent(
                    id: id,
                    title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                    description: desc,
                    startTime: start,
                    endTime: end,
                    isAllDay: isAllDay,
                    meetLink: meetLink,
                    location: loc,
                    attendees: attendees
                )
                parsedList.append(event)
            }
            
            self.rawEvents = parsedList
        }
        
        self.lastSyncDate = Date()
        self.isSyncing = false
    }
    
    // MARK: - Chrome Stealth Fingerprint Script (Injected at .atDocumentStart)
    // Satisfies Google Botguard checks on accounts.google.com before any scripts run
    private var chromeStealthJavaScript: String {
        return """
        (function() {
            // 1. Emulate standard window.chrome namespace
            if (!window.chrome) {
                window.chrome = {
                    app: {
                        isInstalled: false,
                        InstallState: { DISABLED: 'disabled', INSTALLED: 'installed', NOT_INSTALLED: 'not_installed' },
                        RunningState: { CANNOT_RUN: 'cannot_run', READY_TO_RUN: 'ready_to_run', RUNNING: 'running' }
                    },
                    runtime: {
                        OnInstalledReason: {},
                        OnRestartRequiredReason: {},
                        PlatformArch: { ARM: 'arm', X86_64: 'x86_64' },
                        PlatformNaclArch: {},
                        PlatformOs: { MAC: 'mac' },
                        RequestUpdateCheckStatus: {}
                    },
                    loadTimes: function() {
                        return {
                            requestTime: performance.now() / 1000,
                            startLoadTime: performance.now() / 1000,
                            commitLoadTime: performance.now() / 1000,
                            finishDocumentLoadTime: performance.now() / 1000,
                            firstPaintTime: performance.now() / 1000,
                            finishLoadTime: performance.now() / 1000,
                            wasFetchedViaSpdy: true,
                            wasNpnNegotiated: true,
                            npnNegotiatedProtocol: 'h2',
                            wasAlternateProtocolAvailable: false,
                            connectionInfo: 'h2'
                        };
                    },
                    csi: function() {
                        return {
                            startE: Date.now(),
                            onloadT: Date.now(),
                            pageT: performance.now(),
                            tran: 15
                        };
                    }
                };
            }
            
            // 2. Set vendor to 'Google Inc.'
            try {
                Object.defineProperty(navigator, 'vendor', {
                    get: function() { return 'Google Inc.'; },
                    configurable: true
                });
            } catch(e) {}
            
            // 3. Ensure webdriver is false (not automated)
            try {
                Object.defineProperty(navigator, 'webdriver', {
                    get: function() { return false; },
                    configurable: true
                });
            } catch(e) {}
            
            // 4. Emulate navigator.userAgentData client hints
            try {
                if (!navigator.userAgentData) {
                    Object.defineProperty(navigator, 'userAgentData', {
                        get: function() {
                            return {
                                brands: [
                                    { brand: 'Chromium', version: '131' },
                                    { brand: 'Google Chrome', version: '131' },
                                    { brand: 'Not_A Brand', version: '24' }
                                ],
                                mobile: false,
                                platform: 'macOS',
                                getHighEntropyValues: function(hints) {
                                    return Promise.resolve({
                                        architecture: 'arm',
                                        bitness: '64',
                                        brands: [
                                            { brand: 'Chromium', version: '131' },
                                            { brand: 'Google Chrome', version: '131' },
                                            { brand: 'Not_A Brand', version: '24' }
                                        ],
                                        mobile: false,
                                        model: '',
                                        platform: 'macOS',
                                        platformVersion: '15.0.0',
                                        uaFullVersion: '131.0.6778.86'
                                    });
                                }
                            };
                        },
                        configurable: true
                    });
                }
            } catch(e) {}
            
            // 5. Emulate standard Chrome plugins
            try {
                if (!navigator.plugins || navigator.plugins.length === 0) {
                    var fakePlugins = [
                        { name: 'Chrome PDF Plugin', filename: 'internal-pdf-viewer', description: 'Portable Document Format' },
                        { name: 'Chrome PDF Viewer', filename: 'mhjfbmdgcfjbbpaeojofohoefgiehjai', description: '' }
                    ];
                    fakePlugins.item = function(i) { return this[i]; };
                    fakePlugins.namedItem = function(name) {
                        for (var i = 0; i < this.length; i++) {
                            if (this[i].name === name) return this[i];
                        }
                        return null;
                    };
                    fakePlugins.refresh = function() {};
                    Object.defineProperty(navigator, 'plugins', {
                        get: function() { return fakePlugins; },
                        configurable: true
                    });
                }
            } catch(e) {}
        })();
        """
    }
    
    // MARK: - Comprehensive Calendar Extractor Script
    private var calendarExtractorJavaScript: String {
        return """
        (function() {
            window.morphExtractCalendar = function() {
                try {
                    var events = [];
                    var signedIn = !document.querySelector('a[href*="ServiceLogin"], a[href*="accounts.google.com/signin"]');
                    
                    // Detect active Google Account email from DOM
                    var accountEmail = null;
                    var accountEl = document.querySelector('a[href*="SignOutOptions"], [data-email], a[aria-label*="@"], div[aria-label*="@"]');
                    if (accountEl) {
                        var label = accountEl.getAttribute('aria-label') || accountEl.getAttribute('data-email') || '';
                        var emailMatch = label.match(/[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\\\.[a-zA-Z]{2,}/);
                        if (emailMatch) accountEmail = emailMatch[0];
                    }
                    
                    // 1. Check for modern Google Calendar event elements
                    var eventElements = document.querySelectorAll('[data-eventid], [data-event-chip], [data-eventchip], [role="button"][data-date], div[data-key], .N4D8Eb');
                    
                    for (var i = 0; i < Math.min(eventElements.length, 60); i++) {
                        var el = eventElements[i];
                        var text = (el.innerText || el.textContent || '').trim();
                        var ariaLabel = (el.getAttribute('aria-label') || '').trim();
                        
                        if (!text && !ariaLabel) continue;
                        
                        var eventId = el.getAttribute('data-eventid') || el.getAttribute('data-key') || ('evt_' + i);
                        var title = '';
                        var timeText = '';
                        var description = '';
                        
                        // Parse from aria-label if available (Google Calendar accessibility standard)
                        if (ariaLabel && ariaLabel.includes(',')) {
                            var parts = ariaLabel.split(',').map(function(s) { return s.trim(); });
                            // Typically: "Title, Time, Status" or "Time, Title"
                            if (/\\\\d{1,2}(:\\\\d{2})?\\\\s*(am|pm)/i.test(parts[0])) {
                                timeText = parts[0];
                                title = parts[1] || parts[0];
                            } else {
                                title = parts[0];
                                for (var p = 1; p < parts.length; p++) {
                                    if (/\\\\d{1,2}(:\\\\d{2})?\\\\s*(am|pm)/i.test(parts[p])) {
                                        timeText = parts[p];
                                        break;
                                    }
                                }
                            }
                            description = parts.slice(2).join(' • ');
                        }
                        
                        if (!title && text) {
                            var lines = text.split('\\\\n').map(function(s) { return s.trim(); }).filter(Boolean);
                            title = lines[0];
                            if (lines.length > 1) {
                                if (/\\\\d{1,2}(:\\\\d{2})?\\\\s*(am|pm)/i.test(lines[0])) {
                                    timeText = lines[0];
                                    title = lines[1] || lines[0];
                                } else if (/\\\\d{1,2}(:\\\\d{2})?\\\\s*(am|pm)/i.test(lines[1])) {
                                    timeText = lines[1];
                                }
                            }
                            description = lines.slice(2).join(' • ');
                        }
                        
                        if (!title || title.length < 2) continue;
                        
                        // Extract Google Meet link if present
                        var meetLink = null;
                        var meetEl = el.querySelector('a[href*="meet.google.com"]');
                        if (meetEl) {
                            meetLink = meetEl.href;
                        }
                        
                        events.push({
                            id: eventId,
                            title: title,
                            description: description,
                            timeText: timeText,
                            meetLink: meetLink,
                            location: meetLink ? 'Google Meet' : null,
                            isAllDay: timeText === ''
                        });
                    }
                    
                    // 2. Fallback: Parse Agenda / Schedule view rows if present
                    if (events.length === 0) {
                        var agendaRows = document.querySelectorAll('[role="row"], .g-event, [data-row-index]');
                        for (var j = 0; j < Math.min(agendaRows.length, 30); j++) {
                            var r = agendaRows[j];
                            var rText = (r.innerText || r.textContent || '').trim();
                            if (rText && rText.length > 3) {
                                var rParts = rText.split('\\\\n').filter(Boolean);
                                events.push({
                                    id: 'agenda_' + j,
                                    title: rParts[rParts.length > 1 ? 1 : 0],
                                    timeText: rParts[0],
                                    description: rParts.slice(2).join(' • ')
                                });
                            }
                        }
                    }
                    
                    window.webkit.messageHandlers.\(kHandlerName).postMessage({
                        isSignedIn: signedIn,
                        accountEmail: accountEmail,
                        events: events
                    });
                } catch(e) {}
            };
            
            // Watch for DOM changes in calendar view
            var observer = new MutationObserver(function() {
                if (window._morphExtractTimer) clearTimeout(window._morphExtractTimer);
                window._morphExtractTimer = setTimeout(window.morphExtractCalendar, 1500);
            });
            observer.observe(document.body || document.documentElement, { childList: true, subtree: true });
            
            setTimeout(window.morphExtractCalendar, 2000);
        })();
        """
    }
}

// Window delegate to track when the calendar window is closed
private final class CalendarWindowDelegate: NSObject, NSWindowDelegate {
    private let onClose: () -> Void
    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }
    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}

// Dedicated Toolbar View for Google Calendar Web View Window
public struct CalendarWindowToolbarView: View {
    @ObservedObject var engine: GoogleCalendarEngine
    
    public init(engine: GoogleCalendarEngine) {
        self.engine = engine
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            toolbarRow
            securityNoticeRow
        }
        .frame(height: 70)
        .background(Color(red: 0.1, green: 0.1, blue: 0.1))
        .overlay(
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 1),
            alignment: .bottom
        )
    }
    
    private var toolbarRow: some View {
        HStack(spacing: 10) {
            HStack(spacing: 4) {
                Button(action: { if engine.webView.canGoBack { engine.webView.goBack() } }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(engine.webView?.canGoBack == true ? .white : Color.white.opacity(0.3))
                        .frame(width: 26, height: 26)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(engine.webView?.canGoBack != true)
                
                Button(action: { if engine.webView.canGoForward { engine.webView.goForward() } }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(engine.webView?.canGoForward == true ? .white : Color.white.opacity(0.3))
                        .frame(width: 26, height: 26)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(engine.webView?.canGoForward != true)
                
                Button(action: { engine.refresh() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .rotationEffect(.degrees(engine.isSyncing ? 360 : 0))
                        .animation(engine.isSyncing ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default, value: engine.isSyncing)
                        .frame(width: 26, height: 26)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            
            // Home / Today Button
            Button(action: { engine.refresh() }) {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 10))
                    Text("Google Calendar")
                        .font(.system(size: 10.5, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4.5)
                .background(Color.white.opacity(0.12))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // SSO Email Pill
            if let email = engine.configuredUserEmail, !email.isEmpty {
                HStack(spacing: 4) {
                    Circle()
                        .fill(engine.isSignedIn ? Color.green : Color.orange)
                        .frame(width: 5, height: 5)
                    Text(email)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.85))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.08))
                .clipShape(Capsule())
            }
            
            Spacer()
            
            // Action Buttons
            HStack(spacing: 6) {
                // Direct Sign-In with Google Button
                if engine.isSignedIn {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundColor(Color.green)
                        Text("Connected")
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4.5)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Capsule())
                    
                    Button(action: {
                        engine.loadGoogleSignIn()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 9.5))
                            Text("Switch Account")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4.5)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("Sign in with another Google Account")
                } else {
                    Button(action: {
                        engine.loadGoogleSignIn()
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "person.crop.circle.badge.plus")
                                .font(.system(size: 10.5, weight: .bold))
                            Text("Sign In with Google")
                                .font(.system(size: 10.5, weight: .bold))
                        }
                        .foregroundColor(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                
                // Open in System Browser
                Button(action: {
                    engine.openGoogleCalendarInBrowser()
                }) {
                    Image(systemName: "safari")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 26, height: 26)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Open in System Browser (Safari / Chrome)")
                
                // Clear & Reset Cache Button
                Button(action: {
                    engine.clearCookiesAndCache()
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color.red.opacity(0.85))
                        .frame(width: 26, height: 26)
                        .background(Color.red.opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Clear Cookies & Cache")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 42)
    }
    
    private var securityNoticeRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.shield")
                .font(.system(size: 9.5))
                .foregroundColor(.orange)
            
            Text("If Google blocks embedded sign-in (\"not secure\"), sign in via your system browser:")
                .font(.system(size: 10, weight: .regular))
                .foregroundColor(.white.opacity(0.75))
            
            Button(action: {
                engine.openGoogleCalendarInBrowser()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "safari")
                        .font(.system(size: 9.5))
                    Text("Open Safari / Chrome ↗")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundColor(.cyan)
                .padding(.horizontal, 7)
                .padding(.vertical, 2.5)
                .background(Color.cyan.opacity(0.15))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            Text("Or sync macOS Calendar directly")
                .font(.system(size: 9.5, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(.horizontal, 14)
        .frame(height: 28)
        .background(Color.black.opacity(0.25))
    }
}

