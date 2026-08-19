---
id: 001
title: Central TechDocs publication
status: accepted
updated_at: 2026-08-19
owners: victus-fit
---

## Context

Several repositories publish TechDocs, but publication credentials must not be copied into each repository.

## Decision

`victus-infra` owns a reusable GitHub workflow. Documentation repositories invoke it, while one organization-scoped Infisical OIDC identity is restricted to that reusable workflow and can read the existing TechDocs credential path.

## Tradeoffs

Publication depends on `victus-infra`'s default branch and the VPS runner. The credential is shared with Backstage, so it has write access instead of separate read/write identities.

## Alternatives considered

Repository secrets duplicate credentials and create rotation work. A separate identity per documentation repository creates the same policy-management burden.

## Consequences

Each documentation repository grants `id-token: write` and calls the central workflow; it does not store S3 credentials.
