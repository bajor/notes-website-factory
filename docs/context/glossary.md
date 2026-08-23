---
type: Context
title: Project glossary
description: Definitions for PDF rendering, workflow reuse, artifacts, and evaluation.
timestamp: 2026-08-23
---
# Glossary

## Image XObject

A named PDF image resource invoked by a content-stream `Do` operator.

## Soft Mask

A grayscale PDF image that supplies per-pixel opacity for another image resource.

## Vector Artwork

A scene node containing normalized, closed SVG paths traced from an eligible embedded image.

## Raster Asset

An extracted PNG or JPEG file whose source pixels remain pixels in the generated site.

## Evaluation Oracle

Poppler's development-only rendering of the source PDF, used as an independent visual reference for Chromium output.

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
