#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

log() { echo "[INFO] $*"; }
err() {
	echo "[ERROR] $*" >&2
	exit 1
}

require_cmd() {
	command -v "$1" >/dev/null 2>&1 || err "Missing command: $1"
}

require_file() {
	local path="$1"
	[[ -f "$path" ]] || err "Missing file: $path"
}

require_dir() {
	local path="$1"
	[[ -d "$path" ]] || err "Missing dir: $path"
}

validate_stack() {
	local stack="$1"
	local stack_dir="$ROOT_DIR/compose/projects/$stack"
	local env_file="$stack_dir/.env"
	local compose_file="$stack_dir/docker-compose.local.yml"

	log "Validating stack: $stack"

	require_file "$env_file"
	require_file "$compose_file"

	log "$stack: docker compose config"
	docker compose --env-file "$env_file" -f "$compose_file" config >/dev/null

	log "$stack: compose rendered OK"
}

validate_nginx() {
	local nginx_conf="$ROOT_DIR/compose/configs/nginx/nginx.conf"
	local nginx_conf_dir="$ROOT_DIR/compose/configs/nginx/conf.d"

	require_file "$nginx_conf"
	require_dir "$nginx_conf_dir"

	log "Validating nginx config"
	docker run --rm \
		--add-host couchdb:127.0.0.1 \
		--add-host seaweedfs:127.0.0.1 \
		--add-host grafana:127.0.0.1 \
		--add-host prometheus:127.0.0.1 \
		--add-host loki:127.0.0.1 \
		-v "$nginx_conf:/etc/nginx/nginx.conf:ro" \
		-v "$nginx_conf_dir:/etc/nginx/conf.d:ro" \
		nginx:1.28.3-alpine nginx -t
}

validate_required_dirs() {
	local dirs=(
		"$ROOT_DIR/compose/.tmp/core/nginx/logs"
		"$ROOT_DIR/compose/.tmp/core/seaweedfs/data"
		"$ROOT_DIR/compose/.tmp/observability/grafana"
		"$ROOT_DIR/compose/.tmp/observability/loki"
		"$ROOT_DIR/compose/.tmp/observability/prometheus"
		"$ROOT_DIR/compose/.tmp/personal/couchdb/data"
	)

	for dir in "${dirs[@]}"; do
		require_dir "$dir"
	done
}

require_cmd docker
validate_stack personal
validate_stack core
validate_stack observability
validate_required_dirs
validate_nginx

log "Local validation OK"
