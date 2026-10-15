from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa
import geoalchemy2
import pgvector

revision: str = ${repr(up_revision)}
down_revision: Union[str, None] = ${repr(down_revision)}
branch_labels: Union[str, Sequence[str], None] = ${repr(branch_labels)}
depends_on: Union[str, Sequence[str], None] = ${repr(depends_on)}


def upgrade() -> None:
    ${upgrades if upgrades else "return None"}


def downgrade() -> None:
    ${downgrades if downgrades else "return None"}
