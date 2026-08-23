---
type: Issue
title: Extract reusable workflow factory
description: Separate production content, expose artifact generation, and migrate the Algorithms consumer.
status: Done
timestamp: 2026-08-23
---
# Extract Reusable Workflow Factory

## Scope

Implement [ADR 0002](/adr/0002-separate-factory-and-consumers.md), [ADR 0003](/adr/0003-build-artifacts-with-a-reusable-workflow.md), and the scenarios in [BDR 0002](/bdr/0002-reusable-workflow-build-contract.md) and [BDR 0003](/bdr/0003-source-independent-mixed-scene-output.md).

## Acceptance Criteria

- Source, templates, output, work, and evidence paths are independent and protected.
- `site-title` is validated and safely rendered by the factory.
- Generic validation accepts vector-only and source-specific scene counts.
- Factory CI invokes the reusable workflow against one synthetic fixture.
- The factory owns no production PDF and performs no Pages deployment.
- `bajor/algos-for-slow-learners` contains only its PDF and caller workflow.
- The Algorithms consumer passes visual evaluation and deploys from its own job.
- Active documentation and review diagrams match the final ownership boundary.

## Completion Evidence

- [Factory PR 9](https://github.com/bajor/notes-website-factory/pull/9) merged the reusable workflow and repository boundary.
- [Consumer PR 1](https://github.com/bajor/algos-for-slow-learners/pull/1) moved `Algos.pdf` and added the caller and deployment workflow.
- [Consumer run 32644996848](https://github.com/bajor/algos-for-slow-learners/actions/runs/32644996848) passed factory tests, real-source evaluation, both artifact uploads, and Pages deployment.
- [Algorithms for Slow Learners](https://bajor.github.io/algos-for-slow-learners/) serves the deployed artifact with the configured title and accessible board label.
