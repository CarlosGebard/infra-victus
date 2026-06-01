---
id: victus-infra-operations
title: Victus Infra Operations
status: active
updated_at: 2026-05-27
owners:
  - CarlosGebard/victus-infra
related_services:
  - core
  - observability
  - github-actions
  - infisical
related_docs:
  - 000-SYSTEM-CONTEXT.md
  - 100-ARCHITECTURE.md
  - 300-CONTRACTS.md
  - operations/201-LOCAL-RUNTIME.md
  - operations/202-DEPLOYMENT.md
  - operations/203-SECURITY.md
  - operations/204-TROUBLESHOOTING.md
tags:
  - operations
  - deployment
  - validation
  - troubleshooting
---

# Victus Infra Operations

## Operational Overview

`victus-infra` is operated through local Docker Compose workflows and
production GitHub Actions deployments backed by Ansible.

Operational responsibilities include:

- validating Compose and Ansible definitions before changes are merged.
- starting and inspecting local infrastructure stacks.
- deploying `observability` and `core` to the VPS.
- deploying `llm` when LiteLLM and Langfuse services are used.
- keeping runtime secrets outside git.
- recovering from common service, storage, and event failures.

## Runtime Environments

```text
local        developer machine using Compose files and local overrides
ci           GitHub Actions validation and deployment jobs
production   VPS runtime under /srv managed by Ansible and Docker Compose
```

Important differences:

- Local mode uses checked-in Compose files plus local `.env` files.
- CI mode validates configuration and runs deployment workflows.
- Production mode receives secrets from Infisical through GitHub OIDC.

## Execution Workflows

Primary operational workflows live in focused runbooks:

- [operations/201-LOCAL-RUNTIME.md](operations/201-LOCAL-RUNTIME.md) -> local
  validation, startup, logs, and shutdown.
- [operations/202-DEPLOYMENT.md](operations/202-DEPLOYMENT.md) -> production
  deployment through GitHub Actions and Ansible.
- [operations/203-SECURITY.md](operations/203-SECURITY.md) -> secrets, permissions,
  and pre-push safety checks.
- [operations/204-TROUBLESHOOTING.md](operations/204-TROUBLESHOOTING.md) -> common
  runtime failures and recovery guidance.

## Configuration

Runtime configuration is loaded from:

```text
compose/env/*.env.example          committed examples
compose/projects/*/.env            local uncommitted env files
Infisical                           production secret source
/srv/secrets/runtime/               production runtime secret files
```

Required production secrets are documented in
[operations/203-SECURITY.md](operations/203-SECURITY.md).

## Observability

The `observability` stack provides:

```text
prometheus   metrics collection
loki         log storage and querying
```

Operators should inspect deployment logs in GitHub Actions and service logs
through Docker Compose when validating runtime behavior.

The `llm` stack provides LiteLLM key management and Langfuse LLM tracing.
LiteLLM listens on `4000`; Langfuse listens on host port `3001`; Postgres is internal.

## Failure And Recovery

Operational recovery should prefer idempotent workflows:

- rerun validation before deployment.
- rerun deployment from the same git ref when the failure is transient.
- restart individual services before broad stack resets.
- query Postgres when Redis event history is insufficient for final state.
- avoid deleting production data unless a runbook explicitly allows it.

Common recovery procedures live in
[operations/204-TROUBLESHOOTING.md](operations/204-TROUBLESHOOTING.md).

## Operational Boundaries

This hub owns:

- runtime workflows.
- validation commands.
- deployment flow.
- secret handling expectations.
- monitoring and troubleshooting entrypoints.

This hub does not own:

- system shape and component boundaries.
- stable storage, database, event, or DNS contracts.
- decision history.
- application implementation details.

## Related Documentation

- [000-SYSTEM-CONTEXT.md](000-SYSTEM-CONTEXT.md) -> repository purpose,
  scope, and navigation.
- [100-ARCHITECTURE.md](100-ARCHITECTURE.md) -> system structure and runtime
  flow.
- [300-CONTRACTS.md](300-CONTRACTS.md) -> stable interfaces and invariants.
- [decisions/](decisions/) -> decision records.
