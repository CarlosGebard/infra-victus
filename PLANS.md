## Goal
Dejar `infra-victus` operable sin CouchDB, con DNS privado `victus.io` respaldado por CoreDNS + etcd, y con SeaweedFS S3 listo para virtual-host style bajo `*.s3.victus.io`.

## Current State
- Stack `personal`/CouchDB fue retirado del repositorio.
- Stack `core` incluye `nginx`, `seaweedfs`, `etcd`, `coredns`, `postgres` y `redis`.
- `make core-up` levanta `core` local y sincroniza `s3.victus.io`.
- CoreDNS responde `s3.victus.io` y cualquier nombre que termine en `.s3.victus.io` con la IP de NGINX usando `template`.
- `sync-core-dns.sh` también deja registro SkyDNS de hoja para inspección/compatibilidad:
  - `s3.victus.io` -> `/skydns/io/victus/s3/x1`
- `etcd` no usa variables de entorno; se configura por argumentos Compose y guarda datos DNS bajo `/skydns`.

## Important Remaining Work

### 0. Declarative NGINX Vhosts
Goal:
- Convertir routing NGINX de `core` a modelo declarativo por vhost/endpoint.
- Separar HTTP privado sobre Tailscale de HTTPS/certbot.
- Evitar redirects accidentales por existencia de certificados.

Current:
- `networking.vhosts` declara domains, upstream, access policy, preserve_host, HTTP redirect y HTTPS.
- `deploy.yml` queda para mecánica de despliegue; `networking.yml` queda para contrato de red.
- `s3.victus.io` y `*.s3.victus.io` quedan HTTP privado sin redirect.
- Certbot solo considera vhosts con `https.enabled: true`.

Validation:
- `bash tests/ansible/deploy-syntax-check.sh`
- `make compose-validate`
- En VPS tras deploy:
  - `curl -v http://s3.victus.io/`
  - `curl -v http://victus-corpus.s3.victus.io/`
  - `aws --endpoint-url http://s3.victus.io s3api list-buckets`

Risk:
- TLS privado/wildcard requiere Fase 2 con DNS-01.
- Local actual no tiene `ansible-playbook`; syntax-check debe correr en CI o ambiente con Ansible.

### 1. Finish S3 Virtual-Host Routing
Goal:
- Que `s3.victus.io` y `<bucket>.s3.victus.io` lleguen a SeaweedFS S3 con `Host` preservado.

Current:
- NGINX local/template ya incluye:
  - `server_name s3.victus.io *.s3.victus.io ...;`
  - `proxy_set_header Host $host;`
  - `proxy_pass http://seaweedfs:8333;`
- Path-style `/seaweed/s3/` fue retirado para reducir complejidad.

Needed:
- Validar comportamiento S3 real con AWS CLI/boto3 contra virtual-host style.

Validation:
- `dig @127.0.0.1 -p 1053 s3.victus.io +short`
- `dig @127.0.0.1 -p 1053 <bucket>.s3.victus.io +short`
- `curl -H 'Host: <bucket>.s3.victus.io' http://127.0.0.1:8080/`

Risk:
- Browser/SDK will not resolve `victus.io` unless OS/Tailscale DNS is configured.

### 2. S3 Bucket Provisioning
Goal:
- Crear buckets/prefixes S3 declarados de forma idempotente.

Current:
- Contract:
  - `compose/configs/seaweedfs/buckets.json`
- Runtime script:
  - `ops/scripts/runtime/apply-s3-buckets.py`
- Deploy applies contract through internal endpoint:
  - `http://seaweedfs:8333`

Managed buckets:
- `victus-corpus`
- `victus-backups`
- `victus-tmp`

Managed `victus-corpus` prefixes:
- `papers/`
- `analytics/jobs/`
- `analytics/reports/`
- `analytics/reports/2026-05-11/`
- `registry_backups/`

Per-paper layout:
- `papers/{sha256_hash}/raw/source.pdf`
- `papers/{sha256_hash}/stages/01_metadata/`
- `papers/{sha256_hash}/stages/02_normalized/`
- `papers/{sha256_hash}/stages/03_docling/`
- `papers/{sha256_hash}/stages/04_claims/`

Validation:
- `docker run --rm --network core_core_backend ... python /apply-s3-buckets.py`
- `dig @127.0.0.1 -p 1053 <bucket>.s3.victus.io +short`

### 3. Configure Client DNS Resolver
Goal:
- Que clientes resuelvan `s3.victus.io` y `*.s3.victus.io` sin `dig @... -p ...`.

Options:
- Local dev:
  - CoreDNS on `127.0.0.1:53`, then OS resolver points `victus.io` to localhost.
  - Or local dnsmasq/systemd-resolved forwarding `victus.io` to CoreDNS.
- Production:
  - CoreDNS binds to Tailscale IP on port `53`.
  - Tailscale split DNS routes `victus.io` to VPS Tailscale IP.

Validation:
- From client:
  - `dig s3.victus.io`
  - `dig <bucket>.s3.victus.io`

Risk:
- Port `53` conflicts with local resolver or host DNS service.

### 3.5 Core Registry and Event Bus
Goal:
- Agregar Postgres como registry durable de papers y Redis como Streams privado.

Current:
- Postgres service: `postgres`
- Redis service: `redis`
- Both connect to `core_backend` and external `infra_shared_backend`.
- Postgres schema migrations:
  - `ops/db/migrations/versions/0001_create_paper_registry.py`
- Main table:
  - `paper_registry`

Redis stream:
- `victus:events`

Event types:
- `victus:artifact:done`
- `victus:stage:started`
- `victus:stage:done`
- `victus:error`

Docling output path:
- `papers/{sha256_hash}/stages/03_docling/final.json`

Validation:
- `docker compose --env-file compose/env/core.env.example -f compose/projects/core/compose.yml -f compose/projects/core/compose.dev.yml config`
- `docker compose ... up -d postgres redis`
- `docker compose ... exec postgres pg_isready`
- `docker compose ... exec redis redis-cli ping`

Risk:
- External consumers must use `XREADGROUP`/`XACK` correctly to avoid pending-message buildup.

### 3.6 Reusable Victus Bridge
Goal:
- Mantener un SDK/CLI interno reusable para comunicación entre repositorios Victus.

Current:
- Package:
  - `ops/bridge`
- Entrypoint:
  - `uv run victus-ingest`
- Core modules:
  - `config.py`
  - `bridge.py`
  - `registry.py`
  - `storage.py`
  - `events.py`
  - `schemas.py`
  - `cli.py`

Allowed responsibilities:
- Load env config.
- Register/read paper state in Postgres.
- Upload/reference S3 artifacts.
- Publish Redis events.
- Expose generic stage/artifact/event/error methods.

Non-goals:
- No Docling logic.
- No claims extraction.
- No embeddings.
- No Qdrant logic.
- No worker-specific orchestration.

Validation:
- `cd ops/bridge && uv run victus-ingest --help`
- `python3 -m compileall -q ops/bridge/victus_ingest_bridge`

### 3.7 Redis Streams Event Bus
Goal:
- Migrar eventos del bridge desde Redis Pub/Sub a Redis Streams durable.
- Usar `redis-py` en vez de protocolo RESP manual.

Scope:
- Productores publican con `XADD`.
- Cada evento queda en stream `victus:events`.
- Payload completo se guarda como JSON en campo `payload`.
- `event_type`, `paper_id` y `timestamp` quedan como campos indexables simples.

Non-goals:
- No implementar consumers/workers en este repo.
- No crear consumer groups automáticamente en publish.
- No cambiar Postgres como source of truth.

Validation:
- `cd ops/bridge && uv lock`
- `cd ops/bridge && uv run victus-ingest --help`
- `python3 -m compileall -q ops/bridge/victus_ingest_bridge`

Risk:
- Requiere coordinar consumidores externos para leer Streams con `XREADGROUP` y ACK.

### 4. DNS Sync In Production Deploy
Goal:
- Deploy refreshes `s3.victus.io` target IP automatically after core is up.

Current:
- Ansible copies and executes:
  - `/srv/apps/core/scripts/sync-core-dns.sh`
- Local default stays loopback:
  - `make core-up`
- Local Tailscale test mode:
  - `make core-up-tailscale`
  - `./ops/scripts/local/up-core.sh --tailscale`

Validation:
- `ansible-playbook playbooks/deploy.yml`
- On VPS:
  - `cd /srv/apps/core`
  - `docker compose exec etcd etcdctl --endpoints=http://127.0.0.1:2379 get /skydns --prefix`

Risk:
- If `tailscale0` is missing or has no IPv4 in production, deploy fails clearly.

### 5. Clean Old CouchDB Runtime On VPS
Goal:
- Stop and remove old runtime artifacts no longer managed by repo.

Needed:
- Stop old `personal` stack.
- Backup data before deletion.
- Remove old app and secret files only after backup is verified.

Commands are in handoff/runbook notes, not automated yet.

### 6. Validation Gap
Goal:
- Run full checks before claiming final deploy readiness.

Known gap:
- `make ansible-check` did not run in this local environment because `ansible-playbook` is missing.

Required:
- Run `make ansible-check` where Ansible is installed, or install Ansible locally.
- Run `make compose-validate`.

### 7. Grafana Provisioning Still Pending
Goal:
- Make observability fully reproducible, not just running.

Needed:
- Version datasources/dashboards under `compose/configs/grafana/provisioning`.
- Update Ansible deploy config to copy them.

Risk:
- Current Grafana content may be manual state, not fully reproducible.

## Server Cleanup Notes
- Current VPS still has `/srv/apps/personal`; repo no longer manages it.
- Do not delete `/srv/data/couchdb` until backup is created and verified.
- Old `docker-compose.yml` files in `/srv/apps/core`, `/srv/apps/observability`, `/srv/apps/personal` may be stale compatibility files; current deploy uses `compose.yml` + `compose.prod.yml`.

## Validation Commands
```bash
make compose-validate
make ansible-check
make core-up
dig @127.0.0.1 -p 1053 s3.victus.io +short
dig @127.0.0.1 -p 1053 test.s3.victus.io +short
docker compose --env-file compose/projects/core/.env -f compose/projects/core/compose.yml -f compose/projects/core/compose.dev.yml exec -T etcd etcdctl --endpoints=http://127.0.0.1:2379 get /skydns --prefix
```
