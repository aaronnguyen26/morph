import Foundation
import Combine

public enum RiskLevel: String, Codable, Equatable, Comparable, Sendable {
    case low
    case medium
    case high
    
    public var rank: Int {
        switch self {
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        }
    }
    
    public static func < (lhs: RiskLevel, rhs: RiskLevel) -> Bool {
        lhs.rank < rhs.rank
    }
}

public enum ApprovalStatus: String, Codable, Equatable, Sendable {
    case pending
    case approved
    case rejected
    case expired
}

public enum CommandApprovalDecision: Equatable, Sendable {
    case approved
    case rejected
    case expired
    
    public var exitCode: Int32 {
        switch self {
        case .approved: return 0
        case .rejected: return 1
        case .expired: return 124 // Standard POSIX timeout exit code
        }
    }
}

public struct CommandApprovalRequest: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let command: String
    public let riskLevel: RiskLevel
    public let timeoutSeconds: TimeInterval
    public let requestedAt: Date
    public let source: String
    public let metadata: [String: String]
    public var status: ApprovalStatus
    
    public init(
        id: UUID = UUID(),
        command: String,
        riskLevel: RiskLevel = .medium,
        timeoutSeconds: TimeInterval = 30,
        requestedAt: Date = Date(),
        source: String = "CLI",
        metadata: [String: String] = [:],
        status: ApprovalStatus = .pending
    ) {
        self.id = id
        self.command = command
        self.riskLevel = riskLevel
        self.timeoutSeconds = timeoutSeconds
        self.requestedAt = requestedAt
        self.source = source
        self.metadata = metadata
        self.status = status
    }
}

@MainActor
public final class CommandApprovalModel: ObservableObject {
    @Published public var pendingRequests: [CommandApprovalRequest] = []
    @Published public var currentRequest: CommandApprovalRequest?
    @Published public var history: [CommandApprovalRequest] = []
    
    public var hasPendingApproval: Bool {
        currentRequest != nil
    }
    
    private var completionHandlers: [UUID: (CommandApprovalDecision) -> Void] = [:]
    private var expirationTimers: [UUID: AnyCancellable] = [:]
    
    private static var isTestingEnvironment: Bool {
        return ProcessInfo.processInfo.processName.contains("xctest") ||
            ProcessInfo.processInfo.arguments.contains(where: { $0.contains("xctest") }) ||
            ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
            ProcessInfo.processInfo.environment["XCTestBundlePath"] != nil ||
            NSClassFromString("XCTestCase") != nil
    }
    
    public init() {}
    
    // MARK: - Request Lifecycle
    
    @discardableResult
    public func requestApproval(
        command: String,
        riskLevel: RiskLevel = .medium,
        timeoutSeconds: TimeInterval = 30,
        source: String = "CLI",
        metadata: [String: String] = [:],
        completion: ((CommandApprovalDecision) -> Void)? = nil
    ) -> CommandApprovalRequest {
        let request = CommandApprovalRequest(
            command: command,
            riskLevel: riskLevel,
            timeoutSeconds: timeoutSeconds,
            requestedAt: Date(),
            source: source,
            metadata: metadata,
            status: .pending
        )
        
        pendingRequests.append(request)
        if currentRequest == nil {
            currentRequest = request
        }
        
        if let completion = completion {
            completionHandlers[request.id] = completion
        }
        
        if timeoutSeconds > 0 && !Self.isTestingEnvironment {
            let reqId = request.id
            expirationTimers[reqId] = Timer.publish(every: timeoutSeconds, on: .main, in: .common)
                .autoconnect()
                .first()
                .sink { [weak self] _ in
                    self?.expire(id: reqId)
                }
        }
        
        return request
    }
    
    public func approve(id: UUID) {
        resolve(id: id, decision: .approved, newStatus: .approved)
    }
    
    public func reject(id: UUID) {
        resolve(id: id, decision: .rejected, newStatus: .rejected)
    }
    
    public func expire(id: UUID) {
        resolve(id: id, decision: .expired, newStatus: .expired)
    }
    
    public func dismiss() {
        guard let current = currentRequest else { return }
        reject(id: current.id)
    }
    
    private func resolve(id: UUID, decision: CommandApprovalDecision, newStatus: ApprovalStatus) {
        expirationTimers[id]?.cancel()
        expirationTimers.removeValue(forKey: id)
        
        guard let index = pendingRequests.firstIndex(where: { $0.id == id }) else {
            return
        }
        
        var request = pendingRequests[index]
        request.status = newStatus
        pendingRequests.remove(at: index)
        history.insert(request, at: 0)
        
        let handler = completionHandlers.removeValue(forKey: id)
        handler?(decision)
        
        // Post distributed notification for CLI / external scripts waiting on the decision
        DistributedNotificationCenter.default().postNotificationName(
            NSNotification.Name("com.morph.commandApprovalDecision.\(id.uuidString)"),
            object: nil,
            userInfo: [
                "id": id.uuidString,
                "status": newStatus.rawValue,
                "decision": decision == .approved ? "approved" : (decision == .rejected ? "rejected" : "expired"),
                "exitCode": NSNumber(value: decision.exitCode)
            ],
            deliverImmediately: true
        )
        
        // Update currentRequest pointer
        if currentRequest?.id == id {
            currentRequest = pendingRequests.first
        }
    }
}
