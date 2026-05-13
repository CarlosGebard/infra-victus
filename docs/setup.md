# Setup

## Requisitos

- Docker
- Docker Compose
- Python 3.12+
- `uv`
- Ansible para validaciones/deploy

## Primer Uso Local

Desde raíz del repo:

```bash
make ansible-check
make compose-validate
make core-up
```

`make core-up`:

- crea red Docker compartida `infra_shared_backend`
- levanta stack `core`
- sincroniza DNS privado local
- aplica contrato S3 de buckets/prefixes

## Variables Locales

Ejemplos:

```text
compose/env/core.env.example
compose/env/observability.env.example
```

El archivo local real vive en:

```text
compose/projects/core/.env
```

Ese archivo no se commitea.

## Bridge

```bash
cd ops/bridge
uv sync
uv run victus-ingest --help
```

Variables esperadas por el bridge:

```text
VICTUS_PG_DSN=postgresql://victus:<password>@postgres:5432/victus_registry
VICTUS_REDIS_URL=redis://redis:6379/0
VICTUS_S3_ENDPOINT=http://seaweedfs:8333
VICTUS_S3_ACCESS_KEY=<access-key>
VICTUS_S3_SECRET_KEY=<secret-key>
VICTUS_S3_BUCKET=victus-corpus
VICTUS_AWS_REGION=us-east-1
```

## Validación Rápida

```bash
make ansible-check
make compose-validate
python3 -m compileall -q ops/bridge/victus_ingest_bridge
cd ops/bridge && UV_PROJECT_ENVIRONMENT=/tmp/victus-bridge-uv-env uv run victus-ingest --help
```

