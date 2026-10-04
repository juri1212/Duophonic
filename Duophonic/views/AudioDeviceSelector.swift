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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.snappy) { isExpanded.toggle() }
            } label: {
                summary
            }
            .buttonStyle(MenuRowButtonStyle())
            .accessibilityLabel(audioManager.selectedName(for: role) ?? "No Output")
            .accessibilityValue(currentDevice == nil ? "Not Connected" : role.title)
            .accessibilityHint(isExpanded ? "Hides the output devices" : "Shows the output devices")

            volumeSlider
                .padding(.horizontal, MenuMetrics.rowPadding)
                .padding(.top, 3)
                .padding(.bottom, 9)

            if isExpanded {
                deviceList
                    .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
            }
        }
    }

    private var summary: some View {
        HStack(spacing: MenuMetrics.iconSpacing) {
            DeviceIcon(
                systemName: currentDevice?.iconName ?? "speaker.slash",
                isActive: audioManager.isEnabled && currentDevice != nil
            )

            VStack(alignment: .leading, spacing: 1) {
                Text(audioManager.selectedName(for: role) ?? "No Output")
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .contentTransition(.opacity)
            }

            Spacer(minLength: 0)

            ChevronBadge(isOpen: isExpanded)
        }
    }

    private var caption: String {
        if currentDevice == nil { return "Not Connected" }
        return audioManager.isEnabled ? "\(role.title) · \(role.detail)" : role.title
    }

    private var volumeSlider: some View {
        VolumeCapsule(
            value: Binding(
                get: { currentDevice?.volume ?? 0 },
                set: { audioManager.setVolume($0, for: role) }
            ),
            label: "\(currentDevice?.name ?? "Output") Volume"
        )
        .disabled(!(currentDevice?.supportsVolume ?? false))
        .help(
            currentDevice?.supportsVolume == false
                ? "This device's volume can only be changed on the device" : "")
    }

    private var deviceList: some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        return VStack(alignment: .leading, spacing: 0) {
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
                    otherRole: audioManager.uid(for: role.other) == device.uid ? role.other : nil,
                    action: {
                        audioManager.select(device.uid, for: role)
                        withAnimation(.snappy) { isExpanded = false }
                    }
                )
            }
        }
        // A recessed well under the output, like a disclosed section of Control Center.
        .padding(4)
        .containerShape(shape)
        .background { WellBackground(shape: shape) }
        .padding(.horizontal, 2)
        .padding(.bottom, 6)
    }
}

extension AudioAggregateManager.Role {
    var title: String { self == .primary ? "Output 1" : "Output 2" }
    var detail: String { self == .primary ? "Clock source" : "Drift corrected" }
}

private struct AudioDeviceRow: View {
    let device: AudioDevice
    let isSelected: Bool
    /// The other output, if it plays on this device. Picking it swaps the two.
    let otherRole: AudioAggregateManager.Role?
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: MenuMetrics.iconSpacing) {
                DeviceIcon(
                    systemName: device.iconName, isActive: isSelected,
                    size: MenuMetrics.smallIconSize)
                VStack(alignment: .leading, spacing: 0) {
                    Text(device.name)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(device.category.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if let otherRole {
                    Text(otherRole.title)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(GlassFill.well(colorScheme), in: .capsule)
                }
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(DuoColor.ink(colorScheme))
                }
            }
        }
        .buttonStyle(MenuRowButtonStyle(isHighlighted: isSelected))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityValue(otherRole.map { "Used by \($0.title)" } ?? "")
    }
}

#if DEBUG
    #Preview("Expanded Output") {
        AudioDeviceSelectorView(role: .primary, isExpanded: .constant(true))
            .padding(MenuMetrics.windowInset)
            .frame(width: MenuMetrics.windowWidth)
            .environmentObject(AudioAggregateManager.preview)
    }
#endif
