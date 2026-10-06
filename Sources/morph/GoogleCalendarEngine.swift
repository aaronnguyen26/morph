import Foundation
import WebKit
import Combine

@MainActor
public final class GoogleCalendarEngine: NSObject, ObservableObject, WKNavigationDelegate, WKScriptMessageHandler {
    public static let shared = GoogleCalendarEngine()
    
    @Published public var isSyncing: Bool = false
    @Published public var isSignedIn: Bool = false
    @Published public var lastSyncDate: Date?
    @Published public var rawEvents: [CalendarEvent] = []
    @Published public var configuredUserEmail: String?
    
    private var webView: WKWebView!
    private var syncTimer: AnyCancellable?
    private let kHandlerName = "morphCalendarBridge"
    private let kCalendarURL = "https://calendar.google.com/calendar/r"

    
    public override init() {
        super.init()
        setupWebView()
        setupPeriodicSync()
    }
    
    private func setupWebView() {
        let contentController = WKUserContentController()
        contentController.add(self, name: kHandlerName)
        
        // Injected scraping script to extract events directly from Google Calendar DOM
        let scriptSource = """
        (function() {
            window.morphExtractCalendar = function() {
                try {
                    var events = [];
                    // Check if signed in by looking for avatar or sign-in link
                    var signedIn = !document.querySelector('a[href*="ServiceLogin"], a[href*="accounts.google.com/signin"]');
                    
                    // Scrape event chips or agenda items if loaded
                    var chips = document.querySelectorAll('[data-eventid], [data-event-chip], [role="button"][data-date]');
                    for (var i = 0; i < Math.min(chips.length, 30); i++) {
                        var chip = chips[i];
                        var title = (chip.innerText || chip.textContent || '').trim();
                        if (title && title.length > 2) {
                            events.push({
                                id: chip.getAttribute('data-eventid') || ('evt_' + i),
                                title: title.split('\\n')[0],
                                raw: title
                            });
                        }
                    }
                    
                    window.webkit.messageHandlers.\(kHandlerName).postMessage({
                        isSignedIn: signedIn,
                        events: events
                    });
                } catch(e) {}
            };
            
            // Auto-trigger extraction
            setTimeout(window.morphExtractCalendar, 2000);
        })();
        """
        let userScript = WKUserScript(source: scriptSource, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        contentController.addUserScript(userScript)
        
        let config = WKWebViewConfiguration()
        config.userContentController = contentController
        config.websiteDataStore = WKWebsiteDataStore.default() // Shared persistent cookie store with YouTube Music & Google
        
        self.webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 800, height: 600), configuration: config)
        self.webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
        self.webView.navigationDelegate = self
    }
    
    private func setupPeriodicSync() {
        // Sync every 5 minutes in background
        syncTimer = Timer.publish(every: 300, on: .main, in: .common)
        .autoconnect()
        .sink { [weak self] _ in
            self?.refresh()
        }
    }
    
    public func configureAccount(email: String) {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanEmail.isEmpty, cleanEmail.contains("@") else { return }
        
        // Prevent redundant configuration if email didn't change
        if self.configuredUserEmail == cleanEmail && self.isSignedIn {
            return
        }
        
        self.configuredUserEmail = cleanEmail
        self.isSignedIn = true
        
        // Build Google Calendar SSO chooser URL that automatically selects the profile's email
        let escapedEmail = cleanEmail.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cleanEmail
        let ssoURLString = "https://accounts.google.com/AccountChooser?Email=\(escapedEmail)&continue=https%3A%2F%2Fcalendar.google.com%2Fcalendar%2Fr"
        
        isSyncing = true
        if let url = URL(string: ssoURLString) {
            webView.load(URLRequest(url: url))
        }
    }
    
    public func refresh() {
        isSyncing = true
        if let email = configuredUserEmail, !email.isEmpty {
            let escapedEmail = email.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? email
            let ssoURLString = "https://accounts.google.com/AccountChooser?Email=\(escapedEmail)&continue=https%3A%2F%2Fcalendar.google.com%2Fcalendar%2Fr"
            if let url = URL(string: ssoURLString) {
                webView.load(URLRequest(url: url))
                return
            }
        }
        if let url = URL(string: kCalendarURL) {
            webView.load(URLRequest(url: url))
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
    
    // MARK: - Script Message Handler
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == kHandlerName, let dict = message.body as? [String: Any] else { return }
        
        if let signedIn = dict["isSignedIn"] as? Bool {
            self.isSignedIn = signedIn
        }
        
        self.lastSyncDate = Date()
        self.isSyncing = false
    }
}
