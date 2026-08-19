.PHONY: compose-validate ansible-check core-up core-up-tailscale core-down core-logs llm-up llm-down llm-logs backstage-up backstage-down backstage-logs

ansible-check:
	./tests/ansible/check.sh

compose-validate:
	./ops/checks/validate-compose.sh

core-up:
	./ops/scripts/local/up-core.sh

core-up-tailscale:
	./ops/scripts/local/up-core.sh --tailscale

core-down:
	./ops/scripts/local/down-core.sh

core-logs:
	./ops/scripts/local/logs-core.sh

llm-up:
	./ops/scripts/local/up-llm.sh

llm-down:
	./ops/scripts/local/down-llm.sh

llm-logs:
	./ops/scripts/local/logs-llm.sh

backstage-up:
	docker network inspect infra_shared_backend >/dev/null 2>&1 || docker network create infra_shared_backend
	docker compose --env-file compose/env/backstage.env.example -f compose/projects/backstage/compose.yml -f compose/projects/backstage/compose.dev.yml up -d

backstage-down:
	docker compose --env-file compose/env/backstage.env.example -f compose/projects/backstage/compose.yml -f compose/projects/backstage/compose.dev.yml down

backstage-logs:
	docker compose --env-file compose/env/backstage.env.example -f compose/projects/backstage/compose.yml -f compose/projects/backstage/compose.dev.yml logs -f
