//
//  SettingsView.swift
//  Duophonic
//
//  Created by Juri Beforth on 13.12.25.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var launchAtLogin: LaunchAtLogin

    var body: some View {
        VStack(spacing: 12) {
            // Use the label closure so we can add spacing between the label and the toggle control
            Toggle(
                isOn: Binding(
                    get: { launchAtLogin.isEnabled },
                    set: { launchAtLogin.setEnabled($0) }
                )
            ) {
                HStack {
                    Text("Start on login")
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity)
            .toggleStyle(SwitchToggleStyle())
            .onAppear {
                launchAtLogin.refresh()
            }
            .padding(.horizontal, 32)

            if launchAtLogin.requiresApproval {
                Button("Allow in Login Items Settings…", action: launchAtLogin.openSystemSettings)
                    .buttonStyle(.link)
                    .font(.caption)
                    .padding(.horizontal, 32)
            } else if let errorMessage = launchAtLogin.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 32)
            }

            Spacer()

            HStack {
                // GitHub link — replace the URL with your GitHub repo URL
                if let githubURL = URL(
                    string: "https://github.com/juri1212/Duophonic"
                ) {
                    Link(destination: githubURL) {
                        Image(systemName: "chevron.left.slash.chevron.right")
                            .imageScale(.large)
                        Text("GitHub").font(.footnote)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open Duophonic on GitHub")
                    .accessibilityAddTraits(.isLink)
                    .help("Open Duophonic on GitHub")
                }
                Spacer()
                Button {
                    NSApp.terminate(nil)
                } label: {
                    Image(systemName: "power").imageScale(.large)
                }
                .keyboardShortcut("q", modifiers: .command)
                .buttonStyle(.plain)
                .help("Quit Duophonic")
            }.padding(.horizontal, 32)
            Divider()
            Text(
                "Duophonic v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?.?.?")"
            )
            .font(.footnote)
            .padding(2)

        }
        .background(Color.clear)

    }
}

#if DEBUG
    #Preview {
        SettingsView()
            .frame(width: 260 - 2 * 14)
            .padding(14)
            .environmentObject(LaunchAtLogin())
    }
#endif
