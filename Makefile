.PHONY: compose-validate ansible-check core-up core-up-tailscale core-down core-logs

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
