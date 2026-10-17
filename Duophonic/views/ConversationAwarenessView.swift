//
//  ConversationAwarenessView.swift
//  Duophonic
//
//  Created by Juri Beforth on 15.10.26.
//

import AppKit
import SwiftUI

/// A switch per connected AirPods that pauses its Conversation Awareness, so the volume stays
/// put while talking. Hidden while no AirPods are connected.
struct ConversationAwarenessView: View {
    @EnvironmentObject private var manager: ConversationAwarenessManager

    private static let accessibilitySettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!

    var body: some View {
        if !manager.airPods.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Text("Pause Conversation Awareness")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, MenuMetrics.rowPadding)
                    .padding(.top, 4)
                    .padding(.bottom, 2)

                ForEach(manager.airPods) { device in
                    ConversationAwarenessRow(device: device)
                }

                if manager.needsPermission {
                    Button("Allow in Accessibility Settings…") {
                        NSWorkspace.shared.open(Self.accessibilitySettingsURL)
                    }
                    .buttonStyle(MenuRowButtonStyle())
                    .font(.caption)
                } else if let errorMessage = manager.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, MenuMetrics.rowPadding)
                        .padding(.vertical, 3)
                }
            }
            .plate()
            .animation(.easeInOut(duration: 0.2), value: manager.errorMessage)
        }
    }
}

private struct ConversationAwarenessRow: View {
    @EnvironmentObject private var manager: ConversationAwarenessManager
    let device: AudioDevice

    var body: some View {
        let isPaused = manager.isPaused(device)
        HStack(spacing: MenuMetrics.iconSpacing) {
            DeviceIcon(
                systemName: device.iconName, isActive: isPaused, size: MenuMetrics.smallIconSize)
            VStack(alignment: .leading, spacing: 0) {
                Text(device.name)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(isPaused ? "Paused until switched off or quit" : "As set for these AirPods")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .contentTransition(.opacity)
            }
            Spacer(minLength: 0)
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
        .padding(.horizontal, MenuMetrics.rowPadding)
        .padding(.vertical, 5)
        .animation(.easeInOut(duration: 0.2), value: isPaused)
    }
}

#if DEBUG
    #Preview {
        ConversationAwarenessView()
            .padding(MenuMetrics.windowInset)
            .frame(width: MenuMetrics.windowWidth)
            .environmentObject(ConversationAwarenessManager.preview)
    }
#endif
