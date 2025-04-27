COMPOSE_FILES = \
  -f reverse-proxy/docker-compose.yml \
  -f pihole/docker-compose.yml \
  -f web/docker-compose.yml

up:
	docker compose $(COMPOSE_FILES) up -d

down:
	docker compose $(COMPOSE_FILES) down

restart:
	docker compose $(COMPOSE_FILES) down
	docker compose $(COMPOSE_FILES) up -d

logs:
	docker compose $(COMPOSE_FILES) logs -f
