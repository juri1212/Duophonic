//
//  AudioDeviceSelector.swift
//  Duophonic
//
//  Created by Juri Beforth on 19.12.25.
//

import SwiftUI

/// One of the two outputs: its device and volume, with an inline list to pick another device,
/// like a shared listener in the Share Audio card on iPhone.
struct AudioDeviceSelectorView: View {
    @EnvironmentObject private var audioManager: AudioAggregateManager
    let role: AudioAggregateManager.Role
    @Binding var isExpanded: Bool

    private var currentDevice: AudioDevice? { audioManager.device(for: role) }

    /// Aligns content with the device name, past the icon column.
    private let textInset = MenuMetrics.rowPadding + MenuMetrics.iconSize + MenuMetrics.iconSpacing

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.snappy) { isExpanded.toggle() }
            } label: {
                summary
            }
            .buttonStyle(MenuRowButtonStyle())
            .accessibilityLabel(audioManager.selectedName(for: role) ?? "No Output")
            .accessibilityValue(currentDevice == nil ? "Not Connected" : "")
            .accessibilityHint(isExpanded ? "Hides the output devices" : "Shows the output devices")

            volumeSlider
                .padding(.leading, textInset)
                .padding(.trailing, MenuMetrics.rowPadding)
                .padding(.bottom, 6)

            if isExpanded {
                deviceList
                    .transition(.opacity)
            }
        }
    }

    private var summary: some View {
        HStack(spacing: MenuMetrics.iconSpacing) {
            DeviceIcon(
                systemName: currentDevice?.iconName ?? "speaker.slash",
                isActive: audioManager.isEnabled && currentDevice != nil
            )

            VStack(alignment: .leading, spacing: 0) {
                Text(audioManager.selectedName(for: role) ?? "No Output")
                    .lineLimit(1)
                    .truncationMode(.middle)
                if currentDevice == nil {
                    Text("Not Connected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
        }
    }

    private var volumeSlider: some View {
        Slider(
            value: Binding(
                get: { currentDevice?.volume ?? 0 },
                set: { audioManager.setVolume($0, for: role) }
            ),
            in: 0...1
        )
        .controlSize(.small)
        .disabled(!(currentDevice?.supportsVolume ?? false))
        .accessibilityLabel("\(currentDevice?.name ?? "Output") Volume")
        .help(
            currentDevice?.supportsVolume == false
                ? "This device's volume can only be changed on the device" : "")
    }

    private var deviceList: some View {
        VStack(alignment: .leading, spacing: 0) {
            if audioManager.devices.isEmpty {
                Text("No Output Devices")
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, MenuMetrics.rowPadding)
                    .padding(.vertical, 5)
            }
            ForEach(audioManager.devices) { device in
                AudioDeviceRow(
                    device: device,
                    isSelected: audioManager.uid(for: role) == device.uid,
                    action: {
                        audioManager.select(device.uid, for: role)
                        withAnimation(.snappy) { isExpanded = false }
                    }
                )
            }
        }
        // Nested under the output's name, like a disclosed section of a system menu.
        .padding(.leading, MenuMetrics.iconSize + MenuMetrics.iconSpacing)
        .padding(.bottom, 4)
    }
}

private struct AudioDeviceRow: View {
    let device: AudioDevice
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: MenuMetrics.iconSpacing) {
                DeviceIcon(systemName: device.iconName, isActive: isSelected, size: 22)
                Text(device.name)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .buttonStyle(MenuRowButtonStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#if DEBUG
    #Preview("Expanded Output") {
        AudioDeviceSelectorView(role: .primary, isExpanded: .constant(true))
            .padding(MenuMetrics.windowInset)
            .frame(width: 300)
            .environmentObject(AudioAggregateManager.preview)
    }
#endif
