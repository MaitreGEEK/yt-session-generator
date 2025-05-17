#!/bin/sh

echo "[INFO] yt-session-generator (webserver mode): Preparing to start"

XVFB_WHD=${XVFB_WHD:-1280x720x16}
# Use PORT env var from Railway, default to 3000 if not set by Railway for some reason
PORT=${PORT:-3000}
# HOST must be 0.0.0.0 for Docker to allow external connections to the container
HOST="0.0.0.0"

echo "[INFO] yt-session-generator (webserver mode): Starting Xvfb on display :99"
Xvfb :99 -ac -screen 0 "$XVFB_WHD" -nolisten tcp > /dev/null 2>&1 &
XVFBPID=$! # Capture Xvfb PID
sleep 3    # Give Xvfb a moment

echo "[INFO] yt-session-generator (webserver mode): Launching potoken-generator.py server, binding to $HOST on port $PORT"

# This runs potoken-generator.py (from the ghcr.io image) in server mode
# It relies on potoken-generator.py (and its main.py) correctly parsing --host and --port
# and NOT running in --oneshot mode.
DISPLAY=:99 python potoken-generator.py --host "$HOST" --port "$PORT"

# This part will only be reached if the python script above exits
echo "[INFO] yt-session-generator (webserver mode): Python script exited, cleaning up Xvfb."
kill $XVFBPID
wait $XVFBPID