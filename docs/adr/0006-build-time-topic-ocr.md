---
type: ADR
title: Build topic navigation with source-pixel detection and local OCR
description: Detect highlighter frames before vectorization and label their board-space targets with local Tesseract.
status: Accepted
timestamp: 2026-08-29
---
# Build Topic Navigation with Source-Pixel Detection and Local OCR

## Context

The observed Freeform export stores a highlighter frame and its handwritten heading in overlapping image XObjects. Existing vector tracing preserves their appearance but discards original alpha, source dimensions, and object identity after conversion. The browser therefore cannot recover either a reliable frame target or text from the emitted SVG contours.

The topic index is interaction chrome rather than a source rendering. It needs stable board-space bounds, best-effort English labels, no runtime service, and no consumer secret. The user selected lightweight Tesseract and accepted imperfect handwriting recognition over a larger handwriting model or cloud service.

## Decision

We will detect highlighter frames from decoded RGBA image resources before vectorization. A pure relative-geometry classifier will require a visible chromatic border around a substantially empty interior and will reject thin, open, filled, or achromatic candidates. The interpreter will map accepted inner and outer rectangles through the same axis-aligned image transform used by the scene.

`Factory.Topic` will own pure detection, board-space ordering, crop preparation, and OCR-label normalization. `Factory.Ocr` will own per-frame Poppler crops and local `tesseract -l eng --psm 7` process execution. `Factory.Pipeline` will keep temporary crops inside removable staging space and remove them before site promotion. `Factory.Domain` will represent a non-empty `TopicLabel` paired with board-space bounds; `Factory.Site` will serialize topics separately from source-ordered scene nodes.

OCR output will be used only in normal-mode navigation controls. A successful empty result becomes `Topic N`; process failures remain typed build failures. The workflow interface gains no input or secret.

## Rejected Alternatives

- OCR the full page: the observed board is too large for an efficient high-resolution raster and would include unrelated handwriting.
- Infer topics from emitted SVG paths in the browser: vectorization has already discarded source alpha and component semantics, and browser recognition would add a runtime toolchain.
- Use a handwriting transformer model: it improves recognition at the cost of a large model, Python inference stack, download, and longer CI builds.
- Use cloud OCR: it adds credentials, network availability, cost, and a provider dependency to every build.
- Restrict detection to yellow: consumer-independent behavior cannot rely on one source hue.

## Consequences

Poppler moves from evaluation-only use to narrowly cropped build-time rendering, and Tesseract becomes a required build tool. The deployed site remains static and tool-free. Topic labels can contain recognition mistakes, but they cannot alter source pixels or visual evaluation. Relative detector constants become fixed factory policy and require real-source evidence before adjustment.

The fitness functions are multi-hue detector unit tests, process and serialization tests, normal-mode Chromium interaction tests, unchanged visual evaluation thresholds, and inspection of all 12 targets in consumer revision `1bdf230`.

## Verification

- `Factory.Topic` contains no filesystem or process effects.
- `Factory.Ocr` renders only bounded topic crops and returns typed failures.
- `scene.generated.js` separates `topics` from source-ordered `nodes`.
- The Pages artifact contains no PDF, crop, OCR model, or OCR executable.
- `make test`, `make evaluate`, and real-consumer evaluation pass.

# References

1. [OCR topic navigation requirements](/prd/0005-ocr-topic-navigation.md)
2. [Topic navigation behavior](/bdr/0006-topic-index-navigation.md)
3. [Vector-first mixed rendering](/adr/0001-vector-first-mixed-rendering.md)
4. [Tesseract OCR project](https://github.com/tesseract-ocr/tesseract)
