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

    private static let githubURL = URL(string: "https://github.com/juri1212/Duophonic")!
    private static let soundSettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.Sound-Settings.extension")!

    var body: some View {
        VStack(alignment: .leading, spacing: MenuMetrics.sectionSpacing) {
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    NSWorkspace.shared.open(Self.soundSettingsURL)
                } label: {
                    HStack(spacing: MenuMetrics.iconSpacing) {
                        IconBadge(systemName: "slider.horizontal.3")
                        Text("Sound Settings…")
                        Spacer()
                        Image(systemName: "arrow.up.forward")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(MenuRowButtonStyle())

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
        }
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
    }
#endif
