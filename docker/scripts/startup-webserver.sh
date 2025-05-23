#!/bin/sh
set -e

echo "[yt-session-generator] Preparing to start web server..."
PORT=${PORT:-3000}
HOST="0.0.0.0"

echo "[yt-session-generator] Xvfb dimensions: ${XVFB_WHD:-1280x720x16}"
echo "[yt-session-generator] Target bind address: $HOST"
echo "[yt-session-generator] Target port: $PORT"

echo "[yt-session-generator] Starting Xvfb..."
Xvfb :99 -ac -screen 0 "${XVFB_WHD:-1280x720x16}" -nolisten tcp > /dev/null 2>&1 &
XVFBPID=$!
sleep 3 

echo "[yt-session-generator] Launching Python server: potoken-generator.py --bind $HOST --port $PORT"
DISPLAY=:99 python potoken-generator.py --bind "$HOST" --port "$PORT"

echo "[yt-session-generator] Python server process ended unexpectedly. Cleaning up Xvfb."
kill $XVFBPID
wait $XVFBPID
echo "[yt-session-generator] Startup script finished."