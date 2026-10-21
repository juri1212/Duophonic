//
//  ConversationAwarenessView.swift
//  Duophonic
//
//  Created by Juri Beforth on 15.10.26.
//

import SwiftUI

/// The switch under an AirPods output that pauses its Conversation Awareness, so the volume
/// stays put while talking.
struct ConversationAwarenessToggle: View {
    @EnvironmentObject private var manager: ConversationAwarenessManager
    let device: AudioDevice

    var body: some View {
        if manager.isAllowed {
            toggle
        }
    }

    private var toggle: some View {
        let isPaused = manager.isPaused(device)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "person.wave.2")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(
                        isPaused ? AnyShapeStyle(DuoColor.accent) : AnyShapeStyle(.secondary)
                    )
                    .frame(width: 18)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Pause Conversation Awareness")
                        .font(.callout)
                    Text(
                        isPaused ? "Restored when switched off or quit" : "As set for these AirPods"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .contentTransition(.opacity)
                }
                Spacer(minLength: 0)
                PauseSwitch(device: device, isPaused: isPaused)
            }
            ConversationAwarenessMessage(device: device)
        }
        .padding(.horizontal, MenuMetrics.rowPadding)
        .padding(.bottom, 8)
        .animation(.easeInOut(duration: 0.2), value: isPaused)
    }
}

/// Connected AirPods that aren't one of the outputs, so a pause can still be switched off after
/// picking another output.
struct ConversationAwarenessView: View {
    @EnvironmentObject private var manager: ConversationAwarenessManager
    @EnvironmentObject private var audioManager: AudioAggregateManager

    private var otherAirPods: [AudioDevice] {
        let outputs = Set(
            AudioAggregateManager.Role.allCases.compactMap { audioManager.device(for: $0)?.name })
        return manager.airPods.filter { !outputs.contains($0.name) }
    }

    var body: some View {
        let airPods = otherAirPods
        if manager.isAllowed, !airPods.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Text("Pause Conversation Awareness")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, MenuMetrics.rowPadding)
                    .padding(.top, 4)
                    .padding(.bottom, 2)

                ForEach(airPods) { device in
                    ConversationAwarenessRow(device: device)
                }
            }
            .plate()
        }
    }
}

private struct ConversationAwarenessRow: View {
    @EnvironmentObject private var manager: ConversationAwarenessManager
    let device: AudioDevice

    var body: some View {
        let isPaused = manager.isPaused(device)
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: MenuMetrics.iconSpacing) {
                DeviceIcon(
                    systemName: device.iconName, isActive: isPaused,
                    size: MenuMetrics.smallIconSize)
                VStack(alignment: .leading, spacing: 0) {
                    Text(device.name)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(
                        isPaused ? "Paused until switched off or quit" : "As set for these AirPods"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .contentTransition(.opacity)
                }
                Spacer(minLength: 0)
                PauseSwitch(device: device, isPaused: isPaused)
            }
            ConversationAwarenessMessage(device: device)
        }
        .padding(.horizontal, MenuMetrics.rowPadding)
        .padding(.vertical, 5)
        .animation(.easeInOut(duration: 0.2), value: isPaused)
    }
}

private struct PauseSwitch: View {
    @EnvironmentObject private var manager: ConversationAwarenessManager
    let device: AudioDevice
    let isPaused: Bool

    var body: some View {
        if manager.isBusy(device) {
            ProgressView()
                .controlSize(.small)
        } else {
            Toggle(
                "Pause Conversation Awareness",
                isOn: Binding(
                    get: { isPaused },
                    set: { manager.setPaused($0, for: device) }
                )
            )
            .labelsHidden()
            .toggleStyle(.switch)
            .tint(DuoColor.accent)
            .controlSize(.mini)
            .accessibilityLabel("Pause Conversation Awareness of \(device.name)")
        }
    }
}

/// The last error, under the AirPods it's about.
private struct ConversationAwarenessMessage: View {
    @EnvironmentObject private var manager: ConversationAwarenessManager
    let device: AudioDevice

    var body: some View {
        Group {
            if manager.messageDeviceName == device.name, let errorMessage = manager.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 3)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: manager.errorMessage)
    }
}

#if DEBUG
    #Preview {
        ConversationAwarenessView()
            .padding(MenuMetrics.windowInset)
            .frame(width: MenuMetrics.windowWidth)
            .environmentObject(AudioAggregateManager.preview)
            .environmentObject(ConversationAwarenessManager.preview)
    }
#endif
