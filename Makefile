.PHONY: compose-validate ansible-check local-up core-up core-down core-logs

ansible-check:
	./tests/ansible/check.sh

compose-validate:
	./compose/scripts/validate-compose.sh

local-up:
	./compose/scripts/up-local.sh

core-up:
	./compose/scripts/up-core.sh

core-down:
	./compose/scripts/down-core.sh

core-logs:
	./compose/scripts/logs-core.sh
