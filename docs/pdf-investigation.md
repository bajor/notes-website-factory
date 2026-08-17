# PDF Engine Investigation

The implementation uses Poppler CLI tools from `poppler-utils`.

Poppler is a mature PDF parser and renderer used by common Linux PDF tooling. The generator delegates page-count validation, page box inspection, annotation extraction, and raster rendering to Poppler commands instead of implementing PDF internals.

Selected commands:

- `pdfinfo -box`: page count, `MediaBox`, `CropBox`, rotation.
- `qpdf --json`: URI link annotation rectangles and URLs.
- `pdftoppm -png -singlefile -r <dpi>`: deterministic page rasterization.

The tile format is PNG Deep Zoom Image. PNG was selected for the initial implementation because it preserves thin handwriting and small text without lossy artifacts. WebP can reduce output size later, but PNG is the safer default for visual fidelity.

Poppler is GPL-licensed. QPDF uses the Apache License 2.0. This repository invokes both tools as external commands in local development and CI rather than linking either implementation into the Rust binary.
