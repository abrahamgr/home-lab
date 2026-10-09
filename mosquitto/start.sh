#!/bin/sh
# Creates the broker's one user from the environment, then runs Mosquitto. The
# password file is rebuilt on every start, so changing the password is a restart.
set -eu
: "${MQTT_USERNAME:?MQTT_USERNAME is required}" "${MQTT_PASSWORD:?MQTT_PASSWORD is required}"
rm -f /tmp/passwd
touch /tmp/passwd
chmod 0600 /tmp/passwd
chown mosquitto:mosquitto /tmp/passwd
mosquitto_passwd -b /tmp/passwd "$MQTT_USERNAME" "$MQTT_PASSWORD"
exec mosquitto -c /mosquitto/config/mosquitto.conf
