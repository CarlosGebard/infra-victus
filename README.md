# infra-victus

Infraestructura reproducible para un VPS usando:

- Docker Compose como source of truth del runtime
- Ansible para bootstrap, runtime y deploy
- GitHub Actions + OIDC + Infisical para automatización segura

## Layout

- `compose/`
  - stacks `core`, `personal`, `observability`
  - configs que se copian tal cual al host
- `ansible/`
  - `playbooks/bootstrap.yml`
  - `playbooks/runtime.yml`
  - deploys por stack
- `.github/workflows/`
  - `bootstrap-host.yml`
  - `apply-runtime.yml`
  - `deploy-all.yml`
  - `validate-infra.yml`

## Modelo operativo

1. `bootstrap`
   - usuario admin
   - SSH hardening
   - fail2ban / ufw
   - swap

2. `runtime`
   - Docker Engine
   - Docker Compose plugin
   - layout `/srv/...`
   - ownership para datos de contenedores

3. `deploy`
   - `deploy-all.yml` es pipeline CD principal
   - corre automático en `push` a `main` para cambios de infraestructura
   - mantiene orden `observability -> personal -> core`

## Orden recomendado de rollout

1. `observability`
2. `personal`
3. `core`

`core` publica la config edge de NGINX y referencia upstreams de observability y couchdb, por eso el orden importa.

## Validación local

```bash
make ansible-check
make compose-validate
```

## Más contexto

- overview: [docs/README.md](/home/carlos/victus/infra-victus/docs/README.md)
- deploy runbook: [docs/runbooks/deploy.md](/home/carlos/victus/infra-victus/docs/runbooks/deploy.md)
