#!/bin/sh

echo "[INFO] yt-session-generator (webserver mode): internally launching GUI"

XVFB_WHD=${XVFB_WHD:-1280x720x16}
PORT=${PORT:-3000} # Use PORT env var from Railway, default to 3000
HOST="0.0.0.0"     # Listen on all interfaces in the container

echo "[INFO] yt-session-generator (webserver mode): starting Xvfb"
Xvfb :99 -ac -screen 0 $XVFB_WHD -nolisten tcp > /dev/null 2>&1 &
sleep 3

echo "[INFO] yt-session-generator (webserver mode): launching potoken-generator.py server on $HOST:$PORT"

# This command assumes potoken-generator.py (from the pre-built image)
# will parse --host and --port, and that its main logic (calling server.py)
# is correctly invoked this way when not --oneshot.
# The pre-built image should have potoken-generator.py and its dependencies.
DISPLAY=:99 python potoken-generator.py --host $HOST --port $PORT