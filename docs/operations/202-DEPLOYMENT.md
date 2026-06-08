---
id: victus-infra-deployment-operations
title: Deployment Operations
status: active
updated_at: 2026-05-27
owners:
  - CarlosGebard/victus-infra
---

# Deployment Operations

## Purpose

This runbook describes production deployment through GitHub Actions, Infisical,
Tailscale, SSH, and Docker Compose.

## Primary Workflow

Production deploys use the full sequential workflow:

```text
.github/workflows/deploy-all.yml
```

The workflow deploys stacks in order:

```text
observability -> core -> llm
                    \-> wiki
```

The `observability` stack is deployed first so monitoring is available before
the core stack is rolled out. The `llm` and `wiki` stacks are deployed after
core so the shared Docker network and edge routing are already present.

Internal job order:

```text
validate -> preflight -> deploy-observability -> deploy-core -> deploy-llm -> verify
                                                   \-> deploy-wiki -/
```

## Trigger

Manual:

```text
GitHub Actions -> Deploy All Stacks -> Run workflow
```

Manual input:

```text
git_ref    branch, tag, or commit to deploy
```

## Secret Source

Production secrets come from Infisical through GitHub OIDC. Secrets are not
stored in git or GitHub repository secrets.

The deploy workflow reads scoped Infisical paths:

```text
/Hetzner-Server/global     host access and shared deploy secrets
/Hetzner-Server/core       core stack runtime secrets
/Hetzner-Server/llm        LiteLLM and Langfuse runtime secrets
/Hetzner-Server/wiki       Wiki.js runtime secrets
/Hetzner-Server/api-keys   provider API keys named KEY_*
```

Required secrets are listed in [security.md](security.md).

The deployment workflow pulls secrets from Infisical, validates host readiness
with Ansible, materializes stack runtime files in the runner, packages each
stack into a small archive, copies the archive to the host over SSH, and runs
`docker compose up -d --remove-orphans` remotely in dependency order.

## Validation

The full sequential workflow validates:

- required secrets are present.
- Ansible playbook syntax is valid.
- Docker Compose configuration is valid.
- SSH connectivity works.
- target host has Docker and Compose available.

## Runtime Files

Workflows materialize temporary runtime files and copy them into the server
runtime layout over SSH.

Expected production locations:

```text
/srv/apps/
/srv/data/
/srv/logs/
/srv/secrets/runtime/
/srv/backups/
```

## Post-Deployment Verification

The workflow verifies expected containers are running, including:

```text
nginx-private
nginx-public
seaweedfs
loki
prometheus
llm-postgres
litellm
langfuse
wiki
wiki-database
```

LLM service endpoints:

```text
LiteLLM    http://litellm.victus.io
Langfuse   http://langfuse.victus.io
Postgres   internal Docker network only
```

The `llm` deploy does not publish LiteLLM or Langfuse service ports directly.
Private NGINX binds to `TAILSCALE_IPV4` and proxies to the services over
`infra_shared_backend`.

Wiki.js is published through `nginx-public` and proxies to `wiki:3000` over
`infra_shared_backend`. The default production hostname is:

```text
https://wiki.victus.fit
```

If `nginx-private` also binds port `80`, `sync-core-dns.sh` derives
`NGINX_PUBLIC_BIND_IP` from the VPS public route so public and private NGINX do
not compete for the same host socket. Override `NGINX_PUBLIC_BIND_IP` in
`CORE_RUNTIME_ENV` only when the host has multiple public IPv4 addresses.

To preserve an existing Wiki.js database from the previous media stack, set
this in `WIKI_RUNTIME_ENV` before deploy:

```text
WIKIJS_DB_DATA_LOCATION=/srv/data/media/wiki/postgres
```

After the first Langfuse login, create a Langfuse project, generate API keys,
update `LANGFUSE_PUBLIC_KEY` and `LANGFUSE_SECRET_KEY` in Infisical, and
rerun the deployment.

## LiteLLM Runtime Deployments

LiteLLM deployments are defined in Infisical through `LITELLM_DEPLOYMENTS_JSON`.
Each entry references a provider key by env var name:

```json
[
  {
    "model_name": "gemini-flash-lite",
    "model": "gemini/gemini-3.1-flash-lite",
    "api_key_env": "KEY_GEMINI_FLASH_LITE_01",
    "rpm": 15,
    "tpm": 100000
  }
]
```

To add a Gemini key:

1. Add `KEY_GEMINI_FLASH_LITE_NN` in Infisical under `/Hetzner-Server/api-keys`.
2. Add one deployment object referencing that env var.
3. Rerun the deploy workflow.

To change limits, edit `rpm` or `tpm` in `LITELLM_DEPLOYMENTS_JSON` and rerun
the deploy workflow. Ansible regenerates:

```text
/srv/apps/llm/litellm/config.yaml
```

LiteLLM uses `simple-shuffle` routing, so multiple entries with the same
`model_name` balance/fail over across deployments.

Validate through the private endpoint:

```bash
curl http://litellm.victus.io/v1/models \
  -H "Authorization: Bearer <LITELLM_VIRTUAL_KEY>"
```

For request traces, inspect the Langfuse project linked by
`LANGFUSE_PUBLIC_KEY` and `LANGFUSE_SECRET_KEY`.

Manual inspection:

```bash
ssh carlos@<PROD_HOST> "docker ps --all"
```

## GitHub CLI Monitoring

```bash
gh run list --workflow=deploy-all.yml
gh run view <run-id> --log
```

## Rollback Expectation

Prefer redeploying a known-good git ref through the deployment workflow.

Manual rollback on the host should be treated as an emergency operation and
followed by a repository-backed deployment to restore source-of-truth
alignment.
