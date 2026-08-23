---
type: ADR
title: Build artifacts with a reusable workflow
description: Centralize generation and evaluation while leaving Pages deployment to consumers.
status: Accepted
timestamp: 2026-08-23
---
# Build Artifacts with a Reusable Workflow

## Context

GitHub Pages deployment requires write and OpenID Connect permissions tied to the consumer's branch and environment policy. The factory needs its co-located Haskell and template files, while the default checkout in a called workflow resolves to the caller repository.

## Decision

Expose `.github/workflows/build-pdf-site.yml` through `workflow_call`. It checks out the caller as the source and checks out `job.workflow_repository` at `job.workflow_sha` as the factory. It tests, builds, evaluates, and uploads `github-pages` plus `pdf-site-evaluation`. The consumer runs `actions/deploy-pages` in a separate job.

Known consumers reference `main`. Therefore the workflow input, artifact names, and generated filenames are stable public contracts, and new runs intentionally receive the latest merged factory behavior. The exact workflow commit still selects the matching factory implementation within each run.

## Rejected Alternatives

- Deploy inside the reusable workflow: centralizes permissions and environment policy that belong to consumers.
- Check out factory `main` independently: can mismatch a workflow loaded from another commit.
- Publish a compiled binary or container action: adds release machinery without improving the current Haskell workflow boundary.
- Require consumer templates: duplicates the shared viewer.

## Consequences

Consumers need a small build job and deployment job. Pull requests can validate without Pages write permissions. A failed build leaves the previous deployment intact. Referencing `main` means compatibility discipline and the factory CI smoke call are mandatory.

# References

1. [PRD 0002](/prd/0002-reusable-freeform-site-factory.md)
2. [BDR 0002](/bdr/0002-reusable-workflow-build-contract.md)
3. [GitHub reusable workflow documentation](https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows)
