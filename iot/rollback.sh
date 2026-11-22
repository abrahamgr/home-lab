#!/usr/bin/env bash
# Returns iot-home to how it was before the last deploy (iot-home spec 0003, AC-58):
# the database copy taken by iot/backup.sh and the images that wrote it, together.
# A newer database under older images is never produced.
#
#   iot/rollback.sh            newest copy, asks first
#   iot/rollback.sh <dir>      a given copy under iot/backups/
#   iot/rollback.sh -y [dir]   without asking
#
# Run through `make rollback-iot`, which checks the secrets compose needs.
set -euo pipefail
cd "$(dirname "$0")/.."
started=$(date +%s)

yes=false
[ "${1:-}" = -y ] && yes=true && shift
backups=iot/backups
dir="${1:-$(ls -1d "$backups"/*/ 2>/dev/null | sort -r | head -n 1)}"
dir="${dir%/}"
[ -n "$dir" ] && [ -s "$dir/iot.db" ] && [ -s "$dir/images" ] ||
  { echo "rollback: no copy found${1:+ at $1}." >&2; exit 1; }

api_image="$(awk '$1 == "api" { print $2 }' "$dir/images")"
web_image="$(awk '$1 == "web" { print $2 }' "$dir/images")"
for image in "$api_image" "$web_image"; do
  docker image inspect "$image" >/dev/null 2>&1 ||
    { echo "rollback: image $image is no longer on this Pi." >&2; exit 1; }
done

echo "rollback: restores $dir"
echo "  api $api_image"
echo "  web $web_image"
echo "  Changes made in the app since that copy (people, names, grants) are lost."
if ! $yes; then
  read -rp "Type yes to continue: " answer
  [ "$answer" = yes ] || { echo "rollback: nothing changed."; exit 1; }
fi

docker compose stop iot-api iot-web

# As root inside the old image: the volume belongs to its bun user, so hand the files
# back to bun. Stale -wal and -shm files would be replayed onto the copy, so they go.
docker run --rm --entrypoint sh --user root \
  -v iot-data:/data -v "$PWD/$dir:/backup:ro" \
  "$api_image" -c 'rm -f /data/iot.db /data/iot.db-wal /data/iot.db-shm && cp /backup/iot.db* /data/ && chown bun:bun /data/iot.db*'

docker tag "$api_image" iot-home-api:latest
docker tag "$web_image" iot-home-web:latest
docker compose up -d --no-deps --force-recreate iot-api iot-web

# The image's own health check (GET /api/health); start period 10 s, interval 30 s.
for _ in $(seq 1 60); do
  status="$(docker inspect -f '{{.State.Health.Status}}' iot-api 2>/dev/null || echo missing)"
  [ "$status" = healthy ] && break
  [ "$status" = unhealthy ] && break
  sleep 2
done

echo
echo "rollback: iot-api is $status after $(($(date +%s) - started)) s"
docker inspect -f '{{.Name}} {{.Image}}' iot-api iot-web
[ "$status" = healthy ] || { echo "rollback: check docker logs iot-api" >&2; exit 1; }
