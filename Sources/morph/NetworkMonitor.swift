import Foundation
import Network
import Combine

@MainActor
public final class NetworkMonitor: ObservableObject {
    public static let shared = NetworkMonitor()
    
    @Published public private(set) var isConnected: Bool = true
    @Published public private(set) var isWifiConnected: Bool = true
    @Published public private(set) var isExpensive: Bool = false
    @Published public private(set) var isConstrained: Bool = false
    
    /// Test seam: allows deterministic offline testing without relying on physical network status
    public var overrideIsConnected: Bool? = nil {
        didSet {
            if let override = overrideIsConnected {
                self.isConnected = override
                self.isWifiConnected = override
            }
        }
    }
    
    private var monitor: NWPathMonitor?
    private let monitorQueue = DispatchQueue(label: "com.morph.networkmonitor", qos: .utility)
    
    public init(startImmediately: Bool = true) {
        if !MorphEnvironment.isTestingEnvironment && startImmediately {
            start()
        }
    }
    
    public func start() {
        guard monitor == nil else { return }
        let mon = NWPathMonitor()
        mon.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if let override = self.overrideIsConnected {
                    self.isConnected = override
                    self.isWifiConnected = override
                } else {
                    let satisfied = (path.status == .satisfied)
                    self.isConnected = satisfied
                    self.isWifiConnected = satisfied && path.usesInterfaceType(.wifi)
                    self.isExpensive = path.isExpensive
                    self.isConstrained = path.isConstrained
                }
            }
        }
        mon.start(queue: monitorQueue)
        self.monitor = mon
    }
    
    public func stop() {
        monitor?.cancel()
        monitor = nil
    }
    
    public func setConnectedForTesting(_ connected: Bool) {
        self.overrideIsConnected = connected
        self.isConnected = connected
        self.isWifiConnected = connected
    }
}
