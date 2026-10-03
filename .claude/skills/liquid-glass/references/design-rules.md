# Liquid Glass — Design Rules & HIG Guidance

> Cross-cutting design principles for Liquid Glass across all platforms. Incorporates the June 2026 HIG revisions (Sidebars, Tab bars, Scroll views, App icons).

## Visual Hierarchy

Two-layer system:

| Layer | Purpose | Elements | Material |
|-------|---------|----------|----------|
| **UI Layer** (top) | Navigation & controls | Tab bars, toolbars, nav bars, floating buttons, sidebars | Liquid Glass |
| **Content Layer** (bottom) | Brand & data | Text, images, cards, lists, media | Opaque/custom |

- **Don't use glass in the content layer** (HIG). Exception: transient interactive elements (slider knobs, toggle thumbs) during interaction only
- Brand expression belongs in the content layer — colors, imagery, typography. Move brand color OUT of bars and INTO the content/scroll region; glass picks it up dynamically. Solid-color bar backgrounds that letterbox content are the canonical pre-26 anti-pattern
- Custom utilitarian controls read as less native, even dated — spend custom UI only where it differentiates

## Glass Variants

Two design variants — **never mix them in the same context**. (`identity` is an API-level opt-out, not a third variant.)

**Regular** (default): all adaptive effects; works in any size, over any content. Use most of the time.

**Clear**: highly translucent, no adaptive light/dark switching. Requires ALL 3: (1) over media-rich content, (2) a dimming layer won't harm the content, (3) content above is bold and bright. Over bright content, *consider* a dark dimming layer at ~35% opacity (HIG: Materials) — dark content or media playback controls may need none.

### Size-Adaptive Behavior
- **Small elements** (nav bars, tab bars, buttons): flip light/dark based on background
- **Large elements** (menus, sidebars, sheets): adapt but DON'T flip — surface area too big; larger glass simulates thicker material (deeper shadows, stronger lensing)
- Window loses focus (Mac/iPad): glass visually recedes

## Concentricity & Shapes

Inner radius = outer radius − padding. Three shape types: **fixed** (constant radius), **capsule** (radius = half height), **concentric** (calculated from parent).

Platform defaults: iPhone=capsule, iPad/Mac=concentric with window, macOS mini/small/regular=rounded rect, large/extraLarge=capsule.

**Fallback radius**: give concentric shapes a minimum — concentric when nested, the fallback keeps corners rounded standalone. Pinched or flared corners in nested containers usually mean the inner shape should be concentric.

## Tinting

- Tint **selectively** — only primary actions or functionally distinct elements. **Never tint all**
- Generated tones map to background brightness. Use system colors or light/dark-variant custom colors with increased-contrast options
- Don't use solid fills on glass buttons — breaks the material character
- iOS 27: users can tint glass system-wide — test brand colors against user-tinted glass

**Emphasis**: tinted+prominent > tinted > untinted.

## Scroll Edge Effects

Visual separation between floating elements and scrolling content. **Not decorative** — they don't dim like overlays; they exist to keep controls legible.

- **Prefer `.automatic`** (HIG, June 2026) — more opaque separation for top toolbars; on iOS 27+ it has its own appearance and no longer resolves to soft/hard
- `.soft` = progressive fade; `.hard` = opaque backing with a dividing line (pinned headers, tables, free-floating titles on macOS)
- **Only where a scroll view sits behind floating elements. One effect per view edge. Never stack soft and hard.** Split-view panes may each have one — keep heights consistent

## Toolbars

- Don't mix text + icons in the same group (reads as one merged button)
- `.prominent` for the key action (Done, Submit) — one primary action, trailing side, sits alone
- Monochrome icons by default; remove custom backgrounds/borders — hierarchy comes from grouping, not decoration
- Separate groups with spacers; overflow is system-managed on macOS/iPadOS — don't hand-roll an overflow menu
- Give every icon an accessibility label
- Crowded bar → move secondary actions into a More menu; don't create near-duplicate icon variants for related actions — one symbol, text disambiguates

## Tab Bars (June 2026 HIG)

- Floats above content on glass; content peeks through beneath
- **Avoid overflow tabs** — too many tabs turns the trailing one into a More tab
- **Avoid tab colors similar to content-layer backgrounds** — with colorful content, prefer a monochrome tab bar or a clearly differentiated accent
- Tab bar + accessory (Music MiniPlayer pattern): minimizes on scroll with the accessory inline; users exit by tapping a tab or scrolling to top
- iPad: top tab bar can be fixed or convertible to a sidebar (`sidebarAdaptable` — pick the launch presentation, both get a convert button)

## Sidebars (June 2026 HIG)

- Float above content on glass. **Extend content beneath** with `backgroundExtensionEffect` or horizontal scroll; text/controls layer above the extension
- Sidebar icons default to the app accent color — per-icon colors only with a clear purpose; macOS users can override the system accent
- Remove legacy blur/material views

## Search Placement (Liquid Glass conventions)

Placement signals scope — pick by navigation model and search scope:
- **iPhone**: bottom toolbar field/button (preferred — reachable, rides the keyboard up) · top toolbar (bottom occupied) · Search **tab** (standard = suggestions landing page; prominent/button style = straight to keyboard) · inline in content (scoped/local search)
- **iPad/Mac**: trailing toolbar position (split-view apps) · top of sidebar · dedicated search section. Toolbar field auto-collapses to a button under space pressure
- The system field renders on glass in bars, standard in content — automatic by placement; scope bars for lightweight filtering (tokens are low-discoverability — pair with visible filter UI)

## Snippets (App Intents / Siri surfaces)

Interactive snippets are Liquid Glass surfaces that overlay the top of the screen:
- Two types: **Result** (outcome + Done) and **Confirmation** (action verb button, e.g. "Order")
- **Keep content under 340pt tall** — beyond that scrolls, which Apple flags as unexpected friction
- Larger-than-default type for glanceability; margins via `ContainerRelativeShape`; vibrant/branded backgrounds need contrast beyond standard ratios (viewed at a distance)

## iPad specifics

- Window controls sit in the toolbar's leading edge; wrap your toolbar around them. Apps not adapted for the new controls get a reserved compatibility strip above the toolbar that permanently costs vertical space — adapt instead of accepting it
- Extend content edge-to-edge under toolbar/sidebar (scroll edge effects keep bars legible) — especially valuable in small floating windows
- Pointer is 1:1 with a glass "platter" hover highlight that refracts what's beneath — test custom hover behaviors

## Platform notes

- **watchOS**: appearance updates arrive automatically for apps built for watchOS 10+ toolbar/button APIs — audit custom control styles for legibility, no rebuild needed
- **tvOS**: glass appears on focus; adopt standard focus APIs for custom controls; Liquid Glass renders on Apple TV 4K (2nd gen)+ — older devices keep the previous look

## Accessibility & user settings

Automatic with standard components:

| Setting | Adaptation |
|---------|-----------|
| **Reduce Transparency** | Frostier, more opaque |
| **Increase Contrast** | Solid black/white with contrasting border |
| **Reduce Motion** | Disables elastic/fluid properties |
| **User glass tint** (iOS 27) | System-wide tint applied to glass |

Test all four with custom glass elements.

---

## Anti-Patterns

**Glass-on-glass**: Never layer glass on glass — glass can't sample other glass. Use `GlassEffectContainer`/`UIGlassContainerEffect`/`NSGlassEffectContainerView` for clusters, or flatten. Remove floating glass buttons when a glass sheet expands (Maps pattern).

**Content intersecting glass at rest**: Reposition/scale content. Use `backgroundExtensionEffect` for dynamic overlap during scroll, not static overlap.

**Too many glass effects**: GPU-intensive. Limit to top-level navigational elements; avoid glass inside scrolling lists and high-frequency animations (CNN lesson). Consolidate with containers. Profile with Instruments.

**Custom bar backgrounds**: `UIBarAppearance`, `.toolbarBackground()`, `backgroundColor` block glass + scroll edge effects. Remove all.

**Nesting glass modifiers**: Parent + child = double translucency, layered blur, unpredictable rendering. Apply at the highest level only. Inner padding (space glass should cover) goes before the glass modifier; outer margins go OUTSIDE it — wrap in `background`/`overlay` (CNN lesson).

**Forcing `.soft` scroll edges on 27+**: `.automatic` is the system look now; forced soft no longer matches.

**Logos in toolbars**: Scroll edge effect causes legibility issues; prime toolbar real estate isn't a brand surface. Let logos live in content (NYT Cooking: home tab only, fades on scroll; American Airlines: logo scrolls with content).
