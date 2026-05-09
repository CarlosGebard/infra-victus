# Docs Overview

Este repositorio define una infraestructura pequeña, separada por capas y por dominio.

## Capas

- `server-bootstrap`
  - vive fuera de este repo
  - prepara el host base y baseline reusable

- `deploy`
  - copia compose y configs desde el repo al host
  - stagea secretos runtime desde GitHub Actions
  - ejecuta `docker compose up -d`
  - aplica configuración específica de Alloy para este stack

## Stacks

- `core`
  - `nginx`
  - `seaweedfs`
  - `etcd`
  - `coredns`

- `observability`
  - `loki`
  - `prometheus`
  - `grafana`

## Principio clave

Compose es la fuente de verdad del runtime.
Ansible no bootstrappea el host; distribuye archivos del stack y ejecuta despliegue.

## Entry points

- `make ansible-check`
- `make compose-validate`
- `.github/workflows/deploy-all.yml`

## Documentos clave

- secrets y variables: [docs/secrets-and-variables.md](/home/carlos/victus/infra-victus/docs/secrets-and-variables.md)
- contrato DNS privado: [docs/private-dns-contract.md](/home/carlos/victus/infra-victus/docs/private-dns-contract.md)
- README en español: [docs/README.es.md](/home/carlos/victus/infra-victus/docs/README.es.md)
- ADR estructura operativa: [docs/adr/0001-structure-decisions.md](/home/carlos/victus/infra-victus/docs/adr/0001-structure-decisions.md)
