# Home Lab

Self-hosted services running behind an Nginx reverse proxy, with Pi-hole for DNS and ad-blocking.

## Services

| Service | Path | Description |
|---------|------|-------------|
| Pi-hole | `/pihole` | DNS server and ad-blocker |
| iptv | `/tv` | iptv server |
| Web | `/web` | Example static web app |
| iot-home | `/iot` | Light dashboard ([iot-home](https://github.com/abrahamgr/iot-home)), with its MQTT broker on port 1883 |

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
| `make certs` | Generate new self-signed certificates |
| `make restart-nginx` | Restart Nginx to apply changes |

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

## iot-home

Three services: `iot-web`, `iot-api` and `mosquitto`. Open it at http://rb/iot.

### Secrets

Set these in the shell before `make up`, `make restart` or `make update-iot`, which
refuse to run without the first two:

| Variable | What | When to change it |
|---|---|---|
| `MQTT_PASSWORD` | Password of MQTT user `iot`, used by the broker, the API and the Zigbee bridge | Only together with the bridge's setting in eWeLink, or the lights stop updating |
| `IOT_AUTH_SECRET` | Signs sign-in sessions; 32+ characters (`openssl rand -hex 32`) | Never, normally: changing it signs everyone out |
| `IOT_OWNER_EMAIL`, `IOT_OWNER_PASSWORD` | The account to sign in with (password 12+ characters) | First start only. Ignored once the account exists; leave them unset after |

```bash
read -rs MQTT_PASSWORD && export MQTT_PASSWORD
read -rs IOT_AUTH_SECRET && export IOT_AUTH_SECRET
```

Keep the values in a password manager: `IOT_AUTH_SECRET` and `MQTT_PASSWORD` must be the
same on every start.

### Deploy or update

Images are built on a computer, never here. From an iot-home checkout on that computer:

```bash
scripts/ship.sh
```

It builds both images for arm64 and loads them into this Pi's Docker over SSH. Then,
here:

```bash
make update-iot
```

The first time, use `make up` instead (with the owner variables set too), then
`make restart-nginx` to load `nginx/conf.d/http/iot.conf`, and point the bridge at this
Pi: in eWeLink, ZBBridge-U → Device Settings → Home Assistant → Sync Zigbee
Sub-devices, address `192.168.0.125`, port `1883`, user `iot`, password
`MQTT_PASSWORD`.

### Roll back

Every image is also tagged with its commit. List them, point `latest` at an older one,
and recreate:

```bash
docker image ls iot-home-api
```

```bash
docker tag iot-home-api:<commit> iot-home-api:latest && docker tag iot-home-web:<commit> iot-home-web:latest && make update-iot
```

Old images take space on the SD card; remove ones you no longer need with
`docker image rm iot-home-api:<commit> iot-home-web:<commit>`.

### Data

The database is in the `iot-data` volume, retained messages in `mosquitto-data`.
nginx looks up the iot containers per request, so if they are stopped `/iot` answers
502 and everything else keeps working.

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
