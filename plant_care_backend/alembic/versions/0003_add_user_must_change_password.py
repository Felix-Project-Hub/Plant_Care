from __future__ import annotations

from alembic import op
import sqlalchemy as sa

revision = "0003_must_change_psw"
down_revision = "0002_add_user_points"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column("must_change_password", sa.Boolean(), nullable=False, server_default="false"),
    )
    op.alter_column("users", "must_change_password", server_default=None)


def downgrade() -> None:
    op.drop_column("users", "must_change_password")
