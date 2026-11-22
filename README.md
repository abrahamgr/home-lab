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
| `RESEND_API_KEY`, `EMAIL_FROM` | Optional. Emails the link a new person uses to choose a password. `EMAIL_FROM` like `Lights at home <lights@your-domain>`; required with the key | Unset, the owner copies the link from the screen instead |

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

It first takes a copy of the database (see Backups), which stops `iot-api` for a few
seconds; the lights and everything else keep working. Check `docker logs iot-api`
afterwards: it says whether the owner is present and whether email is configured.

The first time, use `make up` instead (with the owner variables set too), then
`make restart-nginx` to load `nginx/conf.d/http/iot.conf`, and point the bridge at this
Pi: in eWeLink, ZBBridge-U → Device Settings → Home Assistant → Sync Zigbee
Sub-devices, address `192.168.0.125`, port `1883`, user `iot`, password
`MQTT_PASSWORD`.

### Who can switch the lights

Managed in the app: the owner (the first account) controls every light, and gives
or takes away other people's control on **Manage**. `iot/grants.json` belonged to the
previous version; nothing reads it now, and it stays only so a rollback to that
version still works.

### Backups

`make update-iot` runs `iot/backup.sh` before starting the new version. It stops
`iot-api`, copies the database out of the `iot-data` volume into
`iot/backups/<UTC time>-<image>/` with the ids of the images that wrote it, and keeps
the newest 5. The copies hold password hashes and emails: they are git-ignored, readable
only by you, and never leave the Pi. There is no copy between deploys: if the data is
damaged then, changes since the last deploy are lost (the Manage record shows what they
were).

### Roll back

```bash
make rollback-iot
```

It puts back the newest copy and the images that wrote it, together, then waits for
the API's health check (about 30 s) and prints how long it took. It asks first, since
changes made in the app since that copy are lost. For an older copy:
`iot/rollback.sh iot/backups/<dir>`.

Old images take space on the SD card. Keep the ones a copy names; remove others with
`docker image rm iot-home-api:<commit> iot-home-web:<commit>`.

### Forgotten owner password

```bash
make iot-owner-password
```

Asks for the new password without showing it, and ends the owner's sessions. Works
with the app running or stopped.

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
