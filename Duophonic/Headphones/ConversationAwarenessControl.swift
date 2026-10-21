//
//  ConversationAwarenessControl.swift
//  Duophonic
//
//  Created by Juri Beforth on 15.10.26.
//

import AppKit
import ApplicationServices

enum ConversationAwarenessError: LocalizedError, Equatable {
    case accessibilityNotAllowed
    case soundMenuUnavailable
    case deviceNotFound(String)
    case unsupported(String)
    case notApplied(String)

    var errorDescription: String? {
        switch self {
        case .accessibilityNotAllowed:
            return "Allow Duophonic in Accessibility settings to change Conversation Awareness."
        case .soundMenuUnavailable:
            return "Show Sound in the menu bar to change Conversation Awareness."
        case .deviceNotFound(let name):
            return "\(name) isn’t listed in the Sound menu."
        case .unsupported(let name):
            return "\(name) don’t support Conversation Awareness."
        case .notApplied(let name):
            return "Conversation Awareness of \(name) didn’t change."
        }
    }
}

/// Reads and changes the Conversation Awareness setting of headphones, identified by the name
/// of their audio device.
@MainActor
protocol ConversationAwarenessControl: AnyObject {
    var isAllowed: Bool { get }
    /// Asks the user for the permission the control needs, if it isn't granted yet.
    func requestPermission()
    func isEnabled(on deviceName: String) async throws -> Bool
    func setEnabled(_ enabled: Bool, on deviceName: String) async throws
}

/// Drives the AirPods controls of the Sound menu through the Accessibility API.
///
/// Conversation Awareness can only be changed by Apple's processes: the Bluetooth daemon
/// requires the restricted `com.apple.bluetooth.system` entitlement, and talking to the AirPods
/// directly disconnects them from macOS. The Sound menu offers the setting for every connected
/// AirPods, so it is opened briefly and its Off/On choice pressed like a user would.
@MainActor
final class ControlCenterConversationAwareness: ConversationAwarenessControl {
    private static let soundMenuIdentifier = "com.apple.menuextra.sound"
    /// Processes that host the system's menu bar extras, newest macOS first.
    private static let menuExtraHosts = ["com.apple.MenuBarAgent", "com.apple.controlcenter"]

    /// The section title in the Sound menu, in the language Control Center shows.
    private lazy var sectionTitle: String = {
        let controlCenter = URL(fileURLWithPath: "/System/Library/CoreServices/ControlCenter.app")
        return Bundle(url: controlCenter)?.localizedString(
            forKey: "Conversation Awareness", value: nil, table: "ListeningMode")
            ?? "Conversation Awareness"
    }()

    var isAllowed: Bool { AXIsProcessTrusted() }

    func requestPermission() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    func isEnabled(on deviceName: String) async throws -> Bool {
        try await withSoundMenu { menu in
            let choice = try await self.choice(for: deviceName, in: menu)
            return choice.on.isOn
        }
    }

    func setEnabled(_ enabled: Bool, on deviceName: String) async throws {
        try await withSoundMenu { menu in
            let choice = try await self.choice(for: deviceName, in: menu)
            guard choice.on.isOn != enabled else { return }
            (enabled ? choice.on : choice.off).press()
            // The menu redraws the device's controls after a change.
            let applied = await poll {
                (try? await self.choice(for: deviceName, in: menu))?.on.isOn == enabled
            }
            guard applied else { throw ConversationAwarenessError.notApplied(deviceName) }
        }
    }

    // MARK: - Sound menu

    private struct SoundMenu {
        let item: AXElement
        let controlCenter: AXElement
    }

    private struct Choice {
        let off: AXElement
        let on: AXElement
    }

    /// Opens the Sound menu for `body` and always closes it again.
    private func withSoundMenu<T>(_ body: (SoundMenu) async throws -> T) async throws -> T {
        guard isAllowed else { throw ConversationAwarenessError.accessibilityNotAllowed }
        guard let item = soundMenuItem(),
            let controlCenter = AXElement.application(bundleIdentifier: "com.apple.controlcenter")
        else {
            throw ConversationAwarenessError.soundMenuUnavailable
        }
        let menu = SoundMenu(item: item, controlCenter: controlCenter)
        item.press()
        defer {
            if isOpen(menu) { item.press() }
        }
        guard await poll({ self.isOpen(menu) }) else {
            throw ConversationAwarenessError.soundMenuUnavailable
        }
        return try await body(menu)
    }

    private func soundMenuItem() -> AXElement? {
        for host in Self.menuExtraHosts {
            guard let app = AXElement.application(bundleIdentifier: host),
                let bar = app.element(for: "AXExtrasMenuBar")
            else { continue }
            if let item = bar.first(where: { $0.identifier == Self.soundMenuIdentifier }) {
                return item
            }
        }
        return nil
    }

    private func isOpen(_ menu: SoundMenu) -> Bool {
        menu.controlCenter.windows.contains { window in
            window.first { $0.identifier?.hasPrefix("sound-device-") == true } != nil
        }
    }

    /// The controls of a device, in menu order: its row, a disclosure triangle and, when
    /// expanded, headings followed by their choices.
    private func deviceRows(in menu: SoundMenu, deviceName: String) -> [AXElement] {
        menu.controlCenter.windows.flatMap { window in
            window.all { $0.identifier == "sound-device-\(deviceName)" }
        }
    }

    private func choice(for deviceName: String, in menu: SoundMenu) async throws -> Choice {
        var rows = deviceRows(in: menu, deviceName: deviceName)
        guard !rows.isEmpty else { throw ConversationAwarenessError.deviceNotFound(deviceName) }
        if let disclosure = rows.first(where: { $0.role == "AXDisclosureTriangle" }),
            !disclosure.isOn
        {
            disclosure.press()
            _ = await poll { self.deviceRows(in: menu, deviceName: deviceName).count > rows.count }
            rows = deviceRows(in: menu, deviceName: deviceName)
        }
        guard let heading = rows.firstIndex(where: { $0.label == sectionTitle }) else {
            throw ConversationAwarenessError.unsupported(deviceName)
        }
        let choices = rows[(heading + 1)...].prefix { $0.role == "AXCheckBox" }
        guard choices.count == 2 else { throw ConversationAwarenessError.unsupported(deviceName) }
        return Choice(off: choices[choices.startIndex], on: choices[choices.startIndex + 1])
    }

    /// Checks `condition` until it holds, for up to two seconds.
    private func poll(_ condition: () async -> Bool) async -> Bool {
        for _ in 0..<40 {
            if await condition() { return true }
            try? await Task.sleep(for: .milliseconds(50))
        }
        return await condition()
    }
}

/// A thin wrapper around `AXUIElement` for the attributes used here.
private struct AXElement {
    let element: AXUIElement

    static func application(bundleIdentifier: String) -> AXElement? {
        guard
            let app = NSRunningApplication.runningApplications(
                withBundleIdentifier: bundleIdentifier
            ).first
        else { return nil }
        let element = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(element, 1)
        return AXElement(element: element)
    }

    private func value(_ attribute: String) -> AnyObject? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success
        else { return nil }
        return value
    }

    func element(for attribute: String) -> AXElement? {
        guard let value = value(attribute), CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return nil
        }
        return AXElement(element: value as! AXUIElement)
    }

    private func elements(_ attribute: String) -> [AXElement] {
        ((value(attribute) as? [AXUIElement]) ?? []).map(AXElement.init)
    }

    var children: [AXElement] { elements(kAXChildrenAttribute) }
    var windows: [AXElement] { elements(kAXWindowsAttribute) }
    var role: String? { value(kAXRoleAttribute) as? String }
    var identifier: String? { value(kAXIdentifierAttribute) as? String }
    var label: String? { value(kAXDescriptionAttribute) as? String }
    var isOn: Bool { (value(kAXValueAttribute) as? Int) == 1 }

    func press() {
        AXUIElementPerformAction(element, kAXPressAction as CFString)
    }

    /// This element and its descendants that match, in depth-first order.
    func all(where predicate: (AXElement) -> Bool) -> [AXElement] {
        var matches = predicate(self) ? [self] : []
        for child in children {
            matches += child.all(where: predicate)
        }
        return matches
    }

    func first(where predicate: (AXElement) -> Bool) -> AXElement? {
        if predicate(self) { return self }
        for child in children {
            if let match = child.first(where: predicate) { return match }
        }
        return nil
    }
}
