//
//  MainView.swift
//  Duophonic
//
//  Created by Juri Beforth on 13.12.25.
//

import SwiftUI

struct MainView: View {
    @Binding var settingsShowing: Bool
    @EnvironmentObject private var audioManager: AudioAggregateManager
    /// Only one device list is open at a time.
    @State private var expandedRole: AudioAggregateManager.Role?

    init(settingsShowing: Binding<Bool> = .constant(false)) {
        _settingsShowing = settingsShowing
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Multi-Output Device")
                Spacer()
                Toggle(
                    isOn: Binding(
                        get: { audioManager.isEnabled },
                        set: { audioManager.setEnabled($0) }
                    )
                ) {}
                .toggleStyle(SwitchToggleStyle())
                .help("Toggle multi-output aggregate device")
                .accessibilityLabel("Multi-Output Device")
                .disabled(!audioManager.isEnabled && !audioManager.canEnable)
            }
            .padding(.horizontal, 16)

            if let errorMessage = audioManager.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)
                    .transition(.opacity)
            }

            VStack(spacing: 8) {
                AudioDeviceSelectorView(role: .primary, isExpanded: isExpanded(.primary))
                AudioDeviceSelectorView(role: .secondary, isExpanded: isExpanded(.secondary))
            }
        }
        .background(Color.clear)
        .animation(.easeInOut(duration: 0.2), value: audioManager.errorMessage)
        .onAppear {
            audioManager.refreshDevices()
        }
        .onDisappear {
            expandedRole = nil
        }
        .onChange(of: settingsShowing) { _, newValue in
            if newValue {
                expandedRole = nil
            }
        }
        .onChange(of: expandedRole) { _, newValue in
            if newValue != nil {
                audioManager.refreshDevices()
            }
        }
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
        MainView(settingsShowing: .constant(false))
            .frame(width: 300 - 2 * 14, height: 300)
            .padding(14)
            .environmentObject(AudioAggregateManager.preview)
    }
#endif
