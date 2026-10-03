//
//  AudioHardware.swift
//  Duophonic
//
//  Created by Juri Beforth on 03.10.26.
//

import Foundation

/// The two system-wide default devices Duophonic takes over while enabled.
enum DefaultDeviceKind: CaseIterable {
    /// Where apps play their audio.
    case output
    /// Where alerts and sound effects play.
    case systemOutput
}

struct AggregateDevice: Equatable {
    let uid: String
    let name: String
    let mainSubDeviceUID: String?
    let subDeviceUIDs: [String]
}

struct AggregateConfiguration: Equatable {
    let uid: String
    let name: String
    /// Clock source of the aggregate; plays without drift compensation.
    let mainUID: String
    /// Resampled (drift compensated) to stay in sync with the main device.
    let secondaryUID: String
    /// Private aggregates are only visible to this process and vanish when it exits.
    var isPrivate = false
}

/// Abstraction over the system's audio hardware so the aggregate logic can be tested
/// without Core Audio. Devices are always identified by their persistent UID.
protocol AudioHardware: AnyObject {
    /// Visible, output-capable devices, excluding aggregates.
    func outputDevices() -> [AudioDevice]
    func aggregateDevices() -> [AggregateDevice]
    func defaultDeviceUID(_ kind: DefaultDeviceKind) -> String?
    func setDefaultDevice(_ kind: DefaultDeviceKind, uid: String) throws
    func createAggregate(_ configuration: AggregateConfiguration) throws
    /// Changes the sub-devices of an existing aggregate without recreating it, so apps that are
    /// playing to it keep running. Safe to call repeatedly; unchanged settings are left alone.
    func updateAggregate(uid: String, mainUID: String, secondaryUID: String) throws
    func destroyAggregate(uid: String) throws
    func setVolume(_ volume: Double, ofDeviceWithUID uid: String) throws
    /// Calls `handler` on the main thread after devices, default devices or volumes changed.
    /// Bursts of changes are coalesced into a single call.
    func startObserving(_ handler: @escaping () -> Void)
    func stopObserving()
}
