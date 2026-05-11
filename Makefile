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

update-iptv:
	docker compose up -d --no-deps --force-recreate iptv

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

