---
id: wikijs-central-documentation
title: Wiki.js is the central documentation system
status: accepted
date: 2026-08-25
---

# Wiki.js is the central documentation system

## Context

Backstage and external TechDocs added a CI, runner, object-storage, catalog,
and authentication dependency chain for documentation updates.

## Decision

Serve Wiki.js at `wiki.victus.fit`. Pages are edited in Wiki.js and stored in
its PostgreSQL database. Repository documentation is not synchronized.

## Consequences

The documentation runtime has only Wiki.js, PostgreSQL, NGINX routing, and its
existing host-side runtime env. The old TechDocs data is not deleted by this
change; it can be removed after Wiki.js is verified.
