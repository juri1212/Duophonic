//
//  InMemoryConversationAwareness.swift
//  Duophonic
//
//  Created by Juri Beforth on 15.10.26.
//

#if DEBUG
    import Combine
    import Foundation

    /// `ConversationAwarenessControl` simulated in memory, for SwiftUI previews and unit tests.
    @MainActor
    final class InMemoryConversationAwareness: ConversationAwarenessControl {
        /// Conversation Awareness of each simulated device, by name. Missing devices aren't found.
        var settings: [String: Bool]
        var isAllowed = true
        var failure: ConversationAwarenessError?
        private(set) var permissionRequests = 0
        private(set) var changes: [(name: String, enabled: Bool)] = []

        init(settings: [String: Bool]) {
            self.settings = settings
        }

        func requestPermission() {
            permissionRequests += 1
        }

        func isEnabled(on deviceName: String) async throws -> Bool {
            try check(deviceName)
        }

        func setEnabled(_ enabled: Bool, on deviceName: String) async throws {
            try check(deviceName)
            settings[deviceName] = enabled
            changes.append((deviceName, enabled))
        }

        @discardableResult
        private func check(_ deviceName: String) throws -> Bool {
            if let failure { throw failure }
            guard let enabled = settings[deviceName] else {
                throw ConversationAwarenessError.deviceNotFound(deviceName)
            }
            return enabled
        }
    }

    extension ConversationAwarenessManager {
        /// Manager with two connected AirPods, one of them paused, for SwiftUI previews.
        static var preview: ConversationAwarenessManager {
            let devices = [
                AudioDevice(uid: "a", name: "AirPods Pro", category: .bluetooth, volume: 0.5),
                AudioDevice(uid: "b", name: "Franka’s AirPods", category: .bluetooth, volume: 0.5),
            ]
            let control = InMemoryConversationAwareness(
                settings: Dictionary(uniqueKeysWithValues: devices.map { ($0.name, true) }))
            let defaults = UserDefaults(suiteName: "DuophonicPreview")!
            defaults.removePersistentDomain(forName: "DuophonicPreview")
            let manager = ConversationAwarenessManager(control: control, defaults: defaults)
            manager.start(following: Just(devices))
            manager.setPaused(true, for: devices[0])
            return manager
        }
    }
#endif
