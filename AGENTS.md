# Agent Guide

## Purpose

Maintain a reusable Haskell software factory that converts a consumer repository's one-page Apple Freeform PDF into a validated, zoomable static-site artifact. Consumers own their PDF, title, workflow trigger, and deployment. The factory owns parsing, rendering, evaluation, shared templates, and artifact production.

## Living Docs

enforcement: strict
onboarded: 2026-08-20

## Non-Negotiable Invariants

- A consumer source contains exactly one non-symlink PDF with exactly one page.
- The factory repository contains no production notes PDF; its only PDF is the synthetic integration fixture.
- Production parsing is Haskell using `pdf-toolbox` plus project-owned interpretation and validation.
- The reusable workflow accepts a validated site title and emits artifacts without deploying them.
- Consumer input, factory source, site output, and evaluation evidence use separate paths.
- Generated sites contain no PDF, full-page PDF raster, OCR output, Canvas fallback, or browser PDF parser.
- Substantially transparent Freeform artwork becomes inline SVG. Opaque and near-opaque screenshots stay raster. Ambiguous soft masks fail explicitly.
- Only genuine supported PDF text operators may become DOM text.
- The shared viewer is factory-owned and supports desktop and mobile interactions.
- The project must not require Rust, TypeScript, Node, Vite, Sharp, OpenSeadragon, OCR, or a backend.
- Poppler and Chromium are development and CI evaluation tools only.
- Unsupported content fails explicitly rather than disappearing silently.
- Never allow a removable output, staging, backup, scratch, or report path to equal or contain a protected input root.

## Required Workflow

1. Read `README.md`, `docs/architecture.md`, and `docs/pdf-investigation.md` before changing parser or workflow behavior.
2. Inspect the existing domain and interpreter before adding a type or operator.
3. Make the smallest change supported by a real consumer PDF observation or focused failing test.
4. Keep deterministic transformations pure. Put filesystem and process effects at module boundaries.
5. Add one focused unit test for each new pure behavior. Do not duplicate assertions or use real I/O in unit tests.
6. Run `make test` after every implementation change.
7. Run `make evaluate` after any parser, geometry, rendering, asset, style, template, or browser-runtime change.
8. Inspect `build/evaluation/report.html`, not only the process exit code.
9. Exercise consumer paths separately from factory templates for workflow-boundary changes.
10. Update the supported profile and limitations in `docs/pdf-investigation.md` when behavior changes.
11. Update the indexed PRD, ADR, BDR, issue, glossary, and architecture view required by the strict living-docs policy.

## Module Ownership

- `generator/src/Factory/Domain.hs`: shared vocabulary and invalid-state prevention.
- `generator/src/Factory/Geometry.hs`: authoritative coordinate and matrix math.
- `generator/src/Factory/Interpreter.hs`: pure PDF operator state machine.
- `generator/src/Factory/Vectorize.hs`: pure image classification, quantization, contour tracing, and simplification.
- `generator/src/Factory/Pdf.hs`: `pdf-toolbox` boundary, stream decoding, resource preparation, raster materialization, and annotations.
- `generator/src/Factory/Site.hs`: scene validation, metadata rendering, and deterministic product emission.
- `generator/src/Factory/Evaluation.hs`: Poppler/Chromium feedback loop and thresholds.
- `generator/src/Factory/Pipeline.hs`: command dispatch, source discovery, path protection, staging, and promotion.
- `site/`: shared static templates and browser interaction runtime.
- `.github/workflows/build-pdf-site.yml`: consumer/factory checkout isolation, toolchain setup, evaluation, and artifact upload.

Do not move logic across these boundaries without updating the architecture document and creating a PR-only SVG under `visual-explanations/`.

## Public Workflow Contract

- `site-title` is the only required input.
- `github-pages` is the deployable artifact name.
- `pdf-site-evaluation` is the evidence artifact name.
- Existing required inputs, artifact names, and generated file names are stable public interfaces.
- New workflow inputs must be optional unless all known consumers are migrated in the same coordinated change.
- The workflow may be referenced through `main`; each run must check out factory code at `job.workflow_sha` to prevent internal version drift.
- The reusable workflow must not request Pages write or OpenID Connect token permissions.

## Coding Rules

- Use GHC2021, `-Wall`, `-Wcompat`, and `-Werror`.
- Prefer named domain types and sum types over primitive values and boolean flags.
- Return `Either BuildError value` for expected parser and validation failures.
- Keep functions short and single-purpose. Avoid speculative abstractions and dependencies.
- Preserve deterministic ordering when reading unordered PDF dictionaries.
- Do not add consumer-specific filenames, dimensions, resource names, scene counts, repository names, or URLs.
- Do not weaken evaluation thresholds or make them caller-configurable merely to pass another source.
- Do not commit `dist/`, `build/`, `dist-newstyle/`, generated evaluation images, or Mermaid source.

## Verification

`make test` must prove:

- all Haskell components compile with warnings as errors;
- every focused unit test passes;
- the synthetic one-page fixture can be inspected and built;
- vector-only output is valid without a raster-assets requirement;
- required distribution files exist;
- the runtime contains no Canvas fallback;
- no PDF is present in the generated site;
- generated resource references are relative.

`make evaluate` must additionally prove:

- Chromium reaches `data-ready="true"` after loading generated assets and fonts;
- visual error and ink metrics meet the constants in `Factory.Evaluation` at 18 and 72 DPI;
- `build/evaluation/report.html` and its reference, generated, and difference images are current.

CI must call `.github/workflows/build-pdf-site.yml` as a reusable workflow against the factory fixture. A real consumer migration must additionally pass the same workflow with its own source checkout.

## Completion Criteria

A change is complete only when focused tests, `make test`, `make evaluate`, reusable-workflow linting, the factory CI smoke call, relevant consumer validation, and strict living-docs maintenance pass; evaluation reports are inspected; and no generated or prohibited artifact is staged.
