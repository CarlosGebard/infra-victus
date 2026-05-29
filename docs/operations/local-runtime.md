---
id: victus-infra-local-runtime
title: Local Runtime Operations
status: active
updated_at: 2026-05-27
owners:
  - CarlosGebard/victus-infra
---

# Local Runtime Operations

## Purpose

This runbook describes local validation and local execution for the shared
Victus infrastructure runtime.

## Requirements

- Docker
- Docker Compose
- Python 3.12+
- `uv`
- Ansible for validation and deployment checks

## Configuration

Committed examples:

```text
compose/env/core.env.example
compose/env/observability.env.example
compose/env/llm.env.example
```

Local runtime env files:

```text
compose/projects/core/.env
compose/projects/observability/.env
compose/projects/llm/.env
```

Local `.env` files are not committed.

## Validate

Run from the repository root:

```bash
make ansible-check
make compose-validate
```

## Start Core

```bash
make core-up
```

This workflow:

- creates the shared Docker network `infra_shared_backend`.
- starts the `core` stack.
- syncs local private DNS.
- applies the S3 bucket and prefix contract idempotently.

## Inspect Core

```bash
docker compose \
  --env-file compose/projects/core/.env \
  -f compose/projects/core/compose.yml \
  -f compose/projects/core/compose.dev.yml \
  ps
```

## Logs

```bash
make core-logs
```

## Stop Core

```bash
make core-down
```

## Run LLM Stack

Create the shared Docker network, then start the stack:

```bash
./ops/scripts/local/ensure-shared-network.sh
docker compose \
  --env-file compose/projects/llm/.env \
  -f compose/projects/llm/compose.yml \
  -f compose/projects/llm/compose.dev.yml \
  up -d
```

Local endpoints:

```text
LiteLLM    http://127.0.0.1:4000
Langfuse   http://127.0.0.1:3001
Postgres   127.0.0.1:55432
```

Production binds LiteLLM and Langfuse to `TAILSCALE_IPV4`, not localhost.

Provider API keys are added through the LiteLLM UI and persisted in the
LiteLLM Postgres database. They should not be committed to git.

## Bridge Smoke Check

```bash
cd ops/bridge
UV_PROJECT_ENVIRONMENT=/tmp/victus-bridge-uv-env uv run victus-ingest --help
```

Expected local bridge variables:

```text
VICTUS_PG_DSN=postgresql://victus:<password>@postgres:5432/victus_registry
VICTUS_REDIS_URL=redis://:<password>@redis:6379/0
VICTUS_S3_ENDPOINT=http://seaweedfs:8333
VICTUS_S3_ACCESS_KEY=<access-key>
VICTUS_S3_SECRET_KEY=<secret-key>
VICTUS_S3_BUCKET=victus-corpus
VICTUS_AWS_REGION=us-east-1
```

Expected variables from other hosts in the private network:

```text
VICTUS_PG_DSN=postgresql://victus:<password>@postgres.victus.io:5432/victus_registry
VICTUS_REDIS_URL=redis://:<password>@redis.victus.io:6379/0
VICTUS_S3_ENDPOINT=http://s3.victus.io
```
