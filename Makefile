up:
	docker compose up -d

down:
	docker compose down

restart:
	docker compose down && docker compose up -d

logs:
	docker compose logs -f

update-pihole:
	docker pull pihole/pihole:latest
	docker compose up -d --no-deps --force-recreate pihole
