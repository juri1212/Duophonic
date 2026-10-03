# Liquid Glass — Migration Guide

> Adopting Liquid Glass in existing apps, and moving 26-era adoptions forward to the 27 SDKs.

## Quick Start

1. **Build with the latest SDK** (Xcode 26+) — standard components auto-adopt glass
2. **Run on current OS releases** — see changes immediately; on macOS 27, many glass refinements are runtime-delivered even without a rebuild

## Compatibility window — the key fact

`UIDesignRequiresCompatibility` (Info.plist, iOS/iPadOS/macOS/tvOS/Catalyst 26.0+) renders the app as it looked against pre-26 SDKs. Apple labels it a **temporary** review-and-refine bridge, and:

> The system **ignores this key when you build for iOS 27 or later**, iPadOS 27, Mac Catalyst 27, macOS 27, or tvOS 27.

Consequences:
- Building with a 26.x SDK: the key still works as a short-term escape hatch
- Building with a 27 SDK: there is no opt-out — Liquid Glass is the only rendering path
- Ship plan: fix conflicts (below) rather than budgeting time for the compat mode; remove the key once you build for 27

## Mixed deployment targets

`Glass.identity` does NOT back-deploy — the `Glass` type itself requires OS 26. For targets below 26, gate with availability:

```swift
extension View {
    @ViewBuilder func glassIfAvailable() -> some View {
        if #available(iOS 26, macOS 26, *) {
            self.glassEffect()
        } else {
            self
        }
    }
}
```

On 26+, `.glassEffect(.identity)` toggles glass off at runtime while preserving view topology (no hierarchy swap), and `.identity.interactive()` gives glass that stays invisible at rest and materializes on interaction.

## Audit Checklist

### Remove Conflicts (High Priority)
- [ ] Remove custom bar backgrounds (`UIBarAppearance`, `.toolbarBackground()`, `backgroundColor`)
- [ ] Remove custom sheet/popover backgrounds (`presentationBackground`, visual-effect views in popovers)
- [ ] Remove legacy sidebar materials (`NSVisualEffectView`, `UIVisualEffectView`)
- [ ] Review control dimensions — Auto Layout, not hard-coded heights (controls got taller)
- [ ] Check safe areas for sidebars/inspectors; extend content with `backgroundExtensionEffect`

### Enhance (Medium Priority)
- [ ] Add `backgroundExtensionEffect` for hero images/headers behind bars and sidebars
- [ ] Review toolbar grouping — spacers between groups, one `.prominent` primary action
- [ ] Consider tab bar minimization for reading screens (`.onScrollDown`)
- [ ] Register custom floating bars for scroll edge effects (`safeAreaBar` / `UIScrollEdgeElementContainerInteraction`)
- [ ] Set `sourceItem`/`sourceView` on all action sheets (iPhone AND iPad anchor inline now)

### Polish (Lower Priority)
- [ ] Tint only primary actions — brand color belongs in the content layer
- [ ] Section headers: title-style capitalization (no longer rendered all-caps)
- [ ] Add SF Symbols to menu items (standard selectors get system icons for free)
- [ ] Move logos out of toolbars (scroll edge legibility)
- [ ] Test: Reduce Transparency, Increase Contrast, Reduce Motion — and the iOS 27 user glass tint
- [ ] Profile GPU with Instruments

## 26 → 27 delta checklist (apps that already adopted glass)

- [ ] Rebuild with the 27 SDKs — glass rendering refreshes automatically; re-run visual QA
- [ ] Remove `UIDesignRequiresCompatibility` if still present (ignored when building for 27)
- [ ] Re-check forced `.soft` scroll edges — `.automatic` has its own look now and is the HIG-preferred style
- [ ] Toolbars: audit item counts against automatic overflow; set `visibilityPriority` / pinned placements where order matters
- [ ] Adopt concentric corners where custom views hug container corners (SwiftUI `ConcentricRectangle`, UIKit `cornerConfiguration`, AppKit `NSViewCornerConfiguration`)
- [ ] Widgets: verify tinted AND clear Home Screen modes (background swaps to system glass)
- [ ] Test with the user-controlled glass tint setting
- [ ] macOS: consider `effectIsInteractive` on glass that backs interactive controls
- [ ] iPhone: evaluate sidebar layout opt-in and prominent tab role where they fit the app's structure

## Real-World Lessons (Apple "Meet with Apple" showcases)

### LTK (Shopping)
- Start small: button → pattern → screen → system. "An upgrade, not a rebuild"
- Controls blend in; creator content takes center stage — the two-layer model paying off

### Slack (Messaging)
- Prototyped three header treatments before landing: concentric (bottom edge never resolved), capsule (read as a giant primary button against dark content), gradient (broke against variable scroll content) — final design accentuates the glass containers instead
- Moved search into the tab bar for global availability, following iOS 26 conventions; the compact tab bar's reclaimed space enabled landscape support
- "Using native controls felt like swimming with the OS"

### CNN (News)
- **Nested glass modifiers** = double translucency, layered blur, unpredictable rendering. Apply at the highest level only
- Glass didn't respect padding as expected (stretching/clipping) — wrap in `background`/`overlay`, keep padding OUTSIDE the glass modifier's scope
- GPU-intensive in scrollable/high-frequency views — reserve glass for static chrome (tab bar, toolbars)
- Conditional glass via a custom view modifier for mixed-deployment targets

### Tide Guide (Marine Weather)
- "Adopt then redesign" — a redesign is not required to adopt; best aspects come from the latest system components
- `.interactive()` glass on small, hard-to-see tap targets; `identity` variant on chart highlights where glass should stay quiet until touched
- Replaced a nested context menu with a glass popover — no more menu-dismiss friction while adjusting settings
- Glass on empty/loading states for the refraction effect

### American Airlines
- Removed the logo from the toolbar — scroll edge effect caused legibility issues. Logo scrolls with content instead
