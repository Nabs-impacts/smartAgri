.PHONY: up down logs migrate revision seed superuser test lint format shell

up:
	docker compose up -d

down:
	docker compose down

logs:
	docker compose logs -f

migrate:
	alembic upgrade head

revision:
	alembic revision --autogenerate -m "auto"

seed:
	python3 scripts/seed.py

superuser:
	python3 scripts/create_superuser.py

test:
	pytest tests

lint:
	ruff check .

format:
	ruff format .

shell:
	python3
