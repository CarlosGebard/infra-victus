# Roadmap

## Antes De Push

- Quitar impresión parcial de `seaweed-s3.json` en workflow.
- Conectar `seaweedfs` a `infra_shared_backend` si otros repos usarán `http://seaweedfs:8333`.
- Revalidar:

```bash
make ansible-check
make compose-validate
cd ops/bridge && UV_PROJECT_ENVIRONMENT=/tmp/victus-bridge-uv-env uv run victus-ingest --help
```

## Próxima Fase

### `victus-processing`

- importar o copiar `ops/bridge`
- usar `ingest_pdf`
- generar artefactos propios
- llamar `mark_artifact_done`
- llamar `stage-done`

### `victus-rag`

- consultar Postgres al iniciar para recuperar pendientes
- escuchar Redis para eventos live
- leer artefactos desde SeaweedFS
- generar embeddings
- escribir en vector store
- llamar `stage-start`, `stage-done`, `publish-error`

### `victus-analytics`

- escuchar eventos Redis
- consultar Postgres
- generar reportes bajo `analytics/reports/`

## Deuda Técnica

- migraciones Postgres versionadas
- tests unitarios del bridge
- Redis Streams si se necesita replay
- Qdrant como stack controlado
- backups automatizados de Postgres y SeaweedFS
- métricas por stage

