//
//  AudioAggregateManagerTests.swift
//  DuophonicTests
//
//  Created by Juri Beforth on 03.10.26.
//

import CoreAudio
import Foundation
import Testing

@testable import Duophonic

@MainActor
@Suite struct AudioAggregateManagerTests {
    private let speakers = AudioDevice(
        uid: "speakers", name: "MacBook Speakers", category: .builtin, volume: 0.5)
    private let airPods = AudioDevice(
        uid: "airpods", name: "AirPods Pro", category: .bluetooth, volume: 0.4)
    private let headphones = AudioDevice(
        uid: "headphones", name: "Beats", category: .bluetooth, volume: nil)

    private let defaults: UserDefaults
    private let hardware: InMemoryAudioHardware

    init() {
        let suiteName = "DuophonicTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        hardware = InMemoryAudioHardware(devices: [speakers, airPods, headphones])
    }

    private func makeManager() -> AudioAggregateManager {
        let manager = AudioAggregateManager(hardware: hardware, defaults: defaults)
        manager.start()
        return manager
    }

    private var aggregateUID: String? { hardware.aggregates.first?.uid }

    // MARK: - Selection

    @Test func initialSelectionUsesCurrentOutputAndPrefersHeadphones() {
        hardware.defaultDevices[.output] = speakers.uid

        let manager = makeManager()

        #expect(manager.primaryUID == speakers.uid)
        #expect(manager.secondaryUID == airPods.uid)
        #expect(manager.canEnable)
    }

    @Test func selectingTheOtherRolesDeviceSwapsSelection() {
        let manager = makeManager()

        manager.select(airPods.uid, for: .primary)

        #expect(manager.primaryUID == airPods.uid)
        #expect(manager.secondaryUID == speakers.uid)
    }

    @Test func selectionIsPersisted() {
        makeManager().select(headphones.uid, for: .secondary)

        let restored = makeManager()

        #expect(restored.primaryUID == speakers.uid)
        #expect(restored.secondaryUID == headphones.uid)
    }

    @Test func disconnectedSelectionIsKeptAndShownByName() {
        let manager = makeManager()
        hardware.devices.removeAll { $0.uid == airPods.uid }

        hardware.simulateChange()

        #expect(manager.secondaryUID == airPods.uid)
        #expect(manager.device(for: .secondary) == nil)
        #expect(manager.selectedName(for: .secondary) == airPods.name)
        #expect(!manager.canEnable)
    }

    @Test func cannotSelectUnknownDevice() {
        let manager = makeManager()

        manager.select("missing", for: .primary)

        #expect(manager.primaryUID == speakers.uid)
    }

    // MARK: - Enable / disable

    @Test func enableCreatesAggregateWithPrimaryAsClockSourceAndMakesItDefault() throws {
        let manager = makeManager()

        manager.enable()

        #expect(manager.isEnabled)
        #expect(manager.errorMessage == nil)
        let configuration = try #require(hardware.createdConfigurations.first)
        #expect(configuration.mainUID == speakers.uid)
        #expect(configuration.secondaryUID == airPods.uid)
        #expect(!configuration.isPrivate)
        #expect(AudioAggregateManager.isOwnAggregate(configuration.uid))
        #expect(hardware.defaultDevices[.output] == configuration.uid)
        #expect(hardware.defaultDevices[.systemOutput] == configuration.uid)
    }

    @Test func disableRestoresEachPreviousDefaultAndRemovesAggregate() {
        hardware.defaultDevices = [.output: headphones.uid, .systemOutput: speakers.uid]
        let manager = makeManager()
        manager.select(airPods.uid, for: .secondary)
        manager.enable()

        manager.disable()

        #expect(!manager.isEnabled)
        #expect(hardware.aggregates.isEmpty)
        #expect(hardware.defaultDevices[.output] == headphones.uid)
        #expect(hardware.defaultDevices[.systemOutput] == speakers.uid)
    }

    @Test func disableFallsBackToPrimaryWhenPreviousOutputIsGone() {
        hardware.defaultDevices = [.output: headphones.uid, .systemOutput: headphones.uid]
        let manager = makeManager()
        manager.select(speakers.uid, for: .primary)
        manager.select(airPods.uid, for: .secondary)
        manager.enable()
        hardware.devices.removeAll { $0.uid == headphones.uid }

        manager.disable()

        #expect(hardware.defaultDevices[.output] == speakers.uid)
    }

    @Test func enableCleansUpWhenAggregateCannotBecomeDefault() {
        hardware.defaultDevices = [.output: speakers.uid, .systemOutput: speakers.uid]
        hardware.failingOperations = [.setDefault(.systemOutput)]
        let manager = makeManager()

        manager.enable()

        #expect(!manager.isEnabled)
        #expect(manager.errorMessage != nil)
        #expect(hardware.aggregates.isEmpty)
        #expect(hardware.defaultDevices[.output] == speakers.uid)
    }

    @Test func enableReportsCreationFailure() {
        hardware.failingOperations = [.create]
        let manager = makeManager()

        manager.enable()

        #expect(!manager.isEnabled)
        #expect(manager.errorMessage != nil)
    }

    @Test func enableRequiresTwoConnectedDevices() {
        hardware.devices = [speakers]
        let manager = makeManager()

        manager.enable()

        #expect(!manager.isEnabled)
        #expect(hardware.createdConfigurations.isEmpty)
    }

    @Test func shutdownTurnsMultiOutputOff() {
        let manager = makeManager()
        manager.enable()

        manager.shutdown()

        #expect(hardware.aggregates.isEmpty)
        #expect(hardware.defaultDevices[.output] == speakers.uid)
    }

    // MARK: - Changing outputs while enabled

    @Test func changingSecondaryWhileEnabledUpdatesAggregateInPlace() {
        let manager = makeManager()
        manager.enable()
        let uid = aggregateUID

        manager.select(headphones.uid, for: .secondary)

        #expect(manager.isEnabled)
        #expect(hardware.createdConfigurations.count == 1)
        #expect(aggregateUID == uid)
        #expect(hardware.aggregates.first?.subDeviceUIDs == [speakers.uid, headphones.uid])
    }

    @Test func swappingWhileEnabledMakesNewPrimaryTheClockSource() {
        let manager = makeManager()
        manager.enable()

        manager.select(airPods.uid, for: .primary)

        #expect(hardware.aggregates.first?.mainSubDeviceUID == airPods.uid)
        #expect(hardware.aggregates.first?.subDeviceUIDs == [airPods.uid, speakers.uid])
    }

    @Test func failedInPlaceUpdateTurnsMultiOutputOff() {
        let manager = makeManager()
        manager.enable()
        hardware.failingOperations = [.update]

        manager.select(headphones.uid, for: .secondary)

        #expect(!manager.isEnabled)
        #expect(manager.errorMessage != nil)
        #expect(hardware.aggregates.isEmpty)
        #expect(hardware.defaultDevices[.output] == speakers.uid)
    }

    // MARK: - External changes

    @Test func choosingAnotherOutputInSystemSettingsTurnsMultiOutputOff() {
        let manager = makeManager()
        manager.enable()
        hardware.defaultDevices[.output] = headphones.uid

        hardware.simulateChange()

        #expect(!manager.isEnabled)
        #expect(hardware.aggregates.isEmpty)
        #expect(hardware.defaultDevices[.output] == headphones.uid)
        #expect(hardware.defaultDevices[.systemOutput] == speakers.uid)
    }

    @Test func aggregateRemovedByTheSystemIsReflected() {
        let manager = makeManager()
        manager.enable()
        hardware.aggregates = []
        hardware.defaultDevices[.output] = speakers.uid

        hardware.simulateChange()

        #expect(!manager.isEnabled)
        #expect(manager.errorMessage != nil)
    }

    @Test func reconnectedDeviceIsReappliedToAggregate() {
        let manager = makeManager()
        manager.enable()
        let updatesBefore = hardware.updateCount
        hardware.devices.removeAll { $0.uid == airPods.uid }
        hardware.simulateChange()

        hardware.devices.append(airPods)
        hardware.simulateChange()

        #expect(manager.isEnabled)
        #expect(hardware.updateCount == updatesBefore + 1)
    }

    @Test func unrelatedChangesLeaveAggregateAlone() {
        let manager = makeManager()
        manager.enable()
        let updatesBefore = hardware.updateCount

        hardware.simulateChange()

        #expect(manager.isEnabled)
        #expect(hardware.updateCount == updatesBefore)
    }

    // MARK: - Crash recovery

    @Test func leftoverAggregateInUseIsAdoptedAfterCrash() {
        let crashed = makeManager()
        crashed.select(airPods.uid, for: .primary)
        crashed.enable()
        let uid = aggregateUID

        let relaunched = makeManager()

        #expect(relaunched.isEnabled)
        #expect(aggregateUID == uid)
        #expect(relaunched.primaryUID == airPods.uid)
        #expect(relaunched.secondaryUID == speakers.uid)

        relaunched.disable()
        #expect(hardware.defaultDevices[.output] == speakers.uid)
    }

    @Test func leftoverAggregatesNotInUseAreRemoved() {
        hardware.aggregates = [
            AggregateDevice(
                uid: "\(AudioAggregateManager.aggregateUIDPrefix).old", name: "x",
                mainSubDeviceUID: speakers.uid, subDeviceUIDs: [speakers.uid, airPods.uid]),
            AggregateDevice(
                uid: "\(UUID().uuidString):aggregate", name: AudioAggregateManager.aggregateName,
                mainSubDeviceUID: speakers.uid, subDeviceUIDs: [speakers.uid, airPods.uid]),
            AggregateDevice(
                uid: "user-made-aggregate", name: "Studio", mainSubDeviceUID: nil,
                subDeviceUIDs: []),
            AggregateDevice(
                uid: "com.example.OtherApp:aggregate", name: "Other", mainSubDeviceUID: nil,
                subDeviceUIDs: []),
        ]

        let manager = makeManager()

        #expect(!manager.isEnabled)
        #expect(
            hardware.aggregates.map(\.uid) == [
                "user-made-aggregate", "com.example.OtherApp:aggregate",
            ])
    }

    @Test func aggregatesOfOtherAppsAreNotAdopted() {
        let other = "com.example.OtherApp:aggregate"
        hardware.aggregates = [
            AggregateDevice(
                uid: other, name: "Other", mainSubDeviceUID: speakers.uid,
                subDeviceUIDs: [speakers.uid, airPods.uid])
        ]
        hardware.defaultDevices = [.output: other, .systemOutput: other]

        let manager = makeManager()

        #expect(!manager.isEnabled)
        #expect(hardware.aggregates.map(\.uid) == [other])
        #expect(hardware.defaultDevices[.output] == other)
    }

    @Test func leftoverDefaultAggregateThatCannotBeAdoptedRestoresOutput() {
        let leftover = "\(AudioAggregateManager.aggregateUIDPrefix).broken"
        hardware.aggregates = [
            AggregateDevice(
                uid: leftover, name: "x", mainSubDeviceUID: nil, subDeviceUIDs: [airPods.uid])
        ]
        hardware.defaultDevices = [.output: leftover, .systemOutput: leftover]
        defaults.set(headphones.uid, forKey: "previousDefaultOutputUID")

        let manager = makeManager()

        #expect(!manager.isEnabled)
        #expect(hardware.aggregates.isEmpty)
        #expect(hardware.defaultDevices[.output] == headphones.uid)
        #expect(hardware.defaultDevices[.systemOutput] != leftover)
    }

    // MARK: - Volume

    @Test func volumeIsClampedAndForwarded() {
        let manager = makeManager()

        manager.setVolume(1.5, for: .primary)

        #expect(manager.device(for: .primary)?.volume == 1)
        #expect(hardware.devices.first { $0.uid == speakers.uid }?.volume == 1)
    }

    @Test func volumeIsIgnoredForDevicesWithoutVolumeControl() {
        let manager = makeManager()
        manager.select(headphones.uid, for: .secondary)

        manager.setVolume(0.8, for: .secondary)

        #expect(manager.device(for: .secondary)?.volume == nil)
    }
}

@Suite struct AudioDeviceCategoryTests {
    @Test(arguments: [
        (kAudioDeviceTransportTypeBuiltIn, AudioDeviceCategory.builtin),
        (kAudioDeviceTransportTypeBluetooth, .bluetooth),
        (kAudioDeviceTransportTypeBluetoothLE, .bluetooth),
        (kAudioDeviceTransportTypeAirPlay, .airplay),
        (kAudioDeviceTransportTypeUSB, .usb),
        (kAudioDeviceTransportTypeHDMI, .display),
        (kAudioDeviceTransportTypeDisplayPort, .display),
        (kAudioDeviceTransportTypeVirtual, .virtual),
        (kAudioDeviceTransportTypeUnknown, .other),
    ])
    func categoryFromTransportType(transportType: UInt32, expected: AudioDeviceCategory) {
        #expect(AudioDeviceCategory(transportType: transportType) == expected)
    }

    @Test func airPodsGetDedicatedIcon() {
        let airPods = AudioDevice(uid: "a", name: "Jane’s AirPods Max", category: .bluetooth)
        let speaker = AudioDevice(uid: "b", name: "JBL Flip", category: .bluetooth)

        #expect(airPods.iconName == "airpods.gen3")
        #expect(speaker.iconName == AudioDeviceCategory.bluetooth.iconName)
    }
}
