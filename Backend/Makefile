.PHONY: up down logs migrate migrate-check revision seed superuser seed-demo test lint format shell

up:
	docker compose up -d

down:
	docker compose down

logs:
	docker compose logs -f

migrate:
	alembic upgrade head

migrate-check:
	docker compose exec api alembic check

revision:
	alembic revision --autogenerate -m "auto"

seed:
	python3 scripts/seed.py

superuser:
	python3 scripts/create_superuser.py $(ARGS)

seed-demo:
	python3 scripts/seed_demo.py

test:
	docker compose run --rm -T --build api pytest tests

lint:
	ruff check .

format:
	ruff format .

shell:
	python3
