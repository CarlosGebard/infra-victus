.PHONY: compose-validate ansible-check core-up core-up-tailscale core-down core-logs llm-up llm-down llm-logs

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
