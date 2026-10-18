# CONTEXT — Passation du projet SmartAgri

**Pour qui est ce fichier** : pour une **autre instance de Claude** (assistant de chat), pas pour un agent de code. Elle m'aide à **piloter** le développement du backend, que les agents de code (OpenCode, Antigravity) écrivent. Colle ce fichier en premier message, puis ajoute : « Lis ce contexte, résume-le-moi en 5 lignes pour confirmer que tu as compris, puis dis-moi quelle est la prochaine tâche (section 9). » Joins aussi `PROGRESS.md` et `smartagri-prompt-backend.md` si tu peux uploader des fichiers.

**Rôle attendu de cette instance :**
- Écrire pour moi les **messages de tâche** à donner aux agents : une tâche à la fois, autonomes (les agents ne voient pas cette conversation), dans un bloc de code prêt à coller, avec la règle « aucun commentaire ni docstring » et « arrête-toi à la fin de la tâche ».
- **Relire et auditer** ce que les agents produisent (je colle les fichiers ou le lien du dépôt) : bugs, failles, écarts avec le prompt.
- **Diagnostiquer** les erreurs Docker, Alembic et pytest que je colle.
- Tenir `PROGRESS.md` à jour et me dire quoi faire ensuite.
- **Vérifier les informations récentes** (images Docker, offres gratuites, API) avant de les affirmer : elles changent vite (MinIO, Gemini CLI et Qwen Code ont tous changé en 2026).
- Ne pas réécrire tout le backend à ma place, sauf demande explicite.

*Dernière mise à jour : 17 octobre 2026.*

---

## 1. Qui je suis et comment tu dois me répondre

- Je m'appelle **Nabs**, étudiant et développeur, au Niger (Niamey).
- Je parle **français**, ton **informel et direct**. Réponses courtes si possible, code **complet et copier-coller**, jamais de squelette.
- Sois **honnête** : si tu n'es pas sûr ou si tu n'as pas pu vérifier quelque chose, dis-le. Corrige-moi si je me trompe.
- Dans tout code généré pour ce projet : **aucun commentaire, aucune docstring**.

## 2. Le projet : SmartAgri

Plateforme nigérienne d'IA agricole. L'utilisateur photographie sa culture (ou filme 15 s) depuis une **app mobile Flutter** ; l'IA détecte maladies, ravageurs et carences, et donne des conseils en **français, haoussa et zarma** (avec audio). L'app gère aussi parcelles, cycles de culture, carnet d'exploitation, météo, NDVI satellite, prix des marchés, alertes, carte des foyers de ravageurs.

- **Contexte terrain** : zones rurales, 2G/3G instable, utilisateurs peu lettrés, Android d'entrée de gamme → application **offline-first**, synchronisation idempotente, UUID générés côté client, uploads directs vers le stockage S3.
- **Profils** : agriculteur, agent de terrain, coopérative, agronome expert, administration (tableau de bord web).
- **Modèle économique choisi (hybride)** : freemium pour les agriculteurs (diagnostic de base gratuit + abonnement ou paiement à l'usage par mobile money) ; SaaS B2B pour coopératives, ONG et agro-industries ; contrat de service ou licence institutionnelle pour l'État. Revenus complémentaires : bailleurs, banques/microfinance, micro-assurance, marketplace d'intrants.
- **Audit prévu avec le gouverneur** : si l'État est intéressé, il pourrait financer et/ou racheter. Stratégie retenue : démo qui marche, **pilote mesurable**, conserver la propriété intellectuelle (contrat de service/licence plutôt que rachat prématuré).

## 3. Décisions techniques prises

- **Backend** : Python 3.12, FastAPI async, SQLAlchemy 2.0 async + asyncpg, Alembic, Celery + Redis, **PostgreSQL 16 + PostGIS + pgvector**, stockage S3-compatible.
- **Image Docker de la base** : `docker/db.Dockerfile` part de `pgvector/pgvector:pg16` et installe `postgresql-16-postgis-3` (les images `postgis/postgis:16-x` sont sur Debian bullseye, dont le dépôt PostgreSQL ne répond plus).
- **Stockage local de développement** : **RustFS** (`rustfs/rustfs`, client `rustfs/rc` pour créer le bucket). MinIO n'est plus utilisable (images supprimées de Docker Hub en septembre 2026). **À vérifier en phase 4** : le support des URL présignées. En production : Cloudflare R2.
- **45 tables**, `TEXT + CHECK` plutôt qu'ENUM, UUID client pour les tables synchronisables, suppression douce (`deleted_at`).
- **IA** : architecture hybride — modèle de vision léger (embarqué TFLite côté mobile + modèle serveur ONNX) + LLM avec RAG sur documents agronomiques + moteur de règles validé par des agronomes (aucun conseil chimique tant que `guideline.validated` n'est pas `true`).
- **Fournisseurs externes** (SMS, paiement, LLM, embeddings, vision, météo, satellite, push) : toujours derrière une **interface abstraite avec une implémentation `fake`**, pour tout faire tourner en local.
- **Paiements** : mobile money (Orange Money, Airtel, Moov, MyNita) via un agrégateur à choisir ; couverture réelle au Niger **à vérifier**. Webhooks signés et idempotents.
- **Mobile** : Flutter, Riverpod ou Bloc, base locale Drift ou Isar, compression des images (~1024 px), upload résumable en tâche de fond, modèle embarqué pour un diagnostic provisoire hors-ligne.

## 4. Fichiers de référence

| Fichier | Rôle |
|---|---|
| `smartagri-prompt-backend.md` | Prompt complet de génération du backend : règles de code, arborescence, 45 tables, ~110 endpoints, logique métier, livraison en 8 phases. **Source de vérité.** (Les mentions de MinIO y ont été remplacées par RustFS.) |
| `PROGRESS.md` | État du dépôt par phase, bugs trouvés lors de l'audit, tâches restantes. À tenir à jour après chaque tâche (dans le dépôt, à côté de `Backend/`). |
| Brief UI/UX | Document Claude : https://claude.ai/code/artifact/92907775-54a4-4e47-accc-bdf9f7bea981 (une quarantaine d'écrans pour le designer) |
| Doc backend | Document Claude : https://claude.ai/code/artifact/9406325d-bce3-4764-b6aa-1001dae55965 (structure, tables, endpoints) |
| Dépôt GitHub | https://github.com/Nabs-impacts/SmartAgri — backend dans `Backend/` |

## 5. État d'avancement (≈ 19 % du backend)

| Phase | Contenu | État |
|---|---|---|
| 1 | Fondations : config, middlewares, 45 modèles, migration, Docker, `/health` | **~100 % — validée sous Docker** (migration vérifiée par `alembic check`). Reste : pinning des dépendances |
| 2 | Auth et comptes | **~95 %** : 7 routes d'auth + `/users/me` (profil, mot de passe, appareils, consentements), 43 tests (commit `3d579e9`). Reste : étape H2 (petits correctifs de H1, export, suppression de compte, tests de permissions) |
| 3 à 8 | Cœur agricole + sync, médias, IA, facturation, données/alertes, admin | 0 % |

**Validé le 17 octobre 2026** : `docker compose up -d --build` démarre les 7 services (`db`, `redis`, `rustfs`, `rustfs-init`, `api`, `worker`, `beat`) ; `alembic upgrade head` applique `0001_initial` ; `GET /health` renvoie `{"status":"healthy","database":"ok","redis":"ok","storage":"ok"}`. Le comptage de 50 relations dans le schéma `public` est normal : 45 tables + `alembic_version` + `spatial_ref_sys` (PostGIS) + la vue `v_cycle_yield` + 2 vues PostGIS.

**Audit statique du dépôt** : 45 tables identiques à la spec, migration alignée sur les modèles, zéro commentaire/docstring/TODO, aucun import cassé.

**Corrigé depuis l'audit** : lecture de `CORS_ORIGINS` et des listes MIME (`Annotated[list[str], NoDecode]`, `pydantic-settings>=2.7.0`) ; `app/workers/celery_app.py` créé ; `.dockerignore` ajouté ; bucket plus public ; `--no-deps` retiré du `pip wheel` ; MinIO remplacé par RustFS ; image `db` reconstruite sur pgvector + PostGIS ; `sqlalchemy[asyncio]` (greenlet) ; adresses Docker (`db`, `redis`, `rustfs`) définies dans le compose ; fichier de planification de beat dans `/tmp`.

**Failles de l'auth.** Corrigées (commits `39be0d4`, `f1397b8`, `3c5f9dc`) : limites par IP sur `otp/request`, `register` et `login` ; limite par numéro appliquée avant la vérification d'existence (plus de fuite 202/429) ; SMS envoyé en tâche de fond et seulement si le compte existe ; verrou de ligne sur les tentatives OTP ; fenêtre de tolérance du refresh (45 s, Redis) ; `purpose` restreint ; hash factice sur `login` ; `logout` vérifie le propriétaire ; **prise de contrôle par pré-inscription fermée** (login refusé tant que le téléphone n'est pas vérifié, mot de passe effacé à la première vérification, `register` remplace un compte non vérifié) ; messages d'erreur de `verify_otp` uniformes. **Restantes / compromis acceptés** : (1) `register` répond 409 pour un numéro vérifié, ce qui permet de tester l'existence d'un compte (voulu par la spec, limité par IP) ; (2) les limites par numéro (OTP et login) permettent à un tiers de bloquer temporairement un utilisateur légitime ; à atténuer plus tard (clé numéro + IP, anti-bot) ; (3) `register()` non atomique ; (4) l'IP cliente vient de `request.client.host` : derrière un reverse proxy en production, configurer les en-têtes de confiance ; (5) SMS en `BackgroundTasks` (perdus si le processus redémarre) : passer à Celery quand les tâches existeront ; (6) prévoir un nettoyage périodique des comptes jamais vérifiés ; (7) en phase 3, les comptes « invités par téléphone » dans une organisation doivent se distinguer des comptes désactivés (aujourd'hui, un compte inactif ne peut pas se connecter).

**Ports** : db (5432), redis (6379) et rustfs (9000) sont publiés sur `127.0.0.1` uniquement (fait) ; l'api reste sur `0.0.0.0:8000` pour les tests depuis le téléphone.

## 6. Commandes utiles (depuis `Backend/`)

```bash
sudo docker compose up -d --build
sudo docker compose ps -a
sudo docker compose logs --tail=40 api worker beat
sudo docker compose exec api alembic upgrade head
curl -s localhost:8000/health
sudo docker compose down
sudo docker compose down -v
```

`down -v` efface les volumes (base, Redis, stockage) : utile pour repartir de zéro en dev. Un « Up » dans `ps` ne prouve rien : lire les logs. Si `password authentication failed` apparaît après un changement de `POSTGRES_PASSWORD`, c'est que le volume garde l'ancien mot de passe : `down -v`.

**Le code est copié dans les images Docker** : après tout changement de code, il faut `docker compose up -d --build`, sinon les conteneurs continuent de tourner avec l'ancien code et `/health` ne prouve rien. Si des caractères étranges comme `51;39;21M` apparaissent dans le terminal (restes de séquences souris après un outil en terminal), lancer `reset`.

## 7. Environnement et outils

- **Machine** : Ubuntu, VS Code. Python local **3.14** (visible dans les `.pyc`) alors que Docker utilise **3.12** → se fier aux résultats dans Docker.
- **Docker** : installé, mais je lance encore `sudo docker compose` (groupe `docker` pas encore actif : `sudo usermod -aG docker $USER` puis déconnexion/reconnexion).
- **Agents de code** : le quota gratuit d'**Antigravity CLI (`agy`)** est épuisé. J'utilise **OpenCode** avec **DeepSeek V4.1 (High)**. OpenRouter gratuit est très limité (50 requêtes/jour sans 10 crédits achetés), donc seulement en secours. GitHub Copilot gratuit pour étudiants : à vérifier.
- **Réseau** : connexion lente, les builds Docker sont longs (5 à 12 minutes sans cache).

## 8. Méthode de travail avec les agents (à garder)

1. **Une tâche à la fois**, l'agent s'arrête à la fin et liste les fichiers modifiés.
2. Chaque message à l'agent commence par : « Lis smartagri-prompt-backend.md et PROGRESS.md. Règle absolue : aucun commentaire ni docstring. »
3. Après chaque tâche : `git diff`, vérifier qu'il n'y a pas de commentaires (`grep -rInE "^\s*#" Backend --include="*.py" --include="*.yml" --exclude-dir=__pycache__`), `git commit`, mise à jour de `PROGRESS.md`.
4. Changer d'outil **seulement entre deux tâches**, jamais au milieu.
5. Les agents annoncent parfois « terminé » sans avoir pu tester (ex. Docker absent de leur environnement) : toujours relancer moi-même la vérification.
6. Pour l'auth, les paiements et les permissions : relecture fichier par fichier.
7. Je fais **tous les commits moi-même** : les agents n'exécutent aucune commande git.
8. Les règles permanentes sont dans un fichier `AGENTS.md` à la racine du dépôt (OpenCode devrait le lire ; sinon coller le préambule dans chaque message) :

```
Règles permanentes :
- Aucun commentaire ni docstring dans le code, y compris YAML et Dockerfile.
- N'exécute aucune commande git (pas de commit, pas de push, pas de checkout) : je fais les commits moi-même.
- Une seule tâche à la fois. À la fin : liste les fichiers modifiés, mets à jour PROGRESS.md, puis arrête-toi.
- Si tu n'as pas pu vérifier quelque chose (Docker, tests), dis-le clairement au lieu d'annoncer que c'est terminé.
```

9. Une **nouvelle session OpenCode par tâche** (le contexte grossit vite et la qualité baisse).

## 9. Prochaines étapes (dans l'ordre) et messages prêts pour les agents

**Étape A — revalidation après lint : faite.** Résultat du 17 octobre 2026 sur base vide : les 7 services démarrent, `alembic upgrade head` réussit, `/health` répond healthy. En revanche `alembic check` échoue : il propose de supprimer **toutes** les tables, parce qu'Alembic compare la base à une metadata **vide** (cause probable : `ruff --fix` a supprimé de `alembic/env.py` un import « inutile » qui chargeait les modèles). La sortie révèle aussi deux autres points : des **doublons d'index spatiaux** (deux index GiST sur la même colonne pour `farms.location`, `plots.geom`, `admin_areas.geom`, `diagnostics.location`, `outbreak_reports.location` : un `idx_` automatique de GeoAlchemy2 et un `ix_` explicite) et la table PostGIS `spatial_ref_sys` à exclure du suivi. Astuce : toujours lancer `docker compose exec api alembic check 2>&1 | tail -3`, la sortie complète est énorme.

**Étape A bis : FAITE (commit `277e901`).** `env.py` charge maintenant tous les modèles et ignore les objets PostGIS, les index spatiaux en double ont été supprimés (un seul `idx_*` par colonne géographique), `make migrate-check` existe, et sur base vide `alembic upgrade head` puis `alembic check` renvoient « No new upgrade operations detected » avec `/health` healthy.

**Étapes B (ports en local uniquement) et C (lint) : faites** (ports sur `127.0.0.1` vérifiés dans `docker compose ps` ; `ruff check .` passe d'après l'agent).

**Étape D — routes d'auth + tests : FAITE (commit `538baac`, 9 tests).** Message utilisé :

```
Lis smartagri-prompt-backend.md (sections 5, 7.1 et 12) et PROGRESS.md. Applique les règles permanentes de AGENTS.md.
Les services auth_service et otp_service existent déjà : ne les réécris pas, appelle-les.
Tâche : crée Backend/app/api/v1/auth.py avec les 7 routes de la section 7.1 (register, otp/request, otp/verify,
login, refresh, logout, password/reset), les schémas manquants dans app/schemas/auth.py, et enregistre le router
dans app/api/router.py.
Crée ensuite Backend/tests/ avec conftest.py et test_auth.py : base de test dédiée (smartagri_test) sur le Postgres
du compose avec migration appliquée et nettoyage entre les tests, Redis sur un autre index que le développement,
SMS_PROVIDER=fake avec un moyen de récupérer le code OTP envoyé. Tests : inscription, OTP valide, OTP faux,
OTP expiré, login mot de passe, refresh avec rotation, rejeu d'un refresh révoqué, logout.
Ajoute une cible `make test` qui lance pytest dans le conteneur api (ajoute les dépendances de test à l'image
si nécessaire). Lance les tests, corrige jusqu'à ce qu'ils passent, mets à jour PROGRESS.md, puis arrête-toi.
```

**Étape E — corrections de sécurité de l'auth : FAITE (commit `39be0d4`, 16 tests).** Message utilisé :

```
Lis PROGRESS.md (Phase 2, failles 1 à 4) et smartagri-prompt-backend.md. Applique les règles permanentes de AGENTS.md.
Corrige uniquement ces 4 points, chacun avec un test dans tests/test_auth.py :
1. otp/request : ajoute une limite par IP (Redis, variable OTP_REQUESTS_PER_IP_WINDOW) et n'envoie le SMS que si le
   compte existe, en renvoyant toujours la même réponse 202.
2. Tentatives OTP : verrou de ligne (SELECT ... FOR UPDATE) pour que des requêtes parallèles ne dépassent pas
   OTP_MAX_ATTEMPTS.
3. refresh : fenêtre de tolérance REFRESH_REUSE_GRACE_SECONDS=45 où un refresh token déjà révoqué est accepté une
   seule fois, et verrou de ligne pour empêcher deux refresh simultanés valides.
4. OtpVerifyRequest.purpose : Literal["login", "verify_phone"] uniquement.
Ajoute les nouvelles variables à config.py et .env.example. Mets à jour PROGRESS.md, puis arrête-toi.
```

**Étape F — durcissement des tests et petits correctifs : FAITE.** Garde-fou dans `conftest.py` (assert sur la base `smartagri_test` et l'index Redis 3 avant tout `TRUNCATE` ou `flushdb`), accents dans les messages, `logout` qui vérifie que le refresh token appartient à l'utilisateur (403 sinon), 5 tests ajoutés.

**Étape G — 2e série de sécurité de l'auth : FAITE (commit `f1397b8`, 27 tests).** Message utilisé :

```
Lis PROGRESS.md et smartagri-prompt-backend.md. Applique les règles permanentes de AGENTS.md.
Tâche : seconde série de corrections de sécurité de l'auth, chacune avec un test. Les tests existants doivent continuer à passer.
1. request_otp (auth_service) : applique la limite par numéro AVANT la vérification d'existence du compte, avec la même
   clé que send_otp, pour que le comportement (202 ou 429) soit identique que le numéro soit inscrit ou non.
2. register : ajoute une limite par IP (Redis, variable REGISTER_REQUESTS_PER_IP_WINDOW) ; au-delà, 429.
3. login_password : limite par numéro et par IP (RATE_LIMIT_LOGIN_PER_MINUTE) ; pour un compte inconnu ou sans mot de
   passe, vérifie quand même un hash factice pour égaliser le temps de réponse.
4. Envoi du SMS : sors-le du chemin de la réponse (BackgroundTasks de FastAPI ou tâche Celery) pour que le temps de
   réponse de otp/request soit identique pour un numéro inscrit ou non.
5. Refactor sans changer le comportement : extrait upsert_device et issue_tokens (dupliqués dans
   verify_otp_and_login, login_password et refresh_token).
Ajoute les variables à config.py et .env.example. make test et ruff doivent passer. Mets à jour PROGRESS.md, puis arrête-toi.
```

**Étape G2 — prise de contrôle par pré-inscription et messages uniformes : FAITE (commit `3c5f9dc`, 31 tests).** Message utilisé :

```
Lis PROGRESS.md et smartagri-prompt-backend.md. Applique les règles permanentes de AGENTS.md.
Tâche : deux corrections de sécurité dans l'auth, chacune avec un test. Les tests existants doivent continuer à passer
(adapte ceux que le changement impose).
1. Prise de contrôle par pré-inscription : un attaquant peut inscrire le numéro d'une victime avec SON mot de passe,
   puis se connecter par mot de passe après que la victime a vérifié son numéro.
   - login_password refuse (même 401 « Identifiants incorrects. » et hash factice) tout compte dont phone_verified_at
     est NULL.
   - Quand une vérification OTP réussit pour un compte dont phone_verified_at était NULL, mets password_hash à NULL.
   - register : si le compte existe mais n'est PAS vérifié, ne renvoie pas 409 : remplace full_name, language et
     password_hash par les nouvelles valeurs, supprime les OTP non consommés de ce numéro, et renvoie un nouvel OTP.
     La réponse est identique à une inscription normale. Si le compte est vérifié, 409 comme aujourd'hui.
2. otp_service.verify_otp : toutes les causes d'échec (aucun code, code incorrect, code expiré, tentatives dépassées)
   renvoient le même code d'erreur et le même message « Code invalide ou expiré. », pour ne pas révéler si un numéro
   est inscrit. Conserve le comptage des tentatives et le verrou de ligne.
Mets à jour PROGRESS.md, puis arrête-toi.
```

**Étape H1 — routes du compte utilisateur, première partie : FAITE (commit `3d579e9`, 43 tests).** Message utilisé :

```
Lis smartagri-prompt-backend.md (sections 5, 7.2 et 12) et PROGRESS.md. Applique les règles permanentes de AGENTS.md.
Ne modifie pas auth_service ni otp_service sauf nécessité.
Tâche : première partie des routes du compte utilisateur, avec tests.
1. Crée app/services/user_service.py et app/api/v1/users.py (router préfixé /users, enregistré dans app/api/router.py),
   et complète app/schemas/user.py. Toutes les routes sont authentifiées.
2. GET /users/me : profil + abonnement effectif (abonnement actif de l'utilisateur, sinon celui d'une organisation dont
   il est membre, sinon le plan free) + quotas restants (plans.quotas moins usage_records du mois courant).
3. PATCH /users/me : full_name, language, admin_area_id (404 si la zone n'existe pas), email (409 s'il est déjà pris,
   null l'efface).
4. PUT /users/me/password : new_password, et current_password obligatoire si un mot de passe existe déjà ; refuse si
   phone_verified_at est NULL ; révoque tous les autres refresh tokens de l'utilisateur.
5. POST /users/me/devices : upsert sur (user_id, fcm_token) avec platform et app_version ; DELETE /users/me/devices/{id} :
   404 si l'appareil n'appartient pas à l'utilisateur.
6. POST /users/me/consents (type, version, accepted) et GET /users/me/consents (dernier état par type).
7. Tests dans tests/test_users.py : profil, PATCH, conflit d'email, mot de passe (avec et sans ancien mot de passe),
   appareils (dont le DELETE d'un appareil d'un autre utilisateur en 404), consentements.
Messages d'erreur en français avec accents. make test et ruff doivent passer. Mets à jour PROGRESS.md, puis arrête-toi.
```

**Étape H2 — petits correctifs de H1, puis export, suppression de compte et tests de permissions.** Revue de H1 : ownership des appareils, vérification du téléphone avant mot de passe et révocation des refresh tokens corrects ; à corriger : aucun contrôle de longueur sur `new_password` (ni `max_length`, donc risque de surcharge CPU avec argon2), le quota `plots` affiche toujours `used = 0`, l'unicité de l'email est vérifiée sans normalisation ni gestion d'`IntegrityError`, avertissement de dépréciation du code 422. Compromis noté : `PUT /users/me/password` révoque **tous** les refresh tokens (y compris celui de l'appareil courant), l'app devra donc se reconnecter dans les 15 minutes.

```
Lis smartagri-prompt-backend.md (sections 5, 7.2 et 12) et PROGRESS.md. Applique les règles permanentes de AGENTS.md.
Fais d'abord ces 4 petits correctifs sur les routes d'auth et /users/me, chacun avec un test, puis la suite.
A. Mots de passe : min_length=8 et max_length=128 sur new_password (PasswordUpdateRequest et PasswordResetRequest) et sur le
   mot de passe de RegisterRequest ; max_length=128 aussi sur le mot de passe de LoginRequest et sur current_password.
B. Quota « plots » dans GET /users/me : used = nombre de parcelles non supprimées des fermes de l'utilisateur (au lieu de 0).
C. PATCH /users/me : mets l'email en minuscules avant comparaison et enregistrement, et transforme une IntegrityError sur
   l'email en 409 (course entre deux requêtes).
D. Remplace la constante dépréciée HTTP_422_UNPROCESSABLE_ENTITY par HTTP_422_UNPROCESSABLE_CONTENT pour supprimer
   l'avertissement de pytest.
Puis la deuxième partie des routes du compte utilisateur :
1. GET /users/me/export : JSON de toutes les données de l'utilisateur présentes en base (profil, appareils, consentements,
   fermes, parcelles, cycles, activités, récoltes, diagnostics, recommandations, paiements), sans jamais inclure de
   données d'un autre utilisateur ni de secrets (hashes de mot de passe ou de tokens).
2. DELETE /users/me : anonymise en une transaction (téléphone remplacé par une valeur unique non réversible, nom et email
   effacés, mot de passe effacé, is_active=false, deleted_at posé, appareils et refresh tokens supprimés) et écrit une
   ligne dans audit_logs via un audit_service minimal (app/services/audit_service.py).
3. Tests : export (ne contient que les données de l'utilisateur) et suppression de compte (login impossible ensuite,
   données anonymisées) dans tests/test_users.py ; tests/test_permissions.py : chaque route /users/me* sans token renvoie
   401, et test unitaire de require_roles avec une mini-application FastAPI (bon rôle 200, mauvais rôle 403) ; aucune clé
   contenant « hash » ou « password » dans les réponses de GET /users/me et de l'export.
Messages d'erreur en français avec accents. make test et ruff doivent passer. Mets à jour PROGRESS.md, puis arrête-toi.
```

**Étape I — phase 3** : organisations, fermes, parcelles, cycles, activités, récoltes, sync, seed (8 régions du Niger, 10 cultures, plans) — c'est le début de la **démo pour le gouverneur** (phases 1 à 3 + médias + diagnostic simulé + écran de stats de rendement, environ 2 à 3 semaines avec les contraintes de quota).

## 10. Points ouverts à ne pas oublier

- Valider avec des **agronomes** (INRAN, université) les protocoles de traitement avant toute recommandation chimique.
- Collecter des **photos locales** pour entraîner le modèle de vision (les jeux publics type PlantVillage généralisent mal au champ).
- Faire valider les **traductions haoussa et zarma** par des locuteurs.
- Choisir l'**agrégateur de paiement**, vérifier sa couverture au Niger et les règles Google Play Billing.
- Vérifier le cadre légal nigérien sur la **protection des données personnelles** (hébergement, consentements) avant l'audit.
- Tester les **URL présignées** avec RustFS en phase 4.
- Figer les versions des dépendances (`requirements.txt` utilise des `>=`).
- Le brief UI/UX est prêt : à envoyer au designer, qui doit commencer par les écrans « P0 ».
