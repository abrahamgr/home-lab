# Setup

All services must use the same Docker network and it should be created manually or ensure all Compose files refer to it.

```bash
docker network create frontend_network
```

## Setup reverse proxy

```bash
docker compose -f ./reverse-proxy/compose.yml up -d
```


## Setup PiHole

Make sure you change your password for web UI.

```bash
PIHOLE_PASSWORD=[your password] docker compose -f ./pihole/compose.yml up -d
```

## Setup web app

```bash
docker compose -f ./web/compose.yml up -d
```
# All at once
Start everything:

```bash
make up
```

Stop everything:

```bash
make down
```

Restart everything (down and up):


```bash
make restart
```

See logs (aggregated logs from all containers):


```bash
make logs
```
