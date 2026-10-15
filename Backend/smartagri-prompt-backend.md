# PROMPT — Génération du backend SmartAgri

Copie tout ce document dans ton IA de génération de code (Claude, etc.). Il est écrit à la deuxième personne, comme une consigne adressée à l'IA.

---

## 0. RÔLE ET OBJECTIF

Tu es un ingénieur backend senior Python. Tu dois écrire le **backend complet et prêt pour la production** de **SmartAgri**, une plateforme nigérienne d'IA agricole : les utilisateurs (agriculteurs, coopératives, agents de terrain, agronomes, administrations) envoient des photos/vidéos de cultures depuis une application mobile Flutter ; une IA analyse les médias, détecte maladies/ravageurs/carences et génère des conseils ; la plateforme gère aussi exploitations, parcelles, cycles de culture, carnet d'exploitation, météo, NDVI satellite, prix de marchés, alertes, surveillance des foyers de ravageurs, abonnements SaaS, licences, paiements mobile money et statistiques pour l'État.

Contexte d'usage : zones rurales du Niger, réseau 2G/3G instable, utilisateurs peu lettrés, langues **français, haoussa, zarma**. Le backend doit donc être **offline-first friendly** (synchronisation idempotente, UUID générés côté client, uploads directs vers S3).

---

## 1. RÈGLES ABSOLUES SUR LE CODE (NON NÉGOCIABLES)

1. **AUCUN COMMENTAIRE, nulle part.** Pas de `#`, pas de docstrings (`"""`), pas de commentaires `--` en SQL, pas de `#` dans les Dockerfile, YAML, `.env.example`, Makefile, `alembic.ini`, `pyproject.toml`, `requirements*.txt`. Le code doit être auto-explicatif par des noms clairs. Si tu écris un seul commentaire, la réponse est invalide.
2. **Code complet, jamais de squelette** : interdits `pass` factice, `...`, `raise NotImplementedError`, `TODO`, `FIXME`, « reste du code ici », « similaire à ci-dessus », fichiers tronqués. Chaque fichier est écrit en entier.
3. **Typage strict** : annotations de type partout, Pydantic v2 pour toutes les entrées/sorties, SQLAlchemy 2.0 avec `Mapped[...]` et `mapped_column`.
4. **Asynchrone de bout en bout** dans l'API (FastAPI + SQLAlchemy async + asyncpg + redis asyncio + httpx). Les tâches Celery utilisent des sessions synchrones ou `asyncio.run` de façon propre.
5. **Séparation des couches** : `api` (routers minces) → `services` (logique métier) → `repositories` ou requêtes SQLAlchemy dans les services → `models`. Aucune logique métier dans les routers.
6. **Aucune valeur secrète en dur.** Tout vient de variables d'environnement via `pydantic-settings`.
7. **Aucune dépendance externe obligatoire pour démarrer en local** : chaque fournisseur externe (SMS, paiement, LLM, embeddings, inférence vision, météo, satellite, push) est derrière une **interface abstraite** avec une implémentation `fake` activée par variable d'environnement, pour que tout tourne en local et en tests sans clés.
8. **Format de sortie** : pour chaque fichier, donne uniquement son chemin en titre puis un bloc de code. Pas de prose entre les fichiers, pas d'explications, pas de résumé. Seules exceptions : la liste des fichiers créés en début de phase et les commandes à lancer en fin de phase.
9. **Style** : Python 3.12, `ruff` (ligne max 100), imports triés, f-strings, pas d'`import *`, pas de variable globale mutable hors singletons de configuration/clients initialisés au démarrage.
10. **Langue** : identifiants, noms de tables, routes et messages techniques en **anglais**. Les messages d'erreur renvoyés à l'utilisateur sont des codes stables (`error.code`) accompagnés d'un `message` en français.

---

## 2. STACK IMPOSÉE

- Python 3.12, FastAPI, Uvicorn (gunicorn + workers uvicorn en prod), Pydantic v2, pydantic-settings.
- PostgreSQL 16 + **PostGIS** + **pgvector** + `pg_trgm` ; SQLAlchemy 2.0 async, asyncpg, GeoAlchemy2, pgvector (python), Alembic.
- Redis (broker Celery, cache, rate limiting, verrous) ; Celery 5 + Celery beat.
- Stockage objet S3-compatible via `aioboto3`/`boto3` (MinIO en local, Cloudflare R2 en prod).
- Sécurité : `argon2-cffi`, `PyJWT`, HMAC-SHA256.
- ML : `onnxruntime`, `numpy`, `Pillow`, extraction de keyframes vidéo avec `opencv-python-headless` ou `ffmpeg` via `subprocess` contrôlé.
- Notifications : `firebase-admin` (FCM) + interface SMS.
- Observabilité : `structlog` (JSON), middleware `X-Request-ID`, `sentry-sdk` optionnel.
- Tests : `pytest`, `pytest-asyncio`, `httpx.AsyncClient`, `testcontainers` ou base de test dédiée.
- Conteneurs : Docker multi-stage + `docker-compose.yml`.

---

## 3. ARBORESCENCE À PRODUIRE

```
smartagri-api/
├── app/
│   ├── main.py
│   ├── core/
│   │   ├── config.py
│   │   ├── security.py
│   │   ├── deps.py
│   │   ├── errors.py
│   │   ├── rate_limit.py
│   │   ├── logging.py
│   │   ├── middleware.py
│   │   ├── pagination.py
│   │   └── geo.py
│   ├── db/
│   │   ├── session.py
│   │   ├── base.py
│   │   └── models/
│   │       ├── identity.py
│   │       ├── organizations.py
│   │       ├── farming.py
│   │       ├── media_ai.py
│   │       ├── knowledge.py
│   │       ├── field_data.py
│   │       ├── billing.py
│   │       └── audit.py
│   ├── schemas/            un fichier par module d'API
│   ├── api/
│   │   ├── router.py
│   │   └── v1/
│   │       ├── auth.py  users.py  organizations.py  farms.py  cycles.py  catalog.py
│   │       ├── media.py  diagnostics.py  recommendations.py  expert.py  chat.py
│   │       ├── data.py  alerts.py  notifications.py  outbreaks.py  sync.py
│   │       ├── billing.py  webhooks.py  licenses.py  api_keys.py  admin.py  system.py
│   ├── services/
│   │   ├── auth_service.py  otp_service.py  user_service.py  organization_service.py
│   │   ├── farm_service.py  cycle_service.py  media_service.py  storage_service.py
│   │   ├── diagnostic_service.py  recommendation_service.py  expert_service.py
│   │   ├── chat_service.py  rag_service.py  weather_service.py  ndvi_service.py
│   │   ├── market_service.py  calendar_service.py  alert_service.py
│   │   ├── notification_service.py  outbreak_service.py  sync_service.py
│   │   ├── subscription_service.py  quota_service.py  license_service.py
│   │   ├── api_key_service.py  stats_service.py  audit_service.py
│   │   └── payments/
│   │       ├── base.py  fake.py  aggregator.py  registry.py  webhook_handler.py
│   ├── providers/
│   │   ├── sms/        base.py  fake.py  http.py
│   │   ├── push/       base.py  fake.py  fcm.py
│   │   ├── llm/        base.py  fake.py  anthropic.py
│   │   ├── embeddings/ base.py  fake.py  http.py
│   │   ├── weather/    base.py  fake.py  open_meteo.py
│   │   └── satellite/  base.py  fake.py  sentinel.py
│   ├── ml/
│   │   ├── inference.py  preprocess.py  rules_engine.py  model_registry.py
│   └── workers/
│       ├── celery_app.py  schedules.py
│       ├── tasks_diagnostic.py  tasks_ingest.py  tasks_weather.py  tasks_ndvi.py
│       ├── tasks_notifications.py  tasks_billing.py  tasks_media.py  tasks_outbreaks.py
├── alembic/  (env.py, script.py.mako, versions/0001_initial.py)
├── alembic.ini
├── scripts/  seed.py  create_superuser.py
├── tests/
│   ├── conftest.py  test_auth.py  test_farms.py  test_sync.py  test_media.py
│   ├── test_diagnostics.py  test_billing.py  test_webhooks.py  test_quota.py
│   ├── test_permissions.py  test_outbreaks.py  test_licenses.py
├── docker/  api.Dockerfile  db.Dockerfile
├── docker-compose.yml
├── Makefile
├── pyproject.toml
├── requirements.txt
├── requirements-dev.txt
└── .env.example
```

---

## 4. CONFIGURATION (`app/core/config.py`) ET `.env.example`

Variables (toutes présentes dans `.env.example`, sans commentaires) :

- Application : `APP_ENV` (local|staging|production), `APP_NAME`, `API_PREFIX=/api/v1`, `CORS_ORIGINS` (liste séparée par virgules), `LOG_LEVEL`, `SENTRY_DSN`.
- Base : `DATABASE_URL` (postgresql+asyncpg), `DATABASE_URL_SYNC` (psycopg pour Alembic/Celery), `DB_POOL_SIZE`, `DB_MAX_OVERFLOW`.
- Redis : `REDIS_URL`, `CELERY_BROKER_URL`, `CELERY_RESULT_BACKEND`.
- Sécurité : `JWT_SECRET`, `JWT_ALGORITHM=HS256`, `ACCESS_TOKEN_MINUTES=15`, `REFRESH_TOKEN_DAYS=30`, `OTP_HMAC_SECRET`, `OTP_TTL_SECONDS=300`, `OTP_MAX_ATTEMPTS=5`, `OTP_REQUESTS_PER_WINDOW=3`, `OTP_WINDOW_SECONDS=600`, `API_KEY_PEPPER`, `LICENSE_KEY_PEPPER`, `LICENSE_TOKEN_SECRET`.
- Stockage : `S3_ENDPOINT_URL`, `S3_REGION`, `S3_ACCESS_KEY`, `S3_SECRET_KEY`, `S3_BUCKET`, `S3_PRESIGN_UPLOAD_SECONDS=600`, `S3_PRESIGN_READ_SECONDS=600`.
- Limites médias : `MAX_IMAGE_BYTES=3145728`, `MAX_VIDEO_BYTES=20971520`, `MAX_VIDEO_SECONDS=15`, `MAX_AUDIO_BYTES=2097152`, `MAX_AUDIO_SECONDS=60`, `ALLOWED_IMAGE_MIME`, `ALLOWED_VIDEO_MIME`, `ALLOWED_AUDIO_MIME`.
- IA : `INFERENCE_MODE` (stub|onnx), `MODEL_CACHE_DIR`, `DIAGNOSTIC_CONFIDENCE_THRESHOLD=0.70`, `OUTBREAK_MIN_CONFIDENCE=0.50`, `OUTBREAK_ALERT_THRESHOLD=5`, `OUTBREAK_ALERT_WINDOW_DAYS=7`, `KEYFRAME_COUNT=5`.
- Fournisseurs : `SMS_PROVIDER` (fake|http), `SMS_HTTP_URL`, `SMS_HTTP_KEY`, `PUSH_PROVIDER` (fake|fcm), `FCM_CREDENTIALS_PATH`, `LLM_PROVIDER` (fake|anthropic), `LLM_API_KEY`, `LLM_MODEL`, `EMBEDDING_PROVIDER` (fake|http), `EMBEDDING_HTTP_URL`, `EMBEDDING_HTTP_KEY`, `EMBEDDING_DIM=1024`, `WEATHER_PROVIDER` (fake|open_meteo), `SATELLITE_PROVIDER` (fake|sentinel), `SENTINEL_CLIENT_ID`, `SENTINEL_CLIENT_SECRET`.
- Paiements : `PAYMENT_PROVIDER_MODE` (fake|live), `PAYMENT_AGGREGATOR_BASE_URL`, `PAYMENT_AGGREGATOR_API_KEY`, `PAYMENT_AGGREGATOR_WEBHOOK_SECRET`, `PAYMENT_PENDING_TIMEOUT_MINUTES=30`, `SUBSCRIPTION_RENEWAL_REMINDER_DAYS=3`.
- Divers : `DATA_EXPORT_URL_SECONDS`, `RATE_LIMIT_LOGIN_PER_MINUTE=10`, `RATE_LIMIT_DEFAULT_PER_MINUTE=120`.

---

## 5. CONVENTIONS TRANSVERSES

- **Préfixe** `/api/v1`. JSON UTF-8. Dates ISO 8601 UTC. Montants en **XOF entiers**.
- **Auth** : header `Authorization: Bearer <access_token>`. Access JWT HS256 de 15 min (claims : `sub`, `role`, `jti`, `exp`, `iat`). Refresh token opaque (64 octets `secrets.token_urlsafe`), stocké en **SHA-256**, 30 jours, **rotation** à chaque usage ; si un refresh déjà révoqué est rejoué, **révoquer tous les refresh tokens de l'utilisateur**.
- **Mots de passe** : argon2id. **OTP** : 6 chiffres, stocké en HMAC-SHA256, expiration 5 min, 5 tentatives, 3 demandes max / 10 min / numéro (Redis).
- **Téléphones** : normalisés en E.164 (indicatif Niger `+227` par défaut si absent) avant tout traitement.
- **Rôles** : `farmer`, `field_agent`, `agronomist`, `org_admin`, `gov_admin`, `super_admin`. Dépendance `require_roles(*roles)`.
- **Propriété** : un utilisateur n'accède qu'à ses ressources ; un `field_agent` et les `owner/admin/agent` d'une organisation accèdent aux fermes de ses membres ; `gov_admin` n'accède qu'à des **agrégats anonymisés**.
- **Pagination** : `?limit=20` (max 100) et `?cursor=<opaque>` ; réponse `{ "items": [...], "next_cursor": null | "..." }`. Curseur = base64url de `(created_at|updated_at, id)`.
- **Erreurs** : toujours `{ "error": { "code": "...", "message": "...", "details": ... } }`. Codes : `VALIDATION_ERROR` (422), `UNAUTHORIZED` (401), `FORBIDDEN` (403), `NOT_FOUND` (404), `CONFLICT` (409), `RATE_LIMITED` (429), `QUOTA_EXCEEDED` (403), `UPLOAD_INVALID` (400), `PAYMENT_FAILED` (402), `INVALID_SIGNATURE` (401), `INTERNAL_ERROR` (500). Handlers globaux pour tout.
- **Idempotence** : header `Idempotency-Key` **obligatoire** sur `POST /subscription/checkout`, accepté sur `POST /diagnostics` et `POST /media/uploads`. Stockage Redis 24 h de `(clé, utilisateur, route) → réponse`. Même clé + même corps = même réponse ; même clé + corps différent = 409.
- **UUID côté client** : `farms`, `plots`, `crop_cycles`, `farm_activities`, `harvests`, `media_files`, `diagnostics` acceptent un `id` fourni ; si l'id existe déjà **pour le même propriétaire**, retourner la ressource existante (200) au lieu d'une erreur ; s'il appartient à un autre utilisateur, 409.
- **Suppression douce** (`deleted_at`) sur les tables marquées `+deleted_at` ; toutes les requêtes de lecture filtrent `deleted_at IS NULL`.
- **Audit** : toute action admin, tout changement de rôle, révocation de licence/clé API, suppression de compte, écrit dans `audit_logs`.
- **Rate limiting** : middleware Redis par IP et par utilisateur ; limites spécifiques OTP et login.
- **Request ID** : généré si absent, renvoyé en `X-Request-ID`, présent dans tous les logs.
- **Santé** : `/health` vérifie Postgres, Redis, S3.

---

## 6. BASE DE DONNÉES — 45 TABLES

Raccourcis : `+created_at` = `created_at TIMESTAMPTZ NOT NULL DEFAULT now()` ; `+updated_at` = `updated_at TIMESTAMPTZ NOT NULL DEFAULT now()` avec trigger `set_updated_at` ; `+deleted_at` = `deleted_at TIMESTAMPTZ NULL`. Les valeurs « A|B|C » sont des contraintes `CHECK` sur `TEXT` (pas d'ENUM PostgreSQL). Les UUID ont `DEFAULT gen_random_uuid()` mais peuvent être fournis. Extensions : `postgis`, `vector`, `pg_trgm`. Les migrations Alembic doivent créer les extensions, la fonction de trigger, tous les index listés, les triggers `updated_at` sur chaque table ayant `+updated_at`, et la vue `v_cycle_yield`.

### 6.1 Identité et accès

1. **admin_areas** : id SERIAL PK ; parent_id INT FK admin_areas ; level TEXT (region|departement|commune) ; name TEXT ; code TEXT UNIQUE ; geom geometry(MultiPolygon,4326) NULL. Index GIST(geom).
2. **users** : id UUID PK ; phone TEXT UNIQUE NOT NULL ; email TEXT UNIQUE NULL ; password_hash TEXT NULL ; full_name TEXT NOT NULL ; role TEXT (farmer|field_agent|agronomist|org_admin|gov_admin|super_admin) DEFAULT 'farmer' ; language TEXT (fr|ha|dje|en) DEFAULT 'fr' ; admin_area_id INT FK ; is_active BOOL DEFAULT true ; phone_verified_at TIMESTAMPTZ NULL ; last_login_at TIMESTAMPTZ NULL ; +created_at +updated_at +deleted_at.
3. **otp_codes** : id UUID PK ; phone TEXT ; code_hash TEXT ; purpose TEXT (login|verify_phone|reset_password) ; attempts INT DEFAULT 0 ; expires_at TIMESTAMPTZ ; consumed_at TIMESTAMPTZ NULL ; +created_at. Index (phone, created_at DESC).
4. **devices** : id UUID PK ; user_id UUID FK users CASCADE ; platform TEXT (android|ios) ; fcm_token TEXT ; app_version TEXT ; last_seen_at TIMESTAMPTZ ; +created_at. Unique (user_id, fcm_token).
5. **refresh_tokens** : id UUID PK ; user_id UUID FK CASCADE ; device_id UUID FK devices SET NULL ; token_hash TEXT UNIQUE ; expires_at ; revoked_at NULL ; +created_at.
6. **consents** : id UUID PK ; user_id FK CASCADE ; type TEXT (terms|privacy|data_sharing_gov|research) ; version TEXT ; accepted BOOL ; +created_at.

### 6.2 Organisations

7. **organizations** : id UUID PK ; name TEXT ; type TEXT (cooperative|ngo|agri_company|bank|insurer|government|other) ; registration_no TEXT NULL ; admin_area_id INT FK NULL ; contact_phone TEXT NULL ; contact_email TEXT NULL ; is_active BOOL DEFAULT true ; +created_at +updated_at.
8. **organization_members** : organization_id UUID FK CASCADE ; user_id UUID FK CASCADE ; member_role TEXT (owner|admin|agent|member) DEFAULT 'member' ; joined_at TIMESTAMPTZ DEFAULT now() ; PK (organization_id, user_id).

### 6.3 Exploitations

9. **farms** : id UUID PK ; owner_id UUID FK users ; organization_id UUID FK NULL ; name TEXT ; village TEXT NULL ; admin_area_id INT FK NULL ; location geography(Point,4326) NULL ; +created_at +updated_at +deleted_at. Index (owner_id), GIST(location).
10. **plots** : id UUID PK ; farm_id UUID FK farms ; name TEXT ; area_ha NUMERIC(10,3) NULL ; geom geometry(Polygon,4326) NULL ; soil_type TEXT (sandy|loam|clay|laterite|other) NULL ; irrigation TEXT (rainfed|drip|gravity|well|other) NULL ; +created_at +updated_at +deleted_at. Index (farm_id), GIST(geom).
11. **crops** : id SERIAL PK ; code TEXT UNIQUE ; name_fr TEXT ; name_ha TEXT NULL ; name_dje TEXT NULL ; category TEXT (cereal|legume|vegetable|fruit|tuber|cash_crop|other) ; cycle_days INT NULL.
12. **crop_cycles** : id UUID PK ; plot_id UUID FK plots ; crop_id INT FK ; variety TEXT NULL ; season TEXT NULL ; sowing_date DATE NULL ; expected_harvest_date DATE NULL ; harvest_date DATE NULL ; status TEXT (planned|growing|harvested|failed) DEFAULT 'planned' ; notes TEXT NULL ; +created_at +updated_at +deleted_at. Index (plot_id, status).
13. **farm_activities** : id UUID PK ; crop_cycle_id UUID FK ; type TEXT (sowing|fertilizing|irrigation|weeding|pesticide|harvest|other) ; performed_on DATE ; product_name TEXT NULL ; quantity NUMERIC(12,2) NULL ; unit TEXT NULL ; cost_xof INT NULL ; notes TEXT NULL ; +created_at +updated_at +deleted_at. Index (crop_cycle_id, performed_on).
14. **harvests** : id UUID PK ; crop_cycle_id UUID FK ; harvested_on DATE ; quantity_kg NUMERIC(12,2) ; quality TEXT (A|B|C) NULL ; sold_kg NUMERIC(12,2) DEFAULT 0 ; avg_price_xof_per_kg NUMERIC(10,2) NULL ; +created_at +updated_at +deleted_at. Index (crop_cycle_id).

### 6.4 Médias, IA, recommandations

15. **media_files** : id UUID PK ; owner_id UUID FK users ; plot_id UUID FK NULL ; crop_cycle_id UUID FK NULL ; kind TEXT (image|video|audio) ; storage_key TEXT ; mime_type TEXT ; size_bytes BIGINT ; width INT NULL ; height INT NULL ; duration_s NUMERIC(6,1) NULL ; sha256 TEXT ; location geography(Point,4326) NULL ; captured_at TIMESTAMPTZ NULL ; upload_status TEXT (pending|uploaded|failed) DEFAULT 'pending' ; +created_at +deleted_at. Index (owner_id, created_at DESC), (sha256).
16. **ai_models** : id SERIAL PK ; name TEXT ; version TEXT ; task TEXT (disease_classification|pest_detection|deficiency|yield_prediction|llm_advisor) ; format TEXT (tflite|onnx|api|other) ; artifact_url TEXT NULL ; metrics JSONB NULL ; is_active BOOL DEFAULT false ; deployed_at TIMESTAMPTZ NULL ; +created_at ; UNIQUE (name, version). Index unique partiel : un seul `is_active = true` par `task`.
17. **diagnosis_labels** : id SERIAL PK ; code TEXT UNIQUE ; kind TEXT (disease|pest|deficiency|weed|healthy) ; name_fr TEXT ; name_ha TEXT NULL ; name_dje TEXT NULL ; description TEXT NULL ; guideline JSONB NULL.
18. **label_crops** : label_id INT FK CASCADE ; crop_id INT FK CASCADE ; PK (label_id, crop_id).
19. **diagnostics** : id UUID PK ; user_id UUID FK ; plot_id UUID FK NULL ; crop_cycle_id UUID FK NULL ; crop_id INT FK NULL ; model_id INT FK ai_models NULL ; source TEXT (on_device|server) DEFAULT 'server' ; status TEXT (pending|processing|done|needs_review|failed) DEFAULT 'pending' ; top_label_id INT FK NULL ; confidence NUMERIC(4,3) NULL ; severity TEXT (low|medium|high) NULL ; user_note TEXT NULL ; location geography(Point,4326) NULL ; error TEXT NULL ; completed_at TIMESTAMPTZ NULL ; +created_at +updated_at +deleted_at. Index (user_id, created_at DESC), (status), GIST(location).
20. **diagnostic_media** : diagnostic_id UUID FK CASCADE ; media_id UUID FK ; PK (diagnostic_id, media_id).
21. **diagnostic_predictions** : id BIGSERIAL PK ; diagnostic_id UUID FK CASCADE ; label_id INT FK ; confidence NUMERIC(4,3) ; rank SMALLINT ; bbox JSONB NULL. Index (diagnostic_id).
22. **expert_reviews** : id UUID PK ; diagnostic_id UUID FK CASCADE ; reviewer_id UUID FK users ; verdict TEXT (confirmed|corrected|unusable) ; corrected_label_id INT FK NULL ; notes TEXT NULL ; +created_at.
23. **recommendations** : id UUID PK ; user_id UUID FK ; diagnostic_id UUID FK SET NULL NULL ; plot_id UUID FK NULL ; crop_cycle_id UUID FK NULL ; source TEXT (rules|llm|expert) ; language TEXT DEFAULT 'fr' ; title TEXT ; body TEXT ; steps JSONB NULL ; citations JSONB NULL ; model_id INT FK NULL ; status TEXT (draft|published|withdrawn) DEFAULT 'published' ; validated_by UUID FK users NULL ; +created_at. Index (user_id, created_at DESC).
24. **recommendation_feedback** : recommendation_id UUID FK CASCADE ; user_id UUID FK CASCADE ; helpful BOOL NULL ; applied BOOL NULL ; comment TEXT NULL ; +created_at ; PK (recommendation_id, user_id).
25. **training_samples** : id UUID PK ; media_id UUID FK ; label_id INT FK ; crop_id INT FK NULL ; source TEXT (expert_review|field_collection|public_dataset) ; split TEXT (train|val|test) NULL ; quality_ok BOOL DEFAULT true ; +created_at.

### 6.5 RAG et chat

26. **knowledge_documents** : id UUID PK ; title TEXT ; source_org TEXT NULL ; url TEXT NULL ; storage_key TEXT NULL ; language TEXT DEFAULT 'fr' ; crop_id INT FK NULL ; published_year INT NULL ; ingest_status TEXT (pending|processing|done|failed) DEFAULT 'pending' ; +created_at.
27. **knowledge_chunks** : id BIGSERIAL PK ; document_id UUID FK CASCADE ; chunk_index INT ; content TEXT ; embedding vector(EMBEDDING_DIM) ; +created_at. Index HNSW (embedding vector_cosine_ops).
28. **chat_sessions** : id UUID PK ; user_id UUID FK CASCADE ; plot_id UUID FK NULL ; title TEXT NULL ; +created_at.
29. **chat_messages** : id BIGSERIAL PK ; session_id UUID FK CASCADE ; role TEXT (user|assistant|system) ; content TEXT ; media_id UUID FK NULL ; citations JSONB NULL ; tokens_in INT NULL ; tokens_out INT NULL ; +created_at. Index (session_id, id).

### 6.6 Données terrain, surveillance, alertes

30. **weather_data** : id BIGSERIAL PK ; admin_area_id INT FK ; obs_date DATE ; kind TEXT (observed|forecast) ; temp_min_c NUMERIC(4,1) NULL ; temp_max_c NUMERIC(4,1) NULL ; rain_mm NUMERIC(6,1) NULL ; humidity_pct NUMERIC(4,1) NULL ; wind_kmh NUMERIC(5,1) NULL ; source TEXT ; +created_at ; UNIQUE (admin_area_id, obs_date, kind, source).
31. **satellite_indices** : id BIGSERIAL PK ; plot_id UUID FK ; obs_date DATE ; ndvi NUMERIC(5,4) NULL ; evi NUMERIC(5,4) NULL ; cloud_cover_pct NUMERIC(4,1) NULL ; source TEXT DEFAULT 'sentinel-2' ; UNIQUE (plot_id, obs_date).
32. **markets** : id SERIAL PK ; name TEXT ; admin_area_id INT FK NULL ; location geography(Point,4326) NULL.
33. **market_prices** : id BIGSERIAL PK ; market_id INT FK ; crop_id INT FK ; price_date DATE ; price_xof_per_kg NUMERIC(10,2) ; source TEXT NULL ; UNIQUE (market_id, crop_id, price_date).
34. **outbreak_reports** : id UUID PK ; diagnostic_id UUID UNIQUE FK CASCADE ; label_id INT FK ; crop_id INT FK NULL ; admin_area_id INT FK NULL ; location geography(Point,4326) NULL ; severity TEXT (low|medium|high) NULL ; verified BOOL DEFAULT false ; reported_at TIMESTAMPTZ DEFAULT now(). Index GIST(location), (label_id, reported_at DESC).
35. **alerts** : id UUID PK ; type TEXT (weather|pest|disease|market|advisory|system) ; severity TEXT (info|warning|critical) DEFAULT 'info' ; title TEXT ; body TEXT ; admin_area_id INT FK NULL ; crop_id INT FK NULL ; starts_at TIMESTAMPTZ DEFAULT now() ; ends_at TIMESTAMPTZ NULL ; created_by UUID FK users NULL ; +created_at.
36. **notifications** : id UUID PK ; user_id UUID FK CASCADE ; alert_id UUID FK SET NULL NULL ; channel TEXT (push|sms|whatsapp|in_app) ; title TEXT ; body TEXT ; status TEXT (queued|sent|failed|read) DEFAULT 'queued' ; sent_at NULL ; read_at NULL ; +created_at. Index (user_id, created_at DESC).

### 6.7 Facturation et licences

37. **plans** : id SERIAL PK ; code TEXT UNIQUE ; name TEXT ; audience TEXT (farmer|organization|government) ; billing_model TEXT (free|subscription|pay_per_use|license) ; interval TEXT (month|quarter|year) NULL ; price_xof INT DEFAULT 0 ; quotas JSONB DEFAULT '{}' ; features JSONB DEFAULT '{}' ; is_active BOOL DEFAULT true.
38. **subscriptions** : id UUID PK ; user_id UUID FK NULL ; organization_id UUID FK NULL ; plan_id INT FK ; status TEXT (trialing|active|past_due|canceled|expired) ; current_period_start TIMESTAMPTZ ; current_period_end TIMESTAMPTZ NULL ; auto_renew BOOL DEFAULT false ; canceled_at NULL ; +created_at +updated_at ; CHECK `num_nonnulls(user_id, organization_id) = 1`. Index (user_id, status), (organization_id, status).
39. **payments** : id UUID PK ; user_id UUID FK NULL ; organization_id UUID FK NULL ; subscription_id UUID FK NULL ; plan_id INT FK NULL ; provider TEXT (orange_money|airtel_money|moov_money|mynita|aggregator|manual) ; provider_ref TEXT NULL ; idempotency_key TEXT UNIQUE ; purpose TEXT (subscription|top_up|license) ; amount_xof INT CHECK > 0 ; currency TEXT DEFAULT 'XOF' ; payer_phone TEXT NULL ; status TEXT (pending|succeeded|failed|refunded) DEFAULT 'pending' ; raw JSONB NULL ; +created_at ; paid_at NULL ; UNIQUE (provider, provider_ref). Index (user_id, created_at DESC), (status, created_at).
40. **payment_events** : id BIGSERIAL PK ; provider TEXT ; event_id TEXT ; payload JSONB ; signature_valid BOOL ; processed_at NULL ; +created_at ; UNIQUE (provider, event_id).
41. **usage_records** : id BIGSERIAL PK ; subscription_id UUID FK CASCADE ; metric TEXT (diagnostic|llm_message|video_analysis|storage_mb) ; quantity INT DEFAULT 1 ; period DATE ; +created_at. Index (subscription_id, metric, period).
42. **license_keys** : id UUID PK ; organization_id UUID FK ; plan_id INT FK ; key_hash TEXT UNIQUE ; max_activations INT DEFAULT 1 ; expires_at NULL ; status TEXT (active|revoked|expired) DEFAULT 'active' ; +created_at.
43. **license_activations** : id UUID PK ; license_id UUID FK CASCADE ; device_fingerprint TEXT ; activated_at DEFAULT now() ; revoked_at NULL ; UNIQUE (license_id, device_fingerprint).

### 6.8 Traçabilité et accès B2B

44. **audit_logs** : id BIGSERIAL PK ; user_id UUID FK SET NULL NULL ; action TEXT ; entity TEXT NULL ; entity_id TEXT NULL ; ip INET NULL ; meta JSONB NULL ; +created_at. Index (user_id, created_at DESC), (entity, entity_id).
45. **api_keys** : id UUID PK ; organization_id UUID FK CASCADE ; name TEXT ; key_hash TEXT UNIQUE ; scopes TEXT[] DEFAULT '{}' ; last_used_at NULL ; revoked_at NULL ; +created_at.

**Vue `v_cycle_yield`** : par `crop_cycles` non supprimé, `crop_cycle_id`, `crop_id`, `plot_id`, `area_ha`, `total_kg` (somme des `harvests` non supprimées), `yield_kg_per_ha = ROUND(total_kg / NULLIF(area_ha,0), 1)`.

---

## 7. ENDPOINTS (tous sous `/api/v1`)

Notation : `Accès` = Public | Auth | rôle(s). Toute route Auth vérifie la propriété de la ressource. Réponses d'erreur selon section 5.

### 7.1 Auth
- `POST /auth/register` — Public — body `phone, full_name, language?, password?` — normalise le téléphone, crée l'utilisateur `farmer` (409 si le téléphone existe), crée la souscription `free`, envoie un OTP `verify_phone`. 201 sans token.
- `POST /auth/otp/request` — Public — body `phone, purpose` — rate limit ; répond **toujours 202 identique** que le numéro existe ou non ; envoie le SMS via `SmsProvider`.
- `POST /auth/otp/verify` — Public — body `phone, code, purpose, device?` — vérifie le HMAC, l'expiration, les tentatives ; pour `login`/`verify_phone` marque `phone_verified_at`, enregistre l'appareil si fourni, renvoie `access_token`, `refresh_token`, `expires_in`, `user`.
- `POST /auth/login` — Public — body `phone, password, device?` — pour les rôles non-farmer ou farmers ayant un mot de passe ; rate limit login.
- `POST /auth/refresh` — Public — body `refresh_token` — rotation, détection de rejeu.
- `POST /auth/logout` — Auth — body `refresh_token` — révoque ce refresh token.
- `POST /auth/password/reset` — Public — body `phone, code, new_password` — valide un OTP `reset_password`, change le mot de passe, révoque tous les refresh tokens.

### 7.2 Compte
- `GET /users/me` — Auth — profil + abonnement effectif + quotas restants (voir 8.4).
- `PATCH /users/me` — Auth — `full_name, language, admin_area_id, email`.
- `POST /users/me/devices` — Auth — upsert `(platform, fcm_token, app_version)`.
- `DELETE /users/me/devices/{id}` — Auth.
- `POST /users/me/consents` — Auth — `type, version, accepted`.
- `GET /users/me/export` — Auth — JSON de toutes les données de l'utilisateur (profil, fermes, parcelles, cycles, activités, récoltes, diagnostics, recommandations, paiements, consentements).
- `DELETE /users/me` — Auth — anonymise : téléphone remplacé par un hash, nom/email effacés, `is_active=false`, `deleted_at` posé, appareils et refresh tokens supprimés ; données agronomiques conservées sans lien d'identité ; écrit un audit log.

### 7.3 Organisations
- `POST /organizations` — Auth — crée l'organisation, le créateur devient `owner`.
- `GET /organizations` — Auth — celles dont l'utilisateur est membre.
- `GET /organizations/{id}` — membre.
- `PATCH /organizations/{id}` — owner, admin.
- `GET /organizations/{id}/members` — owner, admin, agent — avec rôle, nombre de parcelles, surface.
- `POST /organizations/{id}/members` — owner, admin — body `phone, member_role` ; crée un compte inactif en attente si le téléphone est inconnu.
- `DELETE /organizations/{id}/members/{user_id}` — owner, admin — interdit de retirer le dernier owner.
- `GET /organizations/{id}/farms` — owner, admin, agent — fermes des membres, paginé.
- `GET /organizations/{id}/dashboard` — owner, admin — membres, parcelles, surface totale, diagnostics du mois, alertes actives, rendement moyen par culture.

### 7.4 Exploitations, parcelles, cycles
- `GET /farms` — Auth. `POST /farms` — Auth (id client, idempotent). `GET|PATCH|DELETE /farms/{id}` — propriétaire (agent/org : lecture).
- `GET /farms/{id}/plots` — propriétaire. `POST /farms/{id}/plots` — propriétaire ; si `geom` GeoJSON fourni, **recalcule `area_ha`** avec `ST_Area(geography)`.
- `GET|PATCH|DELETE /plots/{id}` — propriétaire.
- `GET /plots/{id}/timeline` — propriétaire — fusion chronologique paginée des activités, diagnostics, récoltes, indices NDVI.
- `GET /plots/{id}/cycles` — propriétaire. `POST /plots/{id}/cycles` — propriétaire ; calcule `expected_harvest_date = sowing_date + crops.cycle_days` si non fourni.
- `GET|PATCH /cycles/{id}` — propriétaire (statut modifiable).
- `GET /cycles/{id}/activities` — propriétaire. `POST /cycles/{id}/activities` — propriétaire. `PATCH|DELETE /activities/{id}` — propriétaire.
- `POST /cycles/{id}/harvests` — propriétaire — passe le cycle à `harvested` si demandé via `close_cycle=true`.
- `GET /cycles/{id}/summary` — propriétaire — rendement (vue), coûts totaux, revenu (`sold_kg × avg_price`), marge, comparaison à la moyenne des cycles de même culture dans la même zone (anonymisée, nécessite ≥ 5 cycles sinon `null`).

### 7.5 Catalogues
- `GET /crops` — Auth — avec `ETag` et `If-None-Match` (304).
- `GET /diagnosis-labels` — Auth — avec ETag, filtre `crop_id`.
- `GET /admin-areas` — Auth — filtre `parent_id`, `level` ; sans géométrie sauf `?include_geom=true`.

### 7.6 Médias
- `POST /media/uploads` — Auth — body `id, kind, mime_type, size_bytes, sha256, width?, height?, duration_s?, lat?, lng?, captured_at?, plot_id?, crop_cycle_id?` ; valide mime et limites (`MAX_*`) → `UPLOAD_INVALID` ; si même `sha256` pour le même utilisateur existe en `uploaded`, renvoie le média existant avec `already_uploaded=true` ; sinon crée `pending` et renvoie `{ media, upload: { method, url, headers, expires_in } }` (URL présignée PUT ; `multipart` initié si taille > 8 Mo). Le `storage_key` suit `users/{owner_id}/{yyyy}/{mm}/{id}.{ext}`.
- `POST /media/{id}/complete` — Auth — `HEAD` sur S3 : taille et existence conformes sinon `failed` + `UPLOAD_INVALID` ; passe `uploaded` ; pour une vidéo met en file `tasks_media.extract_keyframes`.
- `GET /media/{id}` — propriétaire, agronomist (si lié à un diagnostic en revue), super_admin — métadonnées + URL présignée de lecture.
- `DELETE /media/{id}` — propriétaire — suppression douce.

### 7.7 Diagnostics et recommandations
- `POST /diagnostics` — Auth — body `id?, media_ids[1..6], crop_id?, plot_id?, crop_cycle_id?, user_note?, lat?, lng?, source?, on_device_result?` ; vérifie que tous les médias appartiennent à l'utilisateur et sont `uploaded` ; **`check_quota('diagnostic')`** (et `video_analysis` si vidéo) ; crée le diagnostic `pending`, enregistre `usage_records`, enfile `tasks_diagnostic.run_diagnostic` ; répond **202** avec l'objet. Si `on_device_result` est fourni, il est stocké comme prédiction `rank` marquée source `on_device`.
- `GET /diagnostics` — Auth — filtres `plot_id, crop_id, status, from, to`, paginé.
- `GET /diagnostics/{id}` — propriétaire, agronomist, org agent — statut, médias (URLs présignées), `predictions` top-k avec labels localisés, `recommendation` liée.
- `POST /diagnostics/{id}/retry` — propriétaire — uniquement si `failed` ; ne ré-incrémente pas l'usage.
- `DELETE /diagnostics/{id}` — propriétaire.
- `GET /recommendations` — Auth — filtres `plot_id, crop_cycle_id`.
- `GET /recommendations/{id}` — propriétaire.
- `POST /recommendations/{id}/feedback` — propriétaire — upsert `(helpful, applied, comment)`.

### 7.8 Validation experte
- `GET /expert/reviews/queue` — agronomist — diagnostics `needs_review` ou `done` signalés, triés par confiance croissante puis date, paginé.
- `POST /expert/reviews/{diagnostic_id}` — agronomist — body `verdict, corrected_label_id?, notes?` ; en une transaction : crée la review, met à jour `top_label_id` si `corrected`, passe le diagnostic `done`, crée un `training_sample` (sauf `unusable`), publie une recommandation `expert` (régénérée via `rules_engine` sur le label final), notifie l'agriculteur.
- `GET /expert/stats` — agronomist, super_admin — taux d'accord modèle/expert par label et par culture, sur une période.

### 7.9 Chat
- `POST /chat/sessions` — Auth — `plot_id?, title?`. `GET /chat/sessions` — Auth. `DELETE /chat/sessions/{id}` — propriétaire.
- `GET /chat/sessions/{id}/messages` — propriétaire — paginé.
- `POST /chat/sessions/{id}/messages` — propriétaire — body `content, media_id?` ; `check_quota('llm_message')` ; assemble le contexte (parcelle, cycle actif, météo 7 j, 3 derniers diagnostics, langue), récupère top-5 chunks RAG (`pgvector`, similarité cosinus, filtre langue/culture), appelle le LLM avec garde-fous (voir 8.5), enregistre les deux messages avec `citations` ; si `?stream=true` renvoie du **SSE** (`text/event-stream`) avec événements `token`, `citations`, `done`.

### 7.10 Données, alertes, notifications, foyers
- `GET /plots/{id}/weather` — propriétaire — prévisions 7 jours + historique + pluie cumulée depuis le semis du cycle actif, d'après `admin_area_id` de la ferme (sinon plus proche zone par `ST_Contains`).
- `GET /plots/{id}/ndvi` — propriétaire — série triée, `trend` (up|flat|down) et `anomaly` (z-score vs moyenne des 3 dernières campagnes si disponible).
- `GET /calendar` — Auth — filtres `plot_id?, from?, to?` ; tâches à venir calculées depuis les cycles (semis, désherbage à J+15 et J+35, récolte prévue) et la météo.
- `GET /markets` — Auth — filtre `admin_area_id` ou `near=lat,lng&radius_km`. `GET /markets/prices` — Auth — filtres `crop_id, market_id, from, to` ; renvoie aussi la variation sur 30 jours.
- `GET /alerts` — Auth — alertes actives dont `admin_area_id` couvre la zone de l'utilisateur (ou NULL) et `crop_id` correspond à ses cultures actives (ou NULL).
- `POST /alerts` — agronomist, org_admin, gov_admin — crée une alerte ; enfile `tasks_notifications.fanout_alert` (push pour tous, SMS pour `critical`). `PATCH|DELETE /alerts/{id}` — auteur ou super_admin.
- `GET /notifications` — Auth — paginé. `POST /notifications/{id}/read` — Auth. `POST /notifications/read-all` — Auth.
- `GET /outbreaks` — agronomist, org_admin, gov_admin — GeoJSON `FeatureCollection`, filtres `label_id, crop_id, admin_area_id, from, to, verified`, bbox optionnelle ; **pour org_admin et gov_admin, coordonnées arrondies à 2 décimales** et aucun identifiant utilisateur.
- `GET /outbreaks/stats` — org_admin, gov_admin, super_admin — agrégats par label, zone, semaine, avec tendance.
- `PATCH /outbreaks/{id}/verify` — agronomist — body `verified`.

### 7.11 Synchronisation
- `POST /sync/push` — Auth — body `{ "changes": [ { "entity": "farm|plot|crop_cycle|farm_activity|harvest", "op": "upsert|delete", "id": uuid, "data": {...}, "updated_at": iso } ] }` (max 200 éléments) ; traitement idempotent par élément dans des sous-transactions ; règle de conflit : **`updated_at` client plus récent que celui du serveur gagne**, sinon le serveur gagne ; réponse `{ "results": [ { "id", "entity", "status": "applied|conflict|rejected", "server_updated_at", "error?" } ] }`. Les diagnostics et médias passent par leurs routes dédiées.
- `GET /sync/pull?since=<cursor>&limit=200` — Auth — renvoie toutes les entités synchronisables de l'utilisateur (et des fermes dont il est agent) modifiées depuis le curseur, **y compris les suppressions** (`deleted_at` non nul), plus les diagnostics et recommandations récents ; réponse `{ "changes": [...], "next_cursor", "has_more" }`.

### 7.12 Facturation, licences, clés API
- `GET /plans` — Public — filtres `audience`.
- `GET /subscription` — Auth — abonnement effectif (voir 8.4) + consommation du mois vs quotas.
- `POST /subscription/checkout` — Auth + `Idempotency-Key` — body `plan_id, provider, payer_phone, organization_id?` ; refuse si plan `free`/inactif ; crée `payment` `pending` (montant = `plans.price_xof`) ; appelle `payments.registry.get(provider).initiate(...)` ; renvoie `{ payment_id, status, instructions }` ; **n'active rien**.
- `GET /payments/{id}` — propriétaire. `GET /payments` — Auth — paginé.
- `POST /subscription/cancel` — Auth — `auto_renew=false`, `canceled_at=now()`, accès conservé jusqu'à `current_period_end`.
- `GET /usage` — Auth — consommation par métrique pour la période courante.
- `POST /webhooks/payments/{provider}` — Public (signature) — voir 8.3.
- `POST /licenses/activate` — Auth — body `license_key, device_fingerprint` — voir 8.6.
- `GET /organizations/{id}/license` — owner, admin — licences et activations.
- `POST /organizations/{id}/api-keys` — owner, admin — body `name, scopes[]` ; clé `sa_live_<random>` renvoyée **une seule fois**, stockée en HMAC-SHA256 avec `API_KEY_PEPPER`. `GET /organizations/{id}/api-keys`, `DELETE /organizations/{id}/api-keys/{key_id}` — owner, admin.
- Authentification par clé API : header `X-API-Key` accepté sur `GET /outbreaks`, `GET /outbreaks/stats`, `GET /admin/stats/*` selon les `scopes` (`outbreaks:read`, `stats:read`) ; met à jour `last_used_at`.

### 7.13 Administration et système
- `GET /admin/users` — super_admin — recherche (`q`, `role`, `is_active`), paginé. `PATCH /admin/users/{id}` — super_admin — `role, is_active` ; audit log.
- `GET /admin/stats/overview` — gov_admin, super_admin — utilisateurs actifs 30 j, diagnostics 30 j, surface suivie, adoption par commune.
- `GET /admin/stats/yields` — gov_admin, super_admin — rendement moyen par culture/zone/saison ; **masque toute cellule avec moins de 5 cycles**.
- `GET /admin/ai-models`, `POST /admin/ai-models` — super_admin. `POST /admin/ai-models/{id}/activate` — super_admin — désactive l'actif de la même `task` dans la même transaction.
- `POST /admin/knowledge/documents` — super_admin, agronomist — multipart (fichier PDF/texte) + métadonnées ; stocke dans S3, crée le document `pending`, enfile `tasks_ingest.ingest_document`. `GET /admin/knowledge/documents`, `DELETE /admin/knowledge/documents/{id}` — mêmes rôles.
- `GET /admin/training-samples` — super_admin. `POST /admin/training-samples/export` — super_admin — assigne `split` manquants (80/10/10 stratifié par label), écrit un manifeste JSONL dans S3, renvoie une URL présignée.
- `GET /admin/payments` — super_admin — filtres `status, provider, from, to` ; met en évidence les `pending` plus vieux que `PAYMENT_PENDING_TIMEOUT_MINUTES`.
- `POST /admin/licenses` — super_admin — body `organization_id, plan_id, max_activations, expires_at` ; renvoie la clé en clair une seule fois. `POST /admin/licenses/{id}/revoke` — super_admin.
- `GET /admin/audit-logs` — super_admin — filtres `user_id, action, entity, from, to`.
- `GET /health` — Public — 200 si DB, Redis et S3 répondent, sinon 503 avec détail. `GET /version` — Public — version, commit, environnement.

---

## 8. LOGIQUE MÉTIER DÉTAILLÉE

### 8.1 Pipeline de diagnostic (`tasks_diagnostic.run_diagnostic`)
1. Verrouille le diagnostic (`SELECT ... FOR UPDATE SKIP LOCKED`), statut `processing`.
2. Télécharge les médias depuis S3 ; images redimensionnées (côté long 1024, RGB, normalisation du modèle) ; vidéos : `KEYFRAME_COUNT` images réparties uniformément, floues écartées (variance du Laplacien).
3. Charge le modèle actif (`ai_models`, `task=disease_classification`) via `model_registry` (cache local dans `MODEL_CACHE_DIR`, vérification d'un hash). Si `INFERENCE_MODE=stub`, renvoie un résultat déterministe dérivé du sha256 des médias (labels du catalogue filtrés sur la culture) pour permettre le développement du mobile.
4. Agrège les prédictions des images (moyenne des probabilités), garde le top-3 en `diagnostic_predictions`.
5. Si `confidence ≥ DIAGNOSTIC_CONFIDENCE_THRESHOLD` : statut `done`, sinon `needs_review`. Sévérité : `high` ≥ 0,85, `medium` ≥ 0,70, sinon `low` (seuils définis en constantes de configuration).
6. Génère la recommandation : `rules_engine` lit `diagnosis_labels.guideline` ; **si `guideline.validated` n'est pas `true`, aucune recommandation chimique n'est produite** (seulement culturelle/préventive + « consulter un technicien ») ; le LLM reformule dans la langue de l'utilisateur avec les chunks RAG et renvoie `title`, `body`, `steps`, `citations` ; en cas d'échec LLM, fallback sur un gabarit issu des règles seules.
7. Si le label est `disease` ou `pest` et `confidence ≥ OUTBREAK_MIN_CONFIDENCE` : insère `outbreak_reports` (zone déduite par `ST_Contains`).
8. Notifie l'utilisateur (push puis SMS si aucun appareil enregistré), pose `completed_at`. En cas d'exception : statut `failed`, `error` renseigné, retry Celery (3 essais, backoff exponentiel) avant échec définitif.

### 8.2 Alerte automatique de foyers (`tasks_outbreaks.detect_clusters`, toutes les heures)
Pour chaque couple `(label_id, admin_area_id)` ayant ≥ `OUTBREAK_ALERT_THRESHOLD` foyers sur `OUTBREAK_ALERT_WINDOW_DAYS` jours (dont au moins un `verified`), crée une alerte `pest|disease` ciblée sur la zone et la culture, une seule fois par fenêtre (clé de déduplication), puis déclenche la diffusion.

### 8.3 Paiements et webhooks
- Interface `PaymentProvider` : `initiate(payment) -> InitResult`, `verify_signature(headers, raw_body) -> bool`, `parse_event(raw_body) -> ProviderEvent`, `fetch_status(provider_ref) -> ProviderStatus`.
- Implémentations : `fake` (dev/tests : confirme automatiquement après un délai ou via un endpoint de test), `aggregator` (client HTTP générique `httpx`, URL/clé/secret par variables d'environnement, signature HMAC-SHA256 du corps brut comparée en temps constant). Le `registry` mappe `orange_money|airtel_money|moov_money|mynita|aggregator` vers l'agrégateur configuré.
- Webhook : lit le **corps brut**, vérifie la signature (sinon enregistre `signature_valid=false`, répond 401), insère dans `payment_events` (la violation d'unicité `(provider, event_id)` répond **200 sans retraiter**), puis dans **une seule transaction** : verrouille le paiement, passe `succeeded|failed`, pose `paid_at`, et si `succeeded` active ou prolonge l'abonnement (voir 8.4), puis marque l'événement `processed_at`. Réponse 200 rapide ; tout travail lourd en tâche asynchrone.
- `tasks_billing.reconcile_pending_payments` (toutes les 10 min) : pour chaque paiement `pending` de plus de 10 min, appelle `fetch_status` et applique la même logique ; au-delà de `PAYMENT_PENDING_TIMEOUT_MINUTES` passe `failed`.

### 8.4 Abonnements et quotas
- **Abonnement effectif** d'un utilisateur : son abonnement `active|trialing` non expiré ; sinon celui de l'organisation (la plus généreuse) dont il est membre ; sinon `free` (créé à l'inscription).
- **Activation après paiement** : si une souscription active du même plan existe, `current_period_end` est prolongé de l'intervalle à partir de sa fin ; sinon une nouvelle est créée avec `current_period_start = now()`.
- **Quotas** (`plans.quotas`, clés : `diagnostics_per_month`, `llm_messages_per_month`, `video_analyses_per_month`, `plots`, `storage_mb`). Dépendance `check_quota(metric)` : somme `usage_records` du mois courant ; dépassement → 403 `QUOTA_EXCEEDED` avec `details = { metric, limit, used }`. Les quotas `plots` et `storage_mb` sont vérifiés à la création de parcelle et à l'upload.
- `tasks_billing.expire_subscriptions` (quotidien) : passe `expired` les abonnements échus et crée/restaure la souscription `free` ; `tasks_billing.send_renewal_reminders` (quotidien) : notifications `SUBSCRIPTION_RENEWAL_REMINDER_DAYS` jours avant l'échéance.

### 8.5 Chat et garde-fous LLM
Prompt système construit côté serveur : rôle d'assistant agronome pour le Niger, réponse dans la langue de l'utilisateur, concis, étapes numérotées, citations des sources RAG, **interdiction de donner des doses ou noms de pesticides non présents dans les règles validées**, recommandation de consulter un agronome ou un technicien en cas d'incertitude, refus poli hors domaine agricole. Les entrées utilisateur sont encadrées comme données et ne peuvent pas modifier les instructions système. Les tokens consommés sont enregistrés dans `chat_messages`.

### 8.6 Licences
- Génération : clé aléatoire formatée `SA-XXXX-XXXX-XXXX-XXXX`, stockée en HMAC-SHA256 (`LICENSE_KEY_PEPPER`).
- `POST /licenses/activate` : retrouve par hash, vérifie `status=active`, `expires_at`, nombre d'activations non révoquées < `max_activations` (ré-activation du même `device_fingerprint` idempotente) ; renvoie un **token de licence** JWT signé (`LICENSE_TOKEN_SECRET`) contenant `license_id`, `organization_id`, `plan_id`, `device`, `exp`.
- Une licence active confère à l'organisation un abonnement équivalent au plan lié.

### 8.7 RAG
`tasks_ingest.ingest_document` : télécharge le fichier, extrait le texte (PDF via `pypdf`), découpe en chunks de ~800 caractères avec chevauchement de 100 en respectant les paragraphes, calcule les embeddings par lots de 32 via `EmbeddingProvider`, insère dans `knowledge_chunks`, passe le document `done` (ou `failed`). Recherche : `ORDER BY embedding <=> :query LIMIT :k` avec filtres `language` et `crop_id` optionnels.

### 8.8 Météo, NDVI, marchés
- `tasks_weather.refresh_all_areas` (quotidien) : pour chaque `admin_area` ayant des fermes, récupère prévisions 7 j et observations de la veille via `WeatherProvider`, upsert dans `weather_data`.
- `tasks_ndvi.refresh_plots` (tous les 5 jours) : pour chaque parcelle avec `geom` et cycle actif, récupère NDVI/EVI via `SatelliteProvider`, upsert dans `satellite_indices`.
- Les prix de marché sont alimentés par import administrateur (route `POST /admin/market-prices/import` en CSV : `market, crop_code, date, price_xof_per_kg`) — à inclure en plus de la liste ci-dessus, rôle super_admin.

### 8.9 Autres tâches planifiées (`workers/schedules.py`)
- `tasks_media.purge_deleted_media` (quotidien) : supprime de S3 les médias `deleted_at` de plus de 7 jours puis supprime les lignes orphelines.
- `tasks_notifications.fanout_alert` : résout les destinataires par zone/culture, crée les `notifications`, envoie push par lots de 500 (FCM) et SMS pour `critical`, met à jour les statuts.
- `tasks_media.extract_keyframes` : extrait les keyframes d'une vidéo uploadée et les stocke sous `derived/{media_id}/frame_{n}.jpg`.

---

## 9. SÉCURITÉ

- Hachage argon2id ; OTP, refresh tokens, clés API, licences : **jamais en clair en base**.
- Comparaisons de secrets en temps constant (`hmac.compare_digest`).
- Validation stricte des entrées (Pydantic), taille max des corps de requête, MIME vérifié, noms de fichiers générés côté serveur.
- Pas d'énumération de comptes (réponses identiques sur OTP).
- CORS restreint à `CORS_ORIGINS`. Headers de sécurité (`X-Content-Type-Options`, `Referrer-Policy`).
- Requêtes SQL uniquement via SQLAlchemy paramétré.
- Les logs ne contiennent ni OTP, ni tokens, ni clés, ni numéros complets (masqués `+227****1234`).
- Anonymisation systématique pour `gov_admin` et clés API : pas d'identifiant utilisateur, coordonnées arrondies, seuil minimal de 5 observations par cellule agrégée.

---

## 10. DOCKER, COMPOSE, MAKEFILE

- `docker/db.Dockerfile` : image PostGIS officielle + installation de `pgvector` ; healthcheck `pg_isready`.
- `docker/api.Dockerfile` : multi-stage, utilisateur non-root, `gunicorn -k uvicorn.workers.UvicornWorker`, dépendances système minimales pour `opencv-python-headless`/`ffmpeg`.
- `docker-compose.yml` : services `db`, `redis`, `minio`, `minio-init` (création du bucket), `api`, `worker`, `beat`, avec `depends_on` conditionnels sur healthchecks, volumes nommés, variables lues depuis `.env`.
- `Makefile` : cibles `up`, `down`, `logs`, `migrate`, `revision`, `seed`, `superuser`, `test`, `lint`, `format`, `shell`.

---

## 11. DONNÉES INITIALES (`scripts/seed.py`, idempotent)

- **admin_areas** : les 8 régions du Niger (Agadez, Diffa, Dosso, Maradi, Niamey, Tahoua, Tillabéri, Zinder) avec codes, sans géométrie.
- **crops** : `millet` (mil, ha: gero), `sorghum` (sorgho, ha: dawa), `cowpea` (niébé, ha: wake), `maize` (maïs, ha: masara), `rice` (riz, ha: shinkafa), `groundnut` (arachide, ha: gyada), `onion` (oignon, ha: albasa), `tomato` (tomate, ha: tumatir), `cabbage` (chou, ha: kabeji), `pepper` (piment, ha: barkono), avec `category` et `cycle_days` raisonnables ; `name_dje` à `NULL` tant que non validé.
- **diagnosis_labels** : `healthy`, `fall_armyworm`, `desert_locust`, `millet_downy_mildew`, `striga`, `cowpea_aphid`, `tomato_leaf_curl`, `nitrogen_deficiency`, avec `guideline = { "validated": false, "urgency": null, "cultural": [], "biological": [], "chemical": [], "prevention": [] }` et liens `label_crops` cohérents.
- **plans** : `free` (0 XOF, 10 diagnostics/mois, 20 messages IA/mois, 0 analyse vidéo, 3 parcelles), `farmer_pro` (1 500 XOF/mois, 60 diagnostics, 100 messages, 10 vidéos, 20 parcelles), `coop_standard` (25 000 XOF/mois, quotas élevés, audience `organization`), `gov_license` (prix 0, billing_model `license`, audience `government`, quotas illimités représentés par `-1`). Ces valeurs sont des valeurs de départ modifiables en base.
- `scripts/create_superuser.py` : crée un `super_admin` à partir d'arguments CLI (téléphone, nom, mot de passe).

---

## 12. TESTS (pytest, sans réseau externe)

Couvrir au minimum : inscription + OTP + rotation et rejeu de refresh token ; limites de taux OTP ; propriété des ressources et refus 403/404 entre utilisateurs ; upsert idempotent d'une ferme avec UUID client ; `sync/push` (appliqué, conflit, suppression) et `sync/pull` (curseur, suppressions) ; flux média (déclaration, dédoublonnage par sha256, complétion, limites) avec S3 simulé ; création de diagnostic, pipeline en mode stub, passage en `needs_review`, création de foyer ; validation experte et création de `training_sample` ; quotas (`QUOTA_EXCEEDED`) ; checkout idempotent, webhook valide, webhook rejoué (aucun double traitement), webhook à signature invalide ; activation de licence (max activations, révocation) ; anonymisation et seuil de 5 pour les stats État et `GET /outbreaks` ; suppression de compte.

---

## 13. MÉTHODE DE LIVRAISON (À RESPECTER)

Tu produis le projet en **8 phases**. À chaque message, tu livres **une seule phase**, entièrement, puis tu t'arrêtes et j'écris « suite ». Chaque phase commence par la liste des fichiers créés ou modifiés, suivie des fichiers complets (titre = chemin, puis bloc de code), et se termine par les commandes à exécuter pour la valider. **Aucun commentaire dans aucun fichier.**

1. **Fondations** : `pyproject`/requirements, `config`, `logging`, `middleware`, `errors`, `rate_limit`, `pagination`, `security`, `db/session`, `db/base`, tous les modèles SQLAlchemy (45 tables), migration Alembic initiale (extensions, trigger, index, vue), Docker, compose, Makefile, `.env.example`, `main.py`, `/health`, `/version`.
2. **Auth et comptes** : providers SMS (base, fake, http), `otp_service`, `auth_service`, `user_service`, routes `auth` et `users`, `deps` (utilisateur courant, rôles), tests d'auth et de permissions.
3. **Cœur agricole** : organisations, fermes, parcelles, cycles, activités, récoltes, catalogues, `geo`, `sync`, seed, tests associés.
4. **Médias** : `storage_service`, `media_service`, routes média, idempotence, tâches `tasks_media`, tests média.
5. **IA** : `ml/*`, `model_registry`, providers LLM/embeddings, `rag_service`, `diagnostic_service`, `recommendation_service`, `expert_service`, routes diagnostics/recommandations/expert/chat, `tasks_diagnostic`, `tasks_ingest`, routes admin des modèles et du RAG, tests.
6. **Facturation** : `plans`, `subscription_service`, `quota_service`, `payments/*`, `webhook_handler`, `license_service`, `api_key_service`, routes billing/webhooks/licenses/api_keys, `tasks_billing`, tests.
7. **Données et alertes** : providers météo/satellite, services météo/NDVI/marchés/calendrier, alertes, notifications, push, foyers, `tasks_weather`, `tasks_ndvi`, `tasks_notifications`, `tasks_outbreaks`, import des prix, tests.
8. **Administration et finition** : `stats_service`, `audit_service`, routes admin restantes, `schedules.py`, durcissement sécurité, tests de bout en bout, vérification de cohérence globale (imports, routes enregistrées, migrations alignées sur les modèles).

**Critères de réussite** : `docker compose up` démarre sans erreur ; `make migrate seed` réussit ; `make test` passe ; toutes les routes de la section 7 existent et sont documentées par OpenAPI ; aucun commentaire ni docstring dans le dépôt ; aucun `TODO`, `pass` factice ou fichier tronqué.

**Commence maintenant par la phase 1.**
