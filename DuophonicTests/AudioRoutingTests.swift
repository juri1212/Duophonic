//
//  AudioRoutingTests.swift
//  DuophonicTests
//
//  Created by Juri Beforth on 03.10.26.
//

import AVFoundation
import CoreAudio
import Foundation
import Testing
import os

@testable import Duophonic

/// End-to-end routing checks against real Core Audio: a test tone is played into an aggregate
/// and recorded at each of its outputs. The outputs are BlackHole virtual devices, which loop
/// everything played to them back to their input, so no speakers or headphones are needed.
///
/// Requires `brew install blackhole-2ch blackhole-16ch`, skipped otherwise. The aggregates are
/// private, so the system's default output is never touched.
private let blackHole2chUID = "BlackHole2ch_UID"
private let blackHole16chUID = "BlackHole16ch_UID"

@MainActor
@Suite(
    .serialized,
    .enabled(
        if: deviceID(forUID: blackHole2chUID) != nil && deviceID(forUID: blackHole16chUID) != nil,
        "Needs BlackHole: brew install blackhole-2ch blackhole-16ch"))
struct AudioRoutingTests {
    /// Unusual frequency, so audio other apps happen to play to BlackHole can't pass as the tone.
    private let frequency = 997.0
    private let hardware = CoreAudioHardware()

    init() async throws {
        // Without microphone access macOS still runs the input IOProc, but delivers silence.
        let granted =
            switch AVCaptureDevice.authorizationStatus(for: .audio) {
            case .authorized: true
            case .notDetermined: await AVCaptureDevice.requestAccess(for: .audio)
            default: false
            }
        try #require(
            granted,
            "Recording BlackHole needs microphone access for the app running the tests (Duophonic when run from Xcode, otherwise your terminal). Grant it in System Settings → Privacy & Security → Microphone."
        )
    }

    @Test func outputsAreSilentWithoutTone() async throws {
        let first = try LoopbackRecorder(uid: blackHole2chUID)
        defer { first.stop() }
        let second = try LoopbackRecorder(uid: blackHole16chUID)
        defer { second.stop() }

        try await Task.sleep(for: .seconds(0.5))

        #expect(first.amplitude(at: frequency) < 0.01)
        #expect(second.amplitude(at: frequency) < 0.01)
    }

    @Test func toneReachesBothOutputs() async throws {
        let aggregateUID = try createAggregate(
            mainUID: blackHole2chUID, secondaryUID: blackHole16chUID)
        defer { try? hardware.destroyAggregate(uid: aggregateUID) }
        let tone = try TonePlayer(uid: aggregateUID, frequency: frequency)
        defer { tone.stop() }

        try await expectToneAtBothOutputs()
    }

    @Test func toneKeepsReachingBothOutputsAfterSwappingInPlace() async throws {
        let aggregateUID = try createAggregate(
            mainUID: blackHole2chUID, secondaryUID: blackHole16chUID)
        defer { try? hardware.destroyAggregate(uid: aggregateUID) }
        let tone = try TonePlayer(uid: aggregateUID, frequency: frequency)
        defer { tone.stop() }
        try await expectToneAtBothOutputs()

        try hardware.updateAggregate(
            uid: aggregateUID, mainUID: blackHole16chUID, secondaryUID: blackHole2chUID)

        // The player was started before the update and must not have been interrupted.
        try await expectToneAtBothOutputs()
        let aggregate = hardware.aggregateDevices().first { $0.uid == aggregateUID }
        #expect(aggregate?.mainSubDeviceUID == blackHole16chUID)
    }

    // MARK: - Helpers

    private func createAggregate(mainUID: String, secondaryUID: String) throws -> String {
        let uid = "com.juri1212.Duophonic.tests.\(UUID().uuidString)"
        try hardware.createAggregate(
            AggregateConfiguration(
                uid: uid, name: "Duophonic Routing Test", mainUID: mainUID,
                secondaryUID: secondaryUID, isPrivate: true))
        return uid
    }

    /// BlackHole applies its volume control to what it loops back, so the tone only arrives at
    /// the amplitude it was played with at full volume. Returns a closure restoring the volumes.
    private func turnUpOutputs() throws -> () -> Void {
        let outputs = hardware.outputDevices().filter {
            [blackHole2chUID, blackHole16chUID].contains($0.uid) && $0.supportsVolume
        }
        for output in outputs {
            try hardware.setVolume(1, ofDeviceWithUID: output.uid)
        }
        return { [hardware] in
            for output in outputs {
                try? hardware.setVolume(output.volume ?? 1, ofDeviceWithUID: output.uid)
            }
        }
    }

    private func expectToneAtBothOutputs(
        sourceLocation: SourceLocation = #_sourceLocation
    ) async throws {
        let restoreVolumes = try turnUpOutputs()
        defer { restoreVolumes() }
        let first = try LoopbackRecorder(uid: blackHole2chUID)
        defer { first.stop() }
        let second = try LoopbackRecorder(uid: blackHole16chUID)
        defer { second.stop() }

        // Let the aggregate's clocks settle before judging what arrived.
        try await Task.sleep(for: .seconds(0.5))
        first.reset()
        second.reset()
        try await Task.sleep(for: .seconds(0.5))

        let expected = TonePlayer.amplitude * 0.5
        #expect(
            first.amplitude(at: frequency) > expected, "Tone missing at BlackHole 2ch",
            sourceLocation: sourceLocation)
        #expect(
            second.amplitude(at: frequency) > expected, "Tone missing at BlackHole 16ch",
            sourceLocation: sourceLocation)
    }
}

// MARK: - Core Audio helpers

private func deviceID(forUID uid: String) -> AudioObjectID? {
    var address = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyTranslateUIDToDevice,
        mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    var qualifier = uid as CFString
    var id = AudioObjectID(kAudioObjectUnknown)
    var size = UInt32(MemoryLayout<AudioObjectID>.size)
    let status = withUnsafeMutablePointer(to: &qualifier) { qualifier in
        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address,
            UInt32(MemoryLayout<CFString>.size), qualifier, &size, &id)
    }
    return status == noErr && id != kAudioObjectUnknown ? id : nil
}

private func nominalSampleRate(of id: AudioObjectID) -> Double {
    var address = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyNominalSampleRate,
        mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    var rate: Float64 = 0
    var size = UInt32(MemoryLayout<Float64>.size)
    AudioObjectGetPropertyData(id, &address, 0, nil, &size, &rate)
    return rate
}

private struct DeviceNotFound: Error, CustomStringConvertible {
    let uid: String
    var description: String { "Device \(uid) not found" }
}

private func requireDeviceID(forUID uid: String) throws -> AudioObjectID {
    guard let id = deviceID(forUID: uid) else { throw DeviceNotFound(uid: uid) }
    return id
}

private struct IOProcError: Error, CustomStringConvertible {
    let description: String
}

/// Runs `block` on a device's real-time IO thread until stopped.
private final class IOProc {
    private let deviceID: AudioObjectID
    private var procID: AudioDeviceIOProcID?

    init(deviceID: AudioObjectID, block: @escaping AudioDeviceIOBlock) throws {
        self.deviceID = deviceID
        var status = AudioDeviceCreateIOProcIDWithBlock(&procID, deviceID, nil, block)
        if status == noErr {
            status = AudioDeviceStart(deviceID, procID)
        }
        guard status == noErr else {
            stop()
            throw IOProcError(description: "Starting IO on device \(deviceID) failed: \(status)")
        }
    }

    func stop() {
        guard let procID else { return }
        AudioDeviceStop(deviceID, procID)
        AudioDeviceDestroyIOProcID(deviceID, procID)
        self.procID = nil
    }
}

/// Plays a sine tone on every channel of a device.
private final class TonePlayer {
    static let amplitude = 0.25
    private var io: IOProc!

    init(uid: String, frequency: Double) throws {
        let id = try requireDeviceID(forUID: uid)
        let increment = 2 * .pi * frequency / nominalSampleRate(of: id)
        var phase = 0.0
        io = try IOProc(deviceID: id) { _, _, _, output, _ in
            var frames = 0
            for buffer in UnsafeMutableAudioBufferListPointer(output) {
                guard let data = buffer.mData?.assumingMemoryBound(to: Float.self) else {
                    continue
                }
                let channels = Int(buffer.mNumberChannels)
                frames = Int(buffer.mDataByteSize) / MemoryLayout<Float>.size / channels
                // Every buffer starts from the same phase so all outputs get the same tone.
                var bufferPhase = phase
                for frame in 0..<frames {
                    let sample = Float(Self.amplitude * sin(bufferPhase))
                    for channel in 0..<channels {
                        data[frame * channels + channel] = sample
                    }
                    bufferPhase += increment
                }
            }
            phase = (phase + increment * Double(frames)).truncatingRemainder(dividingBy: 2 * .pi)
        }
    }

    func stop() { io.stop() }
}

/// Records the first channel that a BlackHole device loops back to its input.
private final class LoopbackRecorder {
    private let capacity: Int
    private let samples = OSAllocatedUnfairLock(initialState: [Float]())
    private var io: IOProc!
    private let sampleRate: Double

    init(uid: String, seconds: Double = 0.5) throws {
        let id = try requireDeviceID(forUID: uid)
        sampleRate = nominalSampleRate(of: id)
        capacity = Int(sampleRate * seconds)
        io = try IOProc(deviceID: id) { [samples, capacity] _, input, _, _, _ in
            let buffers = UnsafeMutableAudioBufferListPointer(
                UnsafeMutablePointer(mutating: input))
            guard let buffer = buffers.first,
                let data = buffer.mData?.assumingMemoryBound(to: Float.self)
            else { return }
            let channels = Int(buffer.mNumberChannels)
            let frames = Int(buffer.mDataByteSize) / MemoryLayout<Float>.size / channels
            let chunk = (0..<frames).map { data[$0 * channels] }
            samples.withLock { samples in
                samples.append(contentsOf: chunk)
                if samples.count > capacity {
                    samples.removeFirst(samples.count - capacity)
                }
            }
        }
    }

    func reset() { samples.withLock { $0.removeAll(keepingCapacity: true) } }

    func stop() { io.stop() }

    /// Peak amplitude of `frequency` in the recording, via the Goertzel algorithm.
    func amplitude(at frequency: Double) -> Double {
        let samples = samples.withLock { $0 }
        guard !samples.isEmpty else { return 0 }
        let coefficient = 2 * cos(2 * .pi * frequency / sampleRate)
        var previous = 0.0
        var beforePrevious = 0.0
        for sample in samples {
            let current = Double(sample) + coefficient * previous - beforePrevious
            beforePrevious = previous
            previous = current
        }
        let power =
            previous * previous + beforePrevious * beforePrevious
            - coefficient * previous * beforePrevious
        return 2 * sqrt(max(power, 0)) / Double(samples.count)
    }
}
