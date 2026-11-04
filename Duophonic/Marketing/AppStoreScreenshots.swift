//
//  AppStoreScreenshots.swift
//  Duophonic
//
//  Created by Juri Beforth on 02.11.26.
//

#if DEBUG
    import SwiftUI

    // The Mac App Store screenshots, staged from the real menu bar window: each preview is one
    // screenshot of `AppStoreShot.size` points, which a 2x display renders at the 2560 × 1600
    // pixels the App Store asks for. The window's Liquid Glass samples the staged wallpaper, so
    // what you see is what the app looks like on a desktop. `appstore/README.md` explains how
    // to export them.

    enum AppStoreShot {
        static let size = CGSize(width: 1280, height: 800)
        /// The menu bar's height on a Mac without a notch.
        static let menuBarHeight: CGFloat = 26
        /// How far the screen is zoomed in, in the screenshots of the menu bar window.
        static let zoom: CGFloat = 1.3
    }

    // MARK: - Sample devices

    extension AudioDevice {
        fileprivate static let alexAirPods = AudioDevice(
            uid: "alex", name: "Alex’s AirPods Pro", category: .bluetooth, volume: 0.62)
        fileprivate static let samAirPods = AudioDevice(
            uid: "sam", name: "Sam’s AirPods Max", category: .bluetooth, volume: 0.48)
        fileprivate static let speakers = AudioDevice(
            uid: "builtin", name: "MacBook Pro Speakers", category: .builtin, volume: 0.7)
        fileprivate static let beats = AudioDevice(
            uid: "beats", name: "Beats Studio Pro", category: .bluetooth, volume: 0.5)
        fileprivate static let display = AudioDevice(
            uid: "display", name: "Studio Display", category: .display, volume: 0.4)
        fileprivate static let interface = AudioDevice(
            uid: "usb", name: "Scarlett 2i2 USB", category: .usb, volume: nil)
    }

    extension AudioAggregateManager {
        /// A manager playing to `primary` and `secondary`, with `others` in the device list.
        fileprivate static func screenshot(
            _ primary: AudioDevice, _ secondary: AudioDevice, others: [AudioDevice] = [],
            sharing: Bool = true
        ) -> AudioAggregateManager {
            let suite = "DuophonicScreenshots"
            UserDefaults().removePersistentDomain(forName: suite)
            let hardware = InMemoryAudioHardware(devices: [primary, secondary] + others)
            let manager = AudioAggregateManager(
                hardware: hardware, defaults: UserDefaults(suiteName: suite)!)
            manager.refreshDevices()
            manager.select(primary.uid, for: .primary)
            manager.select(secondary.uid, for: .secondary)
            manager.setEnabled(sharing)
            return manager
        }
    }

    // MARK: - Staging

    /// A Duophonic-teal wallpaper, deeper in Dark Mode, like the system's own.
    private struct Wallpaper: View {
        @Environment(\.colorScheme) private var colorScheme

        var body: some View {
            let dark = colorScheme == .dark
            MeshGradient(
                width: 3, height: 3,
                points: [
                    [0, 0], [0.55, 0], [1, 0],
                    [0, 0.5], [0.42, 0.62], [1, 0.4],
                    [0, 1], [0.6, 1], [1, 1],
                ],
                colors: dark
                    ? [
                        Color(red: 0.02, green: 0.06, blue: 0.14),
                        Color(red: 0.03, green: 0.16, blue: 0.24),
                        Color(red: 0.08, green: 0.07, blue: 0.22),
                        Color(red: 0.02, green: 0.22, blue: 0.26),
                        Color(red: 0.03, green: 0.38, blue: 0.40),
                        Color(red: 0.16, green: 0.10, blue: 0.32),
                        Color(red: 0.01, green: 0.10, blue: 0.14),
                        Color(red: 0.05, green: 0.30, blue: 0.34),
                        Color(red: 0.10, green: 0.06, blue: 0.20),
                    ]
                    : [
                        Color(red: 0.05, green: 0.30, blue: 0.42),
                        Color(red: 0.06, green: 0.46, blue: 0.56),
                        Color(red: 0.24, green: 0.30, blue: 0.62),
                        Color(red: 0.04, green: 0.56, blue: 0.58),
                        Color(red: 0.20, green: 0.80, blue: 0.76),
                        Color(red: 0.52, green: 0.50, blue: 0.86),
                        Color(red: 0.60, green: 0.88, blue: 0.80),
                        Color(red: 0.96, green: 0.80, blue: 0.70),
                        Color(red: 0.90, green: 0.66, blue: 0.78),
                    ]
            )
        }
    }

    /// A macOS menu bar with Duophonic's icon, and its window hanging below the icon. Like the
    /// menu bar of macOS 26, it has no background of its own.
    private struct MenuBar<Window: View>: View {
        var appName = "Music"
        /// Whether the window is open, which highlights the icon.
        var isWindowOpen = true
        /// The open menu bar window.
        @ViewBuilder var window: Window

        var body: some View {
            HStack(spacing: 0) {
                HStack(spacing: 22) {
                    Image(systemName: "apple.logo")
                        .font(.system(size: 15))
                    Text(appName).fontWeight(.bold)
                    ForEach(
                        ["File", "Edit", "Song", "View", "Controls", "Window", "Help"], id: \.self
                    ) {
                        Text($0)
                    }
                }
                Spacer()
                HStack(spacing: 18) {
                    Image(systemName: "battery.75percent")
                    Image(systemName: "wifi")
                    statusItem
                    Image(systemName: "switch.2")
                    Image(systemName: "magnifyingglass")
                    Text("Mon 2 Nov  9:41")
                }
            }
            .font(.system(size: 13.5, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .frame(height: AppStoreShot.menuBarHeight)
            // Outside the menu bar's styling, so the window keeps its own fonts and colors.
            .overlayPreferenceValue(StatusItemBounds.self) { anchor in
                if let anchor {
                    GeometryReader { proxy in
                        let icon = proxy[anchor]
                        // Centered on the icon, just below the menu bar, as macOS places it.
                        window
                            .fixedSize()
                            .alignmentGuide(.leading) { $0.width / 2 }
                            .frame(
                                width: proxy.size.width, height: proxy.size.height,
                                alignment: .topLeading
                            )
                            .offset(x: icon.midX, y: AppStoreShot.menuBarHeight + 5)
                    }
                }
            }
        }

        private var statusItem: some View {
            Image("StatusBarIcon")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
                .padding(.horizontal, 9)
                .padding(.vertical, 3)
                .background(.white.opacity(isWindowOpen ? 0.28 : 0), in: .capsule)
                .anchorPreference(key: StatusItemBounds.self, value: .bounds) { $0 }
        }
    }

    private struct StatusItemBounds: PreferenceKey {
        static let defaultValue: Anchor<CGRect>? = nil
        static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
            value = value ?? nextValue()
        }
    }

    /// The menu bar window as macOS draws it: the app's content on Liquid Glass.
    private struct MenuBarWindow: View {
        let manager: AudioAggregateManager
        var expandedRole: AudioAggregateManager.Role?

        var body: some View {
            ContentView(expandedRole: expandedRole)
                .frame(width: MenuMetrics.windowWidth)
                .glassEffect(.regular, in: .rect(cornerRadius: 24))
                .shadow(color: .black.opacity(0.28), radius: 30, y: 16)
                .environmentObject(manager)
                .environmentObject(LaunchAtLogin())
        }
    }

    /// A headline and a line of copy, in the type of Apple's own feature pages.
    private struct Headline: View {
        let title: LocalizedStringKey
        let subtitle: LocalizedStringKey

        var body: some View {
            VStack(alignment: .leading, spacing: 18) {
                Text(title)
                    .font(.system(size: 64, weight: .bold))
                    .tracking(-1.2)
                    .lineSpacing(-6)
                Text(subtitle)
                    .font(.system(size: 24, weight: .medium))
                    .lineSpacing(4)
                    .foregroundStyle(.white.opacity(0.82))
            }
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.18), radius: 16, y: 4)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// A desktop with the menu bar window open under its icon and a headline beside it.
    /// The screen is zoomed into its top-right corner, so the window reads at a glance.
    private struct DesktopShot: View {
        let title: LocalizedStringKey
        let subtitle: LocalizedStringKey
        let manager: AudioAggregateManager
        var expandedRole: AudioAggregateManager.Role?
        /// Less for a tall window, so it fits.
        var zoom = AppStoreShot.zoom

        var body: some View {
            ZStack(alignment: .topLeading) {
                Wallpaper()

                MenuBar {
                    MenuBarWindow(manager: manager, expandedRole: expandedRole)
                }
                .frame(
                    width: AppStoreShot.size.width / zoom, height: AppStoreShot.size.height / zoom,
                    alignment: .topTrailing
                )
                .scaleEffect(zoom, anchor: .topLeading)

                Headline(title: title, subtitle: subtitle)
                    .frame(width: 560, alignment: .leading)
                    .frame(maxHeight: .infinity)
                    .padding(.leading, 88)
                    .padding(.top, AppStoreShot.menuBarHeight * zoom)
            }
            .frame(width: AppStoreShot.size.width, height: AppStoreShot.size.height)
        }
    }

    /// A grid of six feature cards on glass, for the last screenshot.
    private struct FeatureCard: View {
        let symbol: String
        let title: LocalizedStringKey
        let text: LocalizedStringKey

        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background { LensBackground(shape: Circle()) }
                    .padding(.bottom, 18)
                Text(title)
                    .font(.system(size: 21, weight: .semibold))
                    .padding(.bottom, 6)
                Text(text)
                    .font(.system(size: 15.5))
                    .lineSpacing(2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(26)
            .frame(width: 336, height: 196, alignment: .topLeading)
            .glassEffect(.regular, in: .rect(cornerRadius: 30))
        }
    }

    // MARK: - Tiles

    /// The preview canvas renders at most about 1500 × 975 pixels, so only a part of a
    /// screenshot fits at full resolution. Each screenshot preview takes a tile of the grid as
    /// its argument, with a bleed of its neighbors around it, so the corners of the preview
    /// window and the edges of the glass's blur can be cropped away before stitching.
    /// `ScreenshotTiles.whole` renders the whole screenshot, scaled to fit, to look at in Xcode.
    enum ScreenshotTiles {
        static let columns = 4
        static let rows = 4
        /// Wide enough for the blur and refraction of the zoomed glass: with less, the glass
        /// looks different on either side of a seam.
        static let bleed: CGFloat = 128
        static let whole = -1
        static let all = [whole] + Array(0..<(columns * rows))

        static var tileSize: CGSize {
            CGSize(
                width: AppStoreShot.size.width / CGFloat(columns),
                height: AppStoreShot.size.height / CGFloat(rows))
        }
    }

    private struct ScreenshotTile<Content: View>: View {
        let tile: Int
        let colorScheme: ColorScheme
        @ViewBuilder let content: Content

        var body: some View {
            Group {
                if tile == ScreenshotTiles.whole {
                    content
                } else {
                    let size = ScreenshotTiles.tileSize
                    let bleed = ScreenshotTiles.bleed
                    content
                        .offset(
                            x: bleed - CGFloat(tile % ScreenshotTiles.columns) * size.width,
                            y: bleed - CGFloat(tile / ScreenshotTiles.columns) * size.height
                        )
                        .frame(
                            width: size.width + 2 * bleed, height: size.height + 2 * bleed,
                            alignment: .topLeading
                        )
                        .clipped()
                }
            }
            .preferredColorScheme(colorScheme)
        }
    }

    // MARK: - Screenshots
    //
    // Keep these in order and at the top level: the export script renders the Nth preview in
    // this file as screenshot N.

    @available(macOS 27, *)
    #Preview("1 Two Listeners", arguments: ScreenshotTiles.all) { tile in
        ScreenshotTile(tile: tile, colorScheme: .light) {
            DesktopShot(
                title: "Two listeners.\nOne Mac.",
                subtitle: "Play your Mac’s sound on two pairs\nof headphones at once.",
                manager: .screenshot(.alexAirPods, .samAirPods, others: [.speakers])
            )
        }
    }

    @available(macOS 27, *)
    #Preview("2 Any Two Outputs", arguments: ScreenshotTiles.all) { tile in
        ScreenshotTile(tile: tile, colorScheme: .light) {
            DesktopShot(
                title: "Any two outputs.",
                subtitle:
                    "Headphones, speakers, displays or USB.\nMix and match, and switch without\nstopping the music.",
                manager: .screenshot(
                    .alexAirPods, .speakers, others: [.samAirPods, .display, .interface]),
                expandedRole: .secondary,
                zoom: 1.08
            )
        }
    }

    @available(macOS 27, *)
    #Preview("3 In Sync", arguments: ScreenshotTiles.all) { tile in
        ScreenshotTile(tile: tile, colorScheme: .dark) {
            DesktopShot(
                title: "Stays in sync.",
                subtitle:
                    "Drift correction keeps both outputs\ntogether, even through a two‑hour movie.",
                manager: .screenshot(.alexAirPods, .beats, others: [.speakers])
            )
        }
    }

    @available(macOS 27, *)
    #Preview("4 Volume", arguments: ScreenshotTiles.all) { tile in
        ScreenshotTile(tile: tile, colorScheme: .light) {
            DesktopShot(
                title: "Your volume.\nTheir volume.",
                subtitle: "Every listener gets a slider of their\nown, right in the menu bar.",
                manager: .screenshot(
                    AudioDevice(
                        uid: "alex", name: "Alex’s AirPods Pro", category: .bluetooth,
                        volume: 0.82),
                    AudioDevice(
                        uid: "sam", name: "Sam’s AirPods Max", category: .bluetooth,
                        volume: 0.3),
                    others: [.speakers])
            )
        }
    }

    @available(macOS 27, *)
    #Preview("5 Thoughtful", arguments: ScreenshotTiles.all) { tile in
        ScreenshotTile(tile: tile, colorScheme: .dark) {
            FeaturesShot()
        }
    }

    /// Six things Duophonic takes care of, around a headline.
    private struct FeaturesShot: View {
        var body: some View {
            ZStack(alignment: .top) {
                Wallpaper()
                MenuBar(isWindowOpen: false) { EmptyView() }

                VStack(spacing: 44) {
                    VStack(spacing: 14) {
                        Text("Thoughtful by design.")
                            .font(.system(size: 56, weight: .bold))
                            .tracking(-1)
                        Text(
                            "Duophonic tidies up after itself, follows your devices and stays out of your way."
                        )
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(.white.opacity(0.82))
                    }
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .shadow(color: .black.opacity(0.18), radius: 16, y: 4)

                    GlassEffectContainer {
                        Grid(horizontalSpacing: 22, verticalSpacing: 22) {
                            GridRow {
                                FeatureCard(
                                    symbol: "arrow.uturn.backward",
                                    title: "Puts things back",
                                    text:
                                        "Stop sharing and your previous outputs return, for sound and alerts alike."
                                )
                                FeatureCard(
                                    symbol: "arrow.left.arrow.right",
                                    title: "Switch while playing",
                                    text: "Change either output on the fly. The music keeps going.")
                                FeatureCard(
                                    symbol: "dot.radiowaves.left.and.right",
                                    title: "Follows your devices",
                                    text: "Headphones that reconnect rejoin playback automatically."
                                )
                            }
                            GridRow {
                                FeatureCard(
                                    symbol: "clock.arrow.circlepath",
                                    title: "Remembers your pair",
                                    text:
                                        "Your two outputs are ready next time, and at login if you like."
                                )
                                FeatureCard(
                                    symbol: "menubar.rectangle",
                                    title: "Lives in the menu bar",
                                    text:
                                        "Liquid Glass design that feels like part of macOS. No Dock icon."
                                )
                                FeatureCard(
                                    symbol: "hand.raised.fill",
                                    title: "Private by design",
                                    text:
                                        "No accounts, no tracking, no network. Nothing leaves your Mac."
                                )
                            }
                        }
                    }
                }
                .frame(maxHeight: .infinity)
                .padding(.top, AppStoreShot.menuBarHeight)
            }
            .frame(width: AppStoreShot.size.width, height: AppStoreShot.size.height)
        }
    }
#endif
