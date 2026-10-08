import SwiftUI

public struct CommandApprovalView: View {
    @ObservedObject var model: NotchModel
    @State private var timeRemainingRatio: Double = 1.0
    @State private var timerActive: Bool = false
    
    public init(model: NotchModel) {
        self.model = model
    }
    
    private var approval: CommandApprovalModel {
        model.commandApproval
    }
    
    public var body: some View {
        VStack(spacing: 8) {
            // Header Bar
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.shield.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color.orange)
                    
                    Text("Command Approval Gate")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    if let req = approval.currentRequest {
                        riskBadge(for: req.riskLevel)
                    }
                }
                
                Spacer()
                
                if let req = approval.currentRequest {
                    Text("Source: \(req.source)")
                        .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 4)
            
            // Body: Active Approval Card vs Gate Standby
            if let req = approval.currentRequest {
                activeRequestCard(req: req)
            } else {
                gateStandbyCard
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Active Request Card
    private func activeRequestCard(req: CommandApprovalRequest) -> some View {
        VStack(spacing: 8) {
            // Monospace Command Box
            HStack(alignment: .top, spacing: 8) {
                Text("$")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.orange)
                
                Text(req.command)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(2)
                
                Button(action: {
                    let pb = NSPasteboard.general
                    pb.clearContents()
                    pb.setString(req.command, forType: .string)
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 8.5))
                        .foregroundColor(Color.white.opacity(0.6))
                        .padding(4)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Copy Command")
            }
            .padding(10)
            .background(Color.black.opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 0.5)
            )
            
            // Timeout Countdown Bar
            if req.timeoutSeconds > 0 {
                VStack(spacing: 2) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.10))
                                .frame(height: 3)
                            
                            Capsule()
                                .fill(Color.orange)
                                .frame(width: max(0, geo.size.width * CGFloat(timeRemainingRatio)), height: 3)
                        }
                    }
                    .frame(height: 3)
                    
                    HStack {
                        Text("Auto-expires in \(Int(req.timeoutSeconds))s")
                            .font(.system(size: 8.5, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.4))
                        Spacer()
                    }
                }
                .padding(.horizontal, 2)
            }
            
            // Tactile Action Buttons Row
            HStack(spacing: 12) {
                // Reject Button
                Button(action: {
                    approval.reject(id: req.id)
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                        Text("Reject (Esc)")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(Color.white.opacity(0.9))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6.5)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.18), lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                // Authorize Button
                Button(action: {
                    approval.approve(id: req.id)
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text("Authorize (⌘↵)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6.5)
                    .background(Color.white)
                    .clipShape(Capsule())
                    .shadow(color: Color.white.opacity(0.25), radius: 6)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 2)
        }
        .frame(maxHeight: 124)
        .onAppear {
            startTimeCountdown(seconds: req.timeoutSeconds)
        }
    }
    
    // MARK: - Risk Badge
    private func riskBadge(for risk: RiskLevel) -> some View {
        HStack(spacing: 3) {
            Circle()
                .fill(riskColor(for: risk))
                .frame(width: 5, height: 5)
            Text("\(risk.rawValue.uppercased()) RISK")
                .font(.system(size: 8, weight: .heavy, design: .rounded))
                .foregroundColor(riskColor(for: risk))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(riskColor(for: risk).opacity(0.15))
        .clipShape(Capsule())
    }
    
    private func riskColor(for risk: RiskLevel) -> Color {
        switch risk {
        case .high: return .red
        case .medium: return .orange
        case .low: return .cyan
        }
    }
    
    // MARK: - Gate Standby Card
    private var gateStandbyCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.shield")
                .font(.system(size: 20))
                .foregroundColor(Color.white.opacity(0.5))
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Security Gate Armed")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("All developer agent commands and high-risk terminal actions require manual gate authorization.")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(Color.white.opacity(0.45))
            }
            
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 0.5)
        )
        .frame(maxHeight: 124)
    }
    
    private func startTimeCountdown(seconds: TimeInterval) {
        guard seconds > 0 else { return }
        timeRemainingRatio = 1.0
        withAnimation(.linear(duration: seconds)) {
            timeRemainingRatio = 0.0
        }
    }
}

// MARK: - Notch Compact Wings for Command Approval
public struct CompactApprovalWingLeft: View {
    @ObservedObject var approval: CommandApprovalModel
    let model: NotchModel
    
    public init(approval: CommandApprovalModel, model: NotchModel) {
        self.approval = approval
        self.model = model
    }
    
    public var body: some View {
        Button(action: {
            model.openContextualFeature(.commandApproval)
        }) {
            HStack(spacing: 5) {
                Image(systemName: "exclamationmark.shield.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color.orange)
                
                Text("Authorize?")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
            }
            .padding(.leading, 12)
        }
        .buttonStyle(.plain)
        .help("Open Command Approval Gate")
    }
}

public struct CompactApprovalWingRight: View {
    @ObservedObject var approval: CommandApprovalModel
    let model: NotchModel
    
    public init(approval: CommandApprovalModel, model: NotchModel) {
        self.approval = approval
        self.model = model
    }
    
    public var body: some View {
        HStack(spacing: 5) {
            if let req = approval.currentRequest {
                Button(action: {
                    approval.reject(id: req.id)
                }) {
                    Text("Deny")
                        .font(.system(size: 8.5, weight: .bold, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.85))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background(Color.white.opacity(0.15))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("Reject Command")
                
                Button(action: {
                    approval.approve(id: req.id)
                }) {
                    Text("Allow")
                        .font(.system(size: 8.5, weight: .heavy, design: .rounded))
                        .foregroundColor(.black)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2.5)
                        .background(Color.white)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("Authorize Command")
            }
            
            Button(action: {
                model.openContextualFeature(.commandApproval)
            }) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 7.5, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.45))
                    .frame(width: 16, height: 16)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Expand Approval Gate")
        }
        .padding(.trailing, 12)
    }
}
