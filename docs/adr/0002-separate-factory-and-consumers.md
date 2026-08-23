---
type: ADR
title: Separate factory and consumer repositories
description: Keep production PDFs and deployment policy outside the reusable implementation repository.
status: Accepted
timestamp: 2026-08-23
---
# Separate Factory and Consumer Repositories

## Context

The original repository simultaneously owned `Algos.pdf`, Haskell source, templates, generated output, visual evidence, and Pages deployment. PDF discovery and template lookup both used the same root, so another repository could not consume the generator without copying it.

## Decision

The factory owns generator source, shared templates, fixed evaluation policy, and one synthetic integration fixture. A consumer owns exactly one production PDF, its site title, caller trigger, and deployment. Pipeline commands receive independent source, template, output, work, and report paths.

## Rejected Alternatives

- Keep each PDF beside a copied generator: duplicates implementation and causes consumers to drift.
- Keep all production PDFs in the factory: prevents independent ownership and violates the one-PDF discovery contract.
- Accept consumer template overrides: weakens the shared viewer's tested output guarantees.

## Consequences

Consumer repositories stay small, while one factory change can serve many sites. Cross-repository workflow behavior becomes a public interface. The factory needs a synthetic fixture because production content no longer supplies its integration test.

# References

1. [PRD 0002](/prd/0002-reusable-freeform-site-factory.md)
2. [Architecture view](/architecture.md)
