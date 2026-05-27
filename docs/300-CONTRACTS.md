---
id: victus-infra-contracts
title: Victus Infra Contracts
status: active
updated_at: 2026-05-27
owners:
  - CarlosGebard/victus-infra
related_components:
  - core
  - seaweedfs
  - postgres
  - redis
  - coredns
related_docs:
  - 000-SYSTEM-CONTEXT.md
  - 100-ARCHITECTURE.md
  - 200-OPERATIONS.md
tags:
  - contracts
  - storage
  - registry
  - events
  - dns
---

# Victus Infra Contracts

## Purpose

This document defines the stable shared contracts owned by `victus-infra`.

These contracts describe the guarantees that consumer repositories may depend
on when using the shared Victus infrastructure runtime.

## Scope

Covered contracts:

- S3-compatible artifact storage.
- Postgres registry state.
- Redis Streams event delivery.
- Private DNS names for shared services.
- Ownership boundaries between infrastructure and consumers.

Out of scope:

- application business logic.
- worker implementation details.
- SDK or bridge implementation internals.
- RAG, embeddings, or domain-specific processing guarantees.
- operational procedures for deploying or repairing services.

## Ownership Contract

`victus-infra` owns:

- shared runtime service definitions.
- shared infrastructure endpoints.
- shared storage buckets and top-level prefixes.
- shared registry schema and database migrations.
- shared event stream names and envelope expectations.
- private DNS names for infrastructure services.

Consumer repositories own:

- application payload semantics.
- worker lifecycle and retry strategy.
- domain-specific artifact contents.
- validation of payloads they produce or consume.
- compatibility with these shared infrastructure contracts.

Consumers must not depend on internal deployment mechanics, container names,
volume names, or Ansible role internals unless a future contract explicitly
promotes those details to stable interfaces.

## S3 Storage Contract

### Scope

S3-compatible object storage is provided by SeaweedFS and exposed through the
shared infrastructure runtime.

The declarative bucket source is:

```text
compose/configs/seaweedfs/buckets.json
```

### Guaranteed Buckets

The following buckets are repository-owned infrastructure buckets:

```text
victus-corpus
victus-rag
victus-backups
victus-tmp
```

### Bucket Responsibilities

```text
victus-corpus    source papers, paper stages, analytics outputs, registry backups
victus-rag       RAG-derived staging data, datasets, exports, and temporary work
victus-backups   backup artifacts not tied to a single paper prefix
victus-tmp       temporary infrastructure-owned objects
```

### Stable Prefixes

`victus-corpus` owns these top-level prefixes:

```text
papers/
analytics/jobs/
analytics/reports/
analytics/reports/2026-05-11/
registry_backups/
```

`victus-rag` owns these top-level prefixes:

```text
staging/
datasets/
exports/
tmp/
```

### Paper Artifact Layout

Paper-scoped artifacts must live under:

```text
papers/{sha256_hash}/
```

Expected paper layout:

```text
papers/{sha256_hash}/raw/source.pdf
papers/{sha256_hash}/stages/01_metadata/
papers/{sha256_hash}/stages/02_normalized/
papers/{sha256_hash}/stages/03_docling/
papers/{sha256_hash}/stages/04_claims/
```

### Guarantees

- `victus-corpus` is the stable bucket for source papers and paper stage
  artifacts.
- `victus-rag` is the stable bucket for RAG-derived artifacts.
- Paper-scoped prefixes use a content hash segment and end with `/`.
- Infrastructure code may create missing declared buckets and prefixes
  idempotently.

### Invariants

- `paper_registry.s3_prefix` must match `^papers/[^/]+/$`.
- RAG-derived artifacts must not be written as source paper artifacts.
- Source paper artifacts must not depend on consumer-specific storage layouts.
- Temporary objects must not be treated as durable contract outputs.

## Postgres Registry Contract

### Scope

Postgres stores durable shared registry state.

Database:

```text
victus_registry
```

Private DNS endpoint:

```text
postgres.victus.io:5432
```

### Source Of Truth

The schema source is:

```text
ops/db/migrations/versions/0001_create_paper_registry.py
```

### Table

```text
paper_registry
```

### Fields

```text
paper_id     text primary key
doi          text null
s3_prefix    text not null
status_proc  paper_proc_status not null default pending
status_rag   paper_rag_status not null default pending
last_event   timestamptz not null default now()
created_at   timestamptz not null default now()
updated_at   timestamptz not null default now()
```

### Status Values

`status_proc` values:

```text
pending
processing
completed
failed
```

`status_rag` values:

```text
pending
indexed
error
```

### Guarantees

- `paper_id` is the durable primary identifier for a paper registry row.
- `s3_prefix` points to the paper-scoped storage prefix.
- `created_at`, `updated_at`, and `last_event` are always present.
- `updated_at` is refreshed by database trigger on row updates.
- Status columns use database enum types, not free-form text.

### Invariants

- `paper_id` must remain stable after creation.
- `s3_prefix` must remain non-null and match `^papers/[^/]+/$`.
- Postgres remains the durable state anchor for paper lifecycle state.
- Redis events must not be treated as the durable source of truth.

## Redis Streams Event Contract

### Scope

Redis provides a durable operational event stream for shared infrastructure
events.

Private DNS endpoint:

```text
redis.victus.io:6379
```

Primary stream:

```text
victus:events
```

Dead letter stream:

```text
victus:events:dead
```

### Event Envelope

Producers write events using the following field contract:

```text
event_type  stable event name
paper_id    paper identifier when the event is paper-scoped
timestamp   unix timestamp
payload     JSON object encoded as a string
```

Event names currently reserved by infrastructure:

```text
victus:artifact:done
victus:stage:started
victus:stage:done
victus:error
```

### Consumer Expectations

External consumers must use Redis Streams consumer groups.

Consumers are responsible for:

- creating or joining their consumer group.
- acknowledging processed messages.
- validating event payloads before acting on them.
- recovering state from Postgres when they need durable truth.
- moving invalid messages to the dead letter stream when appropriate.

### Guarantees

- `victus:events` is replayable through Redis Streams semantics.
- Events require consumer acknowledgement when read through consumer groups.
- `victus:events:dead` is reserved for rejected or unprocessable messages.
- Event delivery is operationally durable but does not replace Postgres state.

### Invariants

- Consumers must not assume Redis Pub/Sub semantics.
- Consumers must not use Redis as the durable registry source of truth.
- Invalid consumer-specific payloads should not block the primary stream
  indefinitely.
- Acknowledgement means the consumer has accepted responsibility for the
  message outcome.

## Private DNS Contract

### Scope

CoreDNS owns private service discovery for shared Victus infrastructure names.

Zone:

```text
victus.io
```

### Stable Names

```text
s3.victus.io
*.s3.victus.io
postgres.victus.io
redis.victus.io
```

### Guarantees

- Shared services should be addressed through private DNS names where
  available.
- Consumer repositories should prefer stable DNS names over container names.
- DNS names describe infrastructure service roles, not implementation details.

### Invariants

- Container names are not public contracts.
- Host paths are not service discovery contracts.
- A DNS name must not be repurposed for an incompatible service role.

## Compatibility Expectations

- Existing bucket names and top-level prefixes should remain backward
  compatible unless a decision record documents a migration.
- Database enum changes must preserve compatibility for existing consumers or
  include an explicit migration path.
- Event names and required envelope fields should remain stable.
- New contracts should be added explicitly before consumers depend on them.
- Contract-breaking changes require a documented migration path.

## Failure Expectations

- Missing buckets or declared prefixes may be recreated idempotently by
  infrastructure tooling.
- Consumers should tolerate duplicate events and use durable state to determine
  final outcomes.
- Consumers should recover from missed event reads by querying Postgres.
- Invalid events should be isolated to `victus:events:dead` rather than
  silently discarded.
- Temporary storage prefixes may be cleaned without preserving consumer state.

## Related Documents

- [000-SYSTEM-CONTEXT.md](000-SYSTEM-CONTEXT.md) -> repository purpose,
  scope, and terminology.
- [100-ARCHITECTURE.md](100-ARCHITECTURE.md) -> system shape, components,
  boundaries, and flows.
- [200-OPERATIONS.md](200-OPERATIONS.md) -> runtime workflows,
  deployment, and troubleshooting.
- [decisions/](decisions/) -> future decision records for contract-changing
  migrations.
