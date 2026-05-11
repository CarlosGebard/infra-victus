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
2. `core`

## Secretos esperados

Siempre:

- `PROD_HOST`
- `PROD_SSH_PRIVATE_KEY`
- opcionales: `PROD_SSH_PORT`, `PROD_SSH_KNOWN_HOSTS`

No se requiere `PROD_SSH_USER` para flujo actual.

## Variables esperadas en GitHub `production`

`core` no toma dominios desde GitHub Variables. Dominios, vhosts y política HTTP/HTTPS viven en:

```text
ansible/inventories/production/group_vars/networking.yml
```

Por stack:

- `core`
  - `CORE_RUNTIME_ENV` en GitHub Actions solo si no tiene secretos
  - `SEAWEED_S3_ACCESS_KEY`
  - `SEAWEED_S3_SECRET_KEY`
  - opcionales: `COREDNS_BIND_IP`, `COREDNS_DNS_PORT`
- `observability`
  - `GRAFANA_ADMIN_PASSWORD`

## Estado actual de SeaweedFS

Deploy de `core` sí deja listo el runtime S3 de SeaweedFS:

- monta `seaweed-s3.json` en `/srv/secrets/runtime/seaweed-s3.json`
- fuerza ownership `1000:1000`
- fuerza modo `0400`
- valida que el archivo sea JSON válido antes de correr `docker compose up`
- exige al menos una credencial con `accessKey` y `secretKey`

El repo también aplica contrato declarativo de buckets S3:

- contrato: `compose/configs/seaweedfs/buckets.json`
- script runtime: `ops/scripts/runtime/apply-s3-buckets.py`
- deploy lo ejecuta contra endpoint interno `http://seaweedfs:8333`

Implicancia operativa:

- buckets y prefixes declarados se crean de forma idempotente
- prefixes se materializan con objeto `.keep`
- el deploy no borra buckets, prefixes ni objetos no declarados
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
  - `nginx.conf` -> restart `nginx-private` y `nginx-public`
  - `nginx/private/conf.d/core.conf` -> restart `nginx-private`
  - `nginx/public/conf.d/core.conf` -> restart `nginx-public`
  - `core.env` -> recreate `nginx-private`, `seaweedfs`, `coredns`
  - `seaweed-s3.json` -> recreate `seaweedfs`
- `observability`
  - `loki/config.yml` -> restart `loki`
  - `prometheus/prometheus.yml` -> restart `prometheus`
  - `observability.env` -> recreate `loki`, `prometheus`, `grafana`

Razón:

- `docker compose up -d` no siempre reinicia contenedor cuando cambia archivo montado desde host
- secretos o variables de entorno deben entrar al proceso al crear contenedor otra vez
- reinicio/recreate dirigido reduce churn y downtime frente a recrear stack completo

## Edges HTTP

`core` separa edges:

- `nginx-private`: bind a IP Tailscale, HTTP privado, sin certbot
- `nginx-public`: reservado para futuros servicios públicos, sin puertos publicados por ahora

Durante la migración desde el edge único anterior, deploy elimina el contenedor legado `nginx` para liberar puertos antes de crear `nginx-private` y `nginx-public`.

Política actual de `nginx-private`:

- rutas `/seaweed/master/`, `/seaweed/filer/`, `/grafana/`, `/prometheus/`, `/loki/` solo son alcanzables por Tailscale porque el puerto se publica en `NGINX_BIND_IP`
- S3 usa virtual-host style por `s3.victus.io` y `*.s3.victus.io`
- server blocks `seaweed.*`, `filer.*`, `s3.*` no usan allow/deny interno por IP; Docker bridge oculta la IP real del cliente

Nota:

- acceso privado esperado para servicios no públicos: entrar por IP o hostname Tailscale del VPS y usar rutas proxy de NGINX
- endpoint S3 privado esperado: `http://s3.victus.io`
- ejemplo AWS CLI: `aws --endpoint-url http://s3.victus.io s3 ls`
- buckets virtual-host style usan `<bucket>.s3.victus.io`
- `nginx-public` conserva `/.well-known/acme-challenge/` para futura emisión HTTP-01

## Nota operacional

`core` despliega la config edge de NGINX. Esa config referencia `grafana`, `prometheus` y `loki`, así que no conviene desplegar `core` primero.

`infra_shared_backend` es red Docker compartida entre stacks. Debe existir antes de cualquier `docker compose up`. Localmente, `ops/scripts/local/up-local.sh` y `ops/scripts/local/up-core.sh` la crean si falta. En servidor, `deploy/shared` la asegura antes de validar o desplegar stack.

`deploy-all.yml` quedó como pipeline CD principal. En `push` a `main` corre automáticamente solo cuando cambian archivos de infraestructura. Si environment `production` exige aprobación manual en GitHub, workflow quedará pausado ahí hasta aprobar.

NGINX `core` se renderiza desde `networking.vhosts`.

Fase actual:

- endpoints `victus.io` son privados sobre Tailscale
- S3 usa HTTP en `s3.victus.io` y `*.s3.victus.io`
- no hay redirect HTTP -> HTTPS para S3
- vhosts con `https.enabled: false` no entran a certbot

TLS privado/wildcard queda diferido hasta DNS-01.

## DNS privado `victus.io`

`core` ahora incluye:

- `etcd` interno para backend SkyDNS en `/skydns`
- `coredns` para zona privada `victus.io`

Archivos operativos relevantes:

- `compose/configs/coredns/Corefile`
- `ops/scripts/runtime/sync-core-dns.sh`
- `core.env`

Registros manejados por script:

- `s3.victus.io -> <tailscale-ip>`
- `*.s3.victus.io -> <tailscale-ip>` por template CoreDNS

Motivo de TTL corto:

- `tailscale0` puede cambiar IP en eventos de red o reprovisión
- `ttl=30` reduce tiempo de cache vieja en clientes
- subir TTL reduce queries pero empeora convergencia tras cambio de IP

Flujo recomendado post-deploy en servidor:

```bash
cd /srv/apps/core
./scripts/sync-core-dns.sh
```

El deploy de `core` ejecuta este script al final. El comando manual sirve para repoblar DNS tras cambios de IP Tailscale o pruebas operativas.

Efecto del script:

- detecta IP actual de `tailscale0`
- actualiza `core.env` con variables DNS/Tailscale no sensibles
- recrea `coredns` para tomar `COREDNS_BIND_IP` y `COREDNS_DNS_PORT`
- escribe registro SkyDNS de `s3.victus.io` en `etcd`
- recrea `coredns` para que el template wildcard use la IP actual

Si necesitas overlay de producción explícito:

```bash
CORE_COMPOSE_OVERLAY=/srv/apps/core/compose.prod.yml \
CORE_ENV_FILE=/srv/secrets/runtime/core.env \
./scripts/sync-core-dns.sh
```

Verificación manual:

```bash
dig @<tailscale-ip-del-vps> -p 53 s3.victus.io
dig @<tailscale-ip-del-vps> -p 53 any-bucket.s3.victus.io
```

Prueba local por Tailscale desde otro nodo:

```bash
make core-up-tailscale
dig @<tailscale-ip-local> s3.victus.io
dig @<tailscale-ip-local> any-bucket.s3.victus.io
```

Notas:

- `coredns` hace `forward` de consultas fuera de `victus.io` a `1.1.1.1`
- si host ya usa puerto `53`, ajustar `COREDNS_BIND_IP` o `COREDNS_DNS_PORT`
- `etcd` no se publica al host; gestión ocurre vía `docker compose exec etcd etcdctl`
