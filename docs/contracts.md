# Contratos

Este repo mantiene runtime y contratos compartidos.
No mantiene SDK bridge ni consumers.

## Storage S3

Bucket principal:

```text
victus-corpus
```

Layout por paper:

```text
papers/{sha256_hash}/raw/source.pdf
papers/{sha256_hash}/stages/01_metadata/
papers/{sha256_hash}/stages/02_normalized/
papers/{sha256_hash}/stages/03_docling/
papers/{sha256_hash}/stages/04_claims/
```

Contrato declarativo:

```text
compose/configs/seaweedfs/buckets.json
```

## Postgres

Database:

```text
victus_registry
```

Tabla:

```text
paper_registry
```

Campos:

```text
paper_id     text primary key
doi          text null
s3_prefix    text not null
status_proc  pending | processing | completed | failed
status_rag   pending | indexed | error
last_event   timestamptz
created_at   timestamptz
updated_at   timestamptz
```

## Redis

Redis es event log operacional durable usando Streams.

Stream principal:

```text
victus:events
```

Producer:

```text
XADD victus:events * event_type <event> paper_id <id?> timestamp <unix_ts> payload <json>
```

Consumers externos deben usar consumer groups:

```text
XGROUP CREATE victus:events <group> 0 MKSTREAM
XREADGROUP GROUP <group> <consumer> STREAMS victus:events >
XACK victus:events <group> <message_id>
```

Delivery:

```text
durable
replayable
ack required by consumers
Postgres remains source of truth
```

Eventos genéricos:

```text
victus:artifact:done
victus:stage:started
victus:stage:done
victus:error
```

Dead Letter Stream:

```text
victus:events:dead
```

Uso:

```text
consumer validation error -> XADD victus:events:dead -> XACK original
```

## DNS Privado

Zona:

```text
victus.io
```

S3:

```text
s3.victus.io
*.s3.victus.io
```
