# Deploy Runbook

## Flujo

1. validar ansible
2. validar compose
3. ejecutar workflow `deploy.yml`
4. elegir `stack`
5. empezar con `check_mode=true`

## Inputs del workflow

- `stack`
  - `observability`
  - `personal`
  - `core`
- `git_ref`
- `check_mode`

## Orden recomendado

1. `observability`
2. `personal`
3. `core`

## Secretos esperados

Siempre:

- `BOOTSTRAP_HOST`
- `BOOTSTRAP_SSH_USER`
- `BOOTSTRAP_SSH_PRIVATE_KEY`
- opcionales: `BOOTSTRAP_SSH_PORT`, `BOOTSTRAP_KNOWN_HOSTS`

Por stack:

- `core`
  - `CORE_RUNTIME_ENV`
  - `CORE_RUNTIME_SEAWEED_S3_JSON`
- `personal`
  - `PERSONAL_RUNTIME_ENV`
- `observability`
  - `OBSERVABILITY_RUNTIME_ENV`

## Validación mínima antes de push

```bash
make ansible-check
make compose-validate
```

## Nota operacional

`core` despliega la config edge de NGINX. Esa config referencia `couchdb`, `grafana`, `prometheus` y `loki`, así que no conviene desplegar `core` primero.
