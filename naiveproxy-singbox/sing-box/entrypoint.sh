#!/bin/sh
set -eu

mkdir -p /etc/sing-box
envsubst < /etc/sing-box/config.json.template > /etc/sing-box/config.json

exec sing-box run -c /etc/sing-box/config.json
