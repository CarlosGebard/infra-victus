---
id: victus-infra-troubleshooting
title: Troubleshooting Operations
status: active
updated_at: 2026-05-27
owners:
  - CarlosGebard/victus-infra
---

# Troubleshooting Operations

## Bucket Missing Locally

Run the local core startup workflow. It applies declared S3 buckets and prefixes
idempotently.

```bash
make core-up
```

## Redis Does Not Respond Locally

```bash
docker compose \
  --env-file compose/projects/core/.env \
  -f compose/projects/core/compose.yml \
  -f compose/projects/core/compose.dev.yml \
  exec redis sh -c 'redis-cli -a "$REDIS_PASSWORD" ping'
```

## Reset Local Pipeline Postgres

To reset only the local pipeline Postgres data:

```bash
make core-down
rm -rf compose/.tmp/core/pipeline-postgres
make core-up
```

Do not use this procedure in production.

## Missed Event Recovery

Redis Streams are operational event transport. Consumers that need durable
truth should query the schema owned by the pipeline application repository.

## Deployment Validation Fails

Check:

- required Infisical secrets exist.
- `PROD_HOST` is reachable.
- `PROD_SSH_PRIVATE_KEY` is valid and includes newlines.
- `PROD_SSH_PORT` matches the target host.
- Ansible syntax validation passes locally.
- Compose validation passes locally.

## Services Not Running After Deploy

Inspect the target host:

```bash
ssh carlos@<PROD_HOST> "docker ps --all"
```

Then inspect stack logs on the host:

```bash
ssh carlos@<PROD_HOST>
cd /srv/<stack>
docker compose logs <service-name> --tail=100
```

Common causes:

- invalid runtime env values.
- port conflicts.
- missing runtime secret files.
- insufficient disk space under `/srv`.

## Restart One Service

```bash
ssh carlos@<PROD_HOST>
cd /srv/<stack>
docker compose restart <service-name>
```

## Emergency Stack Restart

Use only when a narrower service restart is insufficient:

```bash
ssh carlos@<PROD_HOST>
cd /srv/<stack>
docker compose down
docker compose up -d
```
