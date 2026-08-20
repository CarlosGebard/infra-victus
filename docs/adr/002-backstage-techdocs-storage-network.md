---
id: 002
title: Backstage reads TechDocs through the Core network
status: accepted
updated_at: 2026-08-20
owners: victus-fit
---

## Context

Backstage reads generated TechDocs from the private SeaweedFS S3 endpoint.
SeaweedFS is reachable only on the Core Docker network.

## Decision

Attach the Backstage service to the existing external `core_core_backend`
network. It uses `http://seaweedfs:8333`; the database remains isolated on the
Backstage network.

## Consequences

No S3 port is exposed publicly and no registry or S3 credentials are copied to
individual documentation repositories.
