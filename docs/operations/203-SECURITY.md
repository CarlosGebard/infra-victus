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
- LiteLLM and Langfuse are not published directly in production; access goes
  through private NGINX on the Tailscale interface.

## Required Production Secrets

Production runtime secrets live in the Infisical path configured by
`INFISICAL_SECRET_PATH`, currently `Hetzner-Server`.

```text
PROD_HOST
PROD_SSH_PRIVATE_KEY
SEAWEED_S3_ACCESS_KEY
SEAWEED_S3_SECRET_KEY
POSTGRES_PASSWORD
REDIS_PASSWORD
TAILSCALE_IPV4
LLM_POSTGRES_PASSWORD
LITELLM_DB_PASSWORD
LITELLM_MASTER_KEY
LITELLM_SALT_KEY
LITELLM_UI_PASSWORD
LITELLM_DEPLOYMENTS_JSON
LANGFUSE_DB_PASSWORD
LANGFUSE_NEXTAUTH_SECRET
LANGFUSE_SALT
LANGFUSE_ENCRYPTION_KEY
LANGFUSE_PUBLIC_KEY
LANGFUSE_SECRET_KEY
```

LiteLLM provider keys must be stored in Infisical with the `KEY_` prefix:

```text
api-keys/
KEY_GEMINI_FLASH_LITE_01
KEY_GEMINI_FLASH_LITE_02
```

`LITELLM_DEPLOYMENTS_JSON` stores routing metadata only. It references provider
keys by environment variable name through `api_key_env`; it must not contain
secret values.

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
/srv/secrets/runtime/llm.env
```

The production LiteLLM config is generated at deploy time:

```text
/srv/apps/llm/litellm/config.yaml
```

The generated config uses `api_key: os.environ/KEY_NAME`, so provider key values
stay in `/srv/secrets/runtime/llm.env` and are not written to the config file.

Consumer pipelines should call LiteLLM with logical model aliases and a LiteLLM
virtual key. They must not receive provider keys directly.

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
