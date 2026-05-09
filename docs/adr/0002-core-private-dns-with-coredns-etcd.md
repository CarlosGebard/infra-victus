# ADR 0002: DNS Privado de Core con CoreDNS + etcd

## Estado

Aprobado

## Contexto

`core` ya aloja servicios base de app stack como `nginx` y `seaweedfs`.

Se necesita service discovery privado bajo zona `victus.io`, con soporte para:

- `s3.victus.io`
- `*.s3.victus.io`

Caso más sensible: `SeaweedFS` vía S3 virtual-host style. Cada bucket debe resolver contra misma IP privada del VPS sin hardcodearla en Compose ni en configs estáticas.

IP de Tailscale puede cambiar, así que DNS debe desacoplarse de archivos versionados y poblarse dinámicamente.

## Decisión

Se agrega DNS privado dentro de stack `core` usando:

- `etcd` como backend de datos SkyDNS en ruta `/skydns`
- `CoreDNS` como servidor autoritativo para `victus.io`
- script operacional versionado para leer IP actual de `tailscale0` y escribir registros en `etcd`

Diseño elegido:

- `etcd` queda interno a red `core_backend`
- `CoreDNS` consume `etcd` por endpoint interno `http://etcd:2379`
- `CoreDNS` también hace `forward` de zona raíz `.` a `1.1.1.1`
- registro base `s3.victus.io` usa JSON SkyDNS con `ttl` explícito
- wildcard `*.s3.victus.io` se resuelve con `template`, usando la IP detectada por sync

## Razones

- respeta principio de "Compose como source of truth"
- evita hardcodear IP Tailscale en repo
- mantiene ortogonalidad: config estática separada de dato dinámico
- deja wildcard S3 resoluble desde dominio privado `s3.victus.io`
- no mezcla esta responsabilidad con servicios personales externos al proyecto principal

## Consecuencias

- `core` incorpora dos servicios más: `etcd` y `coredns`
- operación post-deploy debe ejecutar script de sync al menos una vez por cambio de IP
- TTL corto reduce latencia tras cambio de IP; valor inicial `30s`
- no hay HA de DNS/etcd en esta iteración
- wildcard depende de `template` en CoreDNS y del recreate de `coredns` cuando cambia la IP

## Notas operativas

- no se usa lease TTL de `etcd`; se fija `ttl` en payload JSON para evitar cache pinning accidental y para mantener comportamiento predecible
- publicar `53/tcp` y `53/udp` en host puede requerir bind específico o firewall según runtime del VPS
- si un servicio externo necesita DNS privado, debe definirse fuera de esta infraestructura o en una decisión nueva

## Referencias

- [compose/projects/core/compose.yml](/home/carlos/victus/infra-victus/compose/projects/core/compose.yml)
- [compose/configs/coredns/Corefile](/home/carlos/victus/infra-victus/compose/configs/coredns/Corefile)
- [sync-core-dns.sh](/home/carlos/victus/infra-victus/ops/scripts/runtime/sync-core-dns.sh)
