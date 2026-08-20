---
type: Reference
title: Apple Freeform PDF investigation
description: Observed source facts, supported parsing profile, classification policy, and limitations.
timestamp: 2026-08-20
---
# PDF Investigation

## Observed Source

`Algos.pdf` was exported by the iOS Quartz PDF context. The current file has:

- 1 page;
- PDF version 1.4;
- page dimensions `6179.635 x 6144.439` points;
- zero-origin, matching MediaBox and CropBox;
- page rotation `0`;
- 534 content operators;
- 44 image XObjects;
- 35 substantially transparent soft-masked artwork resources;
- 8 opaque raster resources and 1 near-opaque soft-masked screenshot;
- 1 HTTP URI annotation that identifies a YouTube video;
- no PDF font resources or text-showing operators;
- no painted native vector paths in the resulting scene.

The board's visible handwriting and shapes are already raster data inside image XObjects. Their original Freeform geometry is not present in the PDF. Turning handwriting pixels into browser text would require optical character recognition, which is intentionally outside this project. The generator instead traces eligible artwork pixels into SVG contours. This conversion improves zoom behavior but is deterministic and lossy. The scene and browser types can represent DOM text, but production parsing rejects PDF text until font decoding, glyph metrics, and positioning are implemented.

## Observed Resource Classification

The current source deterministically produces 35 vector artwork nodes and 9 raster image nodes. `Im29`, `Im31`, `Im33`, `Im35`, `Im37`, `Im39`, `Im41`, `Im43`, and `Im44` remain raster. The first eight are opaque screenshots or diagrams. `Im44` is a rounded-corner YouTube screenshot whose soft mask is near-opaque.

Classification uses the soft-mask samples before tracing:

- no soft mask, or a transparent-sample fraction at most `0.005`: preserve raster;
- a transparent-sample fraction below `0.01` but above `0.005`: fail as ambiguous;
- a transparent-sample fraction of at least `0.01`: trace as vector;
- no visible samples at alpha `96` or higher: fail as unsupported.

Tracing quantizes RGB channels in steps of 32, treats alpha below 96 as transparent, combines same-color boundaries into even-odd paths, normalizes coordinates to the source image, and simplifies contours with a one-pixel squared tolerance. Four-corner contours are preserved so small holes cannot collapse into diagonals. The browser restores each image XObject's PDF transform when it renders the SVG path data.

## Selected Library

The production parser uses the Haskell `pdf-toolbox` packages:

- `pdf-toolbox-document` opens the file, walks the page tree, resolves objects, and decodes streams;
- `pdf-toolbox-content` parses content streams into operators;
- `pdf-toolbox-core` supplies PDF objects, names, references, arrays, and dictionaries.

The project, not the library, owns the graphics-state interpreter. This keeps coordinate conversion, clipping, opacity, scene validation, and unsupported-operator behavior visible in the educational Haskell code.

## Supported Export Profile

The parser currently supports the subset required by the observed Freeform export:

- graphics save and restore, concatenated transforms, clipping, path construction, and common paint operators;
- grayscale, RGB, and CMYK color operators;
- Freeform opacity resources;
- JPEG image streams and 8-bit Flate streams using DeviceGray, DeviceRGB, or one/three-component ICCBased color spaces;
- Flate soft masks with matching dimensions;
- deterministic soft-mask classification and SVG contour tracing for the observed transparent artwork profile;
- URI link annotations and validated HTTP/HTTPS URLs;
- explicit rejection of PDF text until font decoding and metrics are implemented.

The browser runtime currently requires axis-aligned image matrices. Validation rejects rotations and shear rather than rendering them incorrectly.

## Explicit Limitations

The following valid PDF features are not yet generalized:

- non-zero page-box origins, differing CropBox values, and page rotation;
- inherited page resources;
- Form XObjects;
- Indexed, four-component ICC, color-managed ICC transforms, or other complex image color spaces and decode arrays;
- line cap, line join, miter, and dash graphics state;
- PDF font encoding, embedded fonts, glyph widths, and `ToUnicode` handling;
- separate stroke and fill alpha values;
- internal destinations and non-URI annotation actions.

Tracing does not recover semantic strokes, editable handwriting, original Freeform objects, gradients, or subpixel source geometry. Pixels at supported transparency levels become opaque quantized SVG fills. Opaque content remains raster rather than being guessed into vectors.

Unsupported operators fail with a typed error. Some unsupported structures have dedicated errors, while others are rejected by scene validation. A future parser increment should begin with a real source file demonstrating one missing feature, then add one focused test and one minimal implementation.

## Evaluation Oracle

Poppler's `pdftoppm` renders reference PNGs at 18 and 72 DPI only for development evaluation. Headless Chromium renders the generated site at matching dimensions. `Factory.Evaluation` checks browser readiness, compares every pixel, measures total ink, and writes:

```text
build/evaluation/
|-- difference-18.png
|-- difference-72.png
|-- evaluation.json
|-- generated-18.png
|-- generated-72.png
|-- reference-18.png
|-- reference-72.png
`-- report.html
```

These files are ignored build evidence. They are not deployed, and the generated browser product has no dependency on Poppler.
