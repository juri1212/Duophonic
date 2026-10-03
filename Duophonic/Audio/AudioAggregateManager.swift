//
//  AudioAggregateManager.swift
//  Duophonic
//
//  Created by Juri Beforth on 01.12.25.
//

import Combine
import Foundation
import os

private let logger = Logger(subsystem: "com.juri1212.Duophonic", category: "Aggregate")

/// Owns the multi-output aggregate device: creates it from the selected primary and secondary
/// outputs, keeps it in sync with hardware changes and restores the previous outputs afterwards.
@MainActor
final class AudioAggregateManager: ObservableObject {
    enum Role: CaseIterable {
        case primary
        case secondary

        var other: Role { self == .primary ? .secondary : .primary }
    }

    static let aggregateName = "Multi-Output (Duophonic)"
    static let aggregateUIDPrefix = "com.juri1212.Duophonic.aggregate"

    @Published private(set) var devices: [AudioDevice] = []
    @Published private(set) var primaryUID: String?
    @Published private(set) var secondaryUID: String?
    @Published private(set) var isEnabled = false
    /// Last failure, shown in the UI until the next successful action.
    @Published private(set) var errorMessage: String?

    private let hardware: AudioHardware
    private let defaults: UserDefaults
    private var activeAggregateUID: String? {
        didSet { isEnabled = activeAggregateUID != nil }
    }
    /// Names of the selected devices, so disconnected selections can still be shown.
    private var knownNames: [String: String]

    private enum Key {
        static let primaryUID = "primaryDeviceUID"
        static let secondaryUID = "secondaryDeviceUID"
        static let knownNames = "selectedDeviceNames"

        static func previousDefault(_ kind: DefaultDeviceKind) -> String {
            switch kind {
            case .output: return "previousDefaultOutputUID"
            case .systemOutput: return "previousDefaultSystemOutputUID"
            }
        }
    }

    init(hardware: AudioHardware, defaults: UserDefaults = .standard) {
        self.hardware = hardware
        self.defaults = defaults
        primaryUID = defaults.string(forKey: Key.primaryUID)
        secondaryUID = defaults.string(forKey: Key.secondaryUID)
        knownNames = defaults.dictionary(forKey: Key.knownNames) as? [String: String] ?? [:]
    }

    /// Recovers from a previous crash and begins following hardware changes.
    func start() {
        recoverLeftoverAggregates()
        refreshDevices()
        hardware.startObserving { [weak self] in self?.hardwareDidChange() }
    }

    /// Turns multi-output off and restores the previous outputs. Call before the app exits.
    func shutdown() {
        disable()
        hardware.stopObserving()
    }

    // MARK: - Selection

    var canEnable: Bool {
        guard let primary = device(for: .primary), let secondary = device(for: .secondary) else {
            return false
        }
        return primary.uid != secondary.uid
    }

    func uid(for role: Role) -> String? {
        role == .primary ? primaryUID : secondaryUID
    }

    /// The selected device for `role`, or `nil` if none is selected or it is not connected.
    func device(for role: Role) -> AudioDevice? {
        guard let uid = uid(for: role) else { return nil }
        return devices.first { $0.uid == uid }
    }

    /// The name of the selected device for `role`, even while it is disconnected.
    func selectedName(for role: Role) -> String? {
        guard let uid = uid(for: role) else { return nil }
        return device(for: role)?.name ?? knownNames[uid]
    }

    func refreshDevices() {
        devices = hardware.outputDevices()
        selectMissingDevices()
    }

    /// Selects `uid` for `role`. Picking the device of the other role swaps both.
    /// While enabled, the aggregate is updated in place so playback continues.
    func select(_ uid: String, for role: Role) {
        guard devices.contains(where: { $0.uid == uid }), self.uid(for: role) != uid else {
            return
        }
        if self.uid(for: role.other) == uid {
            setUID(self.uid(for: role), for: role.other)
        }
        setUID(uid, for: role)
        persistSelection()
        applySelectionToAggregate()
    }

    func setVolume(_ volume: Double, for role: Role) {
        guard let uid = uid(for: role),
            let index = devices.firstIndex(where: { $0.uid == uid }),
            devices[index].supportsVolume
        else { return }
        let volume = min(max(volume, 0), 1)
        devices[index].volume = volume
        do {
            try hardware.setVolume(volume, ofDeviceWithUID: uid)
        } catch {
            logger.error("Setting volume failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Enabling

    func setEnabled(_ enabled: Bool) {
        if enabled {
            enable()
        } else {
            disable()
        }
    }

    func enable() {
        guard activeAggregateUID == nil else { return }
        guard canEnable, let primaryUID, let secondaryUID else {
            errorMessage = "Choose two different connected outputs."
            return
        }
        rememberDefaultsToRestore()
        let configuration = AggregateConfiguration(
            uid: "\(Self.aggregateUIDPrefix).\(UUID().uuidString)",
            name: Self.aggregateName,
            mainUID: primaryUID,
            secondaryUID: secondaryUID
        )
        do {
            try hardware.createAggregate(configuration)
        } catch {
            errorMessage = "Couldn’t turn on multi-output. \(error.localizedDescription)"
            return
        }
        do {
            for kind in DefaultDeviceKind.allCases {
                try hardware.setDefaultDevice(kind, uid: configuration.uid)
            }
        } catch {
            // Don't leave a half-configured aggregate behind.
            restoreDefaults(replacing: configuration.uid)
            forgetDefaultsToRestore()
            try? hardware.destroyAggregate(uid: configuration.uid)
            errorMessage = "Couldn’t switch to multi-output. \(error.localizedDescription)"
            return
        }
        activeAggregateUID = configuration.uid
        errorMessage = nil
        logger.info("Enabled multi-output")
    }

    func disable() {
        guard let aggregateUID = activeAggregateUID else { return }
        activeAggregateUID = nil
        restoreDefaults(replacing: aggregateUID)
        forgetDefaultsToRestore()
        do {
            try hardware.destroyAggregate(uid: aggregateUID)
            errorMessage = nil
        } catch {
            errorMessage = "Couldn’t remove the multi-output device. \(error.localizedDescription)"
        }
        logger.info("Disabled multi-output")
    }

    // MARK: - Hardware changes

    private func hardwareDidChange() {
        let previouslyConnected = Set(devices.map(\.uid))
        refreshDevices()
        guard let aggregateUID = activeAggregateUID else { return }

        guard hardware.aggregateDevices().contains(where: { $0.uid == aggregateUID }) else {
            // macOS already switched to another output; just reflect it.
            activeAggregateUID = nil
            forgetDefaultsToRestore()
            errorMessage = "Multi-output was turned off because macOS removed the device."
            return
        }
        guard hardware.defaultDeviceUID(.output) == aggregateUID else {
            // The user chose another output (e.g. in Control Center). Respect that choice.
            logger.info("Default output changed elsewhere; turning multi-output off")
            disable()
            return
        }
        let reconnected = [primaryUID, secondaryUID].compactMap { $0 }
            .filter { !previouslyConnected.contains($0) && devices.contains(uid: $0) }
        if !reconnected.isEmpty {
            // Re-apply settings such as drift compensation to devices that rejoined.
            applySelectionToAggregate()
        }
    }

    /// Adopts an aggregate left behind by a crash if it is still in use, removes all others.
    private func recoverLeftoverAggregates() {
        let currentOutput = hardware.defaultDeviceUID(.output)
        for aggregate in hardware.aggregateDevices() where Self.isOwnAggregate(aggregate.uid) {
            let subDevices = aggregate.subDeviceUIDs
            if activeAggregateUID == nil, aggregate.uid == currentOutput, subDevices.count == 2,
                subDevices[0] != subDevices[1]
            {
                let main =
                    aggregate.mainSubDeviceUID.flatMap { subDevices.contains($0) ? $0 : nil }
                    ?? subDevices[0]
                primaryUID = main
                secondaryUID = subDevices.first { $0 != main }
                persistSelection()
                activeAggregateUID = aggregate.uid
                // Earlier versions never enabled drift compensation; fix that up as well.
                applySelectionToAggregate()
                logger.info("Adopted aggregate \(aggregate.uid, privacy: .public)")
            } else {
                restoreDefaults(replacing: aggregate.uid)
                try? hardware.destroyAggregate(uid: aggregate.uid)
                logger.info("Removed leftover aggregate \(aggregate.uid, privacy: .public)")
            }
        }
        if activeAggregateUID == nil {
            forgetDefaultsToRestore()
        }
    }

    // MARK: - Helpers

    /// Aggregates created by Duophonic, including the `<UUID>:aggregate` UIDs of version 1.0.
    static func isOwnAggregate(_ uid: String) -> Bool {
        uid.hasPrefix(aggregateUIDPrefix) || uid.hasSuffix(":aggregate")
    }

    private func applySelectionToAggregate() {
        guard let aggregateUID = activeAggregateUID else { return }
        guard let primaryUID, let secondaryUID, primaryUID != secondaryUID else {
            disable()
            return
        }
        do {
            try hardware.updateAggregate(
                uid: aggregateUID, mainUID: primaryUID, secondaryUID: secondaryUID)
            errorMessage = nil
        } catch {
            disable()
            errorMessage =
                "Couldn’t change outputs, so multi-output was turned off. \(error.localizedDescription)"
        }
    }

    private func setUID(_ uid: String?, for role: Role) {
        switch role {
        case .primary: primaryUID = uid
        case .secondary: secondaryUID = uid
        }
    }

    /// Fills empty selections: the current output becomes primary, and the secondary prefers
    /// headphones. Disconnected selections are kept so they come back when reconnected.
    private func selectMissingDevices() {
        var changed = false
        if primaryUID == nil {
            let current = hardware.defaultDeviceUID(.output)
            primaryUID = (devices.first { $0.uid == current } ?? devices.first)?.uid
            changed = primaryUID != nil
        }
        if secondaryUID == nil {
            let candidates = devices.filter { $0.uid != primaryUID }
            secondaryUID = (candidates.first { $0.category == .bluetooth } ?? candidates.first)?.uid
            changed = changed || secondaryUID != nil
        }
        if changed {
            persistSelection()
        }
    }

    private func persistSelection() {
        defaults.set(primaryUID, forKey: Key.primaryUID)
        defaults.set(secondaryUID, forKey: Key.secondaryUID)
        let selected = [primaryUID, secondaryUID].compactMap { $0 }
        knownNames = knownNames.filter { selected.contains($0.key) }
        for device in devices where selected.contains(device.uid) {
            knownNames[device.uid] = device.name
        }
        defaults.set(knownNames, forKey: Key.knownNames)
    }

    /// Persisted so the outputs can be restored even after a crash.
    private func rememberDefaultsToRestore() {
        for kind in DefaultDeviceKind.allCases {
            if let current = hardware.defaultDeviceUID(kind), !Self.isOwnAggregate(current) {
                defaults.set(current, forKey: Key.previousDefault(kind))
            }
        }
    }

    private func forgetDefaultsToRestore() {
        for kind in DefaultDeviceKind.allCases {
            defaults.removeObject(forKey: Key.previousDefault(kind))
        }
    }

    /// Points every default device that still uses `aggregateUID` back to a real device:
    /// the one used before, otherwise one of the selected outputs.
    private func restoreDefaults(replacing aggregateUID: String) {
        let available = hardware.outputDevices()
        for kind in DefaultDeviceKind.allCases
        where hardware.defaultDeviceUID(kind) == aggregateUID {
            let candidates = [
                defaults.string(forKey: Key.previousDefault(kind)), primaryUID, secondaryUID,
                available.first { $0.category == .builtin }?.uid, available.first?.uid,
            ]
            guard let target = candidates.compactMap({ $0 }).first(where: available.contains(uid:))
            else { continue }
            do {
                try hardware.setDefaultDevice(kind, uid: target)
            } catch {
                logger.error(
                    "Restoring output failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}

extension Array where Element == AudioDevice {
    fileprivate func contains(uid: String) -> Bool {
        contains { $0.uid == uid }
    }
}
