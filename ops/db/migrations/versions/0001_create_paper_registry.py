"""create paper registry

Revision ID: 0001_create_paper_registry
Revises:
Create Date: 2026-05-12
"""

from alembic import op


revision = "0001_create_paper_registry"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        """
        DO $$
        BEGIN
          IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'paper_proc_status') THEN
            CREATE TYPE paper_proc_status AS ENUM ('pending', 'processing', 'completed', 'failed');
          END IF;
        END
        $$;
        """
    )
    op.execute(
        """
        DO $$
        BEGIN
          IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'paper_rag_status') THEN
            CREATE TYPE paper_rag_status AS ENUM ('pending', 'indexed', 'error');
          END IF;
        END
        $$;
        """
    )
    op.execute(
        """
        CREATE TABLE IF NOT EXISTS paper_registry (
          paper_id text PRIMARY KEY,
          doi text,
          s3_prefix text NOT NULL,
          status_proc paper_proc_status NOT NULL DEFAULT 'pending',
          status_rag paper_rag_status NOT NULL DEFAULT 'pending',
          last_event timestamptz NOT NULL DEFAULT now(),
          created_at timestamptz NOT NULL DEFAULT now(),
          updated_at timestamptz NOT NULL DEFAULT now(),
          CONSTRAINT paper_registry_s3_prefix_format CHECK (s3_prefix ~ '^papers/[^/]+/$')
        );
        """
    )
    op.execute("CREATE INDEX IF NOT EXISTS paper_registry_status_proc_idx ON paper_registry (status_proc);")
    op.execute("CREATE INDEX IF NOT EXISTS paper_registry_status_rag_idx ON paper_registry (status_rag);")
    op.execute("CREATE INDEX IF NOT EXISTS paper_registry_last_event_idx ON paper_registry (last_event DESC);")
    op.execute(
        """
        CREATE OR REPLACE FUNCTION set_paper_registry_updated_at()
        RETURNS trigger
        LANGUAGE plpgsql
        AS $$
        BEGIN
          NEW.updated_at = now();
          RETURN NEW;
        END;
        $$;
        """
    )
    op.execute("DROP TRIGGER IF EXISTS paper_registry_set_updated_at ON paper_registry;")
    op.execute(
        """
        CREATE TRIGGER paper_registry_set_updated_at
        BEFORE UPDATE ON paper_registry
        FOR EACH ROW
        EXECUTE FUNCTION set_paper_registry_updated_at();
        """
    )


def downgrade() -> None:
    op.execute("DROP TRIGGER IF EXISTS paper_registry_set_updated_at ON paper_registry;")
    op.execute("DROP FUNCTION IF EXISTS set_paper_registry_updated_at();")
    op.execute("DROP TABLE IF EXISTS paper_registry;")
    op.execute("DROP TYPE IF EXISTS paper_rag_status;")
    op.execute("DROP TYPE IF EXISTS paper_proc_status;")

