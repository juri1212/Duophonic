//
//  MenuStyle.swift
//  Duophonic
//
//  Created by Juri Beforth on 03.10.26.
//

import SwiftUI

/// Metrics shared by all rows so they line up like the system's menu bar modules.
enum MenuMetrics {
    /// Inset of the hover highlight from the window edge.
    static let windowInset: CGFloat = 6
    /// Inset of row content from its hover highlight.
    static let rowPadding: CGFloat = 9
    static let iconSize: CGFloat = 26
    static let iconSpacing: CGFloat = 10
}

/// A row that highlights on hover, like the items of Control Center's menu bar modules.
struct MenuRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        MenuRow(configuration: configuration)
    }

    private struct MenuRow: View {
        let configuration: Configuration
        @Environment(\.isEnabled) private var isEnabled
        @State private var isHovered = false

        var body: some View {
            configuration.label
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, MenuMetrics.rowPadding)
                .padding(.vertical, 5)
                .foregroundStyle(isEnabled ? .primary : .tertiary)
                .contentShape(.rect)
                .background {
                    if isEnabled && (isHovered || configuration.isPressed) {
                        // Concentric with the menu window, like the system's menu highlights.
                        ConcentricRectangle(corners: .concentric(minimum: 8), isUniform: true)
                            .fill(.fill.tertiary)
                    }
                }
                .onHover { isHovered = $0 }
        }
    }
}

/// A separator inset like the ones between sections of a system menu.
struct MenuSeparator: View {
    var body: some View {
        Divider()
            .padding(.horizontal, MenuMetrics.rowPadding)
            .padding(.vertical, 5)
    }
}

/// A device glyph in a circle, filled with the accent color while the device is playing,
/// like the outputs in Control Center's Sound module.
struct DeviceIcon: View {
    let systemName: String
    var isActive = false
    var size = MenuMetrics.iconSize

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.46, weight: .semibold))
            .foregroundStyle(isActive ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
            .frame(width: size, height: size)
            .background(
                isActive ? AnyShapeStyle(.tint) : AnyShapeStyle(.fill.tertiary),
                in: .circle
            )
            .animation(.easeInOut(duration: 0.2), value: isActive)
            .accessibilityHidden(true)
    }
}
