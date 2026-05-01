# ADR 0001: Decisiones de Estructura Operativa

## Estado

Aceptado

## Contexto

Repositorio queda dividido en dos responsabilidades:

- `server-bootstrap`
- `infra-victus`

Había ambigüedad en tres puntos:

1. si CD debe ser automático o manual
2. qué entra en `server-bootstrap` vs `infra-victus`
3. si Grafana provisioning queda automatizado o manual

## Decisiones

### 1. Deploy del stack corre automático en `push` a `main`

Bootstrap reusable del host queda en `server-bootstrap`.

El deploy del stack sí corre automáticamente en `push` a `main` con filtros de paths relevantes.

Razón:

- bootstrap toca lifecycle sensible del servidor y debe seguir manual
- deploy del stack tiene source of truth en git y conviene que reaccione al merge
- `deploy-all.yml` ya respeta orden `observability -> personal -> core`
- los filtros de paths reducen ejecuciones innecesarias

Esto mantiene claro el flujo:

- host lifecycle manual
- app/service lifecycle automático

### 2. `server-bootstrap` y `infra-victus` se separan por responsabilidad

`server-bootstrap` incluye:

- bootstrap del host
- Docker Engine
- Docker Compose plugin
- Tailscale
- Grafana Alloy package, service y config mínima
- layout base `/srv/...`

`infra-victus` incluye:

- config concreta de Alloy
- deploy de stacks Compose

Razón:

- bootstrap del host debe ser reusable
- deploy del stack no debe cargar instalación base del host
- la configuración concreta de Alloy depende del stack Victus y por eso queda separada

### 3. Deploy queda separado por stack, con orquestación automática

Se mantiene separación lógica por stack:

- `core`
- `personal`
- `observability`

`deploy-all.yml` orquesta el rollout completo y automático cuando corresponde.

Razón:

- menor acoplamiento
- rollout ordenado
- fallas aisladas por dominio

### 4. Grafana provisioning queda preparado en deploy, pero no automatizado todavía

Repositorio mantiene mounts y rutas esperadas para provisioning de Grafana, pero no versiona aún archivos de datasources o dashboards.

Decisión actual:

- directorios se crean
- mount queda listo en Compose
- provisioning de contenido queda pendiente y fuera de automatización por ahora

Razón:

- árbol actual ya prepara estructura
- no existen archivos declarativos versionados para esa capa
- mejor documentar estado real que fingir automatización inexistente

Cuando se agreguen archivos versionados en `compose/configs/grafana/provisioning/`, deberá actualizarse esta decisión.

## Consecuencias

- `server-bootstrap` opera el lifecycle del host
- deploy automático sigue siendo válido para cambios de stack
- `infra-victus` asume host ya bootstrappeado
- Grafana todavía no es completamente reproducible a nivel de dashboards/datasources provisionados

## Referencias

- [deploy-all.yml](/home/carlos/victus/infra-victus/.github/workflows/deploy-all.yml)
- [deploy-observability.yml](/home/carlos/victus/infra-victus/ansible/playbooks/deploy-observability.yml)
