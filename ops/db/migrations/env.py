import os
from logging.config import fileConfig

from alembic import context
from sqlalchemy import URL
from sqlalchemy import engine_from_config, pool


config = context.config

if config.config_file_name is not None:
    fileConfig(config.config_file_name)

target_metadata = None


def database_url() -> str:
    dsn = os.environ.get("VICTUS_PG_DSN")
    if dsn:
        return dsn

    user = os.environ.get("POSTGRES_USER", "victus")
    password = os.environ.get("POSTGRES_PASSWORD")
    database = os.environ.get("POSTGRES_DB", "victus_registry")
    host = os.environ.get("POSTGRES_HOST", "postgres")
    port = os.environ.get("POSTGRES_PORT", "5432")

    if not password:
        raise RuntimeError("POSTGRES_PASSWORD or VICTUS_PG_DSN is required")

    url = URL.create(
        "postgresql+psycopg",
        username=user,
        password=password,
        host=host,
        port=int(port),
        database=database,
    )
    return url.render_as_string(hide_password=False)


def run_migrations_online() -> None:
    config.set_main_option("sqlalchemy.url", database_url())
    connectable = engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )

    with connectable.connect() as connection:
        context.configure(connection=connection, target_metadata=target_metadata)
        with context.begin_transaction():
            context.run_migrations()


run_migrations_online()
