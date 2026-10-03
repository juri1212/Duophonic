//
//  CoreAudioHardware.swift
//  Duophonic
//
//  Created by Juri Beforth on 03.10.26.
//

import AudioToolbox
import CoreAudio
import Foundation
import os

struct CoreAudioError: LocalizedError {
    let operation: String
    let status: OSStatus

    var errorDescription: String? { "\(operation) failed (\(Self.describe(status)))." }

    /// Core Audio errors are mostly four-character codes such as `'!dev'`.
    private static func describe(_ status: OSStatus) -> String {
        let bytes = withUnsafeBytes(of: UInt32(bitPattern: status).bigEndian, Array.init)
        if bytes.allSatisfy({ (0x20...0x7E).contains($0) }),
            let code = String(bytes: bytes, encoding: .ascii)
        {
            return "'\(code)'"
        }
        return String(status)
    }
}

private let logger = Logger(subsystem: "com.juri1212.Duophonic", category: "CoreAudio")

/// `AudioHardware` backed by the Core Audio HAL.
final class CoreAudioHardware: AudioHardware {
    private typealias Listener = (
        object: AudioObjectID, address: AudioObjectPropertyAddress,
        block: AudioObjectPropertyListenerBlock
    )

    private let system = AudioObjectID(kAudioObjectSystemObject)
    private var systemListeners: [Listener] = []
    private var volumeListeners: [AudioObjectID: Listener] = [:]
    private var changeHandler: (() -> Void)?
    private var isChangePending = false

    // MARK: - Devices

    func outputDevices() -> [AudioDevice] {
        allDeviceIDs()
            .compactMap(outputDevice)
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func aggregateDevices() -> [AggregateDevice] {
        allDeviceIDs().filter(isAggregate).compactMap { id in
            guard let uid = string(kAudioDevicePropertyDeviceUID, of: id) else { return nil }
            return AggregateDevice(
                uid: uid,
                name: string(kAudioObjectPropertyName, of: id) ?? "",
                mainSubDeviceUID: string(kAudioAggregateDevicePropertyMainSubDevice, of: id),
                subDeviceUIDs: subDeviceUIDs(of: id)
            )
        }
    }

    func defaultDeviceUID(_ kind: DefaultDeviceKind) -> String? {
        guard let id = uint32(kind.selector, of: system), id != kAudioObjectUnknown else {
            return nil
        }
        return string(kAudioDevicePropertyDeviceUID, of: id)
    }

    func setDefaultDevice(_ kind: DefaultDeviceKind, uid: String) throws {
        try setUInt32(
            deviceID(forUID: uid), kind.selector, of: system,
            operation: "Setting the default output")
    }

    func setVolume(_ volume: Double, ofDeviceWithUID uid: String) throws {
        var address = Self.address(
            kAudioHardwareServiceDeviceProperty_VirtualMainVolume, kAudioObjectPropertyScopeOutput)
        var value = Float32(min(max(volume, 0), 1))
        try check(
            AudioObjectSetPropertyData(
                deviceID(forUID: uid), &address, 0, nil, UInt32(MemoryLayout<Float32>.size),
                &value),
            "Setting the volume")
    }

    // MARK: - Aggregates

    func createAggregate(_ configuration: AggregateConfiguration) throws {
        // Core Audio silently ignores Swift `Bool`s in this dictionary, so all flags are numbers.
        let description: [String: Any] = [
            kAudioAggregateDeviceNameKey as String: configuration.name,
            kAudioAggregateDeviceUIDKey as String: configuration.uid,
            kAudioAggregateDeviceIsPrivateKey as String: configuration.isPrivate ? 1 : 0,
            // Stacked: every sub-device plays the same channels instead of extending them.
            kAudioAggregateDeviceIsStackedKey as String: 1,
            kAudioAggregateDeviceMainSubDeviceKey as String: configuration.mainUID,
            kAudioAggregateDeviceSubDeviceListKey as String: [
                [
                    kAudioSubDeviceUIDKey as String: configuration.mainUID,
                    kAudioSubDeviceDriftCompensationKey as String: 0,
                ],
                [
                    kAudioSubDeviceUIDKey as String: configuration.secondaryUID,
                    kAudioSubDeviceDriftCompensationKey as String: 1,
                ],
            ],
        ]
        var id = AudioObjectID(kAudioObjectUnknown)
        try check(
            AudioHardwareCreateAggregateDevice(description as CFDictionary, &id),
            "Creating the multi-output device")
        guard id != kAudioObjectUnknown else {
            throw CoreAudioError(
                operation: "Creating the multi-output device", status: kAudioHardwareBadDeviceError)
        }
        logger.info("Created aggregate \(configuration.uid, privacy: .public)")
    }

    func updateAggregate(uid: String, mainUID: String, secondaryUID: String) throws {
        let id = try deviceID(forUID: uid)
        let subDevices = [mainUID, secondaryUID]
        if subDeviceUIDs(of: id) != subDevices {
            // Must be an array of UID strings. An array of sub-device dictionaries is
            // accepted with noErr but leaves the aggregate without any sub-device.
            try setCFProperty(
                subDevices as CFArray, kAudioAggregateDevicePropertyFullSubDeviceList, of: id,
                operation: "Changing the outputs")
        }
        // Replacing the sub-devices may also reassign the main device, so check afterwards.
        if string(kAudioAggregateDevicePropertyMainSubDevice, of: id) != mainUID {
            try setCFProperty(
                mainUID as CFString, kAudioAggregateDevicePropertyMainSubDevice, of: id,
                operation: "Changing the primary output")
        }
        // Newly added sub-devices start without drift compensation.
        for subDevice in subDeviceObjects(of: id) {
            guard let subDeviceUID = string(kAudioDevicePropertyDeviceUID, of: subDevice) else {
                continue
            }
            let driftCompensation: UInt32 = subDeviceUID == mainUID ? 0 : 1
            if uint32(kAudioSubDevicePropertyDriftCompensation, of: subDevice)
                != driftCompensation
            {
                try setUInt32(
                    driftCompensation, kAudioSubDevicePropertyDriftCompensation, of: subDevice,
                    operation: "Enabling drift compensation")
            }
        }
        logger.info("Updated aggregate \(uid, privacy: .public)")
    }

    func destroyAggregate(uid: String) throws {
        try check(
            AudioHardwareDestroyAggregateDevice(deviceID(forUID: uid)),
            "Removing the multi-output device")
        logger.info("Destroyed aggregate \(uid, privacy: .public)")
    }

    // MARK: - Change notifications

    func startObserving(_ handler: @escaping () -> Void) {
        stopObserving()
        changeHandler = handler
        for selector in [
            kAudioHardwarePropertyDevices,
            kAudioHardwarePropertyDefaultOutputDevice,
            kAudioHardwarePropertyDefaultSystemOutputDevice,
        ] {
            if let listener = addListener(to: system, Self.address(selector)) {
                systemListeners.append(listener)
            }
        }
        updateVolumeListeners()
    }

    func stopObserving() {
        for listener in systemListeners + volumeListeners.values {
            removeListener(listener)
        }
        systemListeners = []
        volumeListeners = [:]
        changeHandler = nil
    }

    private func updateVolumeListeners() {
        let volumeAddress = Self.address(
            kAudioHardwareServiceDeviceProperty_VirtualMainVolume, kAudioObjectPropertyScopeOutput)
        let deviceIDs = Set(
            allDeviceIDs().filter { id in
                var address = volumeAddress
                return AudioObjectHasProperty(id, &address)
            })
        for (id, listener) in volumeListeners where !deviceIDs.contains(id) {
            removeListener(listener)
            volumeListeners[id] = nil
        }
        for id in deviceIDs where volumeListeners[id] == nil {
            volumeListeners[id] = addListener(to: id, volumeAddress)
        }
    }

    private func addListener(
        to object: AudioObjectID, _ address: AudioObjectPropertyAddress
    ) -> Listener? {
        var address = address
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            MainActor.assumeIsolated { self?.scheduleChangeNotification() }
        }
        let status = AudioObjectAddPropertyListenerBlock(object, &address, .main, block)
        guard status == noErr else {
            logger.error("Adding listener to \(object) failed: \(status)")
            return nil
        }
        return (object, address, block)
    }

    private func removeListener(_ listener: Listener) {
        var address = listener.address
        // Fails harmlessly if the device has already disappeared.
        AudioObjectRemovePropertyListenerBlock(listener.object, &address, .main, listener.block)
    }

    private func scheduleChangeNotification() {
        guard !isChangePending else { return }
        isChangePending = true
        DispatchQueue.main.async { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.isChangePending = false
                self.updateVolumeListeners()
                self.changeHandler?()
            }
        }
    }

    // MARK: - Device helpers

    private func allDeviceIDs() -> [AudioObjectID] {
        objectIDs(kAudioHardwarePropertyDevices, of: system)
    }

    private func outputDevice(_ id: AudioObjectID) -> AudioDevice? {
        let transportType = uint32(kAudioDevicePropertyTransportType, of: id) ?? 0
        guard !isAggregate(id), transportType != kAudioDeviceTransportTypeAggregate,
            uint32(kAudioDevicePropertyIsHidden, of: id) != 1,
            hasOutputStreams(id),
            let uid = string(kAudioDevicePropertyDeviceUID, of: id),
            let name = string(kAudioObjectPropertyName, of: id)
        else { return nil }
        return AudioDevice(
            uid: uid,
            name: name,
            category: AudioDeviceCategory(transportType: transportType),
            volume: volume(of: id)
        )
    }

    private func isAggregate(_ id: AudioObjectID) -> Bool {
        uint32(kAudioObjectPropertyClass, of: id) == kAudioAggregateDeviceClassID
    }

    private func hasOutputStreams(_ id: AudioObjectID) -> Bool {
        var address = Self.address(kAudioDevicePropertyStreams, kAudioObjectPropertyScopeOutput)
        var size: UInt32 = 0
        return AudioObjectGetPropertyDataSize(id, &address, 0, nil, &size) == noErr && size > 0
    }

    private func volume(of id: AudioObjectID) -> Double? {
        var address = Self.address(
            kAudioHardwareServiceDeviceProperty_VirtualMainVolume, kAudioObjectPropertyScopeOutput)
        var isSettable: DarwinBoolean = false
        guard AudioObjectHasProperty(id, &address),
            AudioObjectIsPropertySettable(id, &address, &isSettable) == noErr,
            isSettable.boolValue
        else { return nil }
        var value: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value) == noErr else {
            return nil
        }
        return Double(value)
    }

    private func subDeviceUIDs(of aggregateID: AudioObjectID) -> [String] {
        var address = Self.address(kAudioAggregateDevicePropertyFullSubDeviceList)
        var value: Unmanaged<CFArray>?
        var size = UInt32(MemoryLayout<CFArray?>.size)
        guard AudioObjectGetPropertyData(aggregateID, &address, 0, nil, &size, &value) == noErr
        else { return [] }
        return value?.takeRetainedValue() as? [String] ?? []
    }

    private func subDeviceObjects(of aggregateID: AudioObjectID) -> [AudioObjectID] {
        var classID = kAudioSubDeviceClassID
        return objectIDs(
            kAudioObjectPropertyOwnedObjects, of: aggregateID,
            qualifier: &classID, qualifierSize: UInt32(MemoryLayout<AudioClassID>.size))
    }

    private func deviceID(forUID uid: String) throws -> AudioObjectID {
        var address = Self.address(kAudioHardwarePropertyTranslateUIDToDevice)
        var qualifier = uid as CFString
        var id = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = withUnsafeMutablePointer(to: &qualifier) { qualifier in
            AudioObjectGetPropertyData(
                system, &address, UInt32(MemoryLayout<CFString>.size), qualifier, &size, &id)
        }
        guard status == noErr, id != kAudioObjectUnknown else {
            throw CoreAudioError(
                operation: "Finding the device",
                status: status == noErr ? kAudioHardwareBadDeviceError : status)
        }
        return id
    }

    // MARK: - Property access

    private static func address(
        _ selector: AudioObjectPropertySelector,
        _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    private func check(_ status: OSStatus, _ operation: String) throws {
        guard status == noErr else {
            logger.error("\(operation, privacy: .public) failed: \(status)")
            throw CoreAudioError(operation: operation, status: status)
        }
    }

    private func uint32(
        _ selector: AudioObjectPropertySelector, of id: AudioObjectID
    ) -> UInt32? {
        var address = Self.address(selector)
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value) == noErr else {
            return nil
        }
        return value
    }

    private func setUInt32(
        _ value: UInt32, _ selector: AudioObjectPropertySelector, of id: AudioObjectID,
        operation: String
    ) throws {
        var address = Self.address(selector)
        var value = value
        try check(
            AudioObjectSetPropertyData(
                id, &address, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value),
            operation)
    }

    private func string(
        _ selector: AudioObjectPropertySelector, of id: AudioObjectID
    ) -> String? {
        var address = Self.address(selector)
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<CFString?>.size)
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value) == noErr else {
            return nil
        }
        // Core Audio hands out CF objects at +1.
        return value?.takeRetainedValue() as String?
    }

    private func setCFProperty(
        _ value: CFTypeRef, _ selector: AudioObjectPropertySelector, of id: AudioObjectID,
        operation: String
    ) throws {
        var address = Self.address(selector)
        var value: CFTypeRef? = value
        let status = withUnsafeMutablePointer(to: &value) { value in
            AudioObjectSetPropertyData(
                id, &address, 0, nil, UInt32(MemoryLayout<CFTypeRef?>.size), value)
        }
        try check(status, operation)
    }

    private func objectIDs(
        _ selector: AudioObjectPropertySelector, of id: AudioObjectID,
        qualifier: UnsafeMutableRawPointer? = nil, qualifierSize: UInt32 = 0
    ) -> [AudioObjectID] {
        var address = Self.address(selector)
        var size: UInt32 = 0
        guard
            AudioObjectGetPropertyDataSize(id, &address, qualifierSize, qualifier, &size)
                == noErr
        else { return [] }
        var ids = [AudioObjectID](
            repeating: kAudioObjectUnknown, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard
            AudioObjectGetPropertyData(id, &address, qualifierSize, qualifier, &size, &ids)
                == noErr
        else { return [] }
        return Array(ids.prefix(Int(size) / MemoryLayout<AudioObjectID>.size))
    }
}

extension DefaultDeviceKind {
    fileprivate var selector: AudioObjectPropertySelector {
        switch self {
        case .output: return kAudioHardwarePropertyDefaultOutputDevice
        case .systemOutput: return kAudioHardwarePropertyDefaultSystemOutputDevice
        }
    }
}
