//
//  InMemoryAudioHardware.swift
//  Duophonic
//
//  Created by Juri Beforth on 03.10.26.
//

#if DEBUG
    import Foundation

    /// `AudioHardware` simulated in memory, for SwiftUI previews and unit tests.
    final class InMemoryAudioHardware: AudioHardware {
        enum Operation: Hashable {
            case create
            case update
            case destroy
            case setDefault(DefaultDeviceKind)
            case setVolume
        }

        struct SimulatedError: Error {}

        var devices: [AudioDevice]
        var aggregates: [AggregateDevice] = []
        var defaultDevices: [DefaultDeviceKind: String] = [:]
        /// Operations that throw instead of succeeding.
        var failingOperations: Set<Operation> = []
        private(set) var createdConfigurations: [AggregateConfiguration] = []
        private(set) var updateCount = 0
        private var changeHandler: (() -> Void)?

        init(devices: [AudioDevice], defaultUID: String? = nil) {
            self.devices = devices
            for kind in DefaultDeviceKind.allCases {
                defaultDevices[kind] = defaultUID ?? devices.first?.uid
            }
        }

        /// Delivers a change notification like Core Audio would after a hardware change.
        func simulateChange() {
            changeHandler?()
        }

        func outputDevices() -> [AudioDevice] { devices }

        func aggregateDevices() -> [AggregateDevice] { aggregates }

        func defaultDeviceUID(_ kind: DefaultDeviceKind) -> String? { defaultDevices[kind] }

        func setDefaultDevice(_ kind: DefaultDeviceKind, uid: String) throws {
            try failIfNeeded(.setDefault(kind))
            guard exists(uid) else { throw SimulatedError() }
            defaultDevices[kind] = uid
        }

        func createAggregate(_ configuration: AggregateConfiguration) throws {
            try failIfNeeded(.create)
            createdConfigurations.append(configuration)
            aggregates.append(
                AggregateDevice(
                    uid: configuration.uid,
                    name: configuration.name,
                    mainSubDeviceUID: configuration.mainUID,
                    subDeviceUIDs: [configuration.mainUID, configuration.secondaryUID]
                ))
        }

        func updateAggregate(uid: String, mainUID: String, secondaryUID: String) throws {
            try failIfNeeded(.update)
            guard let index = aggregates.firstIndex(where: { $0.uid == uid }) else {
                throw SimulatedError()
            }
            updateCount += 1
            aggregates[index] = AggregateDevice(
                uid: uid,
                name: aggregates[index].name,
                mainSubDeviceUID: mainUID,
                subDeviceUIDs: [mainUID, secondaryUID]
            )
        }

        func destroyAggregate(uid: String) throws {
            try failIfNeeded(.destroy)
            guard aggregates.contains(where: { $0.uid == uid }) else { throw SimulatedError() }
            aggregates.removeAll { $0.uid == uid }
        }

        func setVolume(_ volume: Double, ofDeviceWithUID uid: String) throws {
            try failIfNeeded(.setVolume)
            guard let index = devices.firstIndex(where: { $0.uid == uid }) else {
                throw SimulatedError()
            }
            devices[index].volume = volume
        }

        func startObserving(_ handler: @escaping () -> Void) {
            changeHandler = handler
        }

        func stopObserving() {
            changeHandler = nil
        }

        private func exists(_ uid: String) -> Bool {
            devices.contains { $0.uid == uid } || aggregates.contains { $0.uid == uid }
        }

        private func failIfNeeded(_ operation: Operation) throws {
            if failingOperations.contains(operation) {
                throw SimulatedError()
            }
        }
    }

    extension AudioAggregateManager {
        /// Manager with sample devices for SwiftUI previews.
        static var preview: AudioAggregateManager {
            let hardware = InMemoryAudioHardware(devices: [
                AudioDevice(
                    uid: "builtin", name: "MacBook Pro Speakers", category: .builtin, volume: 0.7),
                AudioDevice(
                    uid: "airpods", name: "AirPods Pro", category: .bluetooth, volume: 0.45),
                AudioDevice(
                    uid: "headphones", name: "Beats Studio", category: .bluetooth, volume: 0.6),
                AudioDevice(
                    uid: "atv", name: "Living Room Apple TV", category: .airplay, volume: nil),
            ])
            let manager = AudioAggregateManager(
                hardware: hardware, defaults: UserDefaults(suiteName: "DuophonicPreview")!)
            manager.refreshDevices()
            return manager
        }
    }
#endif
