//
//  MacOutputManager.swift
//  FX-Live-Mac
//
//  Manages multi-output routing for macOS.
//  Maps virtual output buses from FxEffect.output to physical audio devices.
//  Each bus can be assigned to a different BASS device with its own mixer stream.
//  Starts with 4 buses (A-D, matching iPad) but can be expanded to any number.
//
//  On iPad, FxEffect.output is a mute-group concept (outputA/B/C/D toggles in settings).
//  On Mac, we extend this to mean actual physical device routing.
//  If no multi-output is configured, all buses route to the default device/mixer.
//

import Foundation
import SwiftUI

// MARK: - Data Models

/// Represents a physical audio output device as enumerated by BASS
struct BASSOutputDevice: Identifiable, Hashable {
    let id: Int          // BASS device index
    let name: String     // Human-readable name
    let isEnabled: Bool  // Whether the device is available
    let isDefault: Bool  // Whether this is the system default
    let channelCount: Int // Number of output channels (2 = stereo, 8 = 7.1, etc.)
    
    var displayName: String {
        isDefault ? "\(name) (Default)" : name
    }
    
    /// Number of stereo channel pairs available
    var channelPairs: Int {
        max(1, channelCount / 2)
    }
    
    /// Label for a specific channel pair (e.g. "Channels 1-2", "Channels 3-4")
    static func channelPairLabel(_ pair: Int) -> String {
        let left = pair * 2 + 1
        let right = pair * 2 + 2
        return "Channels \(left)-\(right)"
    }
}

/// Represents a virtual output bus
struct OutputBus: Identifiable {
    let id: Int              // 0-based index
    var name: String         // "Output A", "Output B", etc.
    var bassDeviceIndex: Int // BASS device index (-1 = use default)
    var channelPair: Int     // Which stereo pair on the device (0 = channels 1-2, 1 = channels 3-4, etc.)
    var deviceChannelCount: Int // Total channels on the assigned device (for mixer creation)
    var mixerStream: Int32   // BASS mixer handle (0 = not created)
    var isInitialised: Bool  // Whether the device+mixer are ready
    
    var label: String {
        OutputBus.labelFor(id)
    }
    
    /// Generate a label for any bus index: 0=A, 1=B, ... 25=Z, 26=AA, etc.
    static func labelFor(_ index: Int) -> String {
        if index < 26 {
            return String(UnicodeScalar(65 + index)!) // A-Z
        }
        // For >26 buses (unlikely but supported): AA, AB, etc.
        let first = (index / 26) - 1
        let second = index % 26
        return String(UnicodeScalar(65 + first)!) + String(UnicodeScalar(65 + second)!)
    }
    
    /// Create a new bus with the given index
    static func create(_ index: Int) -> OutputBus {
        OutputBus(
            id: index,
            name: "Output \(labelFor(index))",
            bassDeviceIndex: -1,
            channelPair: 0,
            deviceChannelCount: 2,
            mixerStream: 0,
            isInitialised: false
        )
    }
}

// MARK: - Output Manager

/// Manages multi-output device routing for the Mac app.
class MacOutputManager: ObservableObject {
    static let shared = MacOutputManager()
    
    // MARK: - Published State
    
    /// The output buses (minimum 4, expandable)
    @Published var buses: [OutputBus] = []
    
    /// Available physical audio devices
    @Published var availableDevices: [BASSOutputDevice] = []
    
    /// Whether multi-output is enabled (vs. single default output)
    @Published var multiOutputEnabled: Bool = false
    
    /// Minimum number of buses (matches iPad's A-D)
    static let minimumBusCount = 4
    
    // MARK: - Private State
    
    /// Cache of mixer handles per device: [bassDeviceIndex: (mixer, channelCount)]
    /// Multiple buses on the same device share one mixer, with routing handled per-stream via matrix.
    private var deviceMixerCache: [Int: (mixer: Int32, channels: Int)] = [:]
    
    /// UserDefaults keys for persisting bus assignments
    private let kMultiOutputEnabled = "multiOutputEnabled"
    private let kBusDevicePrefix = "outputBusDevice_" // + bus index
    private let kBusChannelPairPrefix = "outputBusChannelPair_" // + bus index
    private let kBusCount = "outputBusCount"
    
    // MARK: - Initialisation
    
    private init() {
        let savedCount = max(MacOutputManager.minimumBusCount, UserDefaults.standard.integer(forKey: kBusCount))
        let count = savedCount > 0 ? savedCount : MacOutputManager.minimumBusCount
        buses = (0..<count).map { OutputBus.create($0) }
    }
    
    // MARK: - Bus Management
    
    /// Add a new output bus. Returns the index of the new bus.
    @discardableResult
    func addBus() -> Int {
        let newIndex = buses.count
        buses.append(OutputBus.create(newIndex))
        saveSettings()
        print("🔊 MacOutputManager: added bus \(OutputBus.labelFor(newIndex)), total=\(buses.count)")
        return newIndex
    }
    
    /// Remove the last output bus (won't go below minimum).
    /// Tears down the bus first if it's initialised.
    func removeLastBus() {
        guard buses.count > MacOutputManager.minimumBusCount else { return }
        let lastIndex = buses.count - 1
        teardownBus(lastIndex)
        buses.removeLast()
        saveSettings()
        print("🔊 MacOutputManager: removed last bus, total=\(buses.count)")
    }
    
    // MARK: - Device Enumeration
    
    /// Refresh the list of available audio output devices from BASS
    func enumerateDevices() {
        var devices: [BASSOutputDevice] = []
        let count = Int(fx.audio.getDeviceCount())
        
        for i in 0..<count {
            let name = fx.audio.getDeviceName(Int32(i)) ?? "Unknown Device"
            let enabled = fx.audio.isDeviceEnabled(Int32(i))
            
            // Device 0 in BASS is "No Sound", device 1+ are real devices
            // The default device is typically device 1 or whichever has the BASS_DEVICE_DEFAULT flag
            let isDefault = (i == 1) // Heuristic: device 1 is usually the default on macOS
            
            // Skip "No Sound" device (index 0)
            if i == 0 { continue }
            
            // Query channel count for multi-channel devices
            let channels = Int(fx.audio.getDeviceChannelCount(Int32(i)))
            
            devices.append(BASSOutputDevice(
                id: i,
                name: name,
                isEnabled: enabled,
                isDefault: isDefault,
                channelCount: channels
            ))
        }
        
        availableDevices = devices
        print("🔊 MacOutputManager: enumerated \(devices.count) devices")
        for d in devices {
            print("🔊   Device \(d.id): '\(d.name)' enabled=\(d.isEnabled) default=\(d.isDefault) channels=\(d.channelCount)")
        }
    }
    
    // MARK: - Bus Configuration
    
    /// Assign a physical device to an output bus
    func assignDevice(busIndex: Int, deviceIndex: Int) {
        guard busIndex >= 0 && busIndex < buses.count else { return }
        
        let previousDevice = buses[busIndex].bassDeviceIndex
        
        // Tear down old mixer if device is changing
        if previousDevice != deviceIndex && buses[busIndex].isInitialised {
            teardownBus(busIndex)
        }
        
        buses[busIndex].bassDeviceIndex = deviceIndex
        
        // Update channel count from device info and reset channel pair
        if let device = availableDevices.first(where: { $0.id == deviceIndex }) {
            buses[busIndex].deviceChannelCount = device.channelCount
        } else {
            buses[busIndex].deviceChannelCount = 2
        }
        buses[busIndex].channelPair = 0 // Reset to first pair on device change
        
        // Initialise the new device and create a mixer
        if deviceIndex >= 0 {
            initialiseBus(busIndex)
        }
        
        saveSettings()
    }
    
    /// Assign a channel pair to an output bus (device must already be assigned)
    func assignChannelPair(busIndex: Int, channelPair: Int) {
        guard busIndex >= 0 && busIndex < buses.count else { return }
        guard buses[busIndex].bassDeviceIndex >= 0 else { return }
        guard buses[busIndex].channelPair != channelPair else { return }
        
        // Channel pair is applied per-stream via routing matrix at load time,
        // so we just update the stored value — no need to recreate the mixer.
        buses[busIndex].channelPair = channelPair
        print("🔊 MacOutputManager: bus \(buses[busIndex].label) channel pair changed to \(channelPair)")
        
        saveSettings()
    }
    
    /// Initialise a bus: init the BASS device and create (or reuse) a mixer on it.
    /// Multiple buses on the same device share one multi-channel mixer.
    func initialiseBus(_ busIndex: Int) {
        guard busIndex >= 0 && busIndex < buses.count else { return }
        let deviceIndex = buses[busIndex].bassDeviceIndex
        guard deviceIndex >= 0 else { return }
        
        let channelCount = buses[busIndex].deviceChannelCount
        let channelPair = buses[busIndex].channelPair
        
        print("🔊 MacOutputManager: initialising bus \(buses[busIndex].label) on device \(deviceIndex), channels=\(channelCount), pair=\(channelPair)")
        
        // Check if we already have a mixer for this device
        if let cached = deviceMixerCache[deviceIndex] {
            buses[busIndex].mixerStream = cached.mixer
            buses[busIndex].deviceChannelCount = cached.channels
            buses[busIndex].isInitialised = true
            print("🔊 ✅ MacOutputManager: bus \(buses[busIndex].label) reusing cached mixer=\(cached.mixer) for device \(deviceIndex)")
            return
        }
        
        // Init the device
        let initOK = fx.audio.initOutputDevice(Int32(deviceIndex))
        if !initOK {
            print("🔊 ❌ MacOutputManager: failed to init device \(deviceIndex)")
            return
        }
        
        // Create a mixer — use multi-channel if device supports it
        var mixer: Int32 = 0
        if channelCount > 2 {
            mixer = fx.audio.createMultiChannelMixer(onDevice: Int32(deviceIndex), channels: Int32(channelCount))
        } else {
            mixer = fx.audio.createMixer(onDevice: Int32(deviceIndex))
        }
        
        if mixer == 0 {
            print("🔊 ❌ MacOutputManager: failed to create mixer on device \(deviceIndex)")
            return
        }
        
        // Cache the mixer for this device
        deviceMixerCache[deviceIndex] = (mixer: mixer, channels: channelCount)
        
        buses[busIndex].mixerStream = mixer
        buses[busIndex].isInitialised = true
        
        print("🔊 ✅ MacOutputManager: bus \(buses[busIndex].label) ready, device=\(deviceIndex) mixer=\(mixer) channelPair=\(channelPair)")
    }
    
    /// Tear down a bus. Only frees the device mixer when no other buses are using it.
    func teardownBus(_ busIndex: Int) {
        guard busIndex >= 0 && busIndex < buses.count else { return }
        guard buses[busIndex].isInitialised else { return }
        
        let deviceIndex = buses[busIndex].bassDeviceIndex
        print("🔊 MacOutputManager: tearing down bus \(buses[busIndex].label)")
        
        buses[busIndex].mixerStream = 0
        buses[busIndex].isInitialised = false
        
        // Check if any other bus is still using the same device mixer
        let othersOnSameDevice = buses.enumerated().contains { idx, bus in
            idx != busIndex && bus.bassDeviceIndex == deviceIndex && bus.isInitialised
        }
        
        if !othersOnSameDevice, let cached = deviceMixerCache[deviceIndex] {
            // No other bus needs this mixer — free it
            fx.audio.stop(cached.mixer)
            deviceMixerCache.removeValue(forKey: deviceIndex)
            print("🔊 MacOutputManager: freed mixer for device \(deviceIndex)")
        }
    }
    
    /// Tear down all buses
    func teardownAll() {
        for i in 0..<buses.count {
            teardownBus(i)
        }
        deviceMixerCache.removeAll()
    }
    
    // MARK: - Routing
    
    /// Get the mixer handle for a given output index (matching FxEffect.output).
    /// Returns the bus-specific mixer if multi-output is enabled and the bus is configured,
    /// otherwise returns the default mixer.
    nonisolated func getMixer(for outputIndex: Int) -> Int32 {
        guard multiOutputEnabled else {
            // Single output mode: everything goes to the default mixer
            return fx.audio.getDefaultMixer()
        }
        
        guard outputIndex >= 0 && outputIndex < buses.count else {
            return fx.audio.getDefaultMixer()
        }
        
        let bus = buses[outputIndex]
        if bus.isInitialised && bus.mixerStream != 0 {
            return bus.mixerStream
        }
        
        // Fall back to default mixer if this bus isn't configured
        return fx.audio.getDefaultMixer()
    }
    
    /// Load an audio file onto the correct mixer for the given output index.
    /// Returns the stream handle.
    nonisolated func loadOnOutput(_ filePath: String, outputIndex: Int) -> Int32 {
        let mixer = getMixer(for: outputIndex)
        let defaultMixer = fx.audio.getDefaultMixer()
        
        print("🔊 MacOutputManager.loadOnOutput: outputIndex=\(outputIndex) mixer=\(mixer) defaultMixer=\(defaultMixer) multiOutput=\(multiOutputEnabled)")
        
        if mixer != defaultMixer && mixer != 0 {
            // Check if this bus uses channel-pair routing on a multi-channel device
            if outputIndex >= 0 && outputIndex < buses.count {
                let bus = buses[outputIndex]
                print("🔊   Bus \(bus.label): device=\(bus.bassDeviceIndex) pair=\(bus.channelPair) channels=\(bus.deviceChannelCount) initialised=\(bus.isInitialised)")
                if bus.deviceChannelCount > 2 {
                    // Use channel-pair routing to direct audio to the correct stereo pair
                    return fx.audio.loadFile(withRouting: filePath, mixer: mixer, channelPair: Int32(bus.channelPair), mixerChannels: Int32(bus.deviceChannelCount))
                }
            }
            // Use the bus-specific mixer (standard stereo)
            return fx.audio.load(onMixer: filePath, mixer: mixer)
        } else {
            // Use the standard load (goes to default mixer)
            print("🔊   Using default mixer (no bus-specific routing)")
            return fx.audio.load(filePath)
        }
    }
    
    // MARK: - Test
    
    /// Play a test tone on a specific bus
    func testBus(_ busIndex: Int) {
        guard busIndex >= 0 && busIndex < buses.count else { return }
        let bus = buses[busIndex]
        let mixer = getMixer(for: busIndex)
        print("🔊 testBus(\(busIndex)): mixer=\(mixer) device=\(bus.bassDeviceIndex) pair=\(bus.channelPair) channels=\(bus.deviceChannelCount) initialised=\(bus.isInitialised)")
        if mixer != 0 {
            if bus.deviceChannelCount > 2 {
                fx.audio.playTestToneRouted(mixer, channelPair: Int32(bus.channelPair), mixerChannels: Int32(bus.deviceChannelCount))
            } else {
                fx.audio.playTestTone(mixer)
            }
        }
    }
    
    // MARK: - Level Metering
    
    /// Get levels for a specific bus
    func getLevels(for busIndex: Int) -> (left: Float, right: Float) {
        guard busIndex >= 0 && busIndex < buses.count else { return (-100, -100) }
        let bus = buses[busIndex]
        let mixer = getMixer(for: busIndex)
        if mixer == 0 { return (-100, -100) }
        
        var left: Float = -100
        var right: Float = -100
        
        // For multi-channel devices, read levels for the specific channel pair
        if bus.deviceChannelCount > 2 {
            fx.audio.getLevelForMixer(mixer, channelPair: Int32(bus.channelPair), mixerChannels: Int32(bus.deviceChannelCount), left: &left, right: &right)
        } else {
            fx.audio.getLevelForMixer(mixer, left: &left, right: &right)
        }
        
        return (max(-100, min(0, left)), max(-100, min(0, right)))
    }
    
    // MARK: - Persistence
    
    /// Save bus assignments to UserDefaults
    func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(multiOutputEnabled, forKey: kMultiOutputEnabled)
        defaults.set(buses.count, forKey: kBusCount)
        
        for bus in buses {
            defaults.set(bus.bassDeviceIndex, forKey: "\(kBusDevicePrefix)\(bus.id)")
            defaults.set(bus.channelPair, forKey: "\(kBusChannelPairPrefix)\(bus.id)")
        }
        
        defaults.synchronize()
        print("🔊 MacOutputManager: settings saved")
    }
    
    /// Load bus assignments from UserDefaults and initialise devices
    func loadSettings() {
        let defaults = UserDefaults.standard
        multiOutputEnabled = defaults.bool(forKey: kMultiOutputEnabled)
        
        for i in 0..<buses.count {
            let deviceKey = "\(kBusDevicePrefix)\(i)"
            let pairKey = "\(kBusChannelPairPrefix)\(i)"
            if defaults.object(forKey: deviceKey) != nil {
                buses[i].bassDeviceIndex = defaults.integer(forKey: deviceKey)
                buses[i].channelPair = defaults.integer(forKey: pairKey)
                
                // Restore channel count from the device if available
                if let device = availableDevices.first(where: { $0.id == buses[i].bassDeviceIndex }) {
                    buses[i].deviceChannelCount = device.channelCount
                }
            }
        }
        
        print("🔊 MacOutputManager: settings loaded, multiOutput=\(multiOutputEnabled)")
        for bus in buses {
            print("🔊   Bus \(bus.label): device=\(bus.bassDeviceIndex) channelPair=\(bus.channelPair) channels=\(bus.deviceChannelCount)")
        }
        
        // Initialise any configured buses
        if multiOutputEnabled {
            initialiseAllBuses()
        }
    }
    
    /// Initialise all buses that have a device assigned
    func initialiseAllBuses() {
        for i in 0..<buses.count {
            if buses[i].bassDeviceIndex >= 0 && !buses[i].isInitialised {
                initialiseBus(i)
            }
        }
    }
    
    // MARK: - Enable/Disable Multi-Output
    
    /// Toggle multi-output mode
    func setMultiOutputEnabled(_ enabled: Bool) {
        multiOutputEnabled = enabled
        
        if enabled {
            enumerateDevices()
            initialiseAllBuses()
        } else {
            teardownAll()
        }
        
        saveSettings()
    }
    
    /// Get a human-readable description of what device a bus is assigned to
    func deviceName(for busIndex: Int) -> String {
        guard busIndex >= 0 && busIndex < buses.count else { return "Unknown" }
        let deviceIdx = buses[busIndex].bassDeviceIndex
        
        if deviceIdx < 0 {
            return "Default Output"
        }
        
        if let device = availableDevices.first(where: { $0.id == deviceIdx }) {
            return device.displayName
        }
        
        return "Device \(deviceIdx)"
    }
}
