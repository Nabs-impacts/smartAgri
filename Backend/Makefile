.PHONY: up down logs migrate migrate-check revision seed superuser seed-demo demo-smoke test lint format shell

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
	docker compose exec -T api python -m scripts.seed

superuser:
	@docker compose exec -T api python -m scripts.create_superuser $(ARGS)

seed-demo:
	docker compose exec -T -e DEMO_PASSWORD api python -m scripts.seed_demo

demo-smoke:
	docker compose exec -T -e DEMO_PASSWORD -e ADMIN_PASSWORD -e API_URL=$${API_URL:-http://localhost:8000} api python -m scripts.demo_smoke

test:
	docker compose run --rm -T --build api pytest tests

lint:
	ruff check .

format:
	ruff format .

shell:
	python3
