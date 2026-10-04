//
//  MenuStyle.swift
//  Duophonic
//
//  Created by Juri Beforth on 03.10.26.
//

import SwiftUI

/// Metrics shared by all rows so they line up inside the menu bar window.
enum MenuMetrics {
    static let windowWidth: CGFloat = 320
    /// Inset of the content from the window's glass edge.
    static let windowInset: CGFloat = 10
    /// Spacing between the plates and the header.
    static let sectionSpacing: CGFloat = 8
    static let plateRadius: CGFloat = 20
    /// Inset of rows from their plate.
    static let plateInset: CGFloat = 5
    /// Inset of row content from its hover highlight.
    static let rowPadding: CGFloat = 8
    static let iconSize: CGFloat = 36
    static let smallIconSize: CGFloat = 28
    static let iconSpacing: CGFloat = 10
    static let sliderHeight: CGFloat = 26
}

/// The teal of the app icon, as a lit lens for glyphs that are playing.
enum DuoColor {
    static let accent = Color(red: 0.039, green: 0.729, blue: 0.710)
    static let lens = Color(red: 0.23, green: 0.90, blue: 0.87)
    static let deep = Color(red: 0.024, green: 0.478, blue: 0.463)

    static let lensGradient = EllipticalGradient(
        stops: [
            .init(color: lens, location: 0),
            .init(color: Color(red: 0.039, green: 0.663, blue: 0.639), location: 0.45),
            .init(color: deep, location: 1),
        ],
        center: UnitPoint(x: 0.3, y: 0.15),
        endRadiusFraction: 1.1
    )

    /// Teal text and checkmarks, dark enough to read on the light plates.
    static func ink(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.44, green: 0.95, blue: 0.92) : Color(red: 0.02, green: 0.38, blue: 0.37)
    }
}

/// Fills that sit on the window's Liquid Glass. They are tints, not glass of their own,
/// because glass can't sample other glass.
enum GlassFill {
    static func plate(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? .white.opacity(0.045) : .white.opacity(0.26)
    }

    /// A recessed area, such as a slider track or the device list.
    static func well(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? .black.opacity(0.2) : .black.opacity(0.06)
    }

    static func highlight(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? .white.opacity(0.1) : .white.opacity(0.5)
    }

    /// The specular rim along the top edge of a raised shape.
    static func rim(_ scheme: ColorScheme) -> LinearGradient {
        let strength = scheme == .dark ? 0.2 : 0.85
        return LinearGradient(
            stops: [
                .init(color: .white.opacity(strength), location: 0),
                .init(color: .white.opacity(strength * 0.1), location: 0.45),
                .init(color: .white.opacity(strength * 0.3), location: 1),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

/// A raised tint behind a group of rows, with a specular rim.
struct Plate: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: MenuMetrics.plateRadius, style: .continuous)
        content
            .padding(MenuMetrics.plateInset)
            .containerShape(shape)
            .background {
                shape
                    .fill(GlassFill.plate(colorScheme))
                    .overlay { shape.strokeBorder(GlassFill.rim(colorScheme), lineWidth: 1) }
            }
    }
}

extension View {
    func plate() -> some View { modifier(Plate()) }
}

/// The teal lens behind an active glyph: a lit gradient, an inner rim and a colored glow.
struct LensBackground<S: InsettableShape>: View {
    let shape: S
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        // On dark glass the glow reads as a bright halo, so it stays faint and tight there.
        let isDark = colorScheme == .dark
        shape
            .fill(DuoColor.lensGradient)
            .overlay {
                shape.strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(isDark ? 0.4 : 0.75), .white.opacity(0)],
                        startPoint: .top, endPoint: .center),
                    lineWidth: 1)
            }
            .shadow(
                color: DuoColor.accent.opacity(isDark ? 0.18 : 0.4),
                radius: isDark ? 3 : 6, y: isDark ? 1 : 3)
    }
}

/// The neutral, recessed counterpart of `LensBackground`.
struct WellBackground<S: InsettableShape>: View {
    let shape: S
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        shape
            .fill(GlassFill.well(colorScheme))
            .overlay {
                shape.strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(colorScheme == .dark ? 0.08 : 0.4), .clear],
                        startPoint: .top, endPoint: .center),
                    lineWidth: 1)
            }
    }
}

/// A row that highlights on hover, concentric with the plate it sits on.
struct MenuRowButtonStyle: ButtonStyle {
    /// Keeps the highlight while not hovered, e.g. for the selected device.
    var isHighlighted = false

    func makeBody(configuration: Configuration) -> some View {
        MenuRow(configuration: configuration, isHighlighted: isHighlighted)
    }

    private struct MenuRow: View {
        let configuration: Configuration
        let isHighlighted: Bool
        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.colorScheme) private var colorScheme
        @State private var isHovered = false

        var body: some View {
            configuration.label
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, MenuMetrics.rowPadding)
                .padding(.vertical, 5)
                .foregroundStyle(isEnabled ? .primary : .tertiary)
                .contentShape(.rect)
                .background {
                    if isEnabled && (isHighlighted || isHovered || configuration.isPressed) {
                        let shape = ConcentricRectangle(
                            corners: .concentric(minimum: 10), isUniform: true)
                        shape
                            .fill(GlassFill.highlight(colorScheme))
                            .overlay { shape.stroke(GlassFill.rim(colorScheme), lineWidth: 0.5) }
                    }
                }
                .onHover { isHovered = $0 }
        }
    }
}

/// A capsule button on the window's glass, for the actions at the bottom.
struct PillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Pill(configuration: configuration)
    }

    private struct Pill: View {
        let configuration: Configuration
        @Environment(\.colorScheme) private var colorScheme
        @State private var isHovered = false

        var body: some View {
            configuration.label
                .font(.body.weight(.medium))
                .frame(maxWidth: .infinity, minHeight: 34)
                .contentShape(.capsule)
                .background {
                    Capsule()
                        .fill(
                            isHovered || configuration.isPressed
                                ? GlassFill.highlight(colorScheme) : GlassFill.plate(colorScheme)
                        )
                        .overlay {
                            Capsule().strokeBorder(GlassFill.rim(colorScheme), lineWidth: 1)
                        }
                }
                .scaleEffect(configuration.isPressed ? 0.97 : 1)
                .animation(.snappy(duration: 0.15), value: configuration.isPressed)
                .onHover { isHovered = $0 }
        }
    }
}

/// A device glyph in a circle, lit teal while the device is playing.
struct DeviceIcon: View {
    let systemName: String
    var isActive = false
    var size = MenuMetrics.iconSize

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.44, weight: .semibold))
            .foregroundStyle(isActive ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
            .frame(width: size, height: size)
            .background {
                if isActive {
                    LensBackground(shape: Circle())
                } else {
                    WellBackground(shape: Circle())
                }
            }
            .animation(.easeInOut(duration: 0.25), value: isActive)
            .accessibilityHidden(true)
    }
}

/// A small symbol in a neutral circle, leading a menu item.
struct IconBadge: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 11, weight: .semibold))
            .frame(width: 24, height: 24)
            .background { WellBackground(shape: Circle()) }
            .accessibilityHidden(true)
    }
}

/// A disclosure chevron in a circle that turns down while open.
struct ChevronBadge: View {
    let isOpen: Bool

    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.secondary)
            .frame(width: 22, height: 22)
            .background { WellBackground(shape: Circle()) }
            .rotationEffect(.degrees(isOpen ? 90 : 0))
            .accessibilityHidden(true)
    }
}

/// A volume slider shaped like Control Center's: a recessed capsule with a white fill
/// that carries the speaker glyph.
struct VolumeCapsule: View {
    @Binding var value: Double
    let label: String
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { proxy in
            let height = proxy.size.height
            let travel = max(proxy.size.width - height, 1)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(
                        GlassFill.well(colorScheme)
                            .shadow(.inner(color: .black.opacity(0.18), radius: 2, y: 1)))

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: colorScheme == .dark
                                ? [Color(white: 0.98), Color(white: 0.86)]
                                : [.white, Color(white: 0.94)],
                            startPoint: .top, endPoint: .bottom)
                    )
                    .shadow(color: .black.opacity(0.14), radius: 4, x: 2)
                    .frame(width: height + travel * value)

                Image(systemName: "speaker.wave.3.fill", variableValue: value)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color(white: 0.25))
                    .frame(width: height)
            }
            .contentShape(.capsule)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        value = min(max((drag.location.x - height / 2) / travel, 0), 1)
                    }
            )
        }
        .frame(height: MenuMetrics.sliderHeight)
        .opacity(isEnabled ? 1 : 0.5)
        .allowsHitTesting(isEnabled)
        .accessibilityRepresentation {
            Slider(value: $value, in: 0...1) { Text(label) }
        }
    }
}

/// Sits between the two outputs and shows whether they play together.
struct SyncDivider: View {
    let isLive: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 10) {
            line
            HStack(spacing: 5) {
                Image(systemName: "waveform")
                    .symbolEffect(.variableColor.iterative.reversing, isActive: isLive)
                Text(isLive ? "In Sync" : "Not Sharing")
                    .contentTransition(.opacity)
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(
                isLive ? AnyShapeStyle(DuoColor.ink(colorScheme)) : AnyShapeStyle(.secondary)
            )
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .background(
                isLive ? DuoColor.accent.opacity(0.2) : GlassFill.well(colorScheme), in: .capsule
            )
            .fixedSize()
            line
        }
        .padding(.horizontal, MenuMetrics.rowPadding + 2)
        .padding(.bottom, 6)
        .animation(.easeInOut(duration: 0.25), value: isLive)
    }

    private var line: some View {
        Rectangle()
            .fill(.separator)
            .frame(height: 1)
    }
}
