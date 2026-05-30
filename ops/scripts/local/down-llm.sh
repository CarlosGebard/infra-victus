#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
ENV_FILE="$ROOT_DIR/compose/projects/llm/.env"
COMPOSE_BASE="$ROOT_DIR/compose/projects/llm/compose.yml"
COMPOSE_OVERLAY="$ROOT_DIR/compose/projects/llm/compose.dev.yml"

docker compose --env-file "$ENV_FILE" -f "$COMPOSE_BASE" -f "$COMPOSE_OVERLAY" down "$@"
