//
//  MenuActionsView.swift
//  Duophonic
//
//  Created by Juri Beforth on 13.12.25.
//

import AppKit
import SwiftUI

/// The menu items below the Audio Sharing module.
struct MenuActionsView: View {
    @EnvironmentObject private var launchAtLogin: LaunchAtLogin
    @EnvironmentObject private var conversationAwareness: ConversationAwarenessManager

    private static let githubURL = URL(string: "https://github.com/juri1212/Duophonic")!
    private static let soundSettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.Sound-Settings.extension")!
    private static let bluetoothSettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.BluetoothSettings")!
    private static let accessibilitySettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!

    var body: some View {
        VStack(alignment: .leading, spacing: MenuMetrics.sectionSpacing) {
            VStack(alignment: .leading, spacing: 0) {
                settingsLink(
                    "Sound Settings…", systemImage: "slider.horizontal.3",
                    url: Self.soundSettingsURL)
                settingsLink(
                    "Bluetooth Settings…", systemImage: "wave.3.right",
                    url: Self.bluetoothSettingsURL)

                HStack(spacing: MenuMetrics.iconSpacing) {
                    IconBadge(systemName: "power")
                    Text("Open at Login")
                    Spacer()
                    Toggle(
                        "Open at Login",
                        isOn: Binding(
                            get: { launchAtLogin.isEnabled },
                            set: { launchAtLogin.setEnabled($0) }
                        )
                    )
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(DuoColor.accent)
                    .controlSize(.mini)
                }
                .padding(.horizontal, MenuMetrics.rowPadding)
                .padding(.vertical, 5)

                if launchAtLogin.requiresApproval {
                    Button(
                        "Allow in Login Items Settings…", action: launchAtLogin.openSystemSettings
                    )
                    .buttonStyle(MenuRowButtonStyle())
                    .font(.caption)
                } else if let errorMessage = launchAtLogin.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, MenuMetrics.rowPadding)
                        .padding(.vertical, 3)
                }

                if !conversationAwareness.isAllowed {
                    conversationAwarenessHint
                }
            }
            .plate()

            HStack(spacing: MenuMetrics.sectionSpacing) {
                Button(action: showAboutPanel) {
                    Label("About", systemImage: "info.circle")
                }
                .buttonStyle(PillButtonStyle())

                Button {
                    NSApp.terminate(nil)
                } label: {
                    HStack(spacing: 5) {
                        Text("Quit")
                        Text("⌘Q")
                            .foregroundStyle(.secondary)
                    }
                }
                .keyboardShortcut("q", modifiers: .command)
                .buttonStyle(PillButtonStyle())
                .accessibilityLabel("Quit Duophonic")
            }
        }
        .onAppear {
            launchAtLogin.refresh()
            conversationAwareness.refreshPermission()
        }
    }

    /// Offers the Accessibility access that pausing Conversation Awareness of AirPods needs.
    /// The switches under the AirPods appear once it's granted.
    private var conversationAwarenessHint: some View {
        Button {
            conversationAwareness.requestPermission()
            NSWorkspace.shared.open(Self.accessibilitySettingsURL)
        } label: {
            HStack(spacing: MenuMetrics.iconSpacing) {
                IconBadge(systemName: "person.wave.2")
                VStack(alignment: .leading, spacing: 0) {
                    Text("Conversation Awareness")
                    Text("Allow access to pause it on AirPods")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.forward")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(MenuRowButtonStyle())
    }

    /// A row that opens a pane of System Settings.
    private func settingsLink(_ title: LocalizedStringKey, systemImage: String, url: URL)
        -> some View
    {
        Button {
            NSWorkspace.shared.open(url)
        } label: {
            HStack(spacing: MenuMetrics.iconSpacing) {
                IconBadge(systemName: systemImage)
                Text(title)
                Spacer()
                Image(systemName: "arrow.up.forward")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(MenuRowButtonStyle())
    }

    /// The standard About panel, with a link to the project as credits.
    private func showAboutPanel() {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let credits = NSAttributedString(
            string: "github.com/juri1212/Duophonic",
            attributes: [
                .link: Self.githubURL,
                .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                .paragraphStyle: paragraph,
            ]
        )
        // A menu bar app is never active on its own, so the panel would open behind other windows.
        NSApp.activate()
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
    }
}

#if DEBUG
    #Preview {
        MenuActionsView()
            .padding(MenuMetrics.windowInset)
            .frame(width: MenuMetrics.windowWidth)
            .environmentObject(LaunchAtLogin())
            .environmentObject(ConversationAwarenessManager.preview)
    }
#endif
