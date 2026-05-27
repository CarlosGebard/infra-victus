---
id: victus-infra-architecture
title: Victus Infra Architecture
status: active
updated_at: 2026-05-27
owners:
  - CarlosGebard/victus-infra
related_docs:
  - 000-SYSTEM-CONTEXT.md
  - 200-OPERATIONS.md
  - 300-CONTRACTS.md
  - decisions/
tags:
  - infrastructure
  - docker-compose
  - ansible
  - vps-runtime
---

# Victus Infra Architecture

## Architectural Overview

`victus-infra` is a repository-owned infrastructure runtime for the Victus
ecosystem.

The system is shaped around a single runtime source of truth:

```text
compose/ -> Docker Compose definitions and service configuration
ansible/ -> host orchestration and deployment of repository-owned files
ops/     -> support tooling for validation, runtime tasks, and migrations
```

Docker Compose defines the service topology. Ansible prepares the VPS,
places runtime files, stages secret-dependent configuration, and starts the
same Compose-defined stacks on the server.

The architecture separates infrastructure by domain so each stack can be
reasoned about and deployed independently.

## Major Components

### Core Stack

The `core` stack owns shared infrastructure required by Victus consumers.

```text
compose/projects/core/
```

Primary responsibilities:

- private and public edge routing
- S3-compatible object storage
- durable registry state
- durable event streaming
- private DNS for shared services

Components:

```text
nginx-private    private HTTP edge
nginx-public     public edge placeholder
seaweedfs        S3-compatible object storage
postgres         durable registry database
redis            durable event stream
etcd             CoreDNS backend state
coredns          private DNS for victus.io
```

Inputs:

- Compose files and environment files from `compose/projects/core/`
- service configs from `compose/configs/`
- runtime secrets staged outside the repository

Outputs:

- private service endpoints for consumer repositories
- persistent runtime data
- event and registry state used by downstream systems

### Observability Stack

The `observability` stack owns runtime visibility.

```text
compose/projects/observability/
```

Components:

```text
grafana      dashboard and inspection surface
prometheus   metrics collection
loki         log storage and querying
```

Inputs:

- Compose files and environment files from `compose/projects/observability/`
- observability configuration from `compose/configs/`

Outputs:

- monitoring and logging surfaces for infrastructure operators
- service health and runtime inspection data

### Deployment Layer

The deployment layer owns host preparation and stack rollout.

```text
ansible/playbooks/
ansible/roles/deploy/
```

Responsibilities:

- prepare expected VPS filesystem structure
- distribute repository-owned Compose and configuration files
- stage runtime configuration that depends on secrets
- execute stack deployment in the expected order

Boundaries:

- Ansible orchestrates deployment; it should not become the source of truth
  for service topology.
- Runtime secrets are injected from external secret management and are not
  committed to the repository.

### Operational Tooling

Operational tooling supports local validation, runtime checks, and shared
database lifecycle tasks.

```text
ops/
tests/
```

Responsibilities:

- validate Compose and Ansible definitions
- support local stack lifecycle
- apply shared database migrations
- perform runtime support tasks that belong to infrastructure

## System Boundaries

### Internal Boundaries

```text
core            shared runtime services for consumers
observability   monitoring and logging services
ansible         host orchestration and deployment
ops             validation and runtime support tooling
docs            repository documentation hubs and nodes
```

Each boundary should remain explicit in paths and documentation.

### External Systems

The architecture depends on external systems for execution and automation:

```text
VPS host          production runtime target
GitHub Actions    deployment automation
Infisical         secret source through OIDC
Docker Engine     container runtime
consumer repos    external systems using shared runtime services
```

### Ownership Limits

This repository owns infrastructure shape and shared runtime contracts.

Consumer repositories own:

- product logic
- app workers
- ingest behavior
- embeddings
- RAG pipelines
- domain-specific processing

## Runtime Flow

### Local Flow

```text
developer
  -> Compose project files
    -> local overrides and env files
      -> local Docker runtime
        -> core and/or observability services
```

Local execution validates the same service topology used for server mode,
with local overrides and local environment values.

### Server Flow

```text
GitHub Actions
  -> Infisical OIDC secrets
    -> Ansible playbooks
      -> VPS filesystem and runtime config
        -> Docker Compose up
          -> deployed stack services
```

Server execution keeps Compose as the runtime definition while Ansible owns
the host-level rollout sequence.

### Consumer Interaction Flow

```text
consumer repository
  -> shared infrastructure endpoint
    -> Postgres for durable registry state
    -> SeaweedFS S3 for artifacts
    -> Redis Streams for durable events
    -> private DNS for service discovery
```

Consumer systems interact with infrastructure through stable endpoints and
shared contracts. Detailed contract guarantees live in
[300-CONTRACTS.md](300-CONTRACTS.md).

## Artifact And Data Flow

The runtime supports artifact and state movement for downstream Victus
systems.

```text
source artifact
  -> SeaweedFS S3 object storage
    -> Postgres registry state
      -> Redis Streams event notification
        -> external consumers and workers
```

Storage, registry, and event stream responsibilities are separated:

- SeaweedFS stores objects and derived artifacts.
- Postgres stores durable state and lifecycle status.
- Redis Streams distributes replayable operational events.
- CoreDNS provides stable private names for shared services.

The architecture treats Postgres as the durable state anchor and Redis Streams
as the operational event transport.

## Quality Attributes

### Reproducibility

Runtime topology is defined in checked-in Compose files, which keeps local
and server execution aligned.

### Portability

Environment-specific behavior is expressed through env files, overrides, and
deployment context rather than separate runtime definitions.

### Operability

Stacks are separated by domain, allowing targeted validation, deployment, and
inspection.

### Recoverability

Persistent data is isolated from runtime configuration through explicit host
filesystem areas and service volumes.

### Observability

Monitoring and logging are modeled as a dedicated stack instead of being
embedded into application or core service ownership.

### Low Coupling

Consumer repositories depend on stable infrastructure endpoints and contracts,
not on internal deployment mechanics.

## External Dependencies

```text
Docker Compose   runtime topology and stack execution
Docker Engine    container runtime on local and server environments
Ansible          host orchestration and deployment
GitHub Actions   CI/CD automation
Infisical        secret retrieval through OIDC
SeaweedFS        S3-compatible object storage
Postgres         durable registry state
Redis Streams    durable event stream
CoreDNS/etcd     private DNS service and backing store
Prometheus       metrics collection
Loki             log aggregation
Grafana          observability UI
```

## Documentation Links

- [000-SYSTEM-CONTEXT.md](000-SYSTEM-CONTEXT.md) -> repository purpose,
  scope, concepts, and documentation map.
- [200-OPERATIONS.md](200-OPERATIONS.md) -> validation, deployment,
  maintenance, and troubleshooting.
- [300-CONTRACTS.md](300-CONTRACTS.md) -> shared guarantees, interfaces,
  schemas, and invariants.
- [decisions/](decisions/) -> decision records when architectural reasoning
  needs to be preserved.
