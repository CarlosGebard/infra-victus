#!/usr/bin/env bash

set -euo pipefail

: "${PROD_HOST:?Missing PROD_HOST}"

SSH_PORT="${PROD_SSH_PORT:-22}"
DEPLOY_SSH_USER="${DEPLOY_SSH_USER:-carlos}"

[[ -f /tmp/core-runtime.env ]] || { echo "Missing /tmp/core-runtime.env" >&2; exit 1; }
[[ -f /tmp/seaweed-s3.json ]] || { echo "Missing /tmp/seaweed-s3.json" >&2; exit 1; }

rm -rf /tmp/core-deploy
mkdir -p \
  /tmp/core-deploy/apps/core \
  /tmp/core-deploy/secrets/runtime

cp compose/projects/core/compose.yml /tmp/core-deploy/apps/core/compose.yml
cp compose/projects/core/compose.prod.yml /tmp/core-deploy/apps/core/compose.prod.yml
mkdir -p /tmp/core-deploy/apps/core/nginx/private/conf.d
mkdir -p /tmp/core-deploy/apps/core/nginx/public/conf.d
mkdir -p /tmp/core-deploy/apps/core/nginx/snippets
mkdir -p /tmp/core-deploy/apps/core/coredns
mkdir -p /tmp/core-deploy/apps/core/seaweedfs
mkdir -p /tmp/core-deploy/apps/core/scripts
mkdir -p /tmp/core-deploy/apps/core/db/migrations/versions

cp compose/configs/nginx/nginx.conf /tmp/core-deploy/apps/core/nginx/nginx.conf
cp compose/configs/nginx/conf.d/core.conf /tmp/core-deploy/apps/core/nginx/private/conf.d/core.conf
cp compose/configs/nginx/public/conf.d/core.conf /tmp/core-deploy/apps/core/nginx/public/conf.d/core.conf
cp compose/configs/nginx/snippets/private-access.conf /tmp/core-deploy/apps/core/nginx/snippets/private-access.conf
cp compose/configs/coredns/Corefile /tmp/core-deploy/apps/core/coredns/Corefile
cp compose/configs/seaweedfs/buckets.json /tmp/core-deploy/apps/core/seaweedfs/buckets.json
cp ops/scripts/runtime/sync-core-dns.sh /tmp/core-deploy/apps/core/scripts/sync-core-dns.sh
cp ops/scripts/runtime/apply-s3-buckets.py /tmp/core-deploy/apps/core/scripts/apply-s3-buckets.py
cp ops/scripts/runtime/apply-postgres-migrations.sh /tmp/core-deploy/apps/core/scripts/apply-postgres-migrations.sh
cp ops/db/pyproject.toml /tmp/core-deploy/apps/core/db/pyproject.toml
cp ops/db/uv.lock /tmp/core-deploy/apps/core/db/uv.lock
cp ops/db/alembic.ini /tmp/core-deploy/apps/core/db/alembic.ini
cp ops/db/migrations/env.py /tmp/core-deploy/apps/core/db/migrations/env.py
cp ops/db/migrations/versions/0001_create_paper_registry.py /tmp/core-deploy/apps/core/db/migrations/versions/0001_create_paper_registry.py
cp /tmp/core-runtime.env /tmp/core-deploy/secrets/runtime/core.env
cp /tmp/seaweed-s3.json /tmp/core-deploy/secrets/runtime/seaweed-s3.json

tar -C /tmp/core-deploy -czf /tmp/core-deploy.tgz .
scp -P "$SSH_PORT" /tmp/core-deploy.tgz "$DEPLOY_SSH_USER@$PROD_HOST:/tmp/core-deploy.tgz"

ssh -p "$SSH_PORT" "$DEPLOY_SSH_USER@$PROD_HOST" 'sudo bash -s' <<'REMOTE'
set -euo pipefail

mkdir -p /srv/apps/core /srv/secrets/runtime /srv/logs/nginx-private /srv/logs/nginx-public
mkdir -p /srv/data/seaweed/data /srv/data/etcd/core-dns /srv/data/postgres/victus-registry /srv/data/redis
tar -xzf /tmp/core-deploy.tgz -C /srv
chmod 600 /srv/secrets/runtime/core.env
chown 1000:1000 /srv/secrets/runtime/seaweed-s3.json
chmod 0400 /srv/secrets/runtime/seaweed-s3.json
chmod +x /srv/apps/core/scripts/*.sh /srv/apps/core/scripts/*.py
ln -sfn /srv/secrets/runtime/core.env /srv/apps/core/.env
docker network inspect infra_shared_backend >/dev/null 2>&1 || docker network create infra_shared_backend

cd /srv/apps/core
CORE_ENV_FILE=/srv/secrets/runtime/core.env CORE_COMPOSE_OVERLAY=/srv/apps/core/compose.prod.yml ./scripts/sync-core-dns.sh
docker compose --env-file /srv/secrets/runtime/core.env -f compose.yml -f compose.prod.yml up -d --remove-orphans
docker run --rm \
  --network core_core_backend \
  -v /srv/apps/core/scripts/apply-s3-buckets.py:/apply-s3-buckets.py:ro \
  -v /srv/apps/core/seaweedfs/buckets.json:/buckets.json:ro \
  -v /srv/secrets/runtime/seaweed-s3.json:/seaweed-s3.json:ro \
  python:3.12-alpine \
  python /apply-s3-buckets.py \
    --contract /buckets.json \
    --seaweed-s3-config /seaweed-s3.json \
    --endpoint http://seaweedfs:8333 \
    --wait-timeout 120 \
    --wait-interval 3
rm -f /tmp/core-deploy.tgz
REMOTE
