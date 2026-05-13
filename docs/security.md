# Seguridad

## Principios

- Secretos no viven en git.
- Infisical entrega secretos vía GitHub OIDC.
- GitHub Variables solo para datos no sensibles.
- Docker socket equivale a privilegios altos.
- Servicios internos no publican puertos innecesarios.

## Secretos

Secretos requeridos:

```text
SEAWEED_S3_ACCESS_KEY
SEAWEED_S3_SECRET_KEY
POSTGRES_PASSWORD
REDIS_PASSWORD
GRAFANA_ADMIN_PASSWORD
PROD_SSH_PRIVATE_KEY
```

Postgres y Redis solo deben publicarse en la IP privada de Tailscale.
NGINX no proxya esos servicios TCP.

Runtime en servidor:

```text
/srv/secrets/runtime/core.env
/srv/secrets/runtime/seaweed-s3.json
/srv/secrets/runtime/observability.env
```

Permisos esperados:

```text
secretos 0600
configs  0644
data     0750
```

## Checklist Antes De Push

- `git status --short` revisado.
- No hay `.env` staged.
- No hay `.venv` staged.
- No hay `__pycache__` staged.
- No hay claves ni passwords reales.
- Workflows no imprimen secretos.
