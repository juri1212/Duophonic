# Liquid Glass — UIKit APIs, Patterns & Gotchas

> Untagged APIs require iOS 26.0+ / Xcode 26 SDK. Later additions are tagged `[27.0]`. UIKit modernization mechanics (UIScene requirement, size classes vs idiom, UIRequiresFullScreen changes) are a separate topic — this file covers only the design system.

## UIGlassEffect

Glass material via `UIVisualEffectView`. Distinct from `UIBlurEffect` — designed for the interactive control layer only. Available iOS 26+ / tvOS 26+.

```swift
let glassEffect = UIGlassEffect()               // Regular style (default)
let clearGlass = UIGlassEffect(style: .clear)   // Clear variant (UIGlassEffect.Style)

let effectView = UIVisualEffectView(effect: nil)
view.addSubview(effectView)

// Materialize with animation:
UIView.animate(withDuration: 0.3) { effectView.effect = glassEffect }

// Dematerialize (NOT alpha = 0):
UIView.animate(withDuration: 0.3) { effectView.effect = nil }
```

### Properties

```swift
glassEffect.isInteractive = true       // Scale, bounce, shimmer on touch
glassEffect.tintColor = .systemBlue    // Vibrant adaptive tint
```

**Size-adaptive**: larger → more opaque; smaller → clearer + auto light/dark switching. Default shape is capsule.

**Content**: add to `effectView.contentView`. Labels auto-become vibrant. Use dynamic colors (`.label`, `.secondaryLabel`).

**Animation rule**: glass materialize/dematerialize, corner changes, size changes, and light/dark switches all belong inside `UIView.animate` blocks — outside one they snap without the material animation.

## UIGlassContainerEffect

Groups **multiple related glass elements** for shared rendering, fluid merging, visual correctness, and performance (single sampling pass). A lone glass view doesn't need one.

```swift
let container = UIGlassContainerEffect()
container.spacing = 12  // Merge distance
let containerView = UIVisualEffectView(effect: container)

let child1 = UIVisualEffectView(effect: UIGlassEffect())
let child2 = UIVisualEffectView(effect: UIGlassEffect())
containerView.contentView.addSubview(child1)
containerView.contentView.addSubview(child2)
```

**Split animation**: add at same position without animation, then animate apart.

## Glass Button Configurations

```swift
UIButton.Configuration.glass()               // Standard glass
UIButton.Configuration.prominentGlass()      // Tinted with app tint color
UIButton.Configuration.clearGlass()          // Clear variant
UIButton.Configuration.prominentClearGlass() // Prominent clear
```

## Corner Configuration

Concentricity in UIKit — corners that derive from the container/window curvature:

```swift
view.cornerConfiguration = .uniformCorners(radius: .containerConcentric(minimum: 12))
// UICornerConfiguration factories: .corners(radius:), .uniformCorners(radius:),
// .uniformEdges(topRadius:bottomRadius:), .capsule(maximumRadius:)
// UICornerRadius: fixed values or container-concentric with a minimum fallback
```

Squared corners remain the default — no configuration needed for them.

## UIBackgroundExtensionView

Extends content behind system bars and sidebars via a mirrored + blurred replica outside the safe area.

```swift
let extensionView = UIBackgroundExtensionView()
view.addSubview(extensionView)
extensionView.contentView = heroImageView   // ASSIGN the optional contentView — do not addSubview into it

// Manual placement when needed:
extensionView.automaticallyPlacesContentView = false
// then constrain heroImageView against extensionView.safeAreaLayoutGuide (sidebar-aware)
```

Detail views and overlays must be **siblings of the extension view**, never its subviews.

## Scroll Edge Effects

Two pieces: the scroll view's own edge effects, and an interaction for custom overlaid chrome.

```swift
// Style the scroll view's edges (UIScrollEdgeEffect, iOS 26+/tvOS 26+/visionOS 26+):
scrollView.topEdgeEffect.style = .hard      // .automatic (default) | .soft | .hard
scrollView.bottomEdgeEffect.style = .soft

// Register a container of custom views overlaying a scroll edge —
// its labels/images/glass/controls then shape the edge effect:
let interaction = UIScrollEdgeElementContainerInteraction()
interaction.scrollView = scrollView    // weak
interaction.edge = .bottom             // UIRectEdge
floatingBar.addInteraction(interaction)
```

`[27.0]` **`.automatic` changed visuals**: it no longer resolves to soft/hard — it has its own refined appearance. Re-evaluate any place that forced `.soft` to imitate the old default; that no longer matches the system look.

## Tab Bar

```swift
tabBarController.tabBarMinimizeBehavior = .onScrollDown

// Bottom accessory (e.g. now-playing):
let accessory = UITabAccessory(contentView: nowPlayingView)   // UIView — the only initializer
tabBarController.bottomAccessory = accessory

// React to inline vs standalone rendering — prefer updateProperties() over manual trait registration:
override func updateProperties() {
    super.updateProperties()
    let inline = traitCollection.tabAccessoryEnvironment == .inline
    accessoryView.compact = inline
}
```

`[27.0]`
```swift
tabBarController.prominentTabIdentifier = "cart"              // emphasized tab
tabBarController.sidebar.preferredPlacement = .sidebar        // iPhone sidebar layout opt-in (app decision;
                                                              // system shows it only when space allows)
```

## Navigation Bar & Toolbars

**Bar background is transparent by default.** Remove all `UIBarAppearance`/`backgroundColor` customization.

### Item grouping

Items auto-group on shared glass backgrounds. Image buttons share; text/Done/prominent buttons get separate backgrounds.

```swift
// Split groups with fixedSpace (0 width still splits the glass):
navigationItem.rightBarButtonItems = [doneBtn, .fixedSpace(0), shareBtn, infoBtn]

// Prominent primary action:
doneButton.style = .prominent

// Keep single background across flexible space:
flexSpace.hidesSharedBackground = false  // default true = separates

// Tint a symbol (meaning, not decoration):
flagButton.tintColor = .systemOrange

// Badge (Swift type is UIBarButtonItem.Badge):
bellButton.badge = .count(5)      // also .string("New"), .indicator()

// Hide the ITEM, not its view (an empty glass pill renders otherwise):
filterButton.isHidden = true
```

### Titles & subtitles

```swift
navigationItem.title = "Trip"
navigationItem.subtitle = "June 2026"          // two-line title support
navigationItem.largeSubtitleView = customView  // custom subtitle view in the large title region
```

### `[27.0]` Navigation bar minimization

```swift
var config = navigationItem.navigationBarMinimization   // UIBarMinimization (value type)
config.minimizationBehavior = .onScrollDown             // .automatic | .never | .onScrollDown | .onScrollUp
config.safeAreaAdjustment = .disabled                   // .automatic | .enabled | .disabled
config.restorationBehavior = .atScrollEdge              // .automatic | .atScrollEdge
navigationItem.navigationBarMinimization = config
```

`.atScrollEdge` is honored only with `.onScrollDown`; `.automatic` restoration picks `.atScrollEdge` for items whose `preferredSearchBarPlacement` is `.integratedCentered`. When the navigation bar minimizes, an integrated top tab bar minimizes with it.

## Search Placement

```swift
navigationItem.preferredSearchBarPlacement = .integratedCentered
navigationItem.searchBarPlacementBarButtonItem   // toolbar-button search entry
navigationItem.searchBarPlacementAllowsExternalIntegration = true

// On a search tab (not the navigation item):
UISearchTab { _ in /* ... */ }               // semantic search tab
// UISearchTab.automaticallyActivatesSearch = true — keyboard engages on selection
```

`[27.0]` Menus: glass menus may hide item images by default in iPad/Mac menu bars — override per element with `preferredImageVisibility`.

## Sliders

```swift
slider.trackConfiguration = UISlider.TrackConfiguration(
    allowsTickValuesOnly: true, neutralValue: 0.5, numberOfTicks: 11)
slider.sliderStyle = .thumbless
```

## Sheets & Action Sheets

Sheets adopt glass automatically. **Remove custom `presentationBackground`.**

**Zoom transition from a bar button:**
```swift
detailVC.preferredTransition = .zoom { _ in
    self.navigationItem.rightBarButtonItems?.first
}
```

**Action sheets** anchor to their source on **both iPhone and iPad**:
```swift
alert.popoverPresentationController?.sourceItem = button
// With sourceItem: inline, no cancel button (dismiss by tapping elsewhere)
// Without sourceItem: centered, with cancel button
```

---

## Code Pattern: Background Extension (TV-app style)

```swift
class ShowVC: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        let ext = UIBackgroundExtensionView()
        ext.automaticallyPlacesContentView = false
        view.addSubview(ext)

        ext.contentView = imageView
        imageView.leadingAnchor.constraint(
            equalTo: ext.safeAreaLayoutGuide.leadingAnchor
        ).isActive = true

        // Details as SIBLING of the extension view:
        view.addSubview(detailsView)
    }
}
```

---

## Gotchas

1. **Use the `effect` property, NOT `alpha`** — animate between `UIGlassEffect()` and `nil`. Setting alpha skips the glass materialize/dematerialize animation.
2. **Assign `contentView`, don't add into it** — `UIBackgroundExtensionView.contentView` is an assignable optional; details/overlays are siblings of the extension view.
3. **Remove `UIBarAppearance`/`backgroundColor`** — blocks glass AND scroll edge effects.
4. **`isInteractive = true` for custom glass** — without it, custom glass views have no press feedback.
5. **Action sheet without `sourceItem` = centered + cancel button** — always set a source for the inline anchored appearance.
6. **Scroll-edge style lives on the scroll view** (`topEdgeEffect`/`bottomEdgeEffect`), not on `UIScrollEdgeElementContainerInteraction` — the interaction only registers overlay containers.
7. **Don't force `.soft` on iOS 27+** to imitate the default — `.automatic` has its own look now.
8. **`#available` guard for mixed targets:**
```swift
if #available(iOS 26, *) {
    let effect = UIGlassEffect()
    // apply glass
}
```
