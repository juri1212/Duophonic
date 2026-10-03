# Liquid Glass — App Icons & Icon Composer

> Icons are Liquid Glass surfaces since the 26 releases: layered artwork + system-applied glass effects (specular highlights, refraction, translucency, gyro-driven edge light). Source sessions: WWDC25 220 & 361; HIG App Icons (June 2026 revision).

## Appearance modes

Six runtime appearances, one artwork:

| Runtime appearance | Authoring annotation | Notes |
|---|---|---|
| **Default** (light) | `default` | Prefer colored backgrounds for distinction from other modes |
| **Dark** | `dark` | Check fills manually — colors can vanish against black |
| **Clear light** | `mono` | Monochrome glass, light |
| **Clear dark** | `mono` | Monochrome glass, dark |
| **Tinted light** | `mono` | User color infused into the glass |
| **Tinted dark** | `mono` | User color on the foreground |

The `mono` annotation fans out into all four Clear/Tinted appearances. Mono legibility rule: make at least one element white, map the rest to grays — auto-conversion exists but tune manually.

Platform coverage: all modes on iPhone, iPad, Mac. Apple Watch renders the light appearance only.

## Grids & canvases

- iPhone/iPad/Mac: **1024px** canvas, unified rounded-rectangle grid, rounder corner radius (concentric with system UI)
- watchOS: **1088px** canvas, circular grid that overshoots the rounded-rect (design once, verify edge elements; scale back to the edge or bake in bleed)
- **macOS artwork is now masked** — elements no longer extend outside the shape. Legacy Mac icons get auto-masking + material; irregular shapes get shadows stripped and auto-scaling as a fallback — redraw instead of relying on it (Apple's own Photo Booth example)
- The system applies masking, blur, and effects — never bake them into the source art

## Layer model

- Layers stack in Z-depth (bottom = background); background + foreground layers create the dimensionality
- Groups share glass properties; **max 4 layers per group** — Apple's complexity ceiling
- Liquid Glass is on per layer by default; disable per layer (or disable specular per group) when detail goes "pillowy"
- Properties pre-scoped per appearance: opacity, blend mode, fill. Others apply everywhere; the "+" control adds a per-appearance variant
- Shadows: **neutral** (default, safe anywhere) vs **chromatic** (color spills onto background — for color-on-white designs)

## Design rules (session 220)

- Flat, frontal compositions — perspective/3D competes with the material
- Rounder corners, bolder line weights — light needs edges to travel on
- No baked-in shadows, bevels, or gloss — the material supplies them dynamically
- Reduce shape overlap; translucency + reflective edges need room to read
- Prefer System Light / System Dark gradient backgrounds over pure white/black
- Even single-layer foregrounds benefit from translucency + shadow (Messages); multi-layer stacking adds real depth (Podcasts)

## Icon Composer workflow

1. Design layers in any tool (Figma/Sketch/Photoshop/Illustrator; Apple templates on Apple Design Resources)
2. Export per layer:
   - Flat/vector layers as **SVG**, canvas-sized so they drop into position; number filenames for Z-order
   - **Convert text to outlines first** (SVG doesn't embed fonts)
   - Gradients/raster content as **transparent PNG**
   - **No masks in exports** — applied automatically later; backgrounds/gradients can be added inside Icon Composer
   - Illustrator: Apple provides a layer-to-SVG export script
3. In Icon Composer: drag layers in (auto-alphabetized into a group), group, set per-appearance properties, preview against wallpapers/grids/light motion, test all six appearances
4. Save the **`.icon` file**, drag into Xcode, select in the Project Editor — the system renders every platform/appearance/size from it

Fallback: plain images uploaded straight to Xcode still get the specular edge treatment on-device, but no multi-layer dynamics — acceptable only for very complex/illustrative icons.

## Gotchas

1. Canvas-size mismatch between exported layers breaks positioning — export all layers at the grid canvas size
2. Dark-mode fills usually need manual overrides (the disappearing-maroon-bookmark problem)
3. Watch + rounded-rect: check edge-touching elements against the circular mask
4. Don't ship pre-baked effects — they fight the live material
