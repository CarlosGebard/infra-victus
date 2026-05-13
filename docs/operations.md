# Operación

## Validar Antes De Commit

```bash
make ansible-check
make compose-validate
python3 -m compileall -q ops/bridge/victus_ingest_bridge
cd ops/bridge && UV_PROJECT_ENVIRONMENT=/tmp/victus-bridge-uv-env uv run victus-ingest --help
```

## Local

Levantar:

```bash
make core-up
```

Estado:

```bash
docker compose \
  --env-file compose/projects/core/.env \
  -f compose/projects/core/compose.yml \
  -f compose/projects/core/compose.dev.yml \
  ps
```

Logs:

```bash
make core-logs
```

Bajar:

```bash
make core-down
```

## Deploy

Workflow:

```text
.github/workflows/deploy-all.yml
```

Orden:

```text
observability -> core -> verify
```

## Secretos Requeridos

Infisical debe entregar:

```text
PROD_HOST
PROD_SSH_PRIVATE_KEY
SEAWEED_S3_ACCESS_KEY
SEAWEED_S3_SECRET_KEY
POSTGRES_PASSWORD
REDIS_PASSWORD
GRAFANA_ADMIN_PASSWORD
```

Opcionales:

```text
PROD_SSH_PORT
PROD_SSH_KNOWN_HOSTS
```

## Troubleshooting

### Bucket No Existe

```bash
make core-up
```

### Redis No Responde

```bash
docker compose \
  --env-file compose/projects/core/.env \
  -f compose/projects/core/compose.yml \
  -f compose/projects/core/compose.dev.yml \
  exec redis sh -c 'redis-cli -a "$REDIS_PASSWORD" ping'
```

### Postgres Sin Tabla

Si volumen local ya existía antes del init SQL:

```bash
make core-down
rm -rf compose/.tmp/core/postgres
make core-up
```

No hacer esto en producción.

### Evento Perdido

Redis Pub/Sub no guarda historial. Consumidores deben consultar Postgres al iniciar:

```sql
select *
from paper_registry
where status_proc = 'completed'
  and status_rag in ('pending', 'error');
```
