#!/bin/sh

echo "[INFO] yt-session-generator (webserver mode): Preparing to start"

XVFB_WHD=${XVFB_WHD:-1280x720x16}
PORT=${PORT:-3000}
HOST="0.0.0.0"

echo "[INFO] yt-session-generator (webserver mode): Starting Xvfb on display :99"
Xvfb :99 -ac -screen 0 "$XVFB_WHD" -nolisten tcp > /dev/null 2>&1 &
XVFBPID=$!
sleep 3

echo "[INFO] yt-session-generator (webserver mode): Launching potoken-generator.py server, binding to $HOST on port $PORT"

DISPLAY=:99 python potoken-generator.py --host "$HOST" --port "$PORT"

echo "[INFO] yt-session-generator (webserver mode): Python script exited, cleaning up Xvfb."
kill $XVFBPID
wait $XVFBPID