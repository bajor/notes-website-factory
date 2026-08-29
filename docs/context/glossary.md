---
type: Context
title: Project glossary
description: Definitions for PDF rendering, topic navigation, workflow reuse, artifacts, and evaluation.
timestamp: 2026-08-29
---
# Glossary

## Image XObject

A named PDF image resource invoked by a content-stream `Do` operator.

## Soft Mask

A grayscale PDF image that supplies per-pixel opacity for another image resource.

## Traceable Alpha Sample

A soft-mask sample at or above alpha `96` that the current vector tracer can retain. Nonzero samples below the cutoff are source content and remain raster when a mask contains no traceable sample.

## Vector Artwork

A scene node containing normalized, closed SVG paths traced from an eligible embedded image.

## Raster Asset

An extracted PNG or JPEG file whose source pixels remain pixels in the generated site.

## Miter Limit

A PDF graphics-state value that limits the length of sharp corners formed by miter-joined strokes. The dimensionless value remains unchanged under a supported similarity transform and is emitted as SVG `stroke-miterlimit`.

## Dash Pattern

A PDF graphics-state pair containing a nonnegative segment-length array and a numeric phase. A supported similarity transform scales both uniformly before the factory emits SVG `stroke-dasharray` and `stroke-dashoffset`.

## Similarity Transform

A non-singular affine transform whose linear part combines translation, rotation, reflection, and uniform scale without shear or non-uniform scale. Such a transform preserves angles and allows a PDF native stroke to remain representable by scalar SVG line-width and dash values.

## Named Color Space

A color space selected by a resource name in a PDF content stream. The supported profile resolves one-component and three-component ICC-based resources to grayscale or RGB component interpretation.

## Affine Image Transform

A six-number matrix that can translate, scale, rotate, or shear embedded artwork. The browser composes this PDF matrix with the opposite vertical orientation used by image samples and DOM images.

## Game Link

A typed scene link whose structurally parsed URI matches the documented HTTPS Algo Arcade game-route profile. The normal viewer marks it with a gamepad badge and opens the original URI in a new tab.

## Evaluation Mode

The non-interactive browser rendering mode selected by the evaluator at a specific dots-per-inch scale. It hides controls and synthesized game badges so screenshots contain only PDF-derived scene content.

## Evaluation Oracle

Poppler's development-only rendering of the source PDF, used as an independent visual reference for Chromium output.

## Topic Frame

A closed, thick, chromatic border detected from a Freeform image XObject before vectorization. Its inner rectangle supplies an OCR crop, and its outer board-space rectangle supplies a navigation target.

## Topic Index

The normal-mode `Topics` disclosure whose labels come from build-time OCR and whose actions navigate to stored topic-frame bounds. It is interaction metadata rather than reconstructed source content.

## OCR

Optical character recognition. The factory runs local English Tesseract on bounded topic crops during the build; no OCR engine or source crop enters the generated site.

## Factory Repository

The `notes-website-factory` repository that owns generator source, shared viewer templates, evaluation policy, synthetic fixtures, and the reusable build workflow.

## Consumer Repository

A repository that owns exactly one production PDF, its site title, caller trigger, and Pages deployment policy.

## Reusable Workflow

A workflow declared with GitHub Actions `workflow_call` and invoked as a job from another workflow.

## Caller Workflow

The consumer-owned workflow that selects event triggers, passes `site-title`, grants permissions, and invokes the reusable workflow.

## Pages Artifact

The artifact named `github-pages` that contains the validated static site in the format expected by GitHub Pages deployment actions.

## Evaluation Artifact

The artifact named `pdf-site-evaluation` that contains visual references, generated screenshots, difference images, metrics, and the HTML report.

## Workflow SHA

The commit identifier exposed as `job.workflow_sha` for the workflow file defining a reusable-workflow job. The factory uses it to check out matching implementation source.

## OIDC

OpenID Connect, the token protocol used by GitHub Pages to verify deployment identity. Only the consumer deployment job receives permission to request this token.
