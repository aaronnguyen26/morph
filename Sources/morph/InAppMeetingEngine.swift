import Cocoa
import WebKit
import SwiftUI
import Combine

public enum MeetingService: String, Codable, CaseIterable, Sendable {
    case googleMeet = "Google Meet"
    case zoom = "Zoom"
    case teams = "Microsoft Teams"
    case webex = "Webex"
    case genericWeb = "Online Meeting"
    
    public var iconName: String {
        switch self {
        case .googleMeet:
            return "video.fill"
        case .zoom:
            return "video.bubble.fill"
        case .teams:
            return "person.2.fill"
        case .webex:
            return "dot.radiowaves.left.and.right"
        case .genericWeb:
            return "video"
        }
    }
    
    public var badgeColor: Color {
        switch self {
        case .googleMeet:
            return Color.green
        case .zoom:
            return Color.blue
        case .teams:
            return Color.purple
        case .webex:
            return Color.teal
        case .genericWeb:
            return Color.white
        }
    }
    
    public static func detect(url: URL) -> MeetingService {
        let str = url.absoluteString.lowercased()
        if str.contains("meet.google.com") {
            return .googleMeet
        } else if str.contains("zoom.us") {
            return .zoom
        } else if str.contains("teams.microsoft.com") || str.contains("teams.live.com") {
            return .teams
        } else if str.contains("webex.com") {
            return .webex
        } else {
            return .genericWeb
        }
    }
}

@MainActor
public final class InAppMeetingEngine: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
    public static let shared = InAppMeetingEngine()
    
    @Published public var isInCall: Bool = false
    @Published public var activeCallTitle: String?
    @Published public var activeService: MeetingService = .genericWeb
    @Published public var currentMeetingURL: URL?
    @Published public var isMuted: Bool = false
    @Published public var isCameraOff: Bool = false
    @Published public var callStartedAt: Date?
    @Published public var callDurationSeconds: TimeInterval = 0
    @Published public var formattedCallDuration: String = "00:00"
    @Published public var isMeetingWindowVisible: Bool = false
    @Published public var showInCallScratchpadDrawer: Bool = true
    
    public private(set) var webView: WKWebView!
    private var meetingWindow: NSWindow?
    private var windowDelegate: MeetingWindowDelegate?
    private var callTimer: AnyCancellable?
    
    public var onCallEnded: (() -> Void)?
    public var onCallStarted: ((String?, MeetingService) -> Void)?
    
    private let kChromeUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
    private let kScriptBridgeHandler = "morphMeetingBridge"
    
    public override init() {
        super.init()
        setupWebView()
    }
    
    // MARK: - WebKit Setup with WebRTC Permissions
    private func setupWebView() {
        let contentController = WKUserContentController()
        contentController.add(self, name: kScriptBridgeHandler)
        
        let config = WKWebViewConfiguration()
        config.userContentController = contentController
        config.websiteDataStore = WKWebsiteDataStore.default() // Share authenticated Google/Workspace cookies
        
        // Enable direct media playback & WebRTC audio/video
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsAirPlayForMediaPlayback = true
        
        let prefs = WKPreferences()
        prefs.javaScriptCanOpenWindowsAutomatically = true
        config.preferences = prefs
        
        self.webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 900, height: 640), configuration: config)
        self.webView.customUserAgent = kChromeUserAgent
        self.webView.navigationDelegate = self
        self.webView.uiDelegate = self
    }
    
    // MARK: - URL Normalization (Zoom Web Client & Google Meet)
    
    /// Converts Zoom native app invite links into browser-joinable Zoom Web Client URLs
    public static func normalizeMeetingURL(_ url: URL) -> (url: URL, service: MeetingService) {
        let service = MeetingService.detect(url: url)
        
        switch service {
        case .zoom:
            let str = url.absoluteString
            // Check if it's already a Zoom web client link (/wc/)
            if str.contains("/wc/") {
                return (url, .zoom)
            }
            
            // Extract Zoom meeting ID: matches /j/123456789 or /j/12345678901
            if let regex = try? NSRegularExpression(pattern: #"/j/(\d+)"#, options: []),
               let match = regex.firstMatch(in: str, options: [], range: NSRange(location: 0, length: str.utf16.count)),
               let idRange = Range(match.range(at: 1), in: str) {
                let meetingId = String(str[idRange])
                let query = url.query ?? ""
                let wcURLString: String
                if query.isEmpty {
                    wcURLString = "https://app.zoom.us/wc/\(meetingId)/join"
                } else {
                    wcURLString = "https://app.zoom.us/wc/\(meetingId)/join?\(query)"
                }
                if let normalized = URL(string: wcURLString) {
                    return (normalized, .zoom)
                }
            }
            return (url, .zoom)
            
        case .googleMeet:
            var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
            comps?.scheme = "https"
            return (comps?.url ?? url, .googleMeet)
            
        case .teams, .webex, .genericWeb:
            return (url, service)
        }
    }
    
    // MARK: - Call Lifecycle
    
    @discardableResult
    public func startCall(url: URL, title: String? = nil, scratchpadModel: ScratchpadModel? = nil) -> Bool {
        let (normalizedURL, detectedService) = Self.normalizeMeetingURL(url)
        
        self.isInCall = true
        self.activeCallTitle = title ?? (detectedService == .googleMeet ? "Google Meet Call" : "Zoom Meeting")
        self.activeService = detectedService
        self.currentMeetingURL = normalizedURL
        self.callStartedAt = Date()
        self.callDurationSeconds = 0
        self.formattedCallDuration = "00:00"
        self.isMuted = false
        self.isCameraOff = false
        
        startCallTimer()
        
        // Load normalized call URL in internal WebKit instance
        let req = URLRequest(url: normalizedURL)
        webView.load(req)
        
        if !MorphEnvironment.isTestingEnvironment {
            showMeetingWindow(scratchpadModel: scratchpadModel)
        }
        
        onCallStarted?(self.activeCallTitle, detectedService)
        return true
    }
    
    public func leaveAndCloseCall() {
        self.isInCall = false
        stopCallTimer()
        
        // 1. Send clean hangup signal to Meet / Zoom DOM
        let leaveScript = """
        (function() {
            // Google Meet Leave Button
            var meetLeave = document.querySelector('button[aria-label*="Leave call"], button[aria-label*="Rời khỏi cuộc gọi"], button[jsname="CQylAd"]');
            if (meetLeave) { meetLeave.click(); }
            
            // Zoom Leave Button
            var zoomLeave = document.querySelector('.footer__leave-btn, button[aria-label*="Leave"], button[aria-label*="End"]');
            if (zoomLeave) { zoomLeave.click(); }
            
            // Stop all audio/video tracks to guarantee privacy
            if (navigator.mediaDevices && navigator.mediaDevices.getUserMedia) {
                navigator.mediaDevices.getUserMedia({audio: true, video: true}).then(function(stream) {
                    stream.getTracks().forEach(function(track) { track.stop(); });
                }).catch(function() {});
            }
        })();
        """
        webView.evaluateJavaScript(leaveScript) { _, _ in }
        
        // 2. Navigate away to about:blank to immediately release camera, microphone, and memory
        if let blankURL = URL(string: "about:blank") {
            webView.load(URLRequest(url: blankURL))
        }
        
        // 3. Hide in-app meeting window
        hideMeetingWindow()
        
        // 4. Reset state
        self.activeCallTitle = nil
        self.callStartedAt = nil
        self.callDurationSeconds = 0
        self.formattedCallDuration = "00:00"
        self.currentMeetingURL = nil
        self.isMuted = false
        
        onCallEnded?()
    }
    
    public func toggleMute() {
        self.isMuted.toggle()
        
        // Inject key / click to mute active WebRTC microphone stream
        let muteScript = """
        (function() {
            // Google Meet mute button (Cmd+D / button toggle)
            var meetMic = document.querySelector('button[aria-label*="microphone"], button[aria-label*="Microphone"], button[data-is-muted]');
            if (meetMic) { meetMic.click(); }
            
            // Zoom mute button (Alt+A / button toggle)
            var zoomMic = document.querySelector('.join-audio, .audio-option button, button[aria-label*="mute"], button[aria-label*="Mute"]');
            if (zoomMic) { zoomMic.click(); }
        })();
        """
        webView.evaluateJavaScript(muteScript) { _, _ in }
    }
    
    public func toggleCamera() {
        self.isCameraOff.toggle()
        
        let camScript = """
        (function() {
            // Google Meet camera toggle
            var meetCam = document.querySelector('button[aria-label*="camera"], button[aria-label*="Camera"]');
            if (meetCam) { meetCam.click(); }
            
            // Zoom camera toggle
            var zoomCam = document.querySelector('.video-option button, button[aria-label*="video"], button[aria-label*="Video"]');
            if (zoomCam) { zoomCam.click(); }
        })();
        """
        webView.evaluateJavaScript(camScript) { _, _ in }
    }
    
    // MARK: - Timer
    private func startCallTimer() {
        callTimer?.cancel()
        callTimer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tickDuration(seconds: 1)
            }
    }
    
    public func tickDuration(seconds: TimeInterval = 1) {
        guard isInCall else { return }
        callDurationSeconds += seconds
        
        let total = Int(callDurationSeconds)
        let hours = total / 3600
        let mins = (total % 3600) / 60
        let secs = total % 60
        
        if hours > 0 {
            formattedCallDuration = String(format: "%d:%02d:%02d", hours, mins, secs)
        } else {
            formattedCallDuration = String(format: "%02d:%02d", mins, secs)
        }
    }
    
    private func stopCallTimer() {
        callTimer?.cancel()
        callTimer = nil
    }
    
    // MARK: - Dedicated Meeting Window (Obsidian Glass)
    
    @discardableResult
    public func ensureMeetingWindow(scratchpadModel: ScratchpadModel? = nil) -> NSWindow {
        if let win = meetingWindow {
            return win
        }
        
        let win = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 1080, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        win.title = "Morph Meeting Stage"
        win.titlebarAppearsTransparent = false
        win.isReleasedWhenClosed = false
        win.backgroundColor = NSColor(red: 0.06, green: 0.06, blue: 0.07, alpha: 1.0)
        
        let delegate = MeetingWindowDelegate { [weak self] in
            self?.leaveAndCloseCall()
        }
        self.windowDelegate = delegate
        win.delegate = delegate
        
        let hostingRoot = InAppMeetingStageView(engine: self, scratchpad: scratchpadModel ?? ScratchpadModel())
        let hostingView = NSHostingView(rootView: hostingRoot)
        hostingView.frame = NSRect(x: 0, y: 0, width: 1080, height: 720)
        hostingView.autoresizingMask = [.width, .height]
        
        win.contentView = hostingView
        win.center()
        
        self.meetingWindow = win
        return win
    }
    
    public func showMeetingWindow(scratchpadModel: ScratchpadModel? = nil) {
        guard !MorphEnvironment.isTestingEnvironment else { return }
        let win = ensureMeetingWindow(scratchpadModel: scratchpadModel)
        let svcTitle = activeService.rawValue
        let title = activeCallTitle ?? "Meeting"
        win.title = "Morph — \(svcTitle) (\(title))"
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: false)
        self.isMeetingWindowVisible = true
    }
    
    public func hideMeetingWindow() {
        meetingWindow?.orderOut(nil)
        self.isMeetingWindowVisible = false
    }
    
    public func openInExternalBrowser() {
        guard let url = currentMeetingURL else { return }
        NSWorkspace.shared.open(url)
    }
    
    // MARK: - WKUIDelegate (Automated WebRTC Media Capture Grants)
    
    @available(macOS 12.0, *)
    public func webView(
        _ webView: WKWebView,
        requestMediaCapturePermissionFor origin: WKSecurityOrigin,
        initiatedByFrame frame: WKFrameInfo,
        type: WKMediaCaptureType,
        decisionHandler: @escaping @MainActor @Sendable (WKPermissionDecision) -> Void
    ) {
        // Automatically grant camera and microphone access inside Morph Meeting Stage
        decisionHandler(.grant)
    }
    
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
    
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        // Script telemetry receiver
    }
}

// Window delegate to handle window close button
private final class MeetingWindowDelegate: NSObject, NSWindowDelegate {
    private let onClose: () -> Void
    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }
    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}

// MARK: - WKWebView AppKit View Representable
public struct MeetingWebViewRepresentable: NSViewRepresentable {
    let webView: WKWebView
    
    public init(webView: WKWebView) {
        self.webView = webView
    }
    
    public func makeNSView(context: Context) -> WKWebView {
        return webView
    }
    
    public func updateNSView(_ nsView: WKWebView, context: Context) {}
}

// MARK: - In-App Meeting Stage Full View
public struct InAppMeetingStageView: View {
    @ObservedObject var engine: InAppMeetingEngine
    @ObservedObject var scratchpad: ScratchpadModel
    @State private var localNotes: String = ""
    @State private var noteAppendedFeedback: Bool = false
    
    public init(engine: InAppMeetingEngine, scratchpad: ScratchpadModel) {
        self.engine = engine
        self.scratchpad = scratchpad
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Obsidian Glass Header Bar (Height: 46 pt)
            meetingHeaderToolbar
                .frame(height: 46)
                .background(Color(white: 0.08))
                .overlay(
                    Rectangle()
                        .fill(Color.white.opacity(0.10))
                        .frame(height: 0.5),
                    alignment: .bottom
                )
            
            // Content Body: Split Video Viewport + Scratchpad Drawer
            GeometryReader { geo in
                HStack(spacing: 0) {
                    // Left Pane: WebKit Video Conference
                    MeetingWebViewRepresentable(webView: engine.webView)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    // Right Pane: In-Meeting Scratchpad Notes Drawer
                    if engine.showInCallScratchpadDrawer {
                        Rectangle()
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 1)
                        
                        inCallScratchpadPane
                            .frame(width: max(280, min(380, geo.size.width * 0.32)))
                            .background(Color(white: 0.05))
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
    
    // MARK: - Meeting Header Toolbar
    private var meetingHeaderToolbar: some View {
        HStack(spacing: 10) {
            // Service Badge & Title
            HStack(spacing: 6) {
                Image(systemName: engine.activeService.iconName)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(engine.activeService.badgeColor)
                
                Text(engine.activeService.rawValue)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(engine.activeCallTitle ?? "Live Call")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.85))
                    .lineLimit(1)
            }
            .padding(.leading, 14)
            
            // Live Duration Pill (Zero status dots)
            HStack(spacing: 4) {
                Text(engine.formattedCallDuration)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.green.opacity(0.18))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.green.opacity(0.3), lineWidth: 0.5)
            )
            
            Spacer()
            
            // Call Controls: Mute, Camera, Scratchpad Drawer, Popout, Leave
            HStack(spacing: 7) {
                // Mic Mute Button
                Button(action: {
                    engine.toggleMute()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: engine.isMuted ? "mic.slash.fill" : "mic.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text(engine.isMuted ? "Unmute" : "Mute")
                            .font(.system(size: 10.5, weight: .semibold))
                    }
                    .foregroundColor(engine.isMuted ? .white : .black)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4.5)
                    .background(engine.isMuted ? Color.red.opacity(0.85) : Color.white)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("Toggle Microphone (⌥Space)")
                
                // Notes Drawer Toggle Button
                Button(action: {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                        engine.showInCallScratchpadDrawer.toggle()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "note.text")
                            .font(.system(size: 10))
                        Text("Notes")
                            .font(.system(size: 10.5, weight: .semibold))
                    }
                    .foregroundColor(engine.showInCallScratchpadDrawer ? .black : .white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4.5)
                    .background(engine.showInCallScratchpadDrawer ? Color.white : Color.white.opacity(0.10))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("Toggle in-call Scratchpad Notes")
                
                // Open in External Browser Button
                Button(action: {
                    engine.openInExternalBrowser()
                }) {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 11))
                        .foregroundColor(Color.white.opacity(0.75))
                        .frame(width: 26, height: 26)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Open in System Browser")
                
                // Primary Crimson Leave Call Button
                Button(action: {
                    engine.leaveAndCloseCall()
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "phone.down.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text("Leave Call")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(
                        LinearGradient(
                            colors: [Color.red, Color(red: 0.8, green: 0.1, blue: 0.1)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: Color.red.opacity(0.4), radius: 6)
                }
                .buttonStyle(.plain)
                .help("End & Leave Call (⌘⇧E)")
            }
            .padding(.trailing, 14)
        }
    }
    
    // MARK: - In-Call Scratchpad Pane
    private var inCallScratchpadPane: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                Text("Meeting Scratchpad")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Spacer()
                
                if noteAppendedFeedback {
                    Text("Appended!")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundColor(.green)
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 10)
            
            // Full Note Editor
            TextEditor(text: $scratchpad.text)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.white)
                .padding(6)
                .background(Color.black.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 0.6)
                )
                .padding(.horizontal, 10)
            
            // Quick Append Input Row
            HStack(spacing: 6) {
                TextField("Quick takeaway / action item...", text: $localNotes)
                    .textFieldStyle(.plain)
                    .font(.system(size: 10.5))
                    .foregroundColor(.white)
                    .padding(6)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .onSubmit {
                        appendLocalNote()
                    }
                
                Button(action: appendLocalNote) {
                    HStack(spacing: 3) {
                        Image(systemName: "plus")
                            .font(.system(size: 8, weight: .bold))
                        Text("Add")
                            .font(.system(size: 9.5, weight: .bold))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.white)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(localNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
        }
    }
    
    private func appendLocalNote() {
        let clean = localNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .short)
        let header = engine.activeCallTitle ?? "Meeting"
        let entry = "\n- [\(timestamp)] \(clean)"
        
        if scratchpad.text.isEmpty {
            scratchpad.text = "## \(header) (\(timestamp))\n" + entry
        } else {
            scratchpad.text += entry
        }
        
        localNotes = ""
        withAnimation {
            noteAppendedFeedback = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                noteAppendedFeedback = false
            }
        }
    }
}
