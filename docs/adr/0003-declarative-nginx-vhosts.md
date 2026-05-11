# ADR 0003: Declarative NGINX vhosts

## Estado

Aprobado

## Contexto

El routing de NGINX para `core` mezclaba dominios, TLS, redirects y upstreams dentro de un template con lógica implícita.

El caso problemático fue S3 privado:

- DNS privado resolvía `s3.victus.io`
- NGINX redirigía HTTP a HTTPS porque existía un certificado
- el certificado no cubría `s3.victus.io`
- el endpoint S3 privado necesitaba HTTP sobre Tailscale, no HTTPS público

## Decisión

`core` declara vhosts en inventario Ansible mediante `networking.vhosts`.

Cada vhost define:

- `domains`
- `upstream`
- `access_policy`
- `preserve_host`
- `http.enabled`
- `http.redirect_to_https`
- `https.enabled`

NGINX se renderiza desde ese modelo. Certbot solo considera vhosts con `https.enabled: true` y excluye wildcard domains hasta implementar DNS-01.

`core` separa dos edges:

- `nginx-private`: bind a IP Tailscale, sin certbot, para S3 y servicios administrativos.
- `nginx-public`: sin puertos publicados por ahora, reservado para futuros servicios públicos con TLS.

## Fase actual

Fase 1 deja endpoints `victus.io` como HTTP privado sobre Tailscale:

- `seaweed.victus.io`
- `filer.victus.io`
- `s3.victus.io`
- `*.s3.victus.io`

S3 queda explícitamente sin redirect HTTP -> HTTPS.

La política de acceso de `nginx-private` vive en el bind a la IP Tailscale/firewall del host. No usa allow/deny por IP dentro de NGINX, porque Docker bridge port publishing oculta la IP real del cliente y NGINX ve el gateway Docker como origen.

## Fase futura

Fase 2 agregará DNS-01 para certificados privados/wildcard:

- `s3.victus.io`
- `*.s3.victus.io`

## Consecuencias

- GitHub Actions ya no decide dominio de `core` vía `BASE_DOMAIN`.
- `deploy.yml` queda reservado para mecánica de despliegue; `networking.yml` define contrato de red.
- Cambios de routing quedan visibles en PR.
- El deploy evita redirects accidentales por existencia de certificados.
- HTTPS privado queda diferido hasta necesidad real o DNS-01.
