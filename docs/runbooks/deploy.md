# Deploy Runbook

## Flujo

1. validar ansible
2. validar compose
3. si hay dudas de OIDC o Infisical, ejecutar workflow `debug-infisical-oidc.yml`
4. si hay dudas de reachability o credenciales SSH, ejecutar workflow `debug-ssh-connectivity.yml`
5. ejecutar `bootstrap-host.yml` usando acceso inicial como `root`
6. ejecutar `apply-runtime.yml` usando usuario admin `carlos`
7. ejecutar `deploy.yml`
8. elegir `stack`
9. empezar con `check_mode=true`

## Inputs del workflow

- `bootstrap-host.yml`
  - `git_ref`
- `stack`
  - `observability`
  - `personal`
  - `core`
- `git_ref`
- `check_mode`

## Workflow de debug OIDC

Usar `.github/workflows/debug-infisical-oidc.yml` cuando quieras validar:

- que GitHub entregue token OIDC
- que los `vars.INFISICAL_*` estén presentes
- que Infisical acepte identidad OIDC
- que contrato mínimo de secretos exista

El workflow imprime claims seguros del token. No imprime token completo ni secretos.

## Workflow de debug SSH

Usar `.github/workflows/debug-ssh-connectivity.yml` cuando quieras validar:

- que Infisical entrega `PROD_HOST` y `PROD_SSH_PRIVATE_KEY`
- que workflow pueda entrar como `root`
- que `known_hosts` o `ssh-keyscan` funcionan
- que GitHub Actions puede abrir sesión SSH real contra el VPS

El workflow no ejecuta Ansible ni cambia estado del host. Solo corre:

```bash
echo ok && hostname && whoami
```

## Usuarios por fase

- `debug-ssh-connectivity.yml`: conecta como `root`
- `bootstrap-host.yml`: conecta como `root`
- `apply-runtime.yml`: conecta como `carlos`
- `deploy.yml`: conecta como `carlos`

Razón:

- `root` sirve para primer acceso al host virgen
- bootstrap crea y prepara usuario admin
- runtime y deploy deben operar con usuario admin ya provisionado

## Orden recomendado

1. `observability`
2. `personal`
3. `core`

## Secretos esperados

Siempre:

- `PROD_HOST`
- `PROD_SSH_PRIVATE_KEY`
- opcionales: `PROD_SSH_PORT`, `PROD_SSH_KNOWN_HOSTS`

No se requiere `PROD_SSH_USER` para flujo actual.

Por stack:

- `core`
  - `CORE_RUNTIME_ENV` en GitHub Actions solo si no tiene secretos
  - `SEAWEED_S3_ACCESS_KEY`
  - `SEAWEED_S3_SECRET_KEY`
- `personal`
  - `COUCHDB_USER`
  - `COUCHDB_PASSWORD`
- `observability`
  - `GRAFANA_ADMIN_PASSWORD`

## Validación mínima antes de push

```bash
make ansible-check
make compose-validate
```

## Nota operacional

`core` despliega la config edge de NGINX. Esa config referencia `couchdb`, `grafana`, `prometheus` y `loki`, así que no conviene desplegar `core` primero.
