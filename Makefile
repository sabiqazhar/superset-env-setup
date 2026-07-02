COMPOSE := docker compose

.PHONY: help build up down start stop restart ps logs logs-superset logs-postgres logs-redis shell exec init create-admin rebuild clean status setup-env test pull prune

help:
	@echo "Superset env setup — available commands:"
	@echo ""
	@echo "  Lifecycle"
	@echo "    make build         Build the superset image (no cache)"
	@echo "    make up            Create and start all containers (detached)"
	@echo "    make down          Stop and remove all containers"
	@echo "    make start         Start stopped containers"
	@echo "    make stop          Stop running containers"
	@echo "    make restart       Restart all containers"
	@echo "    make rebuild       Rebuild image then recreate containers"
	@echo "    make clean         Destroy containers, volumes, and local image"
	@echo ""
	@echo "  Monitoring"
	@echo "    make ps            List containers with status"
	@echo "    make status        Alias for ps"
	@echo "    make logs          Tail logs from all services"
	@echo "    make logs-superset Tail logs from superset only"
	@echo "    make logs-postgres Tail logs from postgres only"
	@echo "    make logs-redis    Tail logs from redis only"
	@echo ""
	@echo "  Superset commands"
	@echo "    make shell         Open a bash shell inside the superset container"
	@echo "    make exec cmd=...  Run an arbitrary command in the superset container"
	@echo "    make init          Run superset db upgrade + superset init"
	@echo "    make create-admin  Create the admin user interactively"
	@echo "    make test          Test if superset is responding on port 8088"
	@echo ""
	@echo "  Setup"
	@echo "    make setup-env     Copy .env.example to .env (won't overwrite)"
	@echo "    make prune         Prune unused Docker objects"

build:
	$(COMPOSE) build --no-cache

up:
	$(COMPOSE) up -d

down:
	$(COMPOSE) down

start:
	$(COMPOSE) start

stop:
	$(COMPOSE) stop

restart:
	$(COMPOSE) restart

ps: status

status:
	$(COMPOSE) ps

logs:
	$(COMPOSE) logs -f

logs-superset:
	$(COMPOSE) logs -f superset

logs-postgres:
	$(COMPOSE) logs -f postgres

logs-redis:
	$(COMPOSE) logs -f redis

shell:
	$(COMPOSE) exec superset bash

exec:
	$(COMPOSE) exec superset $(cmd)

init:
	$(COMPOSE) exec superset superset db upgrade
	$(COMPOSE) exec superset superset init

create-admin:
	$(COMPOSE) exec superset superset fab create-admin

test:
	@echo "Checking if superset is reachable at http://localhost:8088 ..."
	@curl -s -o /dev/null -w "HTTP %{http_code}\n" http://localhost:8088 || echo "Not reachable — is superset running?"

rebuild:
	$(COMPOSE) build --no-cache
	$(COMPOSE) up -d --force-recreate

clean:
	$(COMPOSE) down -v --remove-orphans
	docker image rm -f superset-custom:6.0.0 2>/dev/null || true
	rm -rf ./volumes/postgres/* ./volumes/superset_home/*
	sudo rm -rf ./volumes/postgres/* ./volumes/superset_home/* 2>/dev/null || rm -rf ./volumes/postgres/* ./volumes/superset_home/*
	@echo "Cleaned all volumes including bind mounts"

setup-env:
	test -f .env || cp .env.example .env
	test -f .env && echo ".env already exists, skipping"

prune:
	docker system prune -f
