# GitHub Actions Workflows

## Overview

Workflows manage infrastructure deployment via GitHub Actions + Infisical OIDC.

## Workflow Index

| Workflow | Purpose | Trigger | Frequency |
|----------|---------|---------|-----------|
| **`deploy-all.yml`** | **Deploy all stacks in correct order** | `push` to `main` on infra changes + manual dispatch | Production rollout |
| `validate-infra.yml` | Validate compose files + syntax | PR to `main`, manual dispatch | Each infra change |
| `debug-*.yml` | Troubleshooting utilities | Manual dispatch | Debugging only |

## Recommended Deployment Flow

### Fresh VPS Setup

```
1. server-bootstrap/bootstrap-host.yml
   └─ One-time: hardening and initial host access

2. server-bootstrap/apply-runtime.yml
   └─ One-time: Docker, Tailscale, Alloy package, base directories

3. deploy-all.yml
   └─ Repeatable: Deploy apps (observability → core)
```

### Subsequent Updates

```
push to main
  └─ auto-runs validate-infra.yml
  └─ auto-runs deploy-all.yml
```

## Workflow Architecture

### `deploy-all.yml` (Production Standard)

**Status**: Primary deployment orchestrator

**Flow**:
```
validate (all secrets + syntax)
    ↓
deploy-observability (loki, prometheus, grafana)
    ↓
deploy-core (nginx, seaweedfs)
    ↓
verify (services healthy)
```

**Triggers**:
- Automatic: `push` to `main` when infra files change
- Manual: `workflow_dispatch`

**Inputs**:
- `git_ref` (manual only): Branch/tag to deploy (default: main)

**Outputs**:
- ✓ Containers running
- ✓ Logs available in GitHub Actions

**Concurrency**: Prevents parallel deployments (lock on `production-deploy-all`)

**Time**: ~15-20 minutes

### `bootstrap-host.yml`

**Status**: Initial host setup

**Purpose**: Docker installation, system hardening, SSH keys

**Run Once**: On fresh VPS

**Permissions**: Runs as root (requires SUDO)

## Secret Management

All workflows fetch secrets from **Infisical via OIDC**:

1. Workflow requests token from GitHub OIDC provider
2. Token exchanged with Infisical identity
3. Infisical returns project secrets from configured `secret-path` and environment
4. Secrets injected as environment variables
5. Ansible uses injected secrets for configuration

**No secrets stored in GitHub**.

### Required Secrets (In Infisical)

**Production environment** must contain:

```
PROD_HOST                    # Target VPS IP or hostname
PROD_SSH_PORT                # SSH port (default: 22)
PROD_SSH_PRIVATE_KEY         # SSH key for deployment user
PROD_SSH_KNOWN_HOSTS         # Optional: ssh-keyscan output

SEAWEED_S3_ACCESS_KEY        # SeaweedFS S3 credentials
SEAWEED_S3_SECRET_KEY

GRAFANA_ADMIN_PASSWORD       # Grafana admin password
```

**Verify before deploying**:
```bash
# In workflow: "Assert required deploy secrets are present" step
# Shows ✓ for each required secret
```

## Environment Configuration

### Local Development

Use `.env.test`:
```bash
docker compose --env-file .env.test \
  -f compose/projects/core/compose.yml \
  -f compose/projects/core/compose.dev.yml \
  up -d
```

### Production (VPS)

Workflows materialize runtime files at `/tmp/`:
- `/tmp/core-runtime.env`
- `/tmp/observability-runtime.env`
- `/tmp/seaweed-s3.json`

Ansible copies to `/srv/` and executes `docker compose up -d`.

## Validation

### Pre-Deployment Checks

`deploy-all.yml` validates:
- ✓ All Ansible playbook syntax
- ✓ All docker-compose files
- ✓ All required secrets present
- ✓ SSH connectivity
- ✓ Host has Docker + docker-compose

### Post-Deployment Checks

Verifies expected containers running:
- nginx-private
- nginx-public
- seaweedfs
- loki
- prometheus
- grafana

## Concurrency and Locking

- **`deploy-all.yml`**: Locked to `production-deploy-all`
  - Prevents parallel full deployments
  - Cancels in-progress: `false` (let current finish)

## Troubleshooting

### "Workflow failed at validation"

**Check**:
1. All secrets in Infisical? (see Secret Management)
2. `PROD_HOST` reachable? (`ping <host>`)
3. SSH key correct? (test manually: `ssh -i key carlos@<host>`)

**Fix**: Review validation step logs, update Infisical, retry.

### "Deployment succeeded but services not running"

**Check**:
1. Verify step shows expected containers running
2. SSH to host: `docker ps -a`
3. Check logs: `docker logs <container-name>`

**Fix**: Review container logs for errors (config, port conflicts, etc.)

### "SSH authentication failed"

**Check**:
1. `PROD_SSH_PRIVATE_KEY` format (PEM + newlines)
2. Key permissions on target: `chmod 600 ~/.ssh/authorized_keys`
3. SSH user is `carlos` (hardcoded in workflows)

**Fix**: Update key in Infisical, retry.

## Best Practices

✓ Use `deploy-all.yml` for production
✓ Test locally with `.env.test` first
✓ Pin `git_ref` to git tag for releases
✓ Review logs before declaring success
✓ Run `validate-infra.yml` on PRs (automatic)
✓ Document any manual post-deploy steps

✗ Don't run multiple deploys in parallel
✗ Don't modify workflows without testing locally
✗ Don't store secrets in `.env` files
✗ Don't hardcode hostnames (use `PROD_HOST` var)

## Monitoring Deployments

### Via GitHub UI

1. Actions → Select workflow
2. Click latest run
3. View real-time logs

### Via GitHub CLI

```bash
# List recent runs
gh run list --workflow=deploy-all.yml

# View specific run
gh run view <run-id> --log

# Watch live (if running)
gh run watch <run-id>
```

### Deployment Timeline

- **Validate**: 2-3 min
- **Deploy observability**: 4-5 min
- **Deploy core**: 4-5 min
- **Verify**: 1-2 min
- **Total**: 12-16 minutes

## Adding New Stacks

To add a new stack (e.g., `api`):

1. Create `compose/projects/api/compose.yml`
2. Create `compose/projects/api/compose.dev.yml`
3. Create `compose/projects/api/compose.prod.yml`
2. Create `ansible/playbooks/deploy-api.yml`
3. Create `tests/ansible/deploy-api-syntax-check.sh`
4. Add job to `deploy-all.yml` with correct `needs:` ordering
5. Add validation steps for new secrets

See existing stacks for examples.

## References

- Deployment guide: [DEPLOYMENT.md](../DEPLOYMENT.md)
- Ansible playbooks: `ansible/playbooks/`
- Docker compose files: `compose/projects/`
- Configurations: `compose/configs/`
