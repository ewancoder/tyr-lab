#!/bin/sh
# pia-port.sh — called by docker-wireguard-pia with the forwarded port as $1
# Runs inside the gateway container; qBittorrent shares the same netns,
# so its WebUI is reachable on 127.0.0.1.

PORT="$1"
QBT="http://127.0.0.1:${QBT_WEBUI_PORT:-8080}"

echo "[pia-port] got forwarded port ${PORT}"

# Wait for qBittorrent's WebUI to be up (it may start after the tunnel)
i=0
until curl -sf --max-time 3 "${QBT}/api/v2/app/version" >/dev/null 2>&1; do
    i=$((i+1))
    if [ "$i" -ge 60 ]; then
        echo "[pia-port] qBittorrent WebUI not reachable after 5min, giving up"
        exit 1
    fi
    sleep 5
done

# Skip if already set (avoids a needless listener restart)
CURRENT=$(curl -sf "${QBT}/api/v2/app/preferences" | sed -n 's/.*"listen_port":\([0-9]*\).*/\1/p')
if [ "$CURRENT" = "$PORT" ]; then
    echo "[pia-port] listen_port already ${PORT}, nothing to do"
    exit 0
fi

# Apply the new port
if curl -sf -X POST "${QBT}/api/v2/app/setPreferences" \
        --data-urlencode "json={\"listen_port\":${PORT}}"; then
    echo "[pia-port] listen_port updated: ${CURRENT:-unset} -> ${PORT}"
else
    echo "[pia-port] failed to set listen_port"
    exit 1
fi
