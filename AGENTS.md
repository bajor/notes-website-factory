# Agent Guide

## Purpose

Maintain an educational Haskell software factory that converts the repository's one-page Apple Freeform PDF into a static JavaScript DOM/SVG site with raster screenshots.

## Living Docs

enforcement: strict
onboarded: 2026-08-20

## Non-Negotiable Invariants

- The repository input is exactly one non-symlink PDF containing exactly one page.
- Production parsing is Haskell using `pdf-toolbox` plus project-owned interpretation and validation.
- `dist/` must not contain a PDF, full-page PDF raster, OCR output, or browser PDF parser.
- Substantially transparent Freeform artwork becomes inline SVG. Opaque and near-opaque screenshots stay raster. Ambiguous soft masks fail explicitly.
- Only genuine supported PDF text operators become DOM text.
- The project must not require Rust, TypeScript, Node, Vite, Sharp, OpenSeadragon, OCR, or a backend.
- Poppler and Chromium are development evaluation tools only.
- Unsupported content must fail explicitly rather than disappear silently.
- Never allow an output path to equal or contain the repository root.

## Required Workflow

1. Read `README.md`, `docs/architecture.md`, and `docs/pdf-investigation.md` before changing parser behavior.
2. Inspect the existing domain and interpreter before adding a type or operator.
3. Make the smallest change supported by a real PDF observation or failing test.
4. Keep deterministic transformations pure. Put filesystem and process effects at module boundaries.
5. Add one focused unit test for each new pure behavior. Do not duplicate assertions or use real I/O in unit tests.
6. Run `make test` after every implementation change.
7. Run `make evaluate` after any parser, geometry, rendering, asset, style, or browser-runtime change.
8. Inspect `build/evaluation/report.html`, not only the process exit code.
9. Update the supported profile and limitations in `docs/pdf-investigation.md` when behavior changes.
10. Update the indexed PRD, ADR, BDR, issue, and architecture view required by the strict living-docs policy.

## Module Ownership

- `generator/src/Factory/Domain.hs`: shared vocabulary and invalid-state prevention.
- `generator/src/Factory/Geometry.hs`: authoritative coordinate and matrix math.
- `generator/src/Factory/Interpreter.hs`: pure PDF operator state machine.
- `generator/src/Factory/Vectorize.hs`: pure image classification, color quantization, contour tracing, and simplification.
- `generator/src/Factory/Pdf.hs`: `pdf-toolbox` boundary, stream decoding, resource preparation, raster materialization, and annotations.
- `generator/src/Factory/Site.hs`: scene validation and deterministic product emission.
- `generator/src/Factory/Evaluation.hs`: Poppler/Chromium feedback loop and thresholds.
- `generator/src/Factory/Pipeline.hs`: command dispatch, discovery, staging, and promotion.
- `site/`: handwritten static templates and the browser interaction runtime.

Do not move logic across these boundaries without updating the architecture document and creating a PR-only SVG under `visual-explanations/`.

## Coding Rules

- Use GHC2021, `-Wall`, `-Wcompat`, and `-Werror`.
- Prefer named domain types and sum types over primitive values and boolean flags.
- Return `Either BuildError value` for expected parser and validation failures.
- Keep functions short and single-purpose. Avoid speculative abstractions and dependencies.
- Preserve deterministic ordering when reading unordered PDF dictionaries.
- Do not weaken an evaluation threshold merely to make a change pass. Explain and verify any threshold change against both valid and intentionally incomplete output.
- Do not commit `dist/`, `build/`, `dist-newstyle/`, generated evaluation images, or Mermaid source.

## Verification

`make test` must prove:

- all Haskell components compile with warnings as errors;
- every focused unit test passes;
- the real repository PDF can be inspected;
- the real repository PDF builds a valid site;
- required distribution files and extracted assets exist;
- the current PDF emits 35 vector artwork nodes, 9 raster image nodes, and exactly 9 raster assets;
- the runtime contains no Canvas fallback;
- no PDF is present in `dist/`;
- generated resource references are relative.

`make evaluate` must additionally prove:

- Chromium reaches `data-ready="true"` after loading generated assets and fonts;
- visual error and ink metrics meet the constants in `Factory.Evaluation` at 18 and 72 DPI;
- `build/evaluation/report.html` and its reference, generated, and difference images are current.

## Completion Criteria

A change is complete only when its focused tests pass, `make test` passes, visual changes pass `make evaluate`, documentation reflects any changed support boundary, and no generated or prohibited artifact is staged.
