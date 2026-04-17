#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENV_FILE="$ROOT_DIR/compose/projects/core/.env"
COMPOSE_FILE="$ROOT_DIR/compose/projects/core/docker-compose.local.yml"

"$ROOT_DIR/compose/scripts/ensure-shared-network.sh"

docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" up -d "$@"
