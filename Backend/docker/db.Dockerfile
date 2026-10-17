FROM pgvector/pgvector:pg16

RUN apt-get update && apt-get install -y --no-install-recommends \
    postgresql-16-postgis-3 \
    && rm -rf /var/lib/apt/lists/*

HEALTHCHECK --interval=5s --timeout=5s --retries=5 \
    CMD pg_isready -U ${POSTGRES_USER:-smartagri} -d ${POSTGRES_DB:-smartagri} || exit 1
