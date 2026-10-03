# Liquid Glass — AppKit APIs, Patterns & Gotchas

> Untagged APIs require macOS 26.0+ (Tahoe) / Xcode 26 SDK. Later additions are tagged `[27.0]`. Note: many macOS 27 visual refinements are runtime-delivered — an app that adopted glass on macOS 26 picks them up on macOS 27 without rebuilding.

## NSGlassEffectView

```swift
let glass = NSGlassEffectView()
glass.contentView = myContentView  // MUST use contentView — ensures legibility
glass.cornerRadius = 12
glass.tintColor = .controlAccentColor
glass.style = .clear               // NSGlassEffectView.Style: .regular (default) | .clear
```

Always set content via `contentView`. Don't place glass as a sibling behind content.

`[27.0]` **Interactive response** (the click "bounce" shown in Maps):

```swift
glass.effectIsInteractive = true   // default false
```

Enable ONLY for glass that backs interactive controls or containers of interactive controls — not general surfaces. A little goes a long way.

## NSGlassEffectContainerView

Groups **multiple related glass elements**: shared rendering, fluid merging, visual correctness, performance (single sampling pass). A lone glass view doesn't need one.

```swift
let userInfoGlass = NSGlassEffectView()
userInfoGlass.contentView = userInfoView
userInfoGlass.cornerRadius = 999          // capsule-ish

let pickerGlass = NSGlassEffectView()
pickerGlass.contentView = activityPickerView
pickerGlass.cornerRadius = 999

let stack = NSStackView(views: [userInfoGlass, pickerGlass])
let container = NSGlassEffectContainerView()
container.contentView = stack
container.spacing = 10                    // merge distance
```

## NSBackgroundExtensionView

Extends content behind window chrome and sidebars. System creates the mirrored + blurred replica automatically.

```swift
let ext = NSBackgroundExtensionView()
ext.contentView = posterImageView  // Positioned in safe area; replica fills outside
view.addSubview(ext)
```

## Window Corners & Layout Regions

**Window corner radius**: windows with toolbars use a larger radius (concentric with glass toolbar elements); titlebar-only windows use a smaller one. Larger corners can **clip content** near edges.

### `NSView.LayoutRegion` — corner-aware layout guides

`layoutGuide(for:)` is an instance method on the view being constrained:

```swift
let safeArea = myView.layoutGuide(for: .safeArea(cornerAdaptation: .horizontal))

NSLayoutConstraint.activate([
    safeArea.leadingAnchor.constraint(equalTo: button.leadingAnchor),
    safeArea.trailingAnchor.constraint(greaterThanOrEqualTo: button.trailingAnchor),
    safeArea.bottomAnchor.constraint(equalTo: button.bottomAnchor),
])
```

### `[27.0]` Concentric view corners

```swift
class WeatherTile: NSView {
    override var cornerConfiguration: NSViewCornerConfiguration? {
        .uniformCorners(radius: .containerConcentric(12))  // argument = your minimum radius
    }
}
```

`NSViewCornerRadius.containerConcentric(_:)` takes a minimum radius — the effective radius scales up as the view approaches its container's corner; the floor keeps corners rounded when standalone. Applies concentricity to custom views/buttons near window or container corners.

## Split View & Sidebars

Use `NSSplitViewController` — AppKit provides glass automatically:
- **Sidebar**: floating glass above content
- **Inspector**: edge-to-edge glass alongside content

```swift
// Extend content under sidebar — set on CONTENT item, not sidebar:
contentSplitItem.automaticallyAdjustsSafeAreaInsets = true
```

**Remove legacy `NSVisualEffectView`** from sidebars — it blocks the new glass.

`[27.0]` Runtime refinements (no rebuild needed): sidebars extend to window edges, selection uses semibold text, bordered toolbar items over the sidebar adopt glass.

Sidebar icons default to the app accent color — pick per-icon colors only when they carry meaning (HIG, June 2026).

### Split View Accessories

```swift
splitViewItem.addTopAlignedAccessoryViewController(accessory)
// Or: addBottomAlignedAccessoryViewController
```

Per-split-item, influences scroll edge effect size, insets content safe area.

## Scroll Edge Effects

Lives inside `NSScrollView`. Styles: **automatic** (default), **soft** (progressive fade), **hard** (opaque backing + dividing line). Applied automatically under toolbar items, titlebar accessories, and split item accessories; adapts as floating elements come and go.

`[27.0]` `.automatic` resolves to a hard-edge effect when free-floating text is present (e.g. window titles in the title bar). Prefer automatic; only force soft/hard with a specific reason (HIG, June 2026).

## Toolbars

Items auto-group on glass backgrounds by control type.

```swift
// Remove glass from non-interactive items (status text, titles):
statusItem.isBordered = false

// Prominent style + custom tint:
item.style = .prominent
item.backgroundTintColor = .systemGreen

// Badge — static factories:
item.badge = .count(4)        // also .text("New"), .indicator

// Hide an item (not its view):
item.isHidden = true
```

Toolbar glass switches light/dark based on scrolled content brightness (via `NSAppearance`).

## Controls & Buttons

Sizes: `.mini`, `.small`, `.regular`, `.large`, `.extraLarge` (new). All slightly taller than previous macOS.

```swift
button.bezelStyle = .glass           // Glass material (NSButton only)
button.bezelColor = .systemBlue      // Tint the glass
button.borderShape = .capsule        // or .roundedRectangle

// Compact metrics for existing dense layouts (inherited down hierarchy):
view.prefersCompactControlSizeMetrics = true
```

macOS shape defaults: mini/small/regular = rounded rectangle, large/extraLarge = capsule.

## Tint Prominence

`tintProminence` is a property of `NSButton` and `NSSlider` (not every NSView):

```swift
shuffleButton.tintProminence = .secondary  // subdued
playButton.keyEquivalent = "\r"            // default button — auto-gets .primary
slider.tintProminence = .none              // no track fill; .secondary/.primary = filled
slider.neutralValue = 0.5                  // bidirectional fill anchor
```

Values: `.automatic`, `.none`, `.secondary`, `.primary`.

---

## What changed in macOS 27

- Runtime-delivered visual refinements for glass adopters (sidebars, scroll edges, menu glass) — no rebuild required
- `NSViewCornerConfiguration` / `cornerConfiguration` — concentric corners for custom views
- `NSGlassEffectView.effectIsInteractive` — click response for interactive glass
- Make view and button corners concentric — the "Modernize your AppKit app" theme

---

## Gotchas

1. **Remove `NSVisualEffectView` from sidebars** — blocks the new glass from showing through.
2. **Set `contentView`, don't add glass as a sibling** — glass must manage its content for legibility.
3. **`isBordered = false` for non-interactive toolbar items** — status text/labels shouldn't look like buttons.
4. **`automaticallyAdjustsSafeAreaInsets` on CONTENT, not sidebar** — extends content beneath the floating sidebar.
5. **Use Auto Layout** — controls are taller in macOS 26+. `prefersCompactControlSizeMetrics` is a compatibility bridge, not a fix.
6. **Window corners clip content** — use `layoutGuide(for: .safeArea(cornerAdaptation:))` for edge-positioned content.
7. **Glass bezel only on `NSButton`** — don't apply to other control types.
8. **`effectIsInteractive` is for controls**, not decorative surfaces — overuse cheapens the effect.
9. **`#available` guard:**
```swift
if #available(macOS 26, *) {
    let glass = NSGlassEffectView()
    glass.contentView = myView
}
```
