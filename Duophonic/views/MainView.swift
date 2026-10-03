//
//  MainView.swift
//  Duophonic
//
//  Created by Juri Beforth on 13.12.25.
//

import SwiftUI

/// The Audio Sharing module: a switch for sharing and the two outputs it plays to.
struct MainView: View {
    @EnvironmentObject private var audioManager: AudioAggregateManager
    /// Only one device list is open at a time.
    @State private var expandedRole: AudioAggregateManager.Role?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if let errorMessage = audioManager.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, MenuMetrics.rowPadding)
                    .padding(.bottom, 6)
                    .transition(.opacity)
            }

            MenuSeparator()

            ForEach(AudioAggregateManager.Role.allCases, id: \.self) { role in
                AudioDeviceSelectorView(role: role, isExpanded: isExpanded(role))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: audioManager.errorMessage)
        .onAppear {
            audioManager.refreshDevices()
        }
        .onDisappear {
            expandedRole = nil
        }
        .onChange(of: expandedRole) { _, newValue in
            if newValue != nil {
                audioManager.refreshDevices()
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text("Audio Sharing")
                    .font(.headline)
                Text(
                    audioManager.isEnabled
                        ? "Playing on both outputs" : "Play on two outputs at once"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .contentTransition(.opacity)
            }
            Spacer()
            Toggle(
                "Audio Sharing",
                isOn: Binding(
                    get: { audioManager.isEnabled },
                    set: { audioManager.setEnabled($0) }
                )
            )
            .labelsHidden()
            .toggleStyle(.switch)
            .disabled(!audioManager.isEnabled && !audioManager.canEnable)
            .help(audioManager.isEnabled ? "Stop sharing audio" : "Play on both outputs")
        }
        .padding(.horizontal, MenuMetrics.rowPadding)
        .padding(.vertical, 6)
        .animation(.easeInOut(duration: 0.2), value: audioManager.isEnabled)
    }

    private func isExpanded(_ role: AudioAggregateManager.Role) -> Binding<Bool> {
        Binding(
            get: { expandedRole == role },
            set: { expanded in
                if expanded {
                    expandedRole = role
                } else if expandedRole == role {
                    expandedRole = nil
                }
            }
        )
    }
}

#if DEBUG
    #Preview {
        MainView()
            .padding(MenuMetrics.windowInset)
            .frame(width: 300)
            .environmentObject(AudioAggregateManager.preview)
    }
#endif
