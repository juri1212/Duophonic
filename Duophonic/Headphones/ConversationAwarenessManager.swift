//
//  ConversationAwarenessManager.swift
//  Duophonic
//
//  Created by Juri Beforth on 15.10.26.
//

import Combine
import Foundation
import os

private let logger = Logger(subsystem: "com.juri1212.Duophonic", category: "ConversationAwareness")

/// Pauses Conversation Awareness of connected AirPods and restores each one's previous setting
/// when the pause is turned off or the app quits.
@MainActor
final class ConversationAwarenessManager: ObservableObject {
    /// Connected AirPods, by audio device name.
    @Published private(set) var airPods: [AudioDevice] = []
    /// AirPods whose Conversation Awareness Duophonic turned off.
    @Published private(set) var pausedNames: Set<String> = []
    /// AirPods being changed right now.
    @Published private(set) var busyNames: Set<String> = []
    /// Last failure, shown in the UI until the next successful action.
    @Published private(set) var errorMessage: String?
    /// Whether Duophonic has the Accessibility access it needs. The switches are hidden until then.
    @Published private(set) var isAllowed: Bool
    /// The AirPods the error or permission request is about.
    @Published private(set) var messageDeviceName: String?

    private let control: ConversationAwarenessControl
    private let defaults: UserDefaults
    /// The setting each paused AirPods had before, by name.
    private var paused: [String: Bool] = [:] {
        didSet { pausedNames = Set(paused.keys) }
    }
    /// Settings from a pause the app couldn't undo, e.g. because the AirPods were disconnected
    /// when it quit or it was killed. Restored as soon as the AirPods are connected.
    private var pendingRestores: [String: Bool] = [:]
    private var deviceSubscription: AnyCancellable?
    /// Changes run one at a time, as each one drives the same Sound menu.
    private var isChanging = false
    private var waitingChanges: [CheckedContinuation<Void, Never>] = []

    private enum Key {
        static let previousSettings = "conversationAwarenessPreviousSettings"
    }

    init(control: ConversationAwarenessControl, defaults: UserDefaults = .standard) {
        self.control = control
        self.defaults = defaults
        isAllowed = control.isAllowed
        pendingRestores =
            defaults.dictionary(forKey: Key.previousSettings) as? [String: Bool] ?? [:]
    }

    /// Follows the connected AirPods and undoes pauses left over from a previous run.
    func start(following devices: some Publisher<[AudioDevice], Never>) {
        deviceSubscription = devices.sink { [weak self] devices in
            self?.devicesDidChange(devices)
        }
    }

    func isPaused(_ device: AudioDevice) -> Bool { pausedNames.contains(device.name) }
    func isBusy(_ device: AudioDevice) -> Bool { busyNames.contains(device.name) }

    func setPaused(_ pause: Bool, for device: AudioDevice) {
        guard !isBusy(device) else { return }
        messageDeviceName = device.name
        refreshPermission()
        guard isAllowed else { return }
        Task {
            if pause {
                await self.pause(device.name)
            } else {
                await self.resume(device.name)
            }
        }
    }

    /// Asks for Accessibility access, which changing Conversation Awareness needs.
    func requestPermission() {
        control.requestPermission()
    }

    /// Picks up Accessibility access granted or revoked in System Settings.
    func refreshPermission() {
        let wasAllowed = isAllowed
        isAllowed = control.isAllowed
        if isAllowed, !wasAllowed {
            restorePendingOfConnected()
        }
    }

    /// Restores every paused AirPods. Call before the app exits.
    func shutdown() async {
        deviceSubscription = nil
        while !busyNames.isEmpty {
            try? await Task.sleep(for: .milliseconds(50))
        }
        for name in paused.keys.sorted() {
            await resume(name)
        }
    }

    var hasPausedDevices: Bool { !paused.isEmpty }

    // MARK: - Changing the setting

    private func pause(_ name: String) async {
        await perform(on: name) {
            // A leftover pause already turned it off; its setting from before still counts.
            let previous: Bool
            if let pending = pendingRestores.removeValue(forKey: name) {
                previous = pending
            } else {
                previous = try await control.isEnabled(on: name)
            }
            paused[name] = previous
            save()
            if previous {
                try await control.setEnabled(false, on: name)
            }
        } onFailure: {
            if let previous = paused.removeValue(forKey: name) {
                pendingRestores[name] = previous
            }
        }
    }

    private func resume(_ name: String) async {
        guard let previous = paused[name] else { return }
        await perform(on: name) {
            if previous {
                try await control.setEnabled(true, on: name)
            }
            paused[name] = nil
        } onFailure: {
            // Keep the pause so the user can retry, and restore on the next launch otherwise.
        }
        save()
    }

    private func restorePending(_ name: String) async {
        guard let previous = pendingRestores[name] else { return }
        await perform(on: name) {
            if previous {
                try await control.setEnabled(true, on: name)
            }
            pendingRestores[name] = nil
        }
        save()
    }

    private func perform(
        on name: String, _ change: () async throws -> Void, onFailure: () -> Void = {}
    ) async {
        guard !busyNames.contains(name) else { return }
        busyNames.insert(name)
        defer { busyNames.remove(name) }
        await beginChange()
        defer { endChange() }
        do {
            try await change()
            errorMessage = nil
        } catch {
            logger.error(
                "Changing Conversation Awareness of \(name, privacy: .public) failed: \(error.localizedDescription, privacy: .public)"
            )
            onFailure()
            save()
            if error as? ConversationAwarenessError == .accessibilityNotAllowed {
                // The permission hint replaces the switches, so no message is needed.
                isAllowed = false
                errorMessage = nil
            } else {
                messageDeviceName = name
                errorMessage = error.localizedDescription
            }
        }
    }

    private func beginChange() async {
        if isChanging {
            await withCheckedContinuation { waitingChanges.append($0) }
        } else {
            isChanging = true
        }
    }

    private func endChange() {
        if waitingChanges.isEmpty {
            isChanging = false
        } else {
            waitingChanges.removeFirst().resume()
        }
    }

    private func save() {
        let settings = pendingRestores.merging(paused) { _, active in active }
        if settings.isEmpty {
            defaults.removeObject(forKey: Key.previousSettings)
        } else {
            defaults.set(settings, forKey: Key.previousSettings)
        }
    }

    private func devicesDidChange(_ devices: [AudioDevice]) {
        airPods = devices.filter(\.isAirPods)
        isAllowed = control.isAllowed
        restorePendingOfConnected()
    }

    private func restorePendingOfConnected() {
        let connected = Set(airPods.map(\.name))
        let restorable = pendingRestores.keys.filter(connected.contains)
        guard !restorable.isEmpty, isAllowed else { return }
        Task {
            for name in restorable.sorted() {
                await restorePending(name)
            }
        }
    }
}
