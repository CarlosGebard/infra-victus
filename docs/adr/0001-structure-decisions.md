# ADR 0001: Decisiones de Estructura Operativa

## Estado

Aceptado

## Contexto

Repositorio define infraestructura reproducible para VPS con tres capas:

- `bootstrap`
- `runtime`
- `deploy`

Había ambigüedad en tres puntos:

1. si CD debe ser automático o manual
2. qué entra en `runtime`
3. si Grafana provisioning queda automatizado o manual

## Decisiones

### 1. CD sigue manual en GitHub Actions

Los workflows operativos quedan en `workflow_dispatch`.

Se decide no hacer deploy automático en `push` ni en `main`.

Razón:

- infraestructura toca host real
- rollout por stack importa
- `core` depende de `observability` y `personal`
- se quiere control humano antes de aplicar cambios

Esto no impide tener CI automática de validación en futuro.

### 2. `runtime` incluye baseline de host, Docker y agentes host-level actuales

Mientras árbol actual se mantenga, `runtime` incluye:

- Docker Engine
- Docker Compose plugin
- layout `/srv/...`
- ownership de directorios de runtime
- Tailscale
- Grafana Alloy
- validaciones de esos componentes

Razón:

- eso es lo que hoy implementa playbook `ansible/playbooks/runtime.yml`
- Tailscale y Alloy no se despliegan como stack Compose; operan como servicios del host
- documentar esto evita leer `runtime` como “solo Docker”

Si en futuro se quiere separar `Tailscale` o `Alloy` a otra capa, debe abrirse un ADR nuevo y luego ajustar playbooks, variables y validaciones.

### 3. Deploy queda separado por stack

Se mantiene un deploy manual por stack:

- `core`
- `personal`
- `observability`

No habrá `deploy all`.

Razón:

- menor acoplamiento
- rollout controlado
- fallas aisladas por dominio

### 4. Grafana provisioning queda preparado en filesystem, pero no automatizado todavía

Repositorio prepara directorios de provisioning para Grafana, pero no versiona aún archivos de datasources o dashboards.

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

- CD sigue siendo controlado por operador
- `runtime` debe considerarse capa de host, no solo capa Docker
- `TAILSCALE_AUTH_KEY` forma parte de contrato operativo de `runtime`
- Grafana todavía no es completamente reproducible a nivel de dashboards/datasources provisionados

## Referencias

- [apply-runtime.yml](/home/carlos/victus/infra-victus/.github/workflows/apply-runtime.yml)
- [deploy.yml](/home/carlos/victus/infra-victus/.github/workflows/deploy.yml)
- [runtime.yml](/home/carlos/victus/infra-victus/ansible/playbooks/runtime.yml)
- [group_vars/runtime.yml](/home/carlos/victus/infra-victus/ansible/inventories/production/group_vars/runtime.yml)
