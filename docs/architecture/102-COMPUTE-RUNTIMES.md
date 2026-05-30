---
id: victus-infra-compute-runtimes-architecture
title: Compute Runtimes Architecture
status: active
updated_at: 2026-05-30
owners:
  - CarlosGebard/victus-infra
related_docs:
  - ../100-ARCHITECTURE.md
  - ../operations/202-DEPLOYMENT.md
tags:
  - docker-compose
  - ansible
  - runtime
---

# Compute Runtimes Architecture

## Overview

Docker Compose is the runtime source of truth. Ansible prepares the host,
stages configuration, and starts the Compose-defined stacks.

## Stacks

```text
core            shared runtime services
observability   metrics, logs, and dashboards
llm             LLM gateway, key management, tracing, and audit
```

## Runtime Modes

```text
local        Compose base files plus dev overlays
production   Compose base files plus prod overlays staged under /srv/apps
```

## Deployment Flow

Production deployment runs through GitHub Actions and Ansible:

```text
validate -> preflight -> deploy-observability -> deploy-core -> deploy-llm -> verify
```

## Ownership Boundary

Ansible owns host orchestration. Compose owns service topology. Runtime secrets
are external and staged as env files before Compose starts services.
