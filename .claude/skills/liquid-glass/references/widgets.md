# Liquid Glass — Widgets

> Widgets render through glass whenever the user personalizes the Home Screen (tinted/clear modes on iOS, macOS Tahoe desktop + Notification Center) — even if the widget itself never asks for it. Source sessions: WWDC25 278, WWDC26 277.
>
> Availability note: the symbols predate the glass era — `widgetRenderingMode` is iOS 16+/macOS 13+/watchOS 9+, `widgetAccentedRenderingMode` is iOS 18+/macOS 15+/watchOS 11+. What the 26 releases add is the tinted/clear-glass Home Screen pipeline that makes them load-bearing.

## The accented rendering pipeline

Under tinted or clear customization the system: renders the widget in **accented mode** (content tinted, typically white) → strips the `containerBackground` view → substitutes adaptive glass (or the theme color). Simple text widgets survive automatically; layered/opaque/gradient content becomes illegible unless you branch:

```swift
@Environment(\.widgetRenderingMode) var renderingMode   // .fullColor | .accented

ZStack {
    if renderingMode == .fullColor {
        Image(entry.beverageImage).resizable().aspectRatio(contentMode: .fill)
        LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .top, endPoint: .bottom)
    }
    VStack {
        if renderingMode == .accented {
            Image(entry.beverageImage)
                .resizable()
                .widgetAccentedRenderingMode(.desaturated)
                .aspectRatio(contentMode: .fill)
        }
        BeverageTextView()
    }
}
```

## `widgetAccentedRenderingMode(_:)` on Image

| Mode | Effect |
|---|---|
| `nil` (default) | Tinted like primary content |
| `.accented` | Tint with the accent color (white on iOS/macOS; watch-face accent on watchOS) |
| `.desaturated` | Grayscale, consistent across platforms — **default choice for most imagery** |
| `.accentedDesaturated` | Both combined |
| `.fullColor` | Original colors — reserve for media art (album covers, book covers). **Silently ignored on watchOS** |

Bitmap gotcha: photos/cover art can render as a blank white rectangle in accented/clear mode (the system can't auto-accent arbitrary bitmaps) — set `.fullColor` (or `.desaturated`) explicitly.

## `containerBackground` is the swap point

Mark the background with `containerBackground` — that's the view the system replaces with glass under tinted/clear modes. Content outside it survives; content baked into the background disappears with it.

## Test matrix

Verify every widget in **full color + tinted + clear** modes (Xcode Previews canvas covers families, color schemes, and rendering modes; WidgetKit developer mode lifts reload budgets while iterating).

## visionOS

```swift
StaticConfiguration(kind: "BaristaWidget", provider: Provider()) { entry in
    CaffeineTrackerWidgetView(entry: entry)
}
.supportedMountingStyles([.elevated])       // .elevated (on surface, default) | .recessed
.widgetTexture(.paper)                      // .glass (default) | .paper (poster look)
.supportedFamilies([.systemExtraLargePortrait])
```

- `@Environment(\.levelOfDetail)` — `.default` / `.simplified` when viewed from a distance; changes animate like timeline updates
- Existing iPhone/iPad widgets appear on visionOS automatically; color themes apply the same accented pipeline
- `[27.0]` `systemExtraLargePortrait` expands from visionOS to iOS/iPadOS/macOS

## CarPlay

Zero adoption code: the system renders widgets StandBy-style — `systemSmall`, full color, background removed. Touchscreen-interactive; verify in the CarPlay simulator.

## Gotchas

1. Accented mode tints ALL content — opaque becomes solid white, partial transparency becomes white at that opacity. Branch on `widgetRenderingMode` or lose legibility
2. `.fullColor` accented-rendering mode does nothing on watchOS — plan watch imagery as desaturated
3. Don't fight the background swap — put must-survive content in the foreground, not the container background
