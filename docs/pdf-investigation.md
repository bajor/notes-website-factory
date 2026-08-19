# PDF Tooling

The generator deliberately does not implement PDF parsing or rendering.

## Poppler

Poppler is a mature PDF implementation used by common Linux PDF tools. The build invokes:

- `pdfinfo -box` for page count, MediaBox, CropBox, and page rotation;
- `pdftoppm -png -singlefile` for deterministic, high-resolution page rendering.

Poppler is GPL-licensed. It is invoked as an external build-time command and is not shipped with the static site.

## QPDF

`qpdf --json` provides the page object graph, URI link annotations, and annotation rectangles. Recoverable QPDF warnings remain visible in local and CI logs; the real iOS export currently reports two unused objects with zero offsets. QPDF uses the Apache License 2.0 and is invoked as an external build-time command.

## Sharp And libvips

Sharp uses libvips to transform the Poppler PNG into a standards-compliant Deep Zoom pyramid. Sharp uses the Apache License 2.0; libvips uses the GNU Lesser General Public License 2.1 or later. Both are build-time dependencies and are absent from the deployed site.

This division keeps PDF interpretation in production-proven PDF software and limits project-owned logic to validation, coordinate conversion, URL classification, deterministic metadata, and orchestration.
