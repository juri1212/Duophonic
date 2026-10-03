//
//  LaunchAtLogin.swift
//  Duophonic
//
//  Created by Juri Beforth on 03.10.26.
//

import Combine
import ServiceManagement
import os

private let logger = Logger(subsystem: "com.juri1212.Duophonic", category: "LaunchAtLogin")

/// Registers the app as a login item, reflecting changes made in System Settings.
@MainActor
final class LaunchAtLogin: ObservableObject {
    @Published private(set) var isEnabled = false
    /// Registered, but the user still has to allow it in System Settings → Login Items.
    @Published private(set) var requiresApproval = false
    @Published private(set) var errorMessage: String?

    init() {
        refresh()
    }

    func refresh() {
        let status = SMAppService.mainApp.status
        isEnabled = status == .enabled || status == .requiresApproval
        requiresApproval = status == .requiresApproval
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            errorMessage = nil
        } catch {
            logger.error(
                "Updating login item failed: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
        }
        refresh()
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
