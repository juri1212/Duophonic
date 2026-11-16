//
//  AppStoreScreenshots.swift
//  Duophonic
//
//  Created by Juri Beforth on 02.11.26.
//

// Only with the macOS 27 SDK, whose SwiftUI is version 8: the screenshots are previews with
// arguments, which older SDKs don't have. With Xcode 26, as on CI, this file is empty.
#if DEBUG && canImport(SwiftUI, _version: 8.0)
    import AppKit
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
        static let zoom: CGFloat = 1.5
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

    /// The wallpaper behind a screenshot. Each screenshot has its own, so they read as five
    /// different pictures in the App Store's gallery, all around Duophonic's teal.
    private enum Palette {
        /// Teal into lilac and peach.
        case lagoon
        /// Blue into violet, with a teal corner.
        case iris
        /// Magenta into amber, with a teal corner.
        case sunset
        /// Deep teal, for Dark Mode.
        case midnight
        /// Deep violet, for Dark Mode.
        case dusk

        var colors: [Color] {
            let values: [(Double, Double, Double)] =
                switch self {
                case .lagoon:
                    [
                        (0.05, 0.30, 0.42), (0.06, 0.46, 0.56), (0.24, 0.30, 0.62),
                        (0.04, 0.56, 0.58), (0.20, 0.80, 0.76), (0.52, 0.50, 0.86),
                        (0.60, 0.88, 0.80), (0.96, 0.80, 0.70), (0.90, 0.66, 0.78),
                    ]
                case .iris:
                    [
                        (0.07, 0.14, 0.42), (0.12, 0.26, 0.62), (0.30, 0.20, 0.62),
                        (0.08, 0.36, 0.72), (0.26, 0.50, 0.92), (0.58, 0.40, 0.88),
                        (0.24, 0.74, 0.84), (0.56, 0.68, 0.96), (0.94, 0.62, 0.82),
                    ]
                case .sunset:
                    [
                        (0.30, 0.10, 0.38), (0.56, 0.16, 0.44), (0.86, 0.32, 0.38),
                        (0.24, 0.14, 0.50), (0.78, 0.30, 0.52), (0.98, 0.56, 0.38),
                        (0.06, 0.42, 0.52), (0.52, 0.38, 0.70), (0.99, 0.76, 0.56),
                    ]
                case .midnight:
                    [
                        (0.02, 0.06, 0.14), (0.03, 0.16, 0.24), (0.08, 0.07, 0.22),
                        (0.02, 0.22, 0.26), (0.03, 0.38, 0.40), (0.16, 0.10, 0.32),
                        (0.01, 0.10, 0.14), (0.05, 0.30, 0.34), (0.10, 0.06, 0.20),
                    ]
                case .dusk:
                    [
                        (0.05, 0.04, 0.16), (0.10, 0.07, 0.26), (0.03, 0.10, 0.20),
                        (0.12, 0.08, 0.32), (0.20, 0.14, 0.46), (0.03, 0.26, 0.32),
                        (0.04, 0.05, 0.14), (0.10, 0.10, 0.30), (0.02, 0.20, 0.24),
                    ]
                }
            return values.map { Color(red: $0.0, green: $0.1, blue: $0.2) }
        }
    }

    private struct Wallpaper: View {
        let palette: Palette

        var body: some View {
            MeshGradient(
                width: 3, height: 3,
                points: [
                    [0, 0], [0.55, 0], [1, 0],
                    [0, 0.5], [0.42, 0.62], [1, 0.4],
                    [0, 1], [0.6, 1], [1, 1],
                ],
                colors: palette.colors
            )
        }
    }

    /// The app in front, whose menus fill the menu bar.
    private struct FrontApp {
        let name: String
        let menus: [String]

        static let music = FrontApp(
            name: "Music", menus: ["File", "Edit", "Song", "View", "Window", "Help"])
        static let tv = FrontApp(
            name: "TV", menus: ["File", "Edit", "View", "Controls", "Window", "Help"])
    }

    /// A macOS menu bar with Duophonic's icon, and its window hanging below the icon. Like the
    /// menu bar of macOS 26, it has no background of its own.
    private struct MenuBar<Window: View>: View {
        var app = FrontApp.music
        /// The open menu bar window.
        @ViewBuilder var window: Window

        var body: some View {
            HStack(spacing: 0) {
                HStack(spacing: 22) {
                    Image(systemName: "apple.logo")
                        .font(.system(size: 15))
                    Text(app.name).fontWeight(.bold)
                    ForEach(app.menus, id: \.self) {
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

        /// Highlighted, as it is while its window is open.
        private var statusItem: some View {
            Image("StatusBarIcon")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
                .padding(.horizontal, 9)
                .padding(.vertical, 3)
                .background(.white.opacity(0.28), in: .capsule)
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
                // A soft drop shadow, and a tight one where the window meets the desktop.
                .shadow(color: .black.opacity(0.26), radius: 34, y: 18)
                .shadow(color: .black.opacity(0.14), radius: 4, y: 2)
                .environmentObject(manager)
                .environmentObject(LaunchAtLogin())
        }
    }

    /// The app's icon, as the Dock and the App Store show it.
    private struct AppIcon: View {
        let size: CGFloat

        var body: some View {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: size, height: size)
        }
    }

    /// What accompanies a headline, so that no two screenshots look alike.
    private enum HeadlineAccessory {
        case none
        /// The app's icon and name above the headline, for the first screenshot.
        case lockup
        /// A row of device glyphs below the copy.
        case devices([String])
        /// The glyphs of two outputs below the copy, each playing the same waveform.
        case sync([String])
    }

    /// Text with tight tracking between its characters, but none after the last one of a line.
    /// Negative tracking there narrows the text's bounds, which cuts into that character: the
    /// period of a headline lost its right side.
    ///
    /// A function, not an initializer of `Text`: previews fail to compile a file in which an
    /// initializer delegates to `self.init`.
    private func trackedText(_ string: String, tracking: CGFloat) -> Text {
        var text = AttributedString()
        for line in string.split(separator: "\n", omittingEmptySubsequences: false) {
            if !text.characters.isEmpty { text += AttributedString("\n") }
            var tracked = AttributedString(String(line.dropLast()))
            tracked.tracking = tracking
            text += tracked + AttributedString(String(line.suffix(1)))
        }
        return Text(text)
    }

    /// A headline and a line of copy, in the type of Apple's own feature pages.
    private struct Headline: View {
        let title: String
        let subtitle: LocalizedStringKey
        var accessory = HeadlineAccessory.none

        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                if case .lockup = accessory {
                    HStack(spacing: 12) {
                        AppIcon(size: 60)
                        Text("Duophonic")
                            .font(.system(size: 28, weight: .semibold))
                            .tracking(-0.3)
                    }
                    // The icon has a margin of its own.
                    .padding(.leading, -6)
                    .padding(.bottom, 26)
                }

                VStack(alignment: .leading, spacing: 18) {
                    trackedText(title, tracking: -1.2)
                        .font(.system(size: 64, weight: .bold))
                        .lineSpacing(-6)
                    Text(subtitle)
                        .font(.system(size: 24, weight: .medium))
                        .lineSpacing(4)
                        .foregroundStyle(.white.opacity(0.84))
                }
                .shadow(color: .black.opacity(0.18), radius: 16, y: 4)

                switch accessory {
                case .devices(let symbols):
                    DeviceGlyphs(symbols: symbols)
                        .padding(.top, 36)
                case .sync(let symbols):
                    SyncLanes(symbols: symbols)
                        .padding(.top, 40)
                case .none, .lockup:
                    EmptyView()
                }
            }
            .foregroundStyle(.white)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// A row of glass beads, one for each kind of output.
    private struct DeviceGlyphs: View {
        let symbols: [String]

        var body: some View {
            GlassEffectContainer(spacing: 0) {
                HStack(spacing: 14) {
                    ForEach(symbols, id: \.self) { symbol in
                        Image(systemName: symbol)
                            .font(.system(size: 23, weight: .semibold))
                            .frame(width: 62, height: 62)
                            .glassEffect(.clear, in: .circle)
                    }
                }
            }
        }
    }

    /// Two outputs playing the same waveform, with one playhead across both.
    private struct SyncLanes: View {
        let symbols: [String]

        private static let barCount = 54
        private static let playedBars = 33
        private static let barWidth: CGFloat = 4
        private static let barSpacing: CGFloat = 3.5
        private static let iconSize: CGFloat = 46
        private static let iconSpacing: CGFloat = 18

        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(symbols, id: \.self) { symbol in
                    HStack(spacing: Self.iconSpacing) {
                        Image(systemName: symbol)
                            .font(.system(size: 20, weight: .semibold))
                            .frame(width: Self.iconSize, height: Self.iconSize)
                            .background { LensBackground(shape: Circle()) }
                        waveform
                    }
                }
            }
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(.white)
                    .frame(width: 2.5)
                    .padding(.vertical, -9)
                    .shadow(color: DuoColor.lens.opacity(0.9), radius: 8)
                    .offset(x: playheadOffset)
            }
        }

        private var playheadOffset: CGFloat {
            Self.iconSize + Self.iconSpacing
                + CGFloat(Self.playedBars) * (Self.barWidth + Self.barSpacing)
                - Self.barSpacing / 2 - 1.25
        }

        private var waveform: some View {
            HStack(spacing: Self.barSpacing) {
                ForEach(0..<Self.barCount, id: \.self) { bar in
                    Capsule()
                        .fill(
                            bar < Self.playedBars
                                ? AnyShapeStyle(DuoColor.lens) : AnyShapeStyle(.white.opacity(0.3))
                        )
                        .frame(width: Self.barWidth, height: Self.barHeight(bar))
                }
            }
            .frame(height: Self.iconSize)
        }

        /// A fixed shape that looks like music: slow swells with quicker beats on top.
        private static func barHeight(_ bar: Int) -> CGFloat {
            let x = Double(bar)
            let swell = 0.55 + 0.45 * sin(x * 0.21 + 0.6)
            let beat = 0.5 + 0.5 * sin(x * 1.37) * cos(x * 0.53 + 1.1)
            return 6 + 38 * swell * (0.35 + 0.65 * beat)
        }
    }

    /// A desktop with the menu bar window open under its icon and a headline beside it.
    /// The screen is zoomed into its top-right corner, so the window reads at a glance.
    private struct DesktopShot: View {
        let title: String
        let subtitle: LocalizedStringKey
        var accessory = HeadlineAccessory.none
        let palette: Palette
        var app = FrontApp.music
        let manager: AudioAggregateManager
        var expandedRole: AudioAggregateManager.Role?
        /// Less for a tall window, so it fits.
        var zoom = AppStoreShot.zoom

        var body: some View {
            ZStack(alignment: .topLeading) {
                Wallpaper(palette: palette)

                MenuBar(app: app) {
                    MenuBarWindow(manager: manager, expandedRole: expandedRole)
                }
                .frame(
                    width: AppStoreShot.size.width / zoom, height: AppStoreShot.size.height / zoom,
                    alignment: .topTrailing
                )
                .scaleEffect(zoom, anchor: .topLeading)

                Headline(title: title, subtitle: subtitle, accessory: accessory)
                    .frame(width: 560, alignment: .leading)
                    .frame(maxHeight: .infinity)
                    .padding(.leading, 88)
                    .padding(.top, AppStoreShot.menuBarHeight * zoom)
            }
            .frame(width: AppStoreShot.size.width, height: AppStoreShot.size.height)
            .clipped()
        }
    }

    /// The menu bar window up close, running off the bottom of the picture, with a headline
    /// beside it.
    private struct CloseUpShot: View {
        let title: String
        let subtitle: LocalizedStringKey
        let palette: Palette
        let manager: AudioAggregateManager
        var zoom: CGFloat = 2

        var body: some View {
            ZStack(alignment: .topLeading) {
                Wallpaper(palette: palette)

                MenuBarWindow(manager: manager)
                    .fixedSize()
                    .padding(.top, 58)
                    .padding(.trailing, 36)
                    .frame(
                        width: AppStoreShot.size.width / zoom,
                        height: AppStoreShot.size.height / zoom,
                        alignment: .topTrailing
                    )
                    .scaleEffect(zoom, anchor: .topLeading)

                Headline(title: title, subtitle: subtitle)
                    .frame(width: 460, alignment: .leading)
                    .frame(maxHeight: .infinity)
                    .padding(.leading, 88)
            }
            .frame(width: AppStoreShot.size.width, height: AppStoreShot.size.height)
            .clipped()
        }
    }

    /// One of the six feature cards on glass, for the last screenshot.
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
                accessory: .lockup,
                palette: .lagoon,
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
                accessory: .devices([
                    "airpods.pro", "beats.headphones", "hifispeaker.2.fill", "tv",
                    "cable.connector",
                ]),
                palette: .iris,
                manager: .screenshot(
                    .alexAirPods, .speakers, others: [.samAirPods, .display, .interface]),
                expandedRole: .secondary,
                zoom: 1.14
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
                accessory: .sync(["airpods.pro", "beats.headphones"]),
                palette: .midnight,
                app: .tv,
                manager: .screenshot(.alexAirPods, .beats, others: [.speakers])
            )
        }
    }

    @available(macOS 27, *)
    #Preview("4 Volume", arguments: ScreenshotTiles.all) { tile in
        ScreenshotTile(tile: tile, colorScheme: .light) {
            CloseUpShot(
                title: "Your volume.\nTheir volume.",
                subtitle: "Every listener gets a slider of their\nown, right in the menu bar.",
                palette: .sunset,
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
                Wallpaper(palette: .dusk)

                VStack(spacing: 40) {
                    VStack(spacing: 14) {
                        AppIcon(size: 84)
                            .padding(.bottom, 2)
                        trackedText("Thoughtful by design.", tracking: -1)
                            .font(.system(size: 56, weight: .bold))
                        Text(
                            "Duophonic tidies up after itself, follows your devices and stays out of your way."
                        )
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(.white.opacity(0.84))
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
            }
            .frame(width: AppStoreShot.size.width, height: AppStoreShot.size.height)
        }
    }
#endif
