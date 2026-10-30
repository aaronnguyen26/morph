import SwiftUI

public struct MeetingFlightControllerView: View {
    @ObservedObject var model: NotchModel
    @ObservedObject var controller: MeetingFlightControllerModel
    @State private var noteSavedFeedback: Bool = false
    
    public init(model: NotchModel) {
        self.model = model
        self.controller = model.meetingController
    }
    
    @ViewBuilder
    public var body: some View {
        Group {
            if controller.isMeetingActiveOrDetected {
                VStack(spacing: 8) {
                    // Header Bar
                    meetingHeaderBar
                    
                    // Body: Active Call Cockpit vs Detected Meeting Lobby vs Pre-Meeting Readiness
                    if controller.isInCall {
                        activeCallCockpitView
                    } else if controller.isMeetingDetected {
                        detectedMeetingLobbyView
                    } else if let upcoming = controller.upcomingMeeting {
                        preMeetingReadinessView(event: upcoming)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Color.clear
                    .onAppear {
                        model.closeContextualFeature()
                    }
            }
        }
    }
    
    private var meetingHeaderBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: controller.isInCall ? controller.activeService.iconName : "video.badge.waveform.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(controller.isInCall ? controller.activeService.badgeColor : .cyan)
                
                Text("Meeting Cockpit")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                if controller.isInCall {
                    HStack(spacing: 4) {
                        Text(controller.activeService.rawValue.uppercased())
                            .font(.system(size: 8.5, weight: .heavy, design: .rounded))
                            .foregroundColor(controller.activeService.badgeColor)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.10))
                    .clipShape(Capsule())
                } else if controller.isMeetingDetected {
                    Text("DETECTED")
                        .font(.system(size: 8.5, weight: .heavy, design: .rounded))
                        .foregroundColor(.cyan)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.cyan.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
            
            Spacer()
            
            if let appName = controller.detectedAppName {
                HStack(spacing: 4) {
                    Image(systemName: "app.badge.fill")
                        .font(.system(size: 8.5))
                    Text(appName)
                        .font(.system(size: 9.5, weight: .semibold))
                }
                .foregroundColor(Color.white.opacity(0.7))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.08))
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 4)
    }
    
    // MARK: - 1. In-Call Cockpit View
    private var activeCallCockpitView: some View {
        HStack(spacing: 12) {
            // Left Pane: Call Telemetry & Controls
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Image(systemName: controller.activeService.iconName)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(controller.activeService.badgeColor)
                        
                        Text(controller.activeCallTitle ?? "Active Meeting")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                    
                    HStack(spacing: 6) {
                        Text(controller.formattedCallDuration)
                            .font(.system(size: 18, weight: .heavy, design: .monospaced))
                            .foregroundColor(.white)
                        
                        Text("in call")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.5))
                    }
                }
                
                Spacer(minLength: 0)
                
                // Call Management Controls
                HStack(spacing: 7) {
                    // Mute Toggle
                    Button(action: {
                        controller.toggleMute()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: controller.isMuted ? "mic.slash.fill" : "mic.fill")
                                .font(.system(size: 9.5, weight: .bold))
                            Text(controller.isMuted ? "Unmute" : "Mute")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundColor(controller.isMuted ? .white : .black)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(controller.isMuted ? Color.red.opacity(0.85) : Color.white)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("Mute / Unmute Microphone")
                    
                    // Show In-App Meeting Window Stage
                    Button(action: {
                        controller.engine.showMeetingWindow(scratchpadModel: model.scratchpad)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "macwindow")
                                .font(.system(size: 9))
                            Text("Stage")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("Show Floating Meeting Window")
                    
                    // Direct End Call
                    Button(action: {
                        controller.endCall()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "phone.down.fill")
                                .font(.system(size: 9, weight: .bold))
                            Text("End Call")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color.red.opacity(0.85))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("Hang up and close call window")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
            )
            
            // Right Pane: In-Meeting Scratchpad Notes
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "note.text")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                    Text("Take Notes in Scratchpad")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Spacer()
                    if noteSavedFeedback {
                        Text("Appended!")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.green)
                            .transition(.opacity)
                    }
                }
                
                TextField("Key decisions, takeaways, action items...", text: $controller.quickNotes)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Color.black.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                    )
                
                HStack {
                    Spacer()
                    Button(action: {
                        controller.appendNoteToScratchpad(model.scratchpad)
                        withAnimation {
                            noteSavedFeedback = true
                        }
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 1_500_000_000)
                            withAnimation {
                                noteSavedFeedback = false
                            }
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.bubble.fill")
                                .font(.system(size: 8.5))
                            Text("Append to Notes")
                                .font(.system(size: 9.5, weight: .bold))
                        }
                        .foregroundColor(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4.5)
                        .background(Color.white)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(controller.quickNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
            )
        }
        .frame(maxHeight: 124)
    }
    
    // MARK: - 2. Pre-Meeting Readiness View
    private func preMeetingReadinessView(event: CalendarEvent) -> some View {
        let minutesUntil = Int(ceil(max(0, event.startTime.timeIntervalSince(Date())) / 60))
        let detectedService: MeetingService = {
            if let url = controller.resolvedMeetingURL(for: event) {
                return MeetingService.detect(url: url)
            }
            return .genericWeb
        }()
        
        return HStack(spacing: 12) {
            // Meeting Info Card
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(minutesUntil == 0 ? "Starting Now" : "Meeting in \(minutesUntil)m")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundColor(.black)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2.5)
                        .background(Color.white)
                        .clipShape(Capsule())
                    
                    HStack(spacing: 3.5) {
                        Image(systemName: detectedService.iconName)
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundColor(detectedService.badgeColor)
                        Text(detectedService.rawValue)
                            .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                            .foregroundColor(Color.white.opacity(0.85))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
                }
                
                Text(event.title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 9))
                    Text(formattedTimeRange(event: event))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                }
                .foregroundColor(Color.white.opacity(0.6))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 0.5)
            )
            
            // 1-Click Launch Button Card
            VStack(spacing: 6) {
                // Primary In-Morph Call Button
                Button(action: {
                    _ = controller.openMeetLink(event: event, inApp: true, scratchpad: model.scratchpad)
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: detectedService.iconName)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.black)
                        Text("Take Call")
                            .font(.system(size: 12.5, weight: .heavy, design: .rounded))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        LinearGradient(
                            colors: [Color.white, Color(white: 0.9)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: Color.white.opacity(0.25), radius: 6)
                }
                .buttonStyle(.plain)
                .help("Take call directly in Morph with Zoom/Meet stage")
                
                // Secondary External Browser Fallback
                Button(action: {
                    _ = controller.openMeetLink(event: event, inApp: false)
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 7))
                        Text("Open in Browser")
                            .font(.system(size: 9, weight: .medium))
                    }
                    .foregroundColor(Color.white.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
            .frame(width: 150)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 0.5)
            )
        }
        .frame(maxHeight: 124)
    }
    
    // MARK: - 3. Detected Meeting Lobby View (Lobby / Pre-Join Screen)
    private var detectedMeetingLobbyView: some View {
        HStack(spacing: 12) {
            // Left Pane: Meeting Detection Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: controller.activeService.iconName)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(controller.activeService.badgeColor)
                    
                    Text("\(controller.activeService.rawValue) Detected")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("READY TO JOIN")
                        .font(.system(size: 8.5, weight: .heavy, design: .rounded))
                        .foregroundColor(.cyan)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.cyan.opacity(0.15))
                        .clipShape(Capsule())
                }
                
                Text(controller.activeCallTitle ?? (controller.activeService == .googleMeet ? "Google Meet Call" : "Zoom Meeting"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.7))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
            )
            
            // Right Pane: 1-Click Join Meet / Zoom Button
            VStack(spacing: 6) {
                Button(action: {
                    controller.joinDetectedMeeting()
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: controller.activeService.iconName)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.black)
                        Text(controller.activeService == .googleMeet ? "Join Meet" : "Join Zoom")
                            .font(.system(size: 12.5, weight: .heavy, design: .rounded))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        LinearGradient(
                            colors: [Color.white, Color(white: 0.9)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: Color.white.opacity(0.25), radius: 6)
                }
                .buttonStyle(.plain)
                .help("Automatically join \(controller.activeService.rawValue) call")
            }
            .frame(width: 150)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 0.5)
            )
        }
        .frame(maxHeight: 124)
    }
    
    private func formattedTimeRange(event: CalendarEvent) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: event.startTime)) – \(formatter.string(from: event.endTime))"
    }
}

// MARK: - Notch Compact Wings for Meeting Flight Controller
public struct CompactMeetingWingLeft: View {
    @ObservedObject var controller: MeetingFlightControllerModel
    let model: NotchModel
    
    public init(controller: MeetingFlightControllerModel, model: NotchModel) {
        self.controller = controller
        self.model = model
    }
    
    @ViewBuilder
    public var body: some View {
        if controller.isMeetingActiveOrDetected {
            Button(action: {
                model.openContextualFeature(.meetingFlight)
            }) {
                HStack(spacing: 6) {
                    if controller.isInCall {
                        Image(systemName: controller.activeService.iconName)
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundColor(controller.activeService.badgeColor)
                        Text(controller.formattedCallDuration)
                            .font(.system(size: 10.5, weight: .heavy, design: .monospaced))
                            .foregroundColor(.white)
                    } else if controller.isMeetingDetected {
                        Image(systemName: controller.activeService.iconName)
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundColor(controller.activeService.badgeColor)
                        Text(controller.activeService == .googleMeet ? "Meet" : "Zoom")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.cyan)
                    }
                }
                .padding(.leading, 12)
            }
            .buttonStyle(.plain)
            .help(controller.isInCall ? "In Call (\(controller.formattedCallDuration))" : "Join \(controller.activeService.rawValue)")
        } else {
            EmptyView()
        }
    }
}

public struct CompactMeetingWingRight: View {
    @ObservedObject var controller: MeetingFlightControllerModel
    let model: NotchModel
    
    public init(controller: MeetingFlightControllerModel, model: NotchModel) {
        self.controller = controller
        self.model = model
    }
    
    @ViewBuilder
    public var body: some View {
        if controller.isMeetingActiveOrDetected {
            HStack(spacing: 5) {
                if controller.isInCall {
                    // Mic Mute Toggle
                    Button(action: {
                        controller.toggleMute()
                    }) {
                        Image(systemName: controller.isMuted ? "mic.slash.fill" : "mic.fill")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(controller.isMuted ? .red : .white)
                            .frame(width: 18, height: 18)
                            .background(Color.white.opacity(0.14))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help(controller.isMuted ? "Unmute Microphone (⌥Space)" : "Mute Microphone (⌥Space)")
                    
                    // Red End Call Button
                    Button(action: {
                        controller.endCall()
                    }) {
                        Image(systemName: "phone.down.fill")
                            .font(.system(size: 7.5, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 18, height: 18)
                            .background(Color.red.opacity(0.85))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Leave Call & Close (⌘⇧E)")
                } else if controller.isMeetingDetected {
                    // 1-Click Join Meet / Join Zoom
                    Button(action: {
                        controller.joinDetectedMeeting()
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "video.fill")
                                .font(.system(size: 7))
                            Text(controller.activeService == .googleMeet ? "Join Meet" : "Join Zoom")
                                .font(.system(size: 8.5, weight: .heavy, design: .rounded))
                        }
                        .foregroundColor(.black)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2.5)
                        .background(Color.white)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("Join \(controller.activeService.rawValue) automatically")
                }
                
                Button(action: {
                    model.openContextualFeature(.meetingFlight)
                }) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 7.5, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.45))
                        .frame(width: 16, height: 16)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Expand Meeting Cockpit")
            }
            .padding(.trailing, 12)
        } else {
            EmptyView()
        }
    }
}
