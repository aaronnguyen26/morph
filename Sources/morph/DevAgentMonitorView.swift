import SwiftUI

public struct DevAgentMonitorView: View {
    @ObservedObject var model: NotchModel
    @State private var copiedFeedback: Bool = false
    
    public init(model: NotchModel) {
        self.model = model
    }
    
    private var monitor: DevAgentMonitorModel {
        model.devMonitor
    }
    
    public var body: some View {
        VStack(spacing: 6) {
            // Header Bar
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "terminal.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.cyan)
                    
                    Text("Dev Monitor")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    statusBadge
                }
                
                Spacer()
                
                // Copy Logs, Clear, and Cancel Controls
                HStack(spacing: 6) {
                    Button(action: {
                        copyLogOutput()
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: copiedFeedback ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 8))
                            Text(copiedFeedback ? "Copied" : "Copy Log")
                                .font(.system(size: 9.5, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3.5)
                        .background(Color.white.opacity(0.10))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                    .help("Copy full terminal output to clipboard")
                    
                    if monitor.isTaskActive {
                        Button(action: {
                            monitor.cancelTask()
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: "stop.circle.fill")
                                    .font(.system(size: 8))
                                Text("Cancel")
                                    .font(.system(size: 9.5, weight: .semibold))
                            }
                            .foregroundColor(.red)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3.5)
                            .background(Color.red.opacity(0.14))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.red.opacity(0.24), lineWidth: 0.5))
                        }
                        .buttonStyle(.plain)
                        .help("Cancel running dev task")
                    } else {
                        Button(action: {
                            monitor.clearOutput()
                        }) {
                            Text("Clear")
                                .font(.system(size: 9.5, weight: .semibold))
                                .foregroundColor(Color.white.opacity(0.6))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3.5)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .help("Clear terminal screen")
                    }
                }
            }
            .padding(.horizontal, 4)
            
            // Progress Track
            if monitor.progress > 0 && monitor.isTaskActive {
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.12))
                        .frame(height: 3)
                    
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.cyan, Color.white],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(4, CGFloat(monitor.progress) * 600), height: 3)
                }
                .padding(.horizontal, 4)
            }
            
            // Terminal Log Viewer
            terminalLogViewer
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Status Badge
    @ViewBuilder
    private var statusBadge: some View {
        if let task = monitor.currentTask {
            switch task.status {
            case .running:
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.cyan)
                        .frame(width: 5, height: 5)
                    Text("RUNNING")
                        .font(.system(size: 8, weight: .heavy, design: .rounded))
                        .foregroundColor(.cyan)
                    if monitor.progress > 0 {
                        Text("\(Int(monitor.progress * 100))%")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundColor(Color.white.opacity(0.8))
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.cyan.opacity(0.15))
                .clipShape(Capsule())
            case .succeeded:
                HStack(spacing: 3) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 7, weight: .bold))
                    Text("SUCCESS")
                        .font(.system(size: 8, weight: .heavy, design: .rounded))
                }
                .foregroundColor(.green)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.green.opacity(0.15))
                .clipShape(Capsule())
            case .failed:
                HStack(spacing: 3) {
                    Image(systemName: "xmark")
                        .font(.system(size: 7, weight: .bold))
                    Text("FAILED")
                        .font(.system(size: 8, weight: .heavy, design: .rounded))
                }
                .foregroundColor(.red)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.red.opacity(0.15))
                .clipShape(Capsule())
            case .cancelled:
                Text("CANCELLED")
                    .font(.system(size: 8, weight: .heavy, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.6))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.10))
                    .clipShape(Capsule())
            }
        }
    }
    
    // MARK: - Terminal Log Viewer
    private var terminalLogViewer: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(alignment: .leading, spacing: 2) {
                    if monitor.stdoutLines.isEmpty {
                        HStack(spacing: 6) {
                            Text(">_")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.cyan)
                            Text("Ready for background commands & live streaming output...")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(Color.white.opacity(0.4))
                        }
                        .padding(8)
                    } else {
                        ForEach(Array(monitor.stdoutLines.enumerated()), id: \.offset) { idx, line in
                            HStack(alignment: .top, spacing: 6) {
                                Text(String(format: "%02d", idx + 1))
                                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                                    .foregroundColor(Color.white.opacity(0.25))
                                    .frame(width: 18, alignment: .trailing)
                                
                                Text(line)
                                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                                    .foregroundColor(lineColor(for: line))
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .id(idx)
                        }
                    }
                }
                .padding(6)
            }
            .background(Color.black.opacity(0.75))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
            )
            .onChange(of: monitor.stdoutLines.count) { newCount in
                if newCount > 0 {
                    withAnimation(.easeOut(duration: 0.1)) {
                        proxy.scrollTo(newCount - 1, anchor: .bottom)
                    }
                }
            }
        }
        .frame(maxHeight: 120)
    }
    
    private func lineColor(for line: String) -> Color {
        let lower = line.lowercased()
        if lower.contains("error") || lower.contains("failed") || lower.contains("fatal") {
            return Color.red.opacity(0.9)
        } else if lower.contains("warning") || lower.contains("warn") {
            return Color.yellow.opacity(0.9)
        } else if lower.contains("success") || lower.contains("done") || lower.contains("passed") {
            return Color.green.opacity(0.9)
        } else if line.hasPrefix("$") || line.hasPrefix(">") {
            return Color.cyan.opacity(0.9)
        } else {
            return Color.white.opacity(0.85)
        }
    }
    
    private func copyLogOutput() {
        let text = monitor.fullStdoutText
        guard !text.isEmpty else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        withAnimation {
            copiedFeedback = true
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            withAnimation {
                copiedFeedback = false
            }
        }
    }
}

// MARK: - Notch Compact Wings for Dev Monitor
public struct CompactDevMonitorWingLeft: View {
    @ObservedObject var monitor: DevAgentMonitorModel
    let model: NotchModel
    @State private var isSpinning: Bool = false
    
    public init(monitor: DevAgentMonitorModel, model: NotchModel) {
        self.monitor = monitor
        self.model = model
    }
    
    public var body: some View {
        Button(action: {
            model.openContextualFeature(.devMonitor)
        }) {
            HStack(spacing: 5.5) {
                if monitor.isTaskActive {
                    Image(systemName: "terminal.fill")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundColor(.cyan)
                } else if monitor.currentTask?.status == .succeeded {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundColor(.green)
                } else if monitor.currentTask?.status == .failed {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundColor(.red)
                } else {
                    Text(">_")
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)
                }
                
                Text(truncatedMessage)
                    .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.9))
                    .lineLimit(1)
                    .frame(maxWidth: 125, alignment: .leading)
            }
            .padding(.leading, 12)
        }
        .buttonStyle(.plain)
        .help("Open Terminal Monitor")
    }
    
    private var truncatedMessage: String {
        let msg = monitor.statusMessage
        return msg.isEmpty ? "compiling..." : msg
    }
}

public struct CompactDevMonitorWingRight: View {
    @ObservedObject var monitor: DevAgentMonitorModel
    let model: NotchModel
    
    public init(monitor: DevAgentMonitorModel, model: NotchModel) {
        self.monitor = monitor
        self.model = model
    }
    
    public var body: some View {
        HStack(spacing: 5) {
            if monitor.progress > 0 && monitor.isTaskActive {
                Text("\(Int(monitor.progress * 100))%")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .foregroundColor(.cyan)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.cyan.opacity(0.18))
                    .clipShape(Capsule())
            }
            
            Button(action: {
                model.openContextualFeature(.devMonitor)
            }) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 7.5, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.45))
                    .frame(width: 16, height: 16)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Expand Terminal Monitor")
        }
        .padding(.trailing, 12)
    }
}
