import Foundation
import CoreAudio
import AudioToolbox
import Combine

@MainActor
public protocol SystemAudioServiceProtocol: AnyObject {
    var volume: Double { get }
    var isMuted: Bool { get }
    var onVolumeChanged: (@MainActor (Double, Bool) -> Void)? { get set }
    
    func getVolume() -> Double
    func getMuted() -> Bool
    func setSystemVolume(_ newVolume: Double)
    func setMuted(_ isMuted: Bool)
    func startMonitoring()
    func stopMonitoring()
}

@MainActor
public final class SystemAudioService: ObservableObject, SystemAudioServiceProtocol {
    public static let shared = SystemAudioService()
    
    @Published public private(set) var volume: Double = 0.5
    @Published public private(set) var isMuted: Bool = false
    public var onVolumeChanged: (@MainActor (Double, Bool) -> Void)?
    
    private var isMonitoring: Bool = false
    private var currentDeviceID: AudioDeviceID = AudioObjectID(kAudioObjectUnknown)
    
    // Retained listener blocks to safely add and remove with CoreAudio
    private var defaultDeviceListenerBlock: AudioObjectPropertyListenerBlock?
    private var virtualVolumeListenerBlock: AudioObjectPropertyListenerBlock?
    private var scalarVolumeListenerBlock: AudioObjectPropertyListenerBlock?
    private var muteListenerBlock: AudioObjectPropertyListenerBlock?
    
    // Echo suppression
    private var lastSetVolume: Double?
    private var lastSetVolumeTime: Date?
    private var lastSetMute: Bool?
    private var lastSetMuteTime: Date?
    
    public let isTestMode: Bool
    
    public init(isTestMode: Bool = MorphEnvironment.isTestingEnvironment) {
        self.isTestMode = isTestMode
        if !isTestMode {
            let dev = getDefaultOutputDevice()
            self.currentDeviceID = dev
            if dev != kAudioObjectUnknown {
                self.volume = readVolumeFromDevice(dev)
                self.isMuted = readMuteFromDevice(dev)
            }
        }
    }
    
    // MARK: - Protocol Methods
    
    public func getVolume() -> Double {
        if isTestMode {
            return volume
        }
        let dev = getDefaultOutputDevice()
        if dev != kAudioObjectUnknown {
            let vol = readVolumeFromDevice(dev)
            self.volume = vol
            return vol
        }
        return volume
    }
    
    public func getMuted() -> Bool {
        if isTestMode {
            return isMuted
        }
        let dev = getDefaultOutputDevice()
        if dev != kAudioObjectUnknown {
            let muted = readMuteFromDevice(dev)
            self.isMuted = muted
            return muted
        }
        return isMuted
    }
    
    public func setSystemVolume(_ newVolume: Double) {
        let clamped = max(0.0, min(1.0, newVolume))
        self.volume = clamped
        self.lastSetVolume = clamped
        self.lastSetVolumeTime = Date()
        
        guard !isTestMode else { return }
        
        let dev = getDefaultOutputDevice()
        guard dev != kAudioObjectUnknown else { return }
        
        var vol = Float32(clamped)
        let volSize = UInt32(MemoryLayout<Float32>.size)
        
        // 1. Try modern Virtual Main Volume
        var virtualAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        if AudioObjectHasProperty(dev, &virtualAddr) {
            var settable: DarwinBoolean = false
            if AudioObjectIsPropertySettable(dev, &virtualAddr, &settable) == noErr && settable.boolValue {
                _ = AudioObjectSetPropertyData(dev, &virtualAddr, 0, nil, volSize, &vol)
                return
            }
        }
        
        // 2. Fallback to main scalar volume
        var scalarAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        if AudioObjectHasProperty(dev, &scalarAddr) {
            var settable: DarwinBoolean = false
            if AudioObjectIsPropertySettable(dev, &scalarAddr, &settable) == noErr && settable.boolValue {
                _ = AudioObjectSetPropertyData(dev, &scalarAddr, 0, nil, volSize, &vol)
                return
            }
        }
        
        // 3. Fallback to individual output channels (1 & 2)
        for channel in [UInt32(1), UInt32(2)] {
            var channelAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioObjectPropertyScopeOutput,
                mElement: channel
            )
            if AudioObjectHasProperty(dev, &channelAddr) {
                var settable: DarwinBoolean = false
                if AudioObjectIsPropertySettable(dev, &channelAddr, &settable) == noErr && settable.boolValue {
                    _ = AudioObjectSetPropertyData(dev, &channelAddr, 0, nil, volSize, &vol)
                }
            }
        }
    }
    
    public func setMuted(_ isMuted: Bool) {
        self.isMuted = isMuted
        self.lastSetMute = isMuted
        self.lastSetMuteTime = Date()
        
        guard !isTestMode else { return }
        
        let dev = getDefaultOutputDevice()
        guard dev != kAudioObjectUnknown else { return }
        
        var muteVal: UInt32 = isMuted ? 1 : 0
        let muteSize = UInt32(MemoryLayout<UInt32>.size)
        
        var muteAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        if AudioObjectHasProperty(dev, &muteAddr) {
            var settable: DarwinBoolean = false
            if AudioObjectIsPropertySettable(dev, &muteAddr, &settable) == noErr && settable.boolValue {
                _ = AudioObjectSetPropertyData(dev, &muteAddr, 0, nil, muteSize, &muteVal)
                return
            }
        }
        
        for channel in [UInt32(1), UInt32(2)] {
            var chAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyMute,
                mScope: kAudioObjectPropertyScopeOutput,
                mElement: channel
            )
            if AudioObjectHasProperty(dev, &chAddr) {
                var settable: DarwinBoolean = false
                if AudioObjectIsPropertySettable(dev, &chAddr, &settable) == noErr && settable.boolValue {
                    _ = AudioObjectSetPropertyData(dev, &chAddr, 0, nil, muteSize, &muteVal)
                }
            }
        }
    }
    
    // MARK: - Monitoring Lifecycle
    
    public func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        
        guard !isTestMode else { return }
        
        let dev = getDefaultOutputDevice()
        currentDeviceID = dev
        if dev != kAudioObjectUnknown {
            self.volume = readVolumeFromDevice(dev)
            self.isMuted = readMuteFromDevice(dev)
        }
        
        bindDefaultDeviceListener()
        if dev != kAudioObjectUnknown {
            bindDeviceListeners(dev)
        }
    }
    
    public func stopMonitoring() {
        guard isMonitoring else { return }
        isMonitoring = false
        
        guard !isTestMode else { return }
        
        unbindDefaultDeviceListener()
        if currentDeviceID != kAudioObjectUnknown {
            unbindDeviceListeners(currentDeviceID)
            currentDeviceID = AudioObjectID(kAudioObjectUnknown)
        }
    }
    
    // MARK: - CoreAudio Internal Helpers
    
    private func getDefaultOutputDevice() -> AudioDeviceID {
        var dev: AudioDeviceID = AudioObjectID(kAudioObjectUnknown)
        var propSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &addr,
            0,
            nil,
            &propSize,
            &dev
        )
        return status == noErr ? dev : AudioObjectID(kAudioObjectUnknown)
    }
    
    private func readVolumeFromDevice(_ dev: AudioDeviceID) -> Double {
        var volume: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        
        // 1. Virtual Main Volume
        var virtualAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        if AudioObjectHasProperty(dev, &virtualAddr) {
            if AudioObjectGetPropertyData(dev, &virtualAddr, 0, nil, &size, &volume) == noErr {
                return Double(max(0.0, min(1.0, volume)))
            }
        }
        
        // 2. Main scalar volume
        var scalarAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        if AudioObjectHasProperty(dev, &scalarAddr) {
            if AudioObjectGetPropertyData(dev, &scalarAddr, 0, nil, &size, &volume) == noErr {
                return Double(max(0.0, min(1.0, volume)))
            }
        }
        
        // 3. Fallback to channel 1
        for channel in [UInt32(1), UInt32(2)] {
            var chAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioObjectPropertyScopeOutput,
                mElement: channel
            )
            if AudioObjectHasProperty(dev, &chAddr) {
                if AudioObjectGetPropertyData(dev, &chAddr, 0, nil, &size, &volume) == noErr {
                    return Double(max(0.0, min(1.0, volume)))
                }
            }
        }
        
        return self.volume
    }
    
    private func readMuteFromDevice(_ dev: AudioDeviceID) -> Bool {
        var isMuted: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        
        var muteAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        if AudioObjectHasProperty(dev, &muteAddr) {
            if AudioObjectGetPropertyData(dev, &muteAddr, 0, nil, &size, &isMuted) == noErr {
                return isMuted != 0
            }
        }
        
        for channel in [UInt32(1), UInt32(2)] {
            var chAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyMute,
                mScope: kAudioObjectPropertyScopeOutput,
                mElement: channel
            )
            if AudioObjectHasProperty(dev, &chAddr) {
                if AudioObjectGetPropertyData(dev, &chAddr, 0, nil, &size, &isMuted) == noErr {
                    return isMuted != 0
                }
            }
        }
        
        return false
    }
    
    // MARK: - Listener Management
    
    private func bindDefaultDeviceListener() {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor [weak self] in
                guard let self = self, self.isMonitoring else { return }
                let newDev = self.getDefaultOutputDevice()
                guard newDev != self.currentDeviceID && newDev != kAudioObjectUnknown else { return }
                
                if self.currentDeviceID != kAudioObjectUnknown {
                    self.unbindDeviceListeners(self.currentDeviceID)
                }
                self.currentDeviceID = newDev
                self.bindDeviceListeners(newDev)
                
                let newVol = self.readVolumeFromDevice(newDev)
                let newMute = self.readMuteFromDevice(newDev)
                self.volume = newVol
                self.isMuted = newMute
                self.onVolumeChanged?(newVol, newMute)
            }
        }
        self.defaultDeviceListenerBlock = block
        
        _ = AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &addr,
            DispatchQueue.main,
            block
        )
    }
    
    private func unbindDefaultDeviceListener() {
        guard let block = defaultDeviceListenerBlock else { return }
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        _ = AudioObjectRemovePropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &addr,
            DispatchQueue.main,
            block
        )
        self.defaultDeviceListenerBlock = nil
    }
    
    private func bindDeviceListeners(_ dev: AudioDeviceID) {
        guard dev != kAudioObjectUnknown else { return }
        
        let handler: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor [weak self] in
                guard let self = self, self.isMonitoring else { return }
                let currentVol = self.readVolumeFromDevice(self.currentDeviceID)
                let currentMute = self.readMuteFromDevice(self.currentDeviceID)
                
                // Echo suppression for volume
                if let lastSet = self.lastSetVolume, let lastTime = self.lastSetVolumeTime {
                    if abs(currentVol - lastSet) < 0.005 && Date().timeIntervalSince(lastTime) < 0.4 {
                        self.volume = currentVol
                        self.isMuted = currentMute
                        return
                    }
                }
                
                // Echo suppression for mute
                if let lastMute = self.lastSetMute, let lastTime = self.lastSetMuteTime {
                    if currentMute == lastMute && Date().timeIntervalSince(lastTime) < 0.4 {
                        self.volume = currentVol
                        self.isMuted = currentMute
                        return
                    }
                }
                
                let volChanged = abs(self.volume - currentVol) > 0.002
                let muteChanged = self.isMuted != currentMute
                
                if volChanged || muteChanged {
                    self.volume = currentVol
                    self.isMuted = currentMute
                    self.onVolumeChanged?(currentVol, currentMute)
                }
            }
        }
        
        // Virtual volume
        var virtualAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        if AudioObjectHasProperty(dev, &virtualAddr) {
            self.virtualVolumeListenerBlock = handler
            _ = AudioObjectAddPropertyListenerBlock(dev, &virtualAddr, DispatchQueue.main, handler)
        }
        
        // Scalar volume
        var scalarAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        if AudioObjectHasProperty(dev, &scalarAddr) {
            self.scalarVolumeListenerBlock = handler
            _ = AudioObjectAddPropertyListenerBlock(dev, &scalarAddr, DispatchQueue.main, handler)
        }
        
        // Mute
        var muteAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        if AudioObjectHasProperty(dev, &muteAddr) {
            self.muteListenerBlock = handler
            _ = AudioObjectAddPropertyListenerBlock(dev, &muteAddr, DispatchQueue.main, handler)
        }
    }
    
    private func unbindDeviceListeners(_ dev: AudioDeviceID) {
        guard dev != kAudioObjectUnknown else { return }
        
        if let block = virtualVolumeListenerBlock {
            var virtualAddr = AudioObjectPropertyAddress(
                mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
                mScope: kAudioObjectPropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            _ = AudioObjectRemovePropertyListenerBlock(dev, &virtualAddr, DispatchQueue.main, block)
            virtualVolumeListenerBlock = nil
        }
        
        if let block = scalarVolumeListenerBlock {
            var scalarAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioObjectPropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            _ = AudioObjectRemovePropertyListenerBlock(dev, &scalarAddr, DispatchQueue.main, block)
            scalarVolumeListenerBlock = nil
        }
        
        if let block = muteListenerBlock {
            var muteAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyMute,
                mScope: kAudioObjectPropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            _ = AudioObjectRemovePropertyListenerBlock(dev, &muteAddr, DispatchQueue.main, block)
            muteListenerBlock = nil
        }
    }
}

// MARK: - Mock for Automated Testing

@MainActor
public final class MockSystemAudioService: ObservableObject, SystemAudioServiceProtocol {
    @Published public var volume: Double
    @Published public var isMuted: Bool
    public var onVolumeChanged: (@MainActor (Double, Bool) -> Void)?
    
    public private(set) var isMonitoring: Bool = false
    public private(set) var setSystemVolumeCalls: [Double] = []
    public private(set) var setMutedCalls: [Bool] = []
    
    public init(initialVolume: Double = 0.5, initialMuted: Bool = false) {
        self.volume = initialVolume
        self.isMuted = initialMuted
    }
    
    public func getVolume() -> Double {
        return volume
    }
    
    public func getMuted() -> Bool {
        return isMuted
    }
    
    public func setSystemVolume(_ newVolume: Double) {
        let clamped = max(0.0, min(1.0, newVolume))
        self.volume = clamped
        self.setSystemVolumeCalls.append(clamped)
    }
    
    public func setMuted(_ isMuted: Bool) {
        self.isMuted = isMuted
        self.setMutedCalls.append(isMuted)
    }
    
    public func startMonitoring() {
        isMonitoring = true
    }
    
    public func stopMonitoring() {
        isMonitoring = false
    }
    
    /// Simulates user increasing or decreasing volume on laptop hardware
    public func simulateLaptopVolumeChange(to newVolume: Double, isMuted: Bool? = nil) {
        let clamped = max(0.0, min(1.0, newVolume))
        self.volume = clamped
        if let m = isMuted {
            self.isMuted = m
        }
        onVolumeChanged?(clamped, self.isMuted)
    }
    
    /// Simulates user toggling mute on laptop hardware
    public func simulateLaptopMuteChange(to newMuted: Bool) {
        self.isMuted = newMuted
        onVolumeChanged?(self.volume, newMuted)
    }
}
