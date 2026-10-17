//
//  ConversationAwarenessManagerTests.swift
//  DuophonicTests
//
//  Created by Juri Beforth on 15.10.26.
//

import Combine
import Foundation
import Testing

@testable import Duophonic

@MainActor
@Suite struct ConversationAwarenessManagerTests {
    private let airPods = AudioDevice(
        uid: "airpods", name: "AirPods Pro", category: .bluetooth, volume: 0.4)
    private let otherAirPods = AudioDevice(
        uid: "other", name: "Franka’s AirPods", category: .bluetooth, volume: 0.4)
    private let speakers = AudioDevice(
        uid: "speakers", name: "MacBook Speakers", category: .builtin, volume: 0.5)

    private let defaults: UserDefaults
    private let control: InMemoryConversationAwareness
    private let devices: CurrentValueSubject<[AudioDevice], Never>

    init() {
        let suiteName = "DuophonicTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        control = InMemoryConversationAwareness(settings: [
            airPods.name: true, otherAirPods.name: true,
        ])
        devices = CurrentValueSubject([speakers, airPods, otherAirPods])
    }

    private func makeManager() async -> ConversationAwarenessManager {
        let manager = ConversationAwarenessManager(control: control, defaults: defaults)
        manager.start(following: devices)
        await settle(manager)
        return manager
    }

    /// Lets the changes the manager started in the background finish.
    private func settle(_ manager: ConversationAwarenessManager) async {
        for _ in 0..<100 {
            await Task.yield()
        }
        #expect(manager.busyNames.isEmpty)
    }

    private var savedSettings: [String: Bool]? {
        defaults.dictionary(forKey: "conversationAwarenessPreviousSettings") as? [String: Bool]
    }

    @Test func listsOnlyAirPods() async {
        let manager = await makeManager()

        #expect(manager.airPods == [airPods, otherAirPods])
    }

    @Test func pausingTurnsItOffAndResumingTurnsItBackOn() async {
        let manager = await makeManager()

        manager.setPaused(true, for: airPods)
        await settle(manager)

        #expect(manager.isPaused(airPods))
        #expect(control.settings[airPods.name] == false)
        #expect(control.settings[otherAirPods.name] == true)
        #expect(savedSettings == [airPods.name: true])

        manager.setPaused(false, for: airPods)
        await settle(manager)

        #expect(!manager.isPaused(airPods))
        #expect(control.settings[airPods.name] == true)
        #expect(savedSettings == nil)
    }

    @Test func resumingKeepsASettingThatWasAlreadyOff() async {
        control.settings[airPods.name] = false
        let manager = await makeManager()

        manager.setPaused(true, for: airPods)
        await settle(manager)
        manager.setPaused(false, for: airPods)
        await settle(manager)

        #expect(control.settings[airPods.name] == false)
        #expect(control.changes.isEmpty)
    }

    @Test func shutdownRestoresEveryPausedAirPods() async {
        let manager = await makeManager()
        manager.setPaused(true, for: airPods)
        manager.setPaused(true, for: otherAirPods)
        await settle(manager)

        await manager.shutdown()

        #expect(control.settings == [airPods.name: true, otherAirPods.name: true])
        #expect(!manager.hasPausedDevices)
        #expect(savedSettings == nil)
    }

    @Test func pauseLeftOverFromAKilledAppIsUndoneWhenTheAirPodsConnect() async {
        defaults.set([airPods.name: true], forKey: "conversationAwarenessPreviousSettings")
        control.settings[airPods.name] = false
        devices.send([speakers])
        let manager = await makeManager()

        #expect(control.settings[airPods.name] == false)

        devices.send([speakers, airPods])
        await settle(manager)

        #expect(control.settings[airPods.name] == true)
        #expect(!manager.isPaused(airPods))
        #expect(savedSettings == nil)
    }

    @Test func settingThatCouldNotBeRestoredOnQuitIsRestoredOnTheNextLaunch() async {
        let manager = await makeManager()
        manager.setPaused(true, for: airPods)
        await settle(manager)
        control.failure = .deviceNotFound(airPods.name)

        await manager.shutdown()

        #expect(savedSettings == [airPods.name: true])

        control.failure = nil
        _ = await makeManager()

        #expect(control.settings[airPods.name] == true)
        #expect(savedSettings == nil)
    }

    @Test func pausingAgainKeepsTheSettingFromBeforeTheLeftOverPause() async {
        defaults.set([airPods.name: true], forKey: "conversationAwarenessPreviousSettings")
        control.settings[airPods.name] = false
        control.isAllowed = false
        let manager = await makeManager()
        control.isAllowed = true

        manager.setPaused(true, for: airPods)
        await settle(manager)
        manager.setPaused(false, for: airPods)
        await settle(manager)

        #expect(control.settings[airPods.name] == true)
    }

    @Test func failureIsShownAndNothingIsPaused() async {
        control.failure = .unsupported(airPods.name)
        let manager = await makeManager()

        manager.setPaused(true, for: airPods)
        await settle(manager)

        #expect(!manager.isPaused(airPods))
        let expected = ConversationAwarenessError.unsupported(airPods.name).errorDescription
        #expect(manager.errorMessage == expected)
        #expect(savedSettings == nil)
    }

    @Test func withoutPermissionItIsRequestedFirst() async {
        control.isAllowed = false
        let manager = await makeManager()

        manager.setPaused(true, for: airPods)
        await settle(manager)

        #expect(control.permissionRequests == 1)
        #expect(manager.needsPermission)
        #expect(!manager.isPaused(airPods))
        #expect(control.changes.isEmpty)
    }
}
