# Secrets y Variables

## Objetivo

Este documento fija ubicación decidida para valores operativos y secretos en `production`.

No todos estos valores están cableados todavía de esa manera en workflows actuales. Donde exista diferencia, este documento manda como contrato objetivo.

Regla base:

- GitHub Actions `Variables`: datos operativos no sensibles
- GitHub Actions `Secrets`: evitar, salvo necesidad puntual no cubierta por Infisical
- Infisical: passwords, llaves y credenciales atómicas

El repositorio usa GitHub Actions solo como orquestador. Fuente objetivo de secretos runtime: Infisical vía OIDC.

## GitHub Actions

Usar `environment: production`.

### Variables

Estas variables no son secretas y describen entorno o integración:

| Nombre | Dónde | Razón |
| --- | --- | --- |
| `INFISICAL_IDENTITY_ID` | GitHub Actions Variable | Identificador de identidad OIDC usado por workflows |
| `INFISICAL_PROJECT_SLUG` | GitHub Actions Variable | Identificador de proyecto en Infisical |
| `INFISICAL_ENV_SLUG` | GitHub Actions Variable | Ambiente objetivo en Infisical, por ejemplo `prod` |
| `CORE_RUNTIME_ENV` | GitHub Actions Variable | `.env` de `core` solo si no contiene secretos |

### Secrets

No se recomienda guardar secretos de runtime en GitHub Actions mientras exista integración con Infisical.

Excepción:

- si un workflow puntual todavía no fue adaptado y necesita valor temporalmente

## Infisical

Estos valores sí deben salir desde Infisical.

| Nombre | Tipo | Razón |
| --- | --- | --- |
| `PROD_HOST` | secreto operativo actual | Host/IP destino consumido hoy por workflows |
| `PROD_SSH_USER` | secreto operativo actual | Usuario SSH remoto consumido hoy por workflows |
| `PROD_SSH_PRIVATE_KEY` | secreto | Llave privada SSH |
| `PROD_SSH_PORT` | secreto operativo opcional | Puerto SSH si no es `22` |
| `PROD_SSH_KNOWN_HOSTS` | secreto operativo opcional | Huella SSH fija para evitar `ssh-keyscan` |
| `TAILSCALE_AUTH_KEY` | secreto | Token de enrolamiento Tailscale |
| `COUCHDB_USER` | secreto atómico | Usuario CouchDB usado para construir `.env` de `personal` |
| `COUCHDB_PASSWORD` | secreto atómico | Password CouchDB usado para construir `.env` de `personal` |
| `GRAFANA_ADMIN_PASSWORD` | secreto atómico | Password admin Grafana usado para construir `.env` de `observability` |
| `SEAWEED_S3_ACCESS_KEY` | secreto atómico | Access key S3 usada para construir `seaweed-s3.json` |
| `SEAWEED_S3_SECRET_KEY` | secreto atómico | Secret key S3 usada para construir `seaweed-s3.json` |

## Contenido esperado por stack

### `CORE_RUNTIME_ENV`

Hoy `core` solo usa:

- `NGINX_BIND_IP`
- `NGINX_HTTP_PORT`

Si variable no existe en GitHub Actions, workflow genera defaults:

- `NGINX_BIND_IP=127.0.0.1`
- `NGINX_HTTP_PORT=8080`

### SeaweedFS

Workflow construye `/tmp/seaweed-s3.json` desde:

- `SEAWEED_S3_ACCESS_KEY`
- `SEAWEED_S3_SECRET_KEY`

Contrato actual:

```json
{
  "identities": [
    {
      "name": "main",
      "credentials": [
        {
          "accessKey": "SEAWEED_S3_ACCESS_KEY",
          "secretKey": "SEAWEED_S3_SECRET_KEY"
        }
      ],
      "actions": [
        "Admin",
        "Read",
        "Tagging",
        "Write",
        "List"
      ]
    }
  ]
}
```

### `personal`

Workflow construye `.env` desde:

- `COUCHDB_USER`
- `COUCHDB_PASSWORD`

### `observability`

Workflow construye `.env` con defaults más:

- `LOKI_BIND_IP`
- `LOKI_HTTP_PORT`
- `PROMETHEUS_BIND_IP`
- `PROMETHEUS_HTTP_PORT`
- `GRAFANA_ADMIN_USER`
- `GRAFANA_ADMIN_PASSWORD`
- `GRAFANA_BIND_IP`
- `GRAFANA_HTTP_PORT`
- `GRAFANA_ROOT_URL`

Valor secreto requerido:

- `GRAFANA_ADMIN_PASSWORD`

## Cómo lo consume repo

- `bootstrap-host.yml` consume secretos de conexión SSH
- `apply-runtime.yml` consume secretos de conexión SSH y `TAILSCALE_AUTH_KEY` si runtime enrola nodo
- `deploy.yml` consume secretos atómicos y los materializa temporalmente en `/tmp`
- Ansible copia esos archivos a `/srv/secrets/runtime/`

Referencias:

- [deploy.yml](/home/carlos/victus/infra-victus/.github/workflows/deploy.yml)
- [runtime.yml](/home/carlos/victus/infra-victus/ansible/playbooks/runtime.yml)
- [group_vars/deploy.yml](/home/carlos/victus/infra-victus/ansible/inventories/production/group_vars/deploy.yml)

## Nota operativa

No mezclar dos fuentes de verdad para mismo valor.

Ejemplo:

- si `CORE_RUNTIME_ENV` vive en GitHub Actions, mantenerlo libre de secretos
- no recrear blobs `PERSONAL_RUNTIME_ENV` u `OBSERVABILITY_RUNTIME_ENV` en Infisical
