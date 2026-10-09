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

# Run after loading new images with iot-home's scripts/ship.sh.
update-iot: iot-env
	docker compose up -d --no-deps --force-recreate iot-api iot-web

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