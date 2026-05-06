# Home Lab — Claude Context

## Architecture

Single `docker-compose.yml` at the repo root. All services share the `proxy` Docker network managed by Compose (not external/manual).

```
docker-compose.yml     ← all services defined here
nginx/
  nginx.conf           ← uses glob: include /etc/nginx/conf.d/*.conf
  headers.conf         ← common proxy headers, included in each location block
  conf.d/
    pihole.conf        ← routing for /pihole
    web.conf           ← routing for /web
pihole/
  etc-pihole/          ← persistent Pi-hole data (git-ignored)
  etc-dnsmasq.d/       ← custom DNS config
web/
  index.html           ← example static app
```

## Routing

Path-based via Nginx. All apps accessible at `http://<host>/<appname>`. No subdomain DNS records needed.

## Secrets

`PIHOLE_PASSWORD` is passed as a CLI env var: `PIHOLE_PASSWORD=secret make up`. No `.env` file.

## Adding a New App

1. Add a service in `docker-compose.yml` on the `proxy` network — no host port mapping needed
2. Create `nginx/conf.d/<appname>.conf` with a `location /appname { proxy_pass http://<container>/; include /etc/nginx/headers.conf; }` block
3. Run `docker compose up -d`

## Key Constraints

- Do not add host port mappings to new services — they route through Nginx only
- Do not change the network name `proxy` without updating all service definitions
- Pi-hole port 53 (TCP+UDP) is the only non-proxy port exposed
