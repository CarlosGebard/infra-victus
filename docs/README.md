# Documentación

Esta carpeta contiene solo documentos vivos y operativos.

## Orden De Lectura

1. [Setup](setup.md)
2. [Arquitectura](architecture.md)
3. [Contratos](contracts.md)
4. [Operación](operations.md)
5. [Seguridad](security.md)
6. [Roadmap](roadmap.md)

## Plantilla Para Otros Repos

Usar esta estructura base:

```text
README.md              qué es, cómo correr, cómo validar
docs/setup.md          instalación local y variables
docs/architecture.md   componentes y límites
docs/contracts.md      APIs, eventos, storage, schemas
docs/operations.md     deploy, logs, rollback, troubleshooting
docs/security.md       secretos, permisos, red, datos sensibles
docs/roadmap.md        próximos pasos y deuda técnica
```

Regla:

- README corto.
- Docs con comandos reales.
- Sin decisiones históricas largas.
- Sin duplicar contenido.
- Si algo cambia el uso, actualizar docs en el mismo commit.

