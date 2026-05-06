# Home Lab

Self-hosted services running behind an Nginx reverse proxy, with Pi-hole for DNS and ad-blocking.

## Services

| Service | Path | Description |
|---------|------|-------------|
| Pi-hole | `/pihole` | DNS server and ad-blocker |
| Web | `/web` | Example static web app |

## Setup

No manual network creation needed — Docker Compose manages it.

```bash
PIHOLE_PASSWORD=[your password] make up
```

## Commands

| Command | Description |
|---------|-------------|
| `make up` | Start all services |
| `make down` | Stop all services |
| `make restart` | Restart all services |
| `make logs` | Tail aggregated logs |
| `make update-pihole` | Pull latest Pi-hole image and recreate container |

## Adding a New Web App

1. Add a service block to `docker-compose.yml` on the `proxy` network (no ports needed):

```yaml
  myapp:
    image: myapp:latest
    container_name: myapp
    networks:
      - proxy
```

2. Create `nginx/conf.d/myapp.conf`:

```nginx
location /myapp {
  proxy_pass http://myapp/;
  include /etc/nginx/headers.conf;
}
```

3. Restart:

```bash
docker compose up -d
```

## DNS (Pi-hole)

Pi-hole handles DNS for the network. Port 53 is exposed directly from the `pihole` container.


## ipv6

Add the following to `/etc/docker/daemon.json`:
```json
{
    "ipv6": true,
    "fixed-cidr-v6": "fd00:dead:beef::/48"
}
```

Then restart Docker:

```bash
sudo systemctl restart docker
```
