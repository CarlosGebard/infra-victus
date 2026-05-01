# Hetzner First Push Checklist

Usar este documento como primer paso en la próxima sesión.

## Objetivo

Validar que `infra-victus` pueda desplegar correctamente sobre el servidor Hetzner ya preparado, sin romper por secretos, SSH o contrato host.

## Estado esperado antes de empezar

- El repo `server-bootstrap` ya existe fuera de `infra-victus`
- El servidor Hetzner ya fue bootstrappeado con `server-bootstrap`
- El usuario admin remoto ya existe
- Docker, Tailscale y Alloy package ya están instalados en el host

## 1. Validar secretos de Infisical

Confirmar que el cambio a la ruta `Hetzner-Server/` no cambió los nombres exportados a GitHub Actions.

Los workflows de `infra-victus` siguen esperando exactamente estos nombres:

- `PROD_HOST`
- `PROD_SSH_PRIVATE_KEY`
- `PROD_SSH_PORT`
- `PROD_SSH_KNOWN_HOSTS`
- `COUCHDB_USER`
- `COUCHDB_PASSWORD`
- `SEAWEED_S3_ACCESS_KEY`
- `SEAWEED_S3_SECRET_KEY`
- `GRAFANA_ADMIN_PASSWORD`

Revisar también variables de GitHub Actions `production`:

- `INFISICAL_IDENTITY_ID`
- `INFISICAL_PROJECT_SLUG`
- `INFISICAL_ENV_SLUG`
- `BASE_DOMAIN`
- `CERTBOT_EMAIL` opcional
- `CORE_RUNTIME_ENV` opcional y sin secretos

Si Infisical ahora entrega otros nombres, los workflows van a fallar.

## 2. Validar usuario SSH real

Hoy los workflows de `infra-victus` conectan con:

- `ansible_user: carlos`

Confirmar que el usuario admin del servidor Hetzner sigue siendo `carlos`.

Si no lo es:

- ajustar workflows
- ajustar `host-contract.yml`
- ajustar cualquier referencia operativa antes del primer push

## 3. Validar host key SSH

Si el host cambió desde Oracle a Hetzner, revisar:

- `PROD_SSH_KNOWN_HOSTS`

Si contiene la huella vieja del host anterior, SSH puede fallar por mismatch.

Opciones:

- actualizar `PROD_SSH_KNOWN_HOSTS` con la nueva huella
- o dejarlo vacío temporalmente para que el workflow use `ssh-keyscan`

## 4. Validar contrato host en Hetzner

Antes de cualquier `push`, ejecutar manualmente:

1. `server-bootstrap/bootstrap-host.yml` si aún no se hizo
2. `server-bootstrap/apply-runtime.yml`

`infra-victus` ya no hace esta preparación automáticamente ni la modela en Ansible.

## 5. Validar checks locales

Cuando `ansible-playbook` vuelva a estar disponible:

```bash
make ansible-check
make compose-validate
```

Si falla `make ansible-check`:

- revisar que `ansible-playbook` exista en `PATH`

Si falla `make compose-validate`:

- revisar acceso a `/var/run/docker.sock`

## 6. Primer push seguro

Solo hacer `push` a `main` cuando se cumpla todo esto:

- secretos correctos
- usuario SSH correcto
- host key correcta
- host baseline ya aplicado
- checks locales razonables

## 7. Si algo falla en el primer push

Orden de diagnóstico recomendado:

1. revisar si faltó una secret
2. revisar si el usuario SSH real no es `carlos`
3. revisar `PROD_SSH_KNOWN_HOSTS`
4. revisar permisos y directorios base en `/srv`

## 8. Archivos clave a revisar al inicio de la próxima sesión

- [host-contract.yml](/home/carlos/victus/infra-victus/ansible/inventories/production/group_vars/host-contract.yml)
- [alloy-stack.yml](/home/carlos/victus/infra-victus/ansible/inventories/production/group_vars/alloy-stack.yml)
- [deploy runbook](/home/carlos/victus/infra-victus/docs/runbooks/deploy.md)

## Nota final

La primera tarea de la próxima sesión debería ser:

1. verificar secrets de Infisical para Hetzner
2. confirmar usuario SSH real
3. confirmar que `server-bootstrap` ya dejó listo Docker, Alloy y `/srv`
4. recién después evaluar `push` a `main`
