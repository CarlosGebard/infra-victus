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
```

The `observability` stack is deployed first so monitoring is available before
the core stack is rolled out. The `llm` stack is deployed after core so the
shared Docker network is already present.

Internal job order:

```text
validate -> preflight -> deploy-observability -> deploy-core -> deploy-llm -> verify
```

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

The deployment workflow pulls secrets from Infisical, prepares SSH and Ansible
inventory, materializes stack runtime files on the target host, and runs the
stack playbooks in dependency order.

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
