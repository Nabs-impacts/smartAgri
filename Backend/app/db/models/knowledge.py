import uuid
from typing import Any
from pgvector.sqlalchemy import Vector
from sqlalchemy import (
    BigInteger,
    CheckConstraint,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
)
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.base import Base, CreatedAtMixin, UUIDPrimaryKeyMixin
from app.db.models.farming import Crop, Plot
from app.db.models.identity import User
from app.db.models.media_ai import MediaFile


class KnowledgeDocument(Base, UUIDPrimaryKeyMixin, CreatedAtMixin):
    __tablename__ = "knowledge_documents"

    title: Mapped[str] = mapped_column(String, nullable=False)
    source_org: Mapped[str | None] = mapped_column(String, nullable=True)
    url: Mapped[str | None] = mapped_column(String, nullable=True)
    storage_key: Mapped[str | None] = mapped_column(String, nullable=True)
    language: Mapped[str] = mapped_column(
        String, server_default="fr", default="fr", nullable=False
    )
    crop_id: Mapped[int | None] = mapped_column(
        Integer, ForeignKey("crops.id"), nullable=True
    )
    published_year: Mapped[int | None] = mapped_column(Integer, nullable=True)
    ingest_status: Mapped[str] = mapped_column(
        String,
        server_default="pending",
        default="pending",
        nullable=False,
    )

    crop: Mapped[Crop | None] = relationship("Crop")
    chunks: Mapped[list["KnowledgeChunk"]] = relationship(
        "KnowledgeChunk", back_populates="document", cascade="all, delete-orphan"
    )

    __table_args__ = (
        CheckConstraint(
            "ingest_status IN ('pending', 'processing', 'done', 'failed')",
            name="chk_knowledge_documents_status",
        ),
    )


class KnowledgeChunk(Base, CreatedAtMixin):
    __tablename__ = "knowledge_chunks"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    document_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("knowledge_documents.id", ondelete="CASCADE"),
        nullable=False,
    )
    chunk_index: Mapped[int] = mapped_column(Integer, nullable=False)
    content: Mapped[str] = mapped_column(Text, nullable=False)
    embedding: Mapped[list[float]] = mapped_column(Vector(1024), nullable=False)

    document: Mapped[KnowledgeDocument] = relationship(
        "KnowledgeDocument", back_populates="chunks"
    )

    __table_args__ = (
        Index(
            "ix_knowledge_chunks_embedding",
            "embedding",
            postgresql_using="hnsw",
            postgresql_with={"m": 16, "ef_construction": 64},
            postgresql_ops={"embedding": "vector_cosine_ops"},
        ),
    )


class ChatSession(Base, UUIDPrimaryKeyMixin, CreatedAtMixin):
    __tablename__ = "chat_sessions"

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    plot_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("plots.id"), nullable=True
    )
    title: Mapped[str | None] = mapped_column(String, nullable=True)

    user: Mapped[User] = relationship("User")
    plot: Mapped[Plot | None] = relationship("Plot")
    messages: Mapped[list["ChatMessage"]] = relationship(
        "ChatMessage", back_populates="session", cascade="all, delete-orphan"
    )


class ChatMessage(Base, CreatedAtMixin):
    __tablename__ = "chat_messages"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    session_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("chat_sessions.id", ondelete="CASCADE"),
        nullable=False,
    )
    role: Mapped[str] = mapped_column(String, nullable=False)
    content: Mapped[str] = mapped_column(Text, nullable=False)
    media_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("media_files.id"), nullable=True
    )
    citations: Mapped[list[Any] | None] = mapped_column(JSONB, nullable=True)
    tokens_in: Mapped[int | None] = mapped_column(Integer, nullable=True)
    tokens_out: Mapped[int | None] = mapped_column(Integer, nullable=True)

    session: Mapped[ChatSession] = relationship("ChatSession", back_populates="messages")
    media: Mapped[MediaFile | None] = relationship("MediaFile")

    __table_args__ = (
        CheckConstraint(
            "role IN ('user', 'assistant', 'system')",
            name="chk_chat_messages_role",
        ),
        Index("ix_chat_messages_session_id_id", "session_id", "id"),
    )
