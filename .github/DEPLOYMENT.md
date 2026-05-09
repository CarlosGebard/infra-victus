# Deployment Guide

## Overview

Infra-Victus uses deployment workflows:

- **`prepare-victus-host.yml`** - Applies Victus-specific host configuration.
- **`deploy-all.yml`** - Orchestrates all stacks in correct order. Main CD workflow. Auto-runs on `push` to `main` for infra changes.

## Stack Dependencies

```
observability (baseline monitoring)
    ↓
core (app layer, depends on observability)
```

**Reason**: Core's Nginx proxies to observability stack (Grafana). Must exist before core starts.

## Deployment Workflows

### Full Rollout (Recommended)

Use **`deploy-all.yml`** workflow:

1. **Automatic path**
   - Push or merge to `main`
   - If change touches `.github/workflows/`, `ansible/`, `compose/`, or `tests/ansible/`, GitHub starts rollout automatically
   - Workflow deploys pushed commit SHA

2. **Manual path via GitHub UI**
   - Go to Actions → Deploy All Stacks
   - Click "Run workflow"
   - Inputs:
     - `git_ref`: branch/tag to deploy (default: main)
     - `auto_rollback`: currently informational; manual rollback required

3. **Execution Flow**
   ```
   validate (all secrets, syntax, docker-compose)
       ↓
   deploy-observability
       ↓
   deploy-core
       ↓
   verify (services running)
   ```

4. **Timeline**: ~15-20 minutes total

## Manual Deployment (Local Dev)

If needed to deploy manually (not recommended for production):

```bash
# 1. Pull latest
git pull origin main

# 2. Trigger via CLI
gh workflow run deploy-all.yml \
  -f git_ref=main \
  -f auto_rollback=true

# 3. Monitor
gh run list --workflow=deploy-all.yml
gh run view <run-id> --log
```

## Secrets Management

All secrets fetched via Infisical + OIDC at runtime. None stored in GitHub.

### Required Secrets

| Secret | Used By | Source |
|--------|---------|--------|
| `PROD_HOST` | All | Infisical env |
| `PROD_SSH_PRIVATE_KEY` | All | Infisical env |
| `PROD_SSH_PORT` | All | Infisical env (default: 22) |
| `PROD_SSH_KNOWN_HOSTS` | All | Infisical env (optional) |
| `SEAWEED_S3_ACCESS_KEY` | core | Infisical env |
| `SEAWEED_S3_SECRET_KEY` | core | Infisical env |
| `GRAFANA_ADMIN_PASSWORD` | observability | Infisical env |

**Verify before deploying**:
```bash
# In GitHub Actions logs, validate step shows:
✓ PROD_HOST
✓ PROD_SSH_PRIVATE_KEY
✓ SEAWEED_S3_ACCESS_KEY
✓ SEAWEED_S3_SECRET_KEY
✓ GRAFANA_ADMIN_PASSWORD
```

## Post-Deployment Verification

Workflows automatically verify expected services running:

- nginx ✓
- seaweedfs ✓
- loki ✓
- prometheus ✓
- grafana ✓

Manual verification:
```bash
ssh carlos@<PROD_HOST> "docker ps --all"
```

Expected output: project containers with status `running`

## Rollback

### Automatic Rollback (if implemented)

Currently, `deploy-all.yml` supports `auto_rollback` input but requires manual implementation via:
- Ansible handlers
- Docker volume snapshots
- Or manual recovery procedure

### Manual Rollback

```bash
ssh carlos@<PROD_HOST>

# Check current versions
docker ps -a
docker images

# Stop failed stack
cd /srv/core
docker compose down

# Revert to previous commit
git checkout <previous-hash>
docker compose up -d
```

## Troubleshooting

### "Missing PROD_SSH_PRIVATE_KEY"

**Cause**: Infisical secret not configured
**Fix**:
1. Check Infisical project + environment
2. Verify identity token scope includes secrets
3. Re-run workflow

### "Connection refused" to PROD_HOST

**Cause**: SSH key or port mismatch
**Fix**:
1. Verify `PROD_HOST` is correct IP/hostname
2. Check `PROD_SSH_PORT` (default: 22)
3. Ensure key has correct permissions: `chmod 600 ~/.ssh/deploy_key`
4. Test manually: `ssh -i ~/.ssh/deploy_key carlos@<PROD_HOST>`

### Docker compose fails on target

**Cause**: Config or secret mismatch
**Fix**:
1. Check workflow logs for materialized env files
2. SSH to host and validate: `cd /srv/<stack> && docker compose config`
3. Review generated `.env` files
4. Check `/srv/secrets/runtime/` ownership/permissions

### Services not healthy

**Cause**: Healthchecks failing, port conflicts, or resource issues
**Fix**:
1. Check logs: `docker logs <container-name>`
2. Verify port bindings: `docker port <container-name>`
3. Check disk space: `df -h /srv`
4. Review resource limits in compose file

## Best Practices

✓ Always use `deploy-all.yml` for full rollout
✓ Test changes locally with `.env.test` first
✓ Pin `git_ref` to specific tag for production releases
✓ Review logs before and after each deployment
✓ Maintain backup of `/srv/data` before major updates
✓ Document any manual post-deploy steps

✗ Never run multiple deploys in parallel (concurrency lock prevents this)
✗ Don't manually edit production compose files (always via git)
✗ Don't skip secret validation
✗ Don't deploy without verifying all services afterward

## Emergency Procedures

### Full Outage Recovery

```bash
ssh carlos@<PROD_HOST>

# 1. Check all containers
docker ps -a

# 2. View logs for failures
docker logs <container> -n 50 --tail

# 3. If compose files corrupted, revert from git
cd /srv/core && git fetch && git reset --hard origin/main

# 4. Restart stack
docker compose down
docker compose up -d

# 5. Verify
docker ps
docker compose logs -f
```

### Individual Service Restart

```bash
ssh carlos@<PROD_HOST>
cd /srv/<stack>

# Restart single service
docker compose restart <service-name>

# View logs
docker compose logs <service-name> -f
```

## Architecture Overview

```
GitHub Actions
    ↓
Infisical (OIDC)
    ↓
ansible/ (playbooks)
    ↓
VPS:/srv/
    ├── apps/
    ├── data/
    ├── logs/
    ├── secrets/runtime/
    └── backups/
    ↓
Docker Compose
    ├── core/          (nginx, seaweedfs)
    └── observability/ (loki, prometheus, grafana)
```

## References

- Workflow files: `.github/workflows/`
- Compose files: `compose/projects/`
- Ansible playbooks: `ansible/playbooks/`
- Configuration templates: `compose/configs/`
