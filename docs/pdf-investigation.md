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
- 1 HTTP URI annotation that identifies a YouTube video;
- no PDF font resources or text-showing operators.

The board's visible handwriting is already raster data inside image XObjects. Turning those pixels into browser text would require optical character recognition, which is intentionally outside this project. The generator preserves those pixels as extracted image assets. The scene and browser types can represent DOM text, but production parsing rejects PDF text until font decoding, glyph metrics, and positioning are implemented.

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

Unsupported operators fail with a typed error. Some unsupported structures have dedicated errors, while others are rejected by scene validation. A future parser increment should begin with a real source file demonstrating one missing feature, then add one focused test and one minimal implementation.

## Evaluation Oracle

Poppler's `pdftoppm` renders a low-resolution reference PNG only for development evaluation. Headless Chromium renders the generated site at the same dimensions. `Factory.Evaluation` checks browser readiness, compares every pixel, measures total ink, and writes:

```text
build/evaluation/
|-- difference.png
|-- evaluation.json
|-- generated.png
|-- reference.png
`-- report.html
```

These files are ignored build evidence. They are not deployed, and the generated browser product has no dependency on Poppler.
