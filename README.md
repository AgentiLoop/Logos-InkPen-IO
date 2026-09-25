# logos inkpen.io

<a href="https://www.paypal.com/ncp/payment/3DTH3S7XARK98"><img src="https://img.shields.io/badge/Tip_Jar-PayPal-00457C?style=for-the-badge&logo=paypal&logoColor=white" alt="Tip Jar" /></a>

Native FreeHand import (FH3 through FH11 & MX) — opened directly, no intermediate formats. Improved PDF & SVG parsing for Xcode UI, SpriteKit, web graphics, and Linux icons. Apple Pencil support via Luna Display or Sidecar. Built on SwiftUI, Metal & CoreGraphics for macOS 14, 15 & 26. GPU-accelerated vector rendering with real-time previews and instant zoom at any scale.

<img width="1579" height="1376" alt="image" src="https://github.com/user-attachments/assets/360b5a32-a7fb-49a3-b095-05d2f0121533" />

---

## ✏️ Drawing & Pen Tools

- Full FreeHand-style pen tool with calligraphic ink simulation
- Embed original inkpen data in Autodesk SVG exports
- Remove stroke expansion from selection hit test for better performance
- Pressure-sensitive drawing support
- Stroke simplification, deduplication, and smoothing filters

## 🖱️ Selection & Direct Selection

- Direct selection tool with paint/fill-based selection (FreeHand/Illustrator style)
- Option+Click select behind for direct selection tool
- Direct selection moves individual points; arrow key nudging for selected points
- Auto-select topmost member when switching to direct select with group
- Direct selection UI moves with shape during live nudge preview
- Move dialog support for selected points in direct selection mode

## 📐 Offset Path & Transform

- Offset Path feature with document units and ±12 picas / ±50px ranges
- Offset path uses document units with 0.1 precision
- Clamp offset slider when document units change
- Scale X, Scale Y, and Rotate fields in toolbar
- Transform box with direct opacity control
- Bounding box rectangle button in document toolbar

## 📏 Alignment & Anchors

- Align X and Align Y menu items in Object menu
- Separate X-only and Y-only anchor point alignment buttons
- Alignment anchor preference with locked item priority
- Simplified single align button in toolbar

## 📋 Import & Export

- FreeHand document import (`.fh`, `.fh3`, `.fh5`, `.fh6`, `.fh7`, `.fh8`, `.fh9`, `.fh10`, `.fh11`, `.fhmx`) — imports directly from libFreeHand, skipping SVG code generation and reading straight to InkPen objects
- FreeHand `.fh10+` import support improved (IPTC metadata wrapper fix) — tested with `.fh10`; same fix applies to `.fh11` and `.fhmx`
- PDF vector graphic support with single and multiline text box generation
- Closest font substitution for accurate PDF text rendering
- SVG import: shapes added to new layer instead of replacing Guides layer
- SVG text import preserves UUID and textPosition
- PDF and SVG export fixes for groups using memberIDs
- Autodesk SVG export uses true 96 DPI coordinates
- PNG export fix (was upside down from File menu)
- Dynamic format version in SVG and PDF metadata
- Support for additional image formats

## 🗂️ Layers & Groups

- Delete layer button in LayersPanel
- Lock icon as toggle button synced with layers panel
- Layer panel displays group members using memberIDs
- Sync direct selection when selecting from layers panel
- Track selection order in layers panel
- Copy/paste groups with unique UUIDs for all members
- Pasted groups keep members inside group
- Group color/stroke/opacity changes via memberIDs
- Fix nested group rendering to display sub-groups

## 🎯 Snapping, Zoom & View

- Fit screen on first open, never open minimized
- Fit to Page max zoom increased to 16,000%
- Classic Space+Cmd zoom shortcut
- Auto fit-to-page when window is resized
- Snap Page to Artwork/Selection captures all object types
- Show Grid, Snap to Grid, Grid on Top toggles
- Major grid line interval per unit type
- Grid renders above background layer

## 🌈 Color, Opacity & Gradients

- CPU SIMD optimization for color + gradient operations
- Live updates for opacity and width sliders on groups
- Preserve opacity when changing colors
- Fix color picker for groups with memberIDs
- Replace NSColor with PlatformColor and Color.platform* helpers
- Replace GradientSwatchNSView with SwiftUI Canvas
- Migrate to CGColor across PDF, cursors, eyedropper

## 🔤 Text & Typography

- Stroke placement support for text (center, inside, outside)
- Text to outlines with undo support
- Preserve text stroke and layer positions when converting to outlines
- Optimize text stroke rendering — outline once per text
- SVG text import with UUID and textPosition preservation

## ✂️ Path Operations & Clipping

- Combine path operation with unionMultiplePaths support
- Clipping mask with cross-layer support and undo
- Fix path operations duplicate IDs and undo count
- Fix release clipping mask reversing object order
- Fix clipping mask duplicating objects from other layers

## 📐 Units, Dimensions & Coordinates

- Unit-aware Transform X Y W H coordinates
- Show drawing dimensions in document unit
- 3 decimal places for dimension display
- Unit formats standardized to 2–3 decimal places
- Fix guide drag speed — canvasDelta already in doc coords

## ⏮️ Undo & Redo

- Selection/deselection in undo/redo
- Fix undo not available until deselection
- Undo support for group transforms, nested group drag, and property changes
- Undo for path operations, clipping masks, and corner radius changes
- Refactored nudge, text handling, corner radius, and transform controls to use undo helpers

## 🧩 Toolbar & UI

- Interpolation quality popup menu
- Add onTapGesture for instant button response
- Optimize LayersPanel reactivity
- Fix duplicate button actions

## 🖼️ SF Symbols

- SF Symbols integration for browsing and inserting Apple's symbol library
- Search and filter SF Symbols by name
- Insert SF Symbols as vector objects in documents

## ⚡ Performance & Memory

- **Tab suspension** — background tabs drop their full view tree; only the active tab builds DrawingCanvas, RightPanel, and toolbars. Switching tabs rebuilds instantly. Cuts multi-tab memory by ~50%.
- **Memory leak fixes** — Combine subscriptions now cancelled on tab close; document resources (images, objects, undo stack) released when tabs close. Previously leaked entire VectorDocument per closed tab.
- **Removed .drawingGroup() overhead** — grid, rulers, and background views no longer allocate full Retina backing bitmaps (~33MB each). Saves ~130MB per open document.
- **Shared Metal pipelines** — MetalSpatialIndex shares device, command queue, and compiled compute pipelines across all tabs instead of duplicating per document.
- **Shared font list** — system font catalog loaded once, shared across all FontManager instances.
- **Spatial index safety** — guards against inf/NaN bounds from degenerate shapes; caps grid at 10K cells to prevent multi-GB Metal buffer allocations.
- **Shape detection fix** — SVG rectangles (move + 3 lines + close) no longer misclassified as triangles.
- **Image import undo** — addImportedShape wraps all objects in AddObjectCommand for proper Cmd+Z support.
- SIMD optimize pan and coordinate transforms
- SIMD optimize Canvas views, GridView, TextCanvas, GPUMathAccelerator
- SIMD optimize CornerRadiusEditTool, PenPlusMinusTool, UnifiedObjectView gradient
- SIMD8 batch optimization with type aliases
- Exponential zoom easing with SIMD
- Optimize bounding box rectangle for faster response
- O(1) clipped objects cache
- Skip guides in layer rendering — use GuidesView only
- Skip viewport culling for text objects

## 🐛 Bug Fixes & Stability

- Fix tile rendering gaps with pixel-aligned sizes
- Fix tile culling coordinate conversion
- Fix Metal texture color space conversion
- Fix rectangle corner handle directions for cusp conversion
- Fix grid alignment and mm spacing
- Fix keyline view not rendering shapes
- Fix layout recursion warning on startup
- Fix orphaned objects from offset path operation
- Fix fitToPage centering calculation
- Various compile error fixes and warning cleanups

---

## ⌨️ Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| Nudge | Arrow keys |
| Fine Nudge (1/10th) | Option + Arrow |
| Select Behind | Cmd + Click |
| Constrain Drag | Shift + Drag |
| Zoom | Space + Cmd |

---

## 📁 File Formats

| Format | Extension | Description |
|--------|-----------|-------------|
| Ink Pen Document | .inkpen | Native format with full editibility |
| FreeHand Document | .fh, .fh3–.fh11/.fhmx | Import — FreeHand objects and masked gradients (`.fh10+` IPTC fix) |
| SVG | .svg | Scalable Vector Graphics |
| PDF | .pdf | Portable Document Format |
| PNG | .png | Raster image export |

---

## 🗺️ Source Layout

All app code lives in `logos inkpen.io/` (an Xcode synchronized folder — add or move files on disk and Xcode picks them up).

| Folder | What lives there |
|--------|------------------|
| `App/` | `@main` app + menus (`LogosInkPenApp.swift`), `AppDelegate`, global key handling, app-wide state & settings, `Clipboard/`, `Help/`, `Diagnostics/` (logging, stderr filter) |
| `Document/` | `InkpenDocument` (FileDocument), `DocumentState`, registries, snapshots, `Settings/`, `Migration/`, `Selection/` |
| `Document/VectorDocument/` | The core `VectorDocument` class and its extensions, grouped into `Layers/`, `Objects/`, `PathOperations/`, `TextAndColor/`, `Unified/` |
| `Models/` | Plain data types: `Objects/` (shapes, paths, layers), `Text/`, `Color/`, `Gradient/`, `Handles/`, `Tools/`, `Transform/`, `Interface/` |
| `Geometry/` | Pure math: `Bezier/`, `Path/` (boolean ops, path utilities), `Shapes/`, `Math/` |
| `FileFormats/` | `FileOperations` + `Native/` (.inkpen JSON), `Import/`, `Export/`, `PDF/`, `SVG/`, `FreeHand/`, `PNG/` |
| `Rendering/` | `Metal/` compute & tile rendering, `SpatialIndex/`, image tile cache |
| `Undo/` | `CommandManager` and all undoable `Commands/` |
| `Input/` | Pressure / stylus handling |
| `Views/Canvas/` | `DrawingCanvas` and its extensions: `Gestures/`, `Selection/`, `Tools/`, `ObjectRendering/`, `Handles/`, `Overlays/`, `Text/` |
| `Views/Panels/` | Right-side inspector: `Color/`, `Gradient/`, `Layers/`, `PathOperations/`, `StrokeFill/`, `Typography/` |
| `Views/…` | `Window/` (main window, rulers, status bar), `Toolbar/`, `Dialogs/`, `Preferences/`, `Components/`, `Styles/` |
| `Utilities/` | Small cross-cutting `Extensions/` and the SF Symbols library |
| `ThirdParty/` | libfreehand / librevenge (bridged via `logos inkpen.io-Bridging-Header.h`) |

---

## 💻 System Requirements

- macOS (SwiftUI-based)
- Apple Silicon or Intel Mac

---

## 📦 Release

**v1.0.2** — Tribute to FreeHand · Oct 9, 2025 → Apr 9, 2026

- FreeHand `.fh10+` import support improved (IPTC metadata wrapper fix)
- PDF vector graphic support with text box generation and font substitution
- SF Symbols integration for browsing and inserting Apple's symbol library
- PDF and SVG export fixes for groups using memberIDs
- Additional image format support

[Download latest release](https://github.com/macOS26/logos/releases/tag/1.0.2)

---

## License

Copyright (c) 2025-2026 inkpen.io. All rights reserved.
