# Docs Overview

Este repositorio define una infraestructura pequeña, separada por capas y por dominio.

## Capas

- `bootstrap`
  - prepara el host base
  - usuario admin, SSH, sudo, fail2ban, ufw, swap

- `runtime`
  - instala Docker
  - prepara `/srv/apps`, `/srv/data`, `/srv/logs`, `/srv/secrets`, `/srv/backups`
  - deja ownership correctos para los contenedores

- `deploy`
  - copia compose y configs desde el repo al host
  - stagea secretos runtime desde GitHub Actions
  - ejecuta `docker compose up -d`

## Stacks

- `core`
  - `nginx`
  - `seaweedfs`

- `personal`
  - `couchdb`

- `observability`
  - `loki`
  - `prometheus`
  - `grafana`

## Principio clave

Compose es la fuente de verdad del runtime.
Ansible no genera la app; solo prepara host, distribuye archivos y ejecuta despliegue.

## Entry points

- `make ansible-check`
- `make compose-validate`
- `.github/workflows/bootstrap-host.yml`
- `.github/workflows/apply-runtime.yml`
- `.github/workflows/deploy.yml`
