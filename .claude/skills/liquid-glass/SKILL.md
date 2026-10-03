---
name: liquid-glass
description: "Apple Liquid Glass for iOS 26/27 and macOS 26 (Tahoe)/27. Use for SwiftUI/UIKit/AppKit glass APIs: glassEffect, GlassEffectContainer, glassEffectID, UIGlassEffect, NSGlassEffectView, effectIsInteractive. Covers glass button styles, transitions, unions, background extension, scroll edge effects, tab bar and navigation bar minimization, toolbar overflow, concentric corners, search placement, hierarchy, tinting, rendering, and performance. Also covers design migration, UIDesignRequiresCompatibility, tinted/clear widgets (widgetRenderingMode, widgetAccentedRenderingMode), and Icon Composer .icon app icons. Not for SwiftUI styling without glass."
---

# Liquid Glass Design System Reference

> Apple's Liquid Glass — a translucent, dynamic material for controls and navigation — introduced at WWDC25 for the 26-generation releases (iOS/iPadOS/macOS/tvOS/watchOS/visionOS 26), refined and expanded at WWDC26 for the 27 generation. Building with a 27 SDK removes the compatibility opt-out.
>
> **Sources**: WWDC25 sessions 219, 356, 323, 284, 310, 220, 361, 208, 256, 243, 278, 281, 334; WWDC26 sessions 269, 278, 289, 251, 292, 277; Meet with Apple showcases 208, 254–257; Apple HIG (June 2026 revisions); "Adopting Liquid Glass"; Landmarks sample project.

## Resource Routing Table

| If the task involves...                        | Read first                | Then maybe read           |
|------------------------------------------------|---------------------------|---------------------------|
| Implementing glass in SwiftUI                  | references/swiftui.md     | references/design-rules.md |
| Implementing glass in UIKit                    | references/uikit.md       | references/design-rules.md |
| Implementing glass in AppKit                   | references/appkit.md      | references/design-rules.md |
| Widgets under tinted/clear Home Screen modes   | references/widgets.md     | references/design-rules.md |
| App icons / Icon Composer / .icon files        | references/icons.md       |                           |
| Reviewing design / visual hierarchy / critique | references/design-rules.md |                          |
| Search placement / snippets / platform notes   | references/design-rules.md | framework file § Search |
| Migrating an app to iOS 26+, or 26 → 27        | references/migration.md   | references/design-rules.md |
| Debugging visual glitch with glass             | references/design-rules.md (Anti-Patterns) | matching swiftui/uikit/appkit reference |
| Performance issues with glass                  | references/design-rules.md (Anti-Patterns) | matching swiftui/uikit/appkit reference |

## Version Ladder

Untagged APIs in the reference files are 26.0; later additions are tagged `[26.1]` / `[27.0]` inline. The coarse picture:

| SDK generation | What it means for glass |
|---|---|
| **26.0** | Full API surface: glassEffect family, UIGlassEffect, NSGlassEffectView, scroll edge effects, background extension, concentric shapes, icon appearance modes, widget accented rendering. `UIDesignRequiresCompatibility` available as a temporary opt-out |
| **26.1** | `GlassButtonStyle(_:)` — configurable glass button style |
| **27.0** | Rendering refresh — automatic on rebuild, partly runtime-delivered on macOS/watchOS. User-controlled system-wide glass tint. Toolbar overflow management, navigation-bar minimization, prominent tab role, AppKit concentric corners + `effectIsInteractive`, widget XL-portrait on all platforms. **Compat key ignored — no opt-out when building for 27** |

## Glass Variants Quick Matrix

| Variant    | When to use                                      | Visual effect                       |
|------------|--------------------------------------------------|-------------------------------------|
| `.regular` | Default for all standard UI controls             | Adaptive blur, light/dark automatic |
| `.clear`   | Media-rich backgrounds where blur would obscure  | Highly translucent, minimal blur    |
| `.identity`| Runtime opt-out on 26+ (preserves view topology; NOT a back-deployment tool — `Glass` itself is 26+) | No visual effect applied |

Design canon has TWO variants — regular and clear — never mixed in one context (`identity` is code plumbing, not a look). **Clear requires ALL 3**: (1) over media-rich content, (2) a dimming layer won't harm the content, (3) content above is bold and bright. Over bright content, consider ~35% dark dimming (HIG: Materials).

## API Quick Reference

Per-symbol signatures, availability, and gotchas live in the framework files — this table routes, it is not the source of truth.

| API                                  | Framework | Purpose                                      |
|--------------------------------------|-----------|----------------------------------------------|
| `.glassEffect(_:in:)`               | SwiftUI   | Apply glass material to any view              |
| `Glass` struct                       | SwiftUI   | Variant, tint, interactivity configuration    |
| `GlassEffectContainer`              | SwiftUI   | Shared rendering for multiple glass elements  |
| `.glassEffectID(_:in:)` / `.glassEffectTransition(_:)` | SwiftUI | Morph transitions          |
| `.glassEffectUnion(id:namespace:)`  | SwiftUI   | Merge glass elements at rest                  |
| `.buttonStyle(.glass / .glassProminent)`; `GlassButtonStyle(_:)` `[26.1]` | SwiftUI | Glass buttons |
| `.backgroundExtensionEffect()`      | SwiftUI   | Extend content behind bars/sidebars           |
| `.scrollEdgeEffectStyle(_:for:)` / `.scrollEdgeEffectHidden(_:for:)` | SwiftUI | Scroll edge control |
| `.safeAreaBar(edge:…)`              | SwiftUI   | Custom bars that join the edge-effect system  |
| `ConcentricRectangle` / `containerShape(_:)` | SwiftUI | Concentric corner shapes            |
| `ToolbarSpacer` / `.sharedBackgroundVisibility(_:)` | SwiftUI | Toolbar glass grouping       |
| `.visibilityPriority(_:)` `[27.0 iOS · 26.1 macOS]` / `ToolbarOverflowMenu` `[27.0, iOS family — no macOS]` | SwiftUI | Toolbar space management |
| `.toolbarMinimizeBehavior(_:for:)` `[27.0]` | SwiftUI | Navigation-bar minimization            |
| `UIGlassEffect` / `UIGlassContainerEffect` | UIKit | Glass material via `UIVisualEffectView`  |
| `UIButton.Configuration.glass()` (+ prominent/clear variants) | UIKit | Glass buttons          |
| `UIBackgroundExtensionView`          | UIKit     | Extend content behind bars (assign `contentView`) |
| `UIScrollEdgeEffect` / `UIScrollEdgeElementContainerInteraction` | UIKit | Scroll edges     |
| `UIView.cornerConfiguration` / `UICornerConfiguration` | UIKit | Concentric corners           |
| `UITabAccessory(contentView:)` / `tabBarMinimizeBehavior` | UIKit | Tab bar behaviors         |
| `UIBarButtonItem.Badge` / `navigationItem.subtitle` | UIKit | Bar item styling                 |
| `navigationBarMinimization` (`UIBarMinimization`) `[27.0]` | UIKit | Nav-bar minimization      |
| `NSGlassEffectView` (+ `.style`) / `NSGlassEffectContainerView` | AppKit | Glass on macOS      |
| `NSGlassEffectView.effectIsInteractive` `[27.0]` | AppKit | Click response for interactive glass |
| `NSBackgroundExtensionView`          | AppKit    | Background extension for macOS                |
| `layoutGuide(for: .safeArea(cornerAdaptation:))` | AppKit | Corner-aware layout guides         |
| `cornerConfiguration` / `NSViewCornerConfiguration` `[27.0]` | AppKit | Concentric view corners |
| `widgetRenderingMode` / `widgetAccentedRenderingMode(_:)` | WidgetKit | Glass-mode widgets     |

## 5 Core Design Principles

1. **Two layers**: UI layer (glass) floats above content layer (brand/data) — never mix them
2. **Sparing use**: Apply glass only to the most important functional elements (navigation, primary controls)
3. **No stacking**: Never place glass on glass — glass cannot sample other glass correctly
4. **Concentricity**: Shapes nest with derived radii — concentric corners with a minimum-radius fallback
5. **Selective tinting**: Tint only primary actions or functionally distinct elements — and test against the iOS 27 user glass tint setting

## Top Anti-Patterns

| Anti-Pattern | Why it fails | See also |
|---|---|---|
| Glass in content layer | Glass is for navigation/controls only; content is brand/data | design-rules.md § Visual Hierarchy |
| Glass-on-glass stacking | Glass cannot sample other glass; visual artifacts result | design-rules.md § Anti-Patterns |
| Custom bar backgrounds | `UIBarAppearance`/`backgroundColor` block glass + scroll edge effects | migration.md § Audit Checklist |
| Too many glass effects | GPU-intensive; keep glass out of scrolling lists, limit to top-level chrome | design-rules.md § Anti-Patterns |
| Unclustered co-located glass | Multiple related glass elements need a shared container to render/morph together (a lone effect doesn't) | framework file § Container |
| Nesting glass modifiers | Double translucency, unpredictable rendering; apply once at the highest level, padding OUTSIDE glass scope | design-rules.md § Anti-Patterns |
| Hard-coded control heights | Controls are taller since the 26 releases; use Auto Layout | framework file § Gotchas |
| Forcing `.soft` scroll edges on 27+ | `.automatic` is the refined system look now | design-rules.md § Scroll Edge Effects |
| Logos in toolbars | Scroll edge effect hurts legibility; brand belongs in content | migration.md § American Airlines |
