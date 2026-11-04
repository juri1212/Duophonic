//
//  AudioDevice.swift
//  Duophonic
//
//  Created by Juri Beforth on 01.12.25.
//

import CoreAudio

/// An output-capable hardware device that can be one of the two outputs.
struct AudioDevice: Identifiable, Equatable {
    /// Persistent Core Audio UID. Unlike an `AudioObjectID` it survives reconnects and reboots.
    let uid: String
    let name: String
    let category: AudioDeviceCategory
    /// Software volume in `0...1`, or `nil` if the device has no settable volume control.
    var volume: Double?

    var id: String { uid }
    var supportsVolume: Bool { volume != nil }

    /// A glyph of the product itself where its name gives it away, like the Bluetooth menu.
    var iconName: String {
        Self.productIcons.first { category == $0.category && $0.matches(name) }?.symbol
            ?? category.iconName
    }

    /// Checked in order, so more specific names come first.
    private static let productIcons: [ProductIcon] = [
        ProductIcon(.bluetooth, ["airpods max"], "airpods.max"),
        ProductIcon(.bluetooth, ["airpods pro"], "airpods.pro"),
        ProductIcon(.bluetooth, ["airpods"], "airpods.gen3"),
        ProductIcon(.bluetooth, ["powerbeats"], "beats.powerbeats.pro"),
        ProductIcon(.bluetooth, ["studio buds", "solo buds", "beats fit"], "beats.studiobuds"),
        ProductIcon(.bluetooth, ["beats"], "beats.headphones"),
        ProductIcon(.airplay, ["homepod mini"], "homepod.mini.fill"),
        ProductIcon(.airplay, ["homepod"], "homepod.fill"),
        ProductIcon(.airplay, ["apple tv"], "appletv.fill"),
    ]

    private struct ProductIcon {
        let category: AudioDeviceCategory
        let keywords: [String]
        let symbol: String

        init(_ category: AudioDeviceCategory, _ keywords: [String], _ symbol: String) {
            self.category = category
            self.keywords = keywords
            self.symbol = symbol
        }

        func matches(_ name: String) -> Bool {
            keywords.contains { name.localizedCaseInsensitiveContains($0) }
        }
    }
}

enum AudioDeviceCategory: String, CaseIterable {
    case builtin = "Built-In"
    case bluetooth = "Bluetooth"
    case airplay = "AirPlay"
    case usb = "USB"
    case display = "Display"
    case virtual = "Virtual"
    case other = "Other"

    init(transportType: UInt32) {
        switch transportType {
        case kAudioDeviceTransportTypeBuiltIn:
            self = .builtin
        case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE:
            self = .bluetooth
        case kAudioDeviceTransportTypeAirPlay:
            self = .airplay
        case kAudioDeviceTransportTypeUSB:
            self = .usb
        case kAudioDeviceTransportTypeHDMI, kAudioDeviceTransportTypeDisplayPort:
            self = .display
        case kAudioDeviceTransportTypeVirtual:
            self = .virtual
        default:
            self = .other
        }
    }

    var iconName: String {
        switch self {
        case .builtin: return "hifispeaker.2.fill"
        case .bluetooth: return "headphones"
        case .airplay: return "airplayaudio"
        case .usb: return "cable.connector"
        case .display: return "tv"
        case .virtual: return "waveform"
        case .other: return "speaker.wave.2"
        }
    }

    var subtitle: String { rawValue }
}
