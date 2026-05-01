# Deploy Runbook

## Flujo

1. validar ansible
2. validar compose
3. si hay dudas de OIDC o Infisical, ejecutar workflow `debug-infisical-oidc.yml`
4. si hay dudas de reachability o credenciales SSH, ejecutar workflow `debug-ssh-connectivity.yml`
5. ejecutar `bootstrap-host.yml` y `apply-runtime.yml` desde el repo `server-bootstrap`
6. `push` a `main` dispara validación y deploy automático si hubo cambios en `.github/workflows/`, `ansible/`, `compose/` o `tests/ansible/`
7. usar dispatch manual solo para redeploy puntual o rollback operativo

## Inputs del workflow

- `deploy-all.yml`
  - `git_ref` solo en `workflow_dispatch`
  - en `push` a `main`, despliega SHA del commit automáticamente

## Workflow de debug OIDC

Usar `.github/workflows/debug-infisical-oidc.yml` cuando quieras validar:

- que GitHub entregue token OIDC
- que los `vars.INFISICAL_*` estén presentes
- que `vars.INFISICAL_SECRET_PATH` apunte a carpeta correcta
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

- `debug-ssh-connectivity.yml`: conecta como `root` o como el usuario que corresponda al repo de bootstrap
- `deploy-all.yml`: conecta como `carlos`

Razón:

- `server-bootstrap` resuelve el lifecycle del host
- `infra-victus` asume usuario admin ya provisionado
- deploy opera sobre un host ya bootstrappeado

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

## Variables esperadas en GitHub `production`

- `BASE_DOMAIN`
- opcional: `CERTBOT_EMAIL`

Si `CERTBOT_EMAIL` no existe, deploy usa fallback `{{ host.admin_user }}@{{ BASE_DOMAIN }}`.

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

## Estado actual de SeaweedFS

Deploy de `core` sí deja listo el runtime S3 de SeaweedFS:

- monta `seaweed-s3.json` en `/srv/secrets/runtime/seaweed-s3.json`
- fuerza ownership `1000:1000`
- fuerza modo `0400`
- valida que el archivo sea JSON válido antes de correr `docker compose up`
- exige al menos una credencial con `accessKey` y `secretKey`

Lo que todavía no hace el repo:

- no crea buckets automáticamente
- no versiona una lista declarativa de buckets
- no aplica políticas por bucket desde Ansible

Implicancia operativa:

- hoy la IaC configura autenticación S3, no aprovisionamiento de buckets
- si un servicio necesita buckets precreados, hay que crearlos explícitamente después del deploy usando un cliente S3 compatible o una automatización aparte
- si `seaweedfs` no arranca, revisar primero `/srv/secrets/runtime/seaweed-s3.json`; credencial faltante, JSON inválido o permisos distintos de `1000:1000` y `0400` deben tratarse como error de deploy

## Validación mínima antes de push

```bash
make ansible-check
make compose-validate
```

## Reinicio y recreate automáticos

Deploy no hace `down/up` global. Aplica acciones puntuales por stack según tipo de cambio:

- cambio en archivo de config montado por bind mount
  - corre `docker compose restart` solo para servicios afectados
- cambio en compose base, compose overlay de producción o `.env` enlazado
  - corre `docker compose up -d --force-recreate` solo para servicios afectados

Mapa actual:

- `core`
  - `nginx.conf` o `nginx/conf.d/core.conf` -> restart `nginx`
  - `core.env` -> recreate `nginx`, `seaweedfs`
  - `seaweed-s3.json` -> recreate `seaweedfs`
- `personal`
  - `local.ini` -> restart `couchdb`
  - `personal.env` -> recreate `couchdb`
- `observability`
  - `loki/config.yml` -> restart `loki`
  - `prometheus/prometheus.yml` -> restart `prometheus`
  - `observability.env` -> recreate `loki`, `prometheus`, `grafana`

Razón:

- `docker compose up -d` no siempre reinicia contenedor cuando cambia archivo montado desde host
- secretos o variables de entorno deben entrar al proceso al crear contenedor otra vez
- reinicio/recreate dirigido reduce churn y downtime frente a recrear stack completo

## Exposición pública

Política actual de edge:

- `couchdb.{{ BASE_DOMAIN }}` queda público por NGINX
- rutas `/seaweed/master/`, `/seaweed/filer/`, `/seaweed/s3/`, `/grafana/`, `/prometheus/`, `/loki/` solo aceptan origen Tailscale
- server blocks `seaweed.*`, `filer.*`, `s3.*` también quedan restringidos a rangos Tailscale `100.64.0.0/10` y `fd7a:115c:a1e0::/48`

Nota:

- acceso privado esperado para servicios no públicos: entrar por IP o hostname Tailscale del VPS y usar rutas proxy de NGINX
- acceso S3 path-style soportado para setup pequeño: `http://<magicdns-host>/seaweed/s3/`
- ejemplo AWS CLI: `aws --endpoint-url http://<magicdns-host>/seaweed/s3 s3 ls`
- algunos clientes S3 avanzados o URLs prefirmadas siguen siendo más compatibles con hostname dedicado al root en vez de path prefix
- path `/.well-known/acme-challenge/` sigue público para certbot HTTP-01

## Nota operacional

`core` despliega la config edge de NGINX. Esa config referencia `couchdb`, `grafana`, `prometheus` y `loki`, así que no conviene desplegar `core` primero.

`infra_shared_backend` es red Docker compartida entre stacks. Debe existir antes de cualquier `docker compose up`. Localmente, `compose/scripts/up-local.sh` y `compose/scripts/up-core.sh` la crean si falta. En servidor, `deploy/shared` la asegura antes de validar o desplegar stack.

`deploy-all.yml` quedó como pipeline CD principal. En `push` a `main` corre automáticamente solo cuando cambian archivos de infraestructura. Si environment `production` exige aprobación manual en GitHub, workflow quedará pausado ahí hasta aprobar.

Primer deploy TLS para `seaweed.{{ BASE_DOMAIN }}` requiere reachability pública en `80/tcp` y `443/tcp`. `core` sube primero con HTTP + challenge webroot, `certbot` emite cert, luego mismo deploy reprocesa nginx con TLS activo.
