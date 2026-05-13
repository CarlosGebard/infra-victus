#!/usr/bin/env sh
set -eu

MIGRATIONS_DIR="${VICTUS_DB_MIGRATIONS_DIR:-/srv/apps/core/db}"
CORE_ENV_FILE="${CORE_ENV_FILE:-/srv/secrets/runtime/core.env}"
DOCKER_NETWORK="${DOCKER_NETWORK:-core_core_backend}"
POSTGRES_HOST="${POSTGRES_HOST:-postgres}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"
UV_IMAGE="${UV_IMAGE:-ghcr.io/astral-sh/uv:python3.12-alpine}"

env_file_value() {
  [ -f "$CORE_ENV_FILE" ] || return 0
  awk -F= -v key="$1" '
    $1 == key {
      sub(/^[^=]*=/, "")
      print
      exit
    }
  ' "$CORE_ENV_FILE"
}

POSTGRES_DB="${POSTGRES_DB:-$(env_file_value POSTGRES_DB)}"
POSTGRES_USER="${POSTGRES_USER:-$(env_file_value POSTGRES_USER)}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-$(env_file_value POSTGRES_PASSWORD)}"

POSTGRES_DB="${POSTGRES_DB:-victus_registry}"
POSTGRES_USER="${POSTGRES_USER:-victus}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-change-me}"

docker run --rm \
  --network "$DOCKER_NETWORK" \
  --env-file "$CORE_ENV_FILE" \
  -e POSTGRES_HOST="$POSTGRES_HOST" \
  -e POSTGRES_PORT="$POSTGRES_PORT" \
  -e POSTGRES_DB="$POSTGRES_DB" \
  -e POSTGRES_USER="$POSTGRES_USER" \
  -e POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
  -e UV_PROJECT_ENVIRONMENT=/tmp/victus-db-uv-env \
  -e UV_LINK_MODE=copy \
  -v "$MIGRATIONS_DIR:/db:ro" \
  -w /db \
  "$UV_IMAGE" \
  sh -c '
    for i in $(seq 1 40); do
      output="$(uv run alembic upgrade head 2>&1)" && exit 0
      status=$?
      printf "%s\n" "$output"
      case "$output" in
        *"password authentication failed"*|*"role "*" does not exist"*|*"database "*" does not exist"*)
          exit "$status"
          ;;
      esac
      echo "[WAIT] postgres migrations not ready, retrying in 3s"
      sleep 3
    done
    exit 1
  '
