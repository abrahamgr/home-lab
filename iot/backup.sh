#!/usr/bin/env bash
# Takes a cold copy of iot-home's database before a deploy (iot-home spec 0003, AC-58).
# Run by `make update-iot`; safe to run by hand.
#
#   1. Notes the images the running iot-api and iot-web were started from, and tags
#      them iot-home-{api,web}:previous. Read from the containers, not from `latest`:
#      scripts/ship.sh has already moved `latest` to the new images by now.
#   2. Stops iot-api, so nothing writes while the database is copied. The lights do
#      not need the app; only the dashboard is down, for seconds.
#   3. Copies iot.db (and -wal, -shm if present) from the iot-data volume into
#      iot/backups/<UTC time>-<api image>/, with the two image ids beside it, using the
#      previous api image (nothing is pulled).
#   4. Keeps the newest 5 copies.
#
# It leaves iot-api stopped: the deploy that follows starts it. If there is no iot-api
# container yet (the very first deploy), there is nothing to copy and it says so.
set -euo pipefail
cd "$(dirname "$0")/.."

KEEP=5
backups=iot/backups

api_image="$(docker inspect -f '{{.Image}}' iot-api 2>/dev/null || true)"
web_image="$(docker inspect -f '{{.Image}}' iot-web 2>/dev/null || true)"
if [ -z "$api_image" ]; then
  echo "backup: no iot-api container yet; nothing to copy."
  exit 0
fi

docker tag "$api_image" iot-home-api:previous
[ -n "$web_image" ] && docker tag "$web_image" iot-home-web:previous

docker compose stop iot-api

# Copies hold password hashes and emails: only this user may read them.
mkdir -p "$backups"
chmod 700 "$backups"
short="${api_image#sha256:}"
dir="$backups/$(date -u +%Y%m%dT%H%M%SZ)-${short:0:12}"
mkdir -m 700 "$dir"

# As this user, so the copy is owned by them and can be pruned without sudo.
docker run --rm --entrypoint sh --user "$(id -u):$(id -g)" \
  -v iot-data:/data:ro -v "$PWD/$dir:/backup" \
  "$api_image" -c 'cp /data/iot.db /backup/ && for f in /data/iot.db-wal /data/iot.db-shm; do [ ! -e "$f" ] || cp "$f" /backup/; done'
[ -s "$dir/iot.db" ] || { echo "backup: the copy is empty; stopping before the deploy." >&2; exit 1; }

# The images that wrote this copy: the rollback restores both together.
printf 'api %s\nweb %s\n' "$api_image" "${web_image:-}" >"$dir/images"

# Newest first by name (a UTC timestamp); delete all but $KEEP.
ls -1d "$backups"/*/ | sort -r | tail -n +$((KEEP + 1)) | xargs -r rm -rf

echo "backup: $dir ($(du -sh "$dir" | cut -f1))"
