## Goal

Diseñar el siguiente workflow de GitHub Actions para `runtime`, separado de `bootstrap`, enfocado en dejar el host listo para ejecutar la infraestructura: Docker instalado, servicios de runtime activos y filesystem del host preparado con ownership y permisos compatibles con los contenedores.

## Scope

- Crear el playbook `ansible/playbooks/runtime.yml`.
- Definir los roles mínimos de runtime.
- Crear la Action `.github/workflows/apply-runtime.yml`.
- Reusar el patrón OIDC + Infisical ya adoptado para bootstrap.
- Incluir validación previa y ejecución manual controlada.

## Non-goals

- No desplegar aún stacks de aplicación ni observability vía Compose.
- No copiar todavía configs finales de Nginx, Prometheus, Loki o Grafana al host.
- No meter `alloy` en runtime si no lo definimos como prerequisito universal del host.
- No mezclar runtime con deploy de secretos de app.

## Likely files

- `.github/workflows/apply-runtime.yml`
- `ansible/playbooks/runtime.yml`
- `ansible/roles/runtime/docker/**`
- `ansible/roles/runtime/volumes/**`
- `ansible/roles/runtime/runtime_validation/**`
- `ansible/inventories/production/group_vars/runtime.yml`
- `ansible/inventories/production/group_vars/filesystem.yml`
- `ansible/inventories/production/group_vars/deploy.yml`
- `docs/operations/deploy.md`
- posiblemente `tests/ansible/syntax-check.sh` o un script nuevo específico

## Assumptions

- El patrón de autenticación del workflow será el mismo que bootstrap:
  - OIDC + Infisical
  - `environment: production`
  - inventario temporal en CI
- Runtime significa “host listo para correr Compose”, no “stacks desplegados”.
- El runtime debe ser manual en su primera versión.

## Runtime boundary recommendation

Mi recomendación profesional para `runtime`:

- sí entra:
  - instalación y habilitación de Docker
  - plugin Compose
  - pertenencia del usuario admin al grupo `docker`
  - creación del layout `/srv/...`
  - ownership/permissions de directorios de datos para contenedores
  - validación de runtime (docker activo, compose disponible, dirs presentes)

- no entra todavía:
  - `alloy`
  - staging de `core.env`
  - staging de `seaweed-s3.json`
  - copia de configs de app/observability al host
  - `docker compose up`

Razón:

- eso último ya es deploy, no runtime
- `alloy` es observability/host-agent, no prerequisito universal del runtime

## Comparison with ansible_1

Del árbol viejo, lo que sí sirve para `runtime` nuevo es:

- `roles/docker/tasks/main.yml`
- `roles/directories/tasks/main.yml`

Lo que no movería todavía:

- `roles/alloy/*`
- `deploy_core`
- validaciones ligadas al deploy de core

## Proposed runtime roles

Estructura recomendada:

- `runtime/docker`
  - repo Docker
  - paquetes Docker
  - servicio Docker
  - grupo `docker` para admin

- `runtime/filesystem`
  - base dirs `/srv/...`
  - dirs de datos y logs
  - ownership por servicio

- `runtime/validation`
  - `docker.service` running
  - `docker compose version`
  - directorios críticos presentes

Nota:

Hoy el árbol nuevo ya tiene `runtime/docker`, `runtime/volumes` y `runtime/runtime_validation`.
Mi recomendación es:

- usar `runtime/docker`
- renombrar mentalmente `volumes` a filesystem semantics, o directamente llenarlo con esa responsabilidad
- usar `runtime/runtime_validation` para checks

## Milestones

1. Cerrar frontera de runtime
   - Resultado esperado: lista cerrada de lo que runtime instala/prepara y lo que explícitamente no hace.
   - Validación: coherencia con bootstrap y con futuros deploy workflows.

2. Implementar playbook `runtime.yml`
   - Resultado esperado: playbook que carga `group_vars` y orquesta roles de runtime.
   - Archivos probables:
     - `ansible/playbooks/runtime.yml`
   - Validación:
     - `ansible-playbook --syntax-check`

3. Portar Docker al árbol nuevo
   - Resultado esperado: Docker CE + compose plugin instalados y servicio activo.
   - Archivos probables:
     - `ansible/roles/runtime/docker/tasks/main.yml`
   - Validación:
     - syntax-check
     - validación de comandos de runtime

4. Portar filesystem/ownership al árbol nuevo
   - Resultado esperado: `/srv` y subdirectorios preparados con ownership compatible para `couchdb`, `seaweedfs`, `loki`, `prometheus`, `grafana`.
   - Archivos probables:
     - `ansible/roles/runtime/volumes/tasks/main.yml`
     - `ansible/inventories/production/group_vars/filesystem.yml`
     - `ansible/inventories/production/group_vars/deploy.yml`
   - Validación:
     - syntax-check
     - revisión de variables referenciadas

5. Implementar validación de runtime
   - Resultado esperado: checks reproducibles de Docker + filesystem host.
   - Archivos probables:
     - `ansible/roles/runtime/runtime_validation/tasks/main.yml`
     - `tests/ansible/*.sh`
   - Validación:
     - syntax-check

6. Implementar workflow `apply-runtime.yml`
   - Resultado esperado: workflow manual con OIDC + Infisical, syntax-check y apply del playbook runtime.
   - Archivos probables:
     - `.github/workflows/apply-runtime.yml`
     - `docs/operations/deploy.md`
   - Validación:
     - revisión YAML
     - consistencia con bootstrap-host.yml

## Risks

- Si runtime incluye demasiado, volveremos a mezclar runtime con deploy.
- `deploy.yml` hoy contiene tanto dirs de deploy como ownership de servicios; puede requerir una limpieza de variables al portar runtime.
- `alloy` puede tentar a entrar aquí por conveniencia, pero conceptualmente mete observability en una capa demasiado baja.
- Si no definimos bien el inventario temporal en CI, el workflow de runtime repetirá fragilidad del bootstrap.

---

## Goal

Agregar un workflow manual de diagnóstico para validar OIDC de GitHub Actions contra Infisical con información de debug suficiente para aislar fallas de configuración sin exponer secretos.

## Scope

- Crear workflow manual dedicado a OIDC + Infisical debug.
- Verificar presencia de variables requeridas de GitHub environment.
- Solicitar token OIDC desde GitHub Actions.
- Decodificar y mostrar claims seguros del token.
- Ejecutar fetch desde Infisical y validar contrato mínimo.
- Actualizar runbook de deploy para mencionar workflow nuevo.

## Assumptions

- El diagnóstico debe ser manual.
- No se deben imprimir secretos ni tokens completos.
- El repositorio ya tiene permisos `id-token: write` cuando un workflow necesita OIDC.

## Steps

1. Crear `.github/workflows/debug-infisical-oidc.yml`
2. Añadir pasos de debug seguro para claims OIDC
3. Añadir prueba de fetch de secretos desde Infisical
4. Actualizar `docs/runbooks/deploy.md`
5. Revisar sintaxis YAML y consistencia

## Validation

- Revisar workflow renderizado localmente
- Verificar referencias a `vars.INFISICAL_*`
- Validar que no se impriman secretos completos

## Risks

- Mostrar claims OIDC puede exponer metadata de ejecución, pero no secretos; mantener salida acotada.
- Si Infisical requiere `audience` específico y no coincide, el workflow debe fallar con mensaje claro.

## Decision notes

- Recomendación fuerte: runtime = Docker + filesystem + validation
- Recomendación fuerte: `alloy` dejarlo fuera por ahora
- Recomendación fuerte: `apply-runtime.yml` manual y separado
- Recomendación fuerte: usar la misma forma de secretos que bootstrap:
  - `BOOTSTRAP_HOST` / equivalente runtime
  - `BOOTSTRAP_SSH_USER` / equivalente runtime
  - `BOOTSTRAP_SSH_PRIVATE_KEY` / equivalente runtime

## One design recommendation

Mi recomendación es no crear nuevos nombres de secretos para runtime.
Usaría los mismos secretos de conexión al host que bootstrap, porque cambian la operación, no la identidad del servidor:

- `BOOTSTRAP_HOST`
- `BOOTSTRAP_SSH_USER`
- `BOOTSTRAP_SSH_PRIVATE_KEY`
- opcionales:
  - `BOOTSTRAP_SSH_PORT`
  - `BOOTSTRAP_KNOWN_HOSTS`

Eso reduce complejidad y evita dos contratos distintos para la misma máquina.

## Ready-to-implement summary

El siguiente workflow debería ser `apply-runtime.yml`, manual, con OIDC + Infisical igual que bootstrap, y ejecutar un nuevo `ansible/playbooks/runtime.yml` que orqueste solo tres responsabilidades: instalación de Docker, preparación del filesystem `/srv/...` con ownership correcto y validación del runtime del host. Mi recomendación es dejar `alloy` fuera en esta fase y tratarlo después como parte de observability o de una capa host-agent separada.

---

## Goal

Refactorizar la capa de deploy para que deje de estar centrada en `core` y pase a un modelo modular por stack: `deploy` para core, `personal` para CouchDB y `observability` para Loki/Prometheus/Grafana, manteniendo a Docker Compose como source of truth y a Ansible solo como distribuidor/ejecutor.

## Scope

- Renombrar `deploy-core` a `deploy` en playbook, workflow y checks.
- Definir variables de deploy por stack en `group_vars`.
- Mantener un rol `deploy/shared` para preparación común y staging de secretos.
- Crear roles/playbooks específicos para `core`, `personal` y `observability`.
- Completar workflows manuales de GitHub Actions para los tres stacks.
- Actualizar la documentación operativa para reflejar el flujo nuevo.

## Non-goals

- No fusionar stacks en un solo deploy.
- No generar Compose o configs desde Ansible.
- No cambiar el layout base de `/srv/...`.
- No introducir un “deploy all”.

## Likely files

- `ansible/inventories/production/group_vars/deploy.yml`
- `ansible/playbooks/deploy.yml`
- `ansible/playbooks/deploy-personal.yml`
- `ansible/playbooks/deploy-observability.yml`
- `ansible/roles/deploy/shared/tasks/main.yml`
- `ansible/roles/deploy/core/tasks/main.yml`
- `ansible/roles/deploy/personal/tasks/main.yml`
- `ansible/roles/deploy/observability/tasks/main.yml`
- `tests/ansible/check.sh`
- `tests/ansible/deploy-syntax-check.sh`
- `tests/ansible/deploy-personal-syntax-check.sh`
- `tests/ansible/deploy-observability-syntax-check.sh`
- `.github/workflows/deploy.yml`
- `.github/workflows/deploy-personal.yml`
- `.github/workflows/deploy-observability.yml`
- `docs/operations/deploy.md`

## Assumptions

- Todos los secretos de deploy vendrán desde Infisical vía OIDC en GitHub Actions.
- `core` seguirá necesitando secretos runtime para `.env` y SeaweedFS S3.
- `personal` y `observability` solo requieren `.env` por ahora.
- La secuencia de rollout seguirá siendo controlada manualmente desde Actions.

## Milestones

1. Normalizar el modelo de variables de deploy
   - Resultado esperado: `group_vars/deploy.yml` describe cada stack con compose, `.env`, secretos opcionales y directorios/configs asociados.
   - Validación: revisión estática de referencias desde roles/playbooks.

2. Separar Ansible por stack
   - Resultado esperado: playbooks y roles individuales para `deploy`, `personal` y `observability`, con `shared` reutilizado.
   - Validación:
     - `tests/ansible/deploy-syntax-check.sh`
     - `tests/ansible/deploy-personal-syntax-check.sh`
     - `tests/ansible/deploy-observability-syntax-check.sh`

3. Alinear CI/CD y documentación
   - Resultado esperado: workflows manuales coherentes con el contrato de Infisical y docs actualizadas al nuevo naming.
   - Validación:
     - `tests/ansible/check.sh`
     - revisión YAML de `.github/workflows/*.yml`

## Risks

- `core` depende de upstreams de observability definidos en NGINX, así que el orden de rollout sigue importando.

---

## Goal

Documentar contrato operativo de variables y secretos, y dejar registradas decisiones estructurales del repositorio para evitar ambigüedad en CI/CD, runtime y provisioning.

## Scope

- Crear un documento en `docs/` con matriz de variables y secretos.
- Crear un ADR corto en `docs/adr/` con decisiones de estructura vigentes.
- Mantener CD manual en GitHub Actions.
- Explicar el boundary actual de `runtime`.
- Explicar estado decidido de provisioning para Grafana.

## Assumptions

- No se cambia comportamiento del repositorio en este paso; solo se documenta contrato y decisiones.
- Las decisiones deben reflejar estado actual del árbol.
- Si más adelante cambian `runtime` o provisioning, debe abrirse un nuevo ADR.

## Steps

1. Crear `docs/secrets-and-variables.md`
2. Crear `docs/adr/0001-structure-decisions.md`
3. Actualizar `docs/README.md` con enlaces nuevos
4. Revisar consistencia con workflows, compose y group_vars actuales

## Validation

- Verificar que nombres documentados existan en `.github/workflows/*.yml`
- Verificar que paths y contratos coincidan con `compose/` y `ansible/inventories/production/group_vars/`
- Revisar enlaces desde `docs/README.md`

## Risks

- Si decisiones documentadas no reflejan intención futura del proyecto, luego habrá que reemplazarlas con un ADR nuevo.
- Documentar estado actual de `runtime` puede consolidar acoplamientos que después convenga separar.
- Un modelo de variables demasiado genérico puede volver menos legibles los roles.
- Si falta algún secreto opcional/obligatorio en workflows, el primer run en GitHub fallará aunque la sintaxis local pase.

## Ready-to-implement summary

La ruta mínima segura es: 1) mover `deploy-core` a `deploy` sin cambiar el comportamiento de `core`, 2) extraer un contrato de variables por stack en `group_vars/deploy.yml`, 3) añadir `personal` y `observability` como despliegues independientes con sus propios workflows y syntax-checks, y 4) cerrar con una validación integral desde `tests/ansible/check.sh`.

---

## Goal

Consolidar los workflows de deploy en un solo `.github/workflows/deploy.yml` parametrizado por stack, manteniendo separados los playbooks y roles de Ansible para no perder modularidad operacional ni mezclar dominios.

## Scope

- Reemplazar los workflows `deploy-personal.yml` y `deploy-observability.yml` por un único `deploy.yml` con input `stack`.
- Mantener los playbooks `deploy.yml`, `deploy-personal.yml` y `deploy-observability.yml`.
- Resolver dentro del workflow la selección de syntax-check, playbook y staging de secretos según stack.
- Actualizar la documentación operativa del flujo de deploy.

## Non-goals

- No crear un “deploy all”.
- No fusionar playbooks de Ansible.
- No cambiar la estructura de stacks ni de secretos en `group_vars`.
- No tocar bootstrap ni runtime.

## Likely files

- `.github/workflows/deploy.yml`
- `.github/workflows/deploy-personal.yml`
- `.github/workflows/deploy-observability.yml`
- `docs/operations/deploy.md`
- `PLANS.md`

## Assumptions

- Todos los stacks siguen usando el mismo acceso SSH al host.
- La diferencia por stack se resuelve con secretos runtime y playbooks distintos.
- GitHub Actions puede seguir usando `workflow_dispatch` con inputs simples y explícitos.

## Milestones

1. Diseñar selección por stack dentro de `deploy.yml`
   - Resultado esperado: inputs claros para `stack`, `git_ref` y `check_mode`.
   - Validación:
     - revisión del YAML

2. Consolidar la lógica de ejecución
   - Resultado esperado: un solo workflow instala dependencias, prepara SSH, materializa secretos correctos y ejecuta el playbook correcto según `stack`.
   - Validación:
     - revisión estática de ramas `core`, `personal`, `observability`

3. Eliminar workflows duplicados y actualizar docs
   - Resultado esperado: una sola entrypoint de deploy en GitHub Actions y documentación alineada.
   - Validación:
     - `rg 'deploy-personal|deploy-observability' .github docs`

## Risks

- Un workflow único mal hecho puede esconder errores de contrato por stack.
- Si la lógica condicional queda demasiado implícita, la operación puede perder claridad.
- El orden de rollout sigue importando aunque exista un solo workflow.

## Ready-to-implement summary

La ruta mínima segura es mantener Ansible separado por stack y unificar solo la capa de GitHub Actions. El workflow único debe recibir `stack`, validar los secretos requeridos para ese stack, generar los archivos temporales necesarios y ejecutar el syntax-check y playbook correspondientes.
