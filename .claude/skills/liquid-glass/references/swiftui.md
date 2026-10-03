# Liquid Glass — SwiftUI APIs, Patterns & Gotchas

> Untagged APIs require iOS 26.0+ / macOS 26.0+ / Xcode 26 SDK. Later additions are tagged `[26.1]` or `[27.0]`. Building with the iOS 27 / macOS 27 SDKs refines glass rendering automatically — same APIs, updated look.

## Glass Effect

### `glassEffect(_:in:)`

Renders a glass shape anchored behind a view's bounds (including padding). Automatically applies vibrant text color for legibility.

```swift
nonisolated func glassEffect(
    _ glass: Glass = .regular,
    in shape: some Shape = DefaultGlassEffectShape() // Capsule
) -> some View
```

```swift
Text("Hello").padding().glassEffect()                                    // Basic
Text("Status").padding().glassEffect(in: .rect(cornerRadius: 16.0))     // Custom shape
Text("Action").padding().glassEffect(.regular.tint(.orange).interactive()) // Tinted + interactive
```

## Glass Struct

```swift
Glass.regular              // Default adaptive glass
Glass.clear                // Highly translucent (media-rich backgrounds only)
Glass.identity             // No effect — API-level opt-out for conditional code paths
                           // (design-wise there are only TWO variants: regular and clear)

// Chainable modifiers:
.tint(.blue)               // Vibrant adaptive tint (for primary actions, not decoration)
.interactive()             // Press/hover feedback: scale, bounce, shimmer (custom controls)
```

`[27.0]` Users can tint Liquid Glass system-wide via a device setting; standard and custom glass adapt automatically — include that setting in visual QA passes.

## GlassEffectContainer

Groups **multiple related glass elements**: shared rendering pass, fluid merging, morph transitions. Required when glass shapes sit near each other, morph into each other, or number more than a few — glass can't sample other glass, so co-located effects render inconsistently without a shared container. A single standalone `glassEffect()` does NOT need one.

```swift
GlassEffectContainer(spacing: 40.0) {   // init(spacing: CGFloat?, content:)
    HStack(spacing: 40.0) {
        Image(systemName: "scribble.variable")
            .frame(width: 80, height: 80)
            .glassEffect()
        Image(systemName: "eraser.fill")
            .frame(width: 80, height: 80)
            .glassEffect()
    }
}
```

- **`spacing`**: elements merge when within this distance. If container spacing > stack spacing, effects blend at rest
- One container per cluster improves performance (single sampling pass)

## Glass Morphing

### `glassEffectID(_:in:)` + `glassEffectTransition(_:)`

```swift
@State private var isExpanded = false
@Namespace private var namespace

GlassEffectContainer(spacing: 40.0) {
    HStack(spacing: 40.0) {
        Image(systemName: "scribble.variable")
            .frame(width: 80, height: 80)
            .glassEffect()
            .glassEffectID("pencil", in: namespace)
        if isExpanded {
            Image(systemName: "eraser.fill")
                .frame(width: 80, height: 80)
                .glassEffect()
                .glassEffectID("eraser", in: namespace)
        }
    }
}
Button("Toggle") { withAnimation { isExpanded.toggle() } }
    .buttonStyle(.glass)
```

**Transition types** (`GlassEffectTransition`): `.matchedGeometry` (default — smooth morph for shapes within container spacing), `.materialize` (fade + glass materialize animation for distant shapes), `.identity` (no transition changes).

To set one explicitly, use the dedicated modifier — NOT the generic `.transition(...)`:
```swift
.glassEffectTransition(.materialize)
```

Requirements: both views in same `GlassEffectContainer`, both with `.glassEffect()`, same `@Namespace`, trigger with `withAnimation`.

## Glass Union

### `glassEffectUnion(id:namespace:)`

Merges multiple glass elements into one shape at rest. Separate on interaction.

```swift
GlassEffectContainer(spacing: 20.0) {
    HStack(spacing: 20.0) {
        ForEach(symbolSet.indices, id: \.self) { item in
            Image(systemName: symbolSet[item])
                .frame(width: 80, height: 80)
                .glassEffect()
                .glassEffectUnion(id: item < 2 ? "1" : "2", namespace: namespace)
        }
    }
}
```

## Button Styles

```swift
Button("Action") { }.buttonStyle(.glass)                            // Standard glass
Button("Primary") { }.buttonStyle(.glassProminent)                   // Tinted/prominent
Button("Custom") { }.buttonStyle(.glass(.regular.tint(.indigo)))     // Configured — .glass(_:) is 26.0
```

`[26.1]` The direct type initializer `GlassButtonStyle(.regular.tint(.indigo))` arrived in 26.1; the static `.glass(_:)` form above is 26.0.

Buttons automatically morph into menus, popovers, and dialogs when they trigger presentations.

Bordered buttons default to capsule shape (`buttonBorderShape(.capsule)`); macOS mini/small/regular sizes keep rounded rects. `controlSize` gains an extra-large size for prominent actions.

## Concentric Shapes

Concentricity = inner corner radius derived from the container's radius minus padding. The shape API:

```swift
// A rectangle whose corners stay concentric with the containing shape:
ConcentricRectangle()                                   // all corners concentric to container
ConcentricRectangle(corners: .concentric(minimum: 12), isUniform: true)

// Shape shorthand (available when the shape type is ConcentricRectangle):
.background(.tint, in: .rect(corners: .concentric, isUniform: true))

// Corner style type: Edge.Corner.Style — fixed radius or concentric (with optional fallback minimum)
```

Define what "the container" means for your subtree with `containerShape(_:)`:
```swift
content
    .containerShape(.rect(cornerRadius: 20))  // concentric children now derive from this
```

Platform shape defaults: iPhone controls = capsule; iPad/Mac = concentric with window; macOS mini/small/regular controls = rounded rect, large/extraLarge = capsule. Use a **fallback/minimum radius** so shapes stay rounded when not nested.

## Background Extension

### `.backgroundExtensionEffect()`

Extends content behind system bars and sidebars. Creates a **mirrored + blurred replica** outside the safe area — nothing actually scrolls under.

```swift
// Landmarks — hero image extends behind sidebar/nav bar:
Image(landmark.backgroundImageName)
    .resizable()
    .aspectRatio(contentMode: .fill)
    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
    .backgroundExtensionEffect()
```

Text and controls must be layered above, never inside the extension.

## Scroll Edge Effects & Custom Bars

System bars get scroll edge effects automatically. Style them, hide them, or register your own bar-like views:

```swift
.scrollEdgeEffectStyle(.soft, for: .top)    // subtle progressive fade (iOS/iPadOS default feel)
.scrollEdgeEffectStyle(.hard, for: .bottom) // opaque cutoff line (macOS default feel, pinned headers)
.scrollEdgeEffectHidden(true, for: .all)    // suppress edge effects in this hierarchy
```

Default is an automatic effect — don't force `.soft` to "match the system": `[27.0]` the automatic style has its own refined appearance and no longer simply resolves to soft/hard.

**Custom floating bars**: place chrome with `safeAreaBar` so content scrolls under it and it participates in edge effects:

```swift
ScrollView { /* content */ }
    .safeAreaBar(edge: .bottom) { CustomPlaybackBar() }
// Overloads exist for VerticalEdge and HorizontalEdge
```

## Tab Bar

```swift
TabView { /* tabs */ }
    .tabBarMinimizeBehavior(.onScrollDown)   // members: .automatic, .never, .onScrollDown, .onScrollUp
    .tabViewBottomAccessory { NowPlayingView() }
```

- Minimizing applies to iPhone tab bars only; the bar re-expands on reverse scroll
- Read `tabViewBottomAccessoryPlacement` from the environment to compact the accessory when it collapses inline
- Search tab: `Tab(role: .search)` — trailing separated tab; the search field replaces the tab bar on selection
- `[27.0]` `Tab(role: .prominent)` — visually emphasized tab (e.g. a Cart tab)
- Tab-to-sidebar adaptation: `.tabViewStyle(.sidebarAdaptable)`

## Toolbars

```swift
.toolbar {
    ToolbarItem { ShareLink(item: landmark, preview: landmark.sharePreview) }
    ToolbarSpacer(.fixed)                      // splits shared glass into separate groups
    ToolbarItemGroup {
        LandmarkFavoriteButton(landmark: landmark)
        LandmarkCollectionsMenu(landmark: landmark)
    }
    ToolbarSpacer(.flexible)
    ToolbarItem { Button("Info", systemImage: "info") { } }
}

// Remove glass background from one item:
ToolbarItem { AvatarView() }.sharedBackgroundVisibility(.hidden)

// Badge on a toolbar button:
Button("Notifications", systemImage: "bell") { }.badge(3)

// Hide the ITEM, not the view inside it (an empty glass pill renders otherwise).
// macOS only: ToolbarContent.hidden(_:)
ToolbarItem { FilterButton() }.hidden(!isFilterAvailable)
// iOS/iPadOS: conditionally emit the item in the toolbar builder:
if isFilterAvailable { ToolbarItem { FilterButton() } }
```

Toolbar icons are monochrome by default; `.tint(_:)` only where color carries meaning (primary action), never decoration.

### Toolbar space management (split availability)

Overflow is automatic when space runs out. Availability differs by platform:
- `visibilityPriority(_ priority: ToolbarItemVisibilityPriority)` — **iOS/iPadOS 27, macOS 26.1** (watchOS/tvOS/visionOS 27 accept only `.automatic`; `.low`/`.high` are iOS+macOS)
- `ToolbarOverflowMenu` / `toolbarOverflowMenu(content:)` / `.topBarPinnedTrailing` — **iOS/iPadOS/visionOS 27; not available on macOS** (macOS keeps system-managed overflow)

```swift
.toolbar {
    ToolbarItemGroup { UndoButton(); RedoButton() }
        .visibilityPriority(.high)
    ToolbarOverflowMenu {                      // explicit overflow destination [27.0, iOS family]
        ChoosePhotoButton(); ExportButton(); ClearAllButton()
    }
    ToolbarItem(placement: .topBarPinnedTrailing) { ShareButton() }
    // pinned = stays visible normally, but can still overflow while search is active and space is tight
}
```

Don't hand-roll overflow menus — the system adds one on macOS/iPadOS when items no longer fit.

### `[27.0]` Navigation bar minimization

Documented for the 27 SDKs but absent from Xcode 27 beta 3's interfaces (arrives in a later beta) — verify against your toolchain before relying on it:

```swift
NavigationStack {
    ScrollView { /* ... */ }
        .toolbarMinimizeBehavior(.onScrollDown, for: .navigationBar)
        // companion: .toolbarMinimizationSafeAreaAdjustment(_:for:)
}
```

`ToolbarMinimizeBehavior`: `.automatic` / `.never` / `.onScrollDown` / `.onScrollUp`. The modifier exists on all platforms at 27, but `.onScrollDown`/`.onScrollUp`/`.never` (and the safe-area `.enabled`/`.disabled`) are iOS-only — other platforms take `.automatic` only. With `.automatic`, iOS minimizes navigation bars when a `searchable` uses the `.toolbarPrincipal` placement.

## Search

```swift
NavigationSplitView { /* ... */ }
    .searchable(text: $query)     // whole-view: bottom-aligned on iPhone, top-trailing iPad/Mac — automatic
```

- `searchToolbarBehavior(.minimize)` — search collapses to a toolbar button until tapped (**iOS/iPadOS/Catalyst/visionOS**; `.minimize` is unavailable on native macOS, where the toolbar field collapses automatically under space pressure)
- Search tab pattern: `Tab(role: .search)` + `.searchable` on the `TabView`
- The field rides up with the keyboard on iPhone; don't fight the placement conventions

## Sheets & Presentations

Partial-height sheets are inset with a glass background by default; full-height transitions to opaque and anchors to the display edge. **Remove custom `presentationBackground`** — it blocks the system material.

Zoom morph from a toolbar button (`ToolbarContent.matchedTransitionSource` is 26.0; the plain `View` overload predates it — iOS 18):
```swift
.toolbar {
    ToolbarItem { Button("Details") { showSheet = true } }
        .matchedTransitionSource(id: "details", in: namespace)
}
.sheet(isPresented: $showSheet) {
    DetailView().navigationTransition(.zoom(sourceID: "details", in: namespace))
}
```

Confirmation dialogs anchor to their source control (set the source; no more bottom-anchored sheets by default).

## Sliders & Controls

```swift
Slider(value: $speed, in: 0...100, step: 10)         // automatic tick marks with `step:`
Slider(value: $level, in: 0...1) { /* label */ }
    // manual ticks closure + neutralValue: for bidirectional fill anchor
```

Toggles, segmented pickers, and slider knobs transform into Liquid Glass during interaction — automatic for standard controls.

---

## Code Pattern: Landmarks BadgesView

Real Landmarks sample — combines Container + morphing + platform conditionals:

```swift
struct BadgesView: View {
    @Namespace private var namespace
    @State private var isExpanded = false
    @Environment(ModelData.self) var modelData

    var body: some View {
        GlassEffectContainer(spacing: Constants.badgeGlassSpacing) {
            VStack(alignment: .center, spacing: Constants.badgeButtonTopSpacing) {
                if isExpanded {
                    VStack(spacing: Constants.badgeSpacing) {
                        ForEach(modelData.earnedBadges) { badge in
                            BadgeLabel(badge: badge)
                                .glassEffect(.regular, in: .rect(cornerRadius: Constants.badgeCornerRadius))
                                .glassEffectID(badge.id, in: namespace)
                        }
                    }
                }
                Button {
                    withAnimation { isExpanded.toggle() }
                } label: {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                }
                .buttonStyle(.glass)
                #if os(macOS)
                .tint(.clear)
                #endif
                .glassEffectID("togglebutton", in: namespace)
            }
            .frame(width: Constants.badgeFrameWidth)
        }
    }
}
```

## What changed in the iOS 27 / macOS 27 SDKs

- Rebuilding refreshes glass rendering (lensing, tint response) — zero code changes
- Users can tint glass system-wide (device setting) — test both tinted and untinted
- Toolbars: automatic overflow + `visibilityPriority` / `ToolbarOverflowMenu` / `.topBarPinnedTrailing`
- Navigation bar minimize: `toolbarMinimizeBehavior(_:for:)`
- `Tab(role: .prominent)`
- iPad/Mac menus default to minimal icons; opt items back in with `.labelStyle(.titleAndIcon)`
- Custom interactive glass on macOS responds to mouse input appropriately (automatic behavior)
- Window activation observable via `\.appearsActive` (pre-existing API; glass visually recedes on inactive windows)

---

## Gotchas

1. **Apply `glassEffect` AFTER appearance modifiers** — glass captures content at the point it's applied. `.font()` and **inner padding** (the space the glass shape should cover) go before `.glassEffect()`.
2. **Outer margins go OUTSIDE the glass scope** — to space a glass element from its surroundings, wrap in `background`/`overlay` and pad outside the glass modifier. Never nest glass modifiers: parent+child glass = double translucency and unpredictable rendering (CNN's adoption lesson). Apply glass once, at the highest level that needs it.
3. **Container spacing > layout spacing = blend at rest** — match `GlassEffectContainer(spacing:)` to your stack spacing intentionally.
4. **Remove custom `presentationBackground`** and **custom toolbar backgrounds** — they block glass and scroll edge effects.
5. **`GlassEffectContainer` must wrap both source and destination** for morph transitions.
6. **`Glass.identity` is a runtime opt-out on 26+, NOT a back-deployment tool** — `Glass` itself requires OS 26. Use it to toggle glass off while preserving view topology (and `.identity.interactive()` for glass that materializes only during interaction — Tide Guide's chart pattern). For mixed deployment targets, use the `#available` wrapper in migration.md.
7. **Use `.glassEffectTransition(_:)`, not `.transition(_:)`,** for glass add/remove animation control.
8. **Hide the toolbar ITEM, never just its inner view** (an empty glass pill remains): macOS via `ToolbarContent.hidden(_:)`; iOS/iPadOS by conditionally emitting the item in the builder.
9. **Glass is GPU-intensive in scrollable/high-frequency contexts** — reserve custom glass for static chrome; profile with Instruments (SwiftUI performance instrument).
