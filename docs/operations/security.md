---
id: victus-infra-security-operations
title: Security Operations
status: active
updated_at: 2026-05-27
owners:
  - CarlosGebard/victus-infra
---

# Security Operations

## Purpose

This runbook defines operational security expectations for secrets, runtime
files, and pre-push checks.

## Principles

- Secrets do not live in git.
- Infisical provides production secrets through GitHub OIDC.
- GitHub repository variables are only for non-sensitive values.
- Docker socket access is high privilege.
- Internal services should not publish unnecessary ports.

## Required Production Secrets

```text
PROD_HOST
PROD_SSH_PRIVATE_KEY
SEAWEED_S3_ACCESS_KEY
SEAWEED_S3_SECRET_KEY
POSTGRES_PASSWORD
REDIS_PASSWORD
GRAFANA_ADMIN_PASSWORD
```

Optional production secrets:

```text
PROD_SSH_PORT
PROD_SSH_KNOWN_HOSTS
```

## Runtime Secret Files

Production runtime secret files live under:

```text
/srv/secrets/runtime/core.env
/srv/secrets/runtime/seaweed-s3.json
/srv/secrets/runtime/observability.env
```

## Expected Permissions

```text
secrets  0600
configs  0644
data     0750
```

## Network Exposure

Postgres and Redis should only be reachable through the private network.

NGINX does not proxy Postgres or Redis TCP traffic.

## Pre-Push Safety Check

Before pushing infrastructure changes:

- review `git status --short`.
- ensure no `.env` files are staged.
- ensure no `.venv` directories are staged.
- ensure no `__pycache__` files are staged.
- ensure no private keys or passwords are staged.
- ensure workflows do not print secret values.

