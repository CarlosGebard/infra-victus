#!/usr/bin/env bash

set -euo pipefail

: "${PROD_HOST:?Missing PROD_HOST}"

SSH_PORT="${PROD_SSH_PORT:-22}"
DEPLOY_SSH_USER="${DEPLOY_SSH_USER:-carlos}"

[[ -f /tmp/observability-runtime.env ]] || { echo "Missing /tmp/observability-runtime.env" >&2; exit 1; }

rm -rf /tmp/observability-deploy
mkdir -p \
  /tmp/observability-deploy/apps/observability/loki \
  /tmp/observability-deploy/apps/observability/prometheus \
  /tmp/observability-deploy/secrets/runtime

cp compose/projects/observability/compose.yml /tmp/observability-deploy/apps/observability/compose.yml
cp compose/projects/observability/compose.prod.yml /tmp/observability-deploy/apps/observability/compose.prod.yml
cp compose/configs/loki/config.yml /tmp/observability-deploy/apps/observability/loki/config.yml
cp compose/configs/prometheus/prometheus.yml /tmp/observability-deploy/apps/observability/prometheus/prometheus.yml
cp /tmp/observability-runtime.env /tmp/observability-deploy/secrets/runtime/observability.env

tar -C /tmp/observability-deploy -czf /tmp/observability-deploy.tgz .
scp -P "$SSH_PORT" /tmp/observability-deploy.tgz "$DEPLOY_SSH_USER@$PROD_HOST:/tmp/observability-deploy.tgz"

ssh -p "$SSH_PORT" "$DEPLOY_SSH_USER@$PROD_HOST" 'sudo bash -s' <<'REMOTE'
set -euo pipefail

mkdir -p /srv/apps/observability /srv/secrets/runtime /srv/data/observability/loki /srv/data/observability/prometheus /srv/logs
tar -xzf /tmp/observability-deploy.tgz -C /srv
chmod 600 /srv/secrets/runtime/observability.env
ln -sfn /srv/secrets/runtime/observability.env /srv/apps/observability/.env
docker network inspect infra_shared_backend >/dev/null 2>&1 || docker network create infra_shared_backend

cd /srv/apps/observability
docker compose --env-file /srv/secrets/runtime/observability.env -f compose.yml -f compose.prod.yml up -d --remove-orphans
rm -f /tmp/observability-deploy.tgz
REMOTE
