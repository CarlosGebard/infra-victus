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
Ansible, and Docker Compose.

## Primary Workflow

Production deploys use:

```text
.github/workflows/deploy-all.yml
```

Deployment order:

```text
validate -> preflight -> deploy-observability -> deploy-core -> deploy-llm -> verify
```

Stack dependency:

```text
observability -> core -> llm
```

The `observability` stack is deployed first so monitoring is available before
the core stack is rolled out. The `llm` stack is deployed after core so the
shared Docker network is already present.

## Triggers

Automatic:

```text
push to main touching infrastructure paths
```

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

Required secrets are listed in [security.md](security.md).

The workflow pulls secrets from Infisical into GitHub Actions environment
variables, materializes stack-specific runtime env files under `/tmp`, then
passes those file paths to Ansible. Ansible copies them into
`/srv/secrets/runtime/` with `0600` permissions.

## Validation

The deployment workflow validates:

- required secrets are present.
- Ansible playbook syntax is valid.
- Docker Compose configuration is valid.
- SSH connectivity works.
- target host has Docker and Compose available.

## Runtime Files

Workflows materialize temporary runtime files and Ansible copies them into the
server runtime layout.

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
grafana
llm-postgres
litellm
langfuse
```

LLM service endpoints on the host:

```text
LiteLLM    <TAILSCALE_IPV4>:4000
Langfuse   <TAILSCALE_IPV4>:3001
Postgres   internal Docker network only
```

The `llm` deploy binds LiteLLM and Langfuse to `TAILSCALE_IPV4` and opens
ports `4000` and `3001` only on the configured Tailscale interface.

After the first Langfuse login, create a Langfuse project, generate API keys,
update `LANGFUSE_PUBLIC_KEY` and `LANGFUSE_SECRET_KEY` in Infisical, and
rerun the deployment.

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
