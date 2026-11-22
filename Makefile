# bash, not sh: iot-owner-password reads without echo (read -s).
SHELL := /bin/bash

up: iot-env
	docker compose up -d

down:
	docker compose down

restart: iot-env
	docker compose down && docker compose up -d

logs:
	docker compose logs -f

update-pihole:
	docker pull pihole/pihole:latest
	docker compose up -d --no-deps --force-recreate pihole

update-iptv:
	docker compose up -d --no-deps --force-recreate iptv

# Run after loading new images with iot-home's scripts/ship.sh. Takes a copy of the
# database first (iot/backup.sh), which stops iot-api; the up starts it again.
update-iot: iot-env
	iot/backup.sh
	docker compose up -d --no-deps --force-recreate iot-api iot-web

# Back to before the last update-iot: its database copy and the images that wrote it.
rollback-iot: iot-env
	iot/rollback.sh

# Sets the iot-home owner's password, e.g. when it is forgotten. Works with the app
# running or stopped; the owner's sessions end. The password never reaches argv.
iot-owner-password:
	@read -rsp "New owner password (12+ characters): " p; echo; \
		printf '%s\n' "$$p" | docker compose run --rm -T --no-deps iot-api bun owner-password.js

# Without these, compose would recreate the iot containers with blank secrets.
iot-env:
	@test -n "$$MQTT_PASSWORD" -a -n "$$IOT_AUTH_SECRET" || \
		{ echo "Set MQTT_PASSWORD and IOT_AUTH_SECRET first (README, iot-home)."; exit 1; }

certs:
	mkdir -p nginx/certs
	openssl req -x509 -newkey rsa:4096 -sha256 -nodes \
		-keyout nginx/certs/cert.key \
		-out nginx/certs/cert.pem \
		-not_after 20380119031407Z \
		-subj "/CN=rb" \
		-addext "subjectAltName=DNS:localhost,DNS:rb,IP:192.168.0.125,IP:127.0.0.1" \
		-addext "keyUsage=digitalSignature,keyEncipherment" \
		-addext "extendedKeyUsage=serverAuth" \
		-addext "basicConstraints=CA:FALSE"

restart-nginx:
	docker exec -d nginx-proxy nginx -s reload