---
id: victus-infra-system-context
title: Victus Infra System Context
status: active
updated_at: 2026-05-27
owners:
  - CarlosGebard/victus-infra
---

# Victus Infra System Context

## Purpose

`victus-infra` defines and operates the shared infrastructure runtime for the
Victus ecosystem.

The repository exists to keep the VPS runtime reproducible, portable, and
safe to deploy. It provides the infrastructure layer used by other Victus
repositories, but it does not contain product application code.

The core idea is:

```text
one runtime source of truth, two execution modes: local and server
```

## System Goals

- Keep Docker Compose as the source of truth for runtime services.
- Use Ansible to prepare the host and deploy repository-owned runtime files.
- Support local validation before server deployment.
- Keep secrets outside the repository.
- Separate infrastructure domains so stacks can evolve and deploy independently.
- Provide stable shared contracts for storage, registry state, events, and DNS.

### Non-Goals

- Implement application business logic.
- Own app-specific workers, pipelines, embeddings, or RAG behavior.
- Use the VPS as the primary test environment.
- Generate runtime configuration from Ansible when checked-in config is enough.

## Repository Scope

This repository owns:

- Docker Compose definitions for shared Victus infrastructure stacks.
- Runtime configuration files distributed to the VPS.
- Ansible playbooks, roles, and inventory for deployment.
- Operational scripts for local and runtime support tasks.
- Database migrations for shared infrastructure state.
- Documentation for context, architecture, operations, contracts, and decisions.

This repository does not own:

- Product application source code.
- Consumer repositories that use the shared infrastructure.
- Private runtime secrets.
- App-specific data processing logic.
- Long-term product roadmap outside infrastructure concerns.

## Documentation Map

This repository is moving toward a Hub-and-Node documentation model:

```text
docs/000-SYSTEM-CONTEXT.md    repository purpose, scope, concepts, navigation
docs/100-ARCHITECTURE.md      system shape, components, runtime boundaries
docs/200-OPERATIONS.md        validation, deploy, maintenance, troubleshooting
docs/300-CONTRACTS.md         shared guarantees, interfaces, schemas, invariants
docs/decisions/               decision records and architectural rationale
```

Current documentation nodes:

- [README.md](../README.md) -> short project entrypoint and common commands.
- [100-ARCHITECTURE.md](100-ARCHITECTURE.md) -> current architecture hub.
- [200-OPERATIONS.md](200-OPERATIONS.md) -> current operations hub.
- [300-CONTRACTS.md](300-CONTRACTS.md) -> current contracts hub.
- [operations/local-runtime.md](operations/local-runtime.md) -> local
  runtime usage.
- [operations/deployment.md](operations/deployment.md) -> deployment
  workflow.
- [operations/security.md](operations/security.md) -> secrets and safety
  checks.
- [operations/troubleshooting.md](operations/troubleshooting.md) -> common
  recovery procedures.
- [operations/roadmap.md](operations/roadmap.md) -> operational roadmap.

## Core Concepts

`runtime source of truth`
: The Compose files in this repository define what runs. Deployment tooling
copies and starts them; it should not redefine the stack.

`stack`
: A deployable service group with a clear domain boundary. Current stacks are
`core` and `observability`.

`core`
: Shared infrastructure required by Victus consumers, including private edge
routing, object storage, durable registry state, event streaming, and private
DNS.

`observability`
: Monitoring and logging services used to inspect runtime health.

`private DNS`
: Internal service naming under the `victus.io` zone, backed by CoreDNS.

`shared contracts`
: Stable expectations exposed to other repositories, including S3 layout,
Postgres registry schema, Redis Streams usage, and DNS names.

`local mode`
: Developer validation mode using local Compose overrides and test env files.

`server mode`
: Production mode where Ansible prepares the host and deploys the same
repository-owned runtime definitions.

## Repository Structure

```text
compose/   Docker Compose projects, environment examples, and service configs
ansible/   VPS deployment playbooks, roles, inventory, and group vars
ops/       operational scripts, checks, and database migration tooling
tests/     validation scripts for deployment automation
docs/      current documentation nodes during the documentation migration
.github/   GitHub Actions workflows and deployment notes
```

## Design Principles

- Prefer small, explicit changes over broad infrastructure rewrites.
- Keep infrastructure and application concerns separate.
- Preserve one source of truth for runtime definitions.
- Make local validation meaningful before production deployment.
- Keep domain boundaries visible in paths, stack names, and documentation.
- Treat contracts as stable interfaces for consuming repositories.
- Keep operational behavior reproducible and scriptable.
- Optimize documentation for safe navigation by humans and AI agents.
