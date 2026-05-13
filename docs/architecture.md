# Arquitectura

## Propósito

`victus-infra` entrega runtime común para repos Victus.

Este repo no implementa lógica de producto, Solo provee infraestructura común y contratos de comunicación.

## Componentes

### Core
```text
nginx-private    edge HTTP privado
nginx-public     reservado para edge público
seaweedfs        storage S3-compatible
postgres         registry durable de papers
redis            durable event stream
etcd             backend DNS privado
coredns          DNS privado victus.io
```

### Observability
```text
grafana
prometheus
loki
```

## Redes
```text
core_backend          red interna de core
infra_shared_backend  red compartida entre repos/stacks
edge                  edge NGINX
```

Servicios pensados para otros repos:
```text
postgres
redis
seaweedfs
```

## Datos

Producción:

```text
/srv/apps      compose/configs/scripts desplegados
/srv/data      datos persistentes
/srv/logs      logs de servicios
/srv/secrets   secretos runtime
```

## Flujo De Ingesta Esperado

```text
repo consumidor
  -> bridge
    -> Postgres: registra paper/estado
    -> SeaweedFS: sube o referencia artefacto
    -> Redis Streams: publica evento durable
```

Postgres es source of truth. Redis Streams es event log operacional para workers/consumers.
