#!/bin/sh

echo "[INFO] yt-session-generator (webserver mode): Preparing to start"

XVFB_WHD=${XVFB_WHD:-1280x720x16}
PORT=${PORT:-3000}
HOST="0.0.0.0"

echo "[INFO] yt-session-generator (webserver mode): Starting Xvfb on display :99"
# Run Xvfb in the background and ensure it stays running as long as this script does
Xvfb :99 -ac -screen 0 "$XVFB_WHD" -nolisten tcp > /dev/null 2>&1 &
XVFBPID=$!

# Give Xvfb a moment to initialize
sleep 3

echo "[INFO] yt-session-generator (webserver mode): Launching potoken-generator.py server, binding to $HOST on port $PORT"

# Explicitly call the Python interpreter on the script
# Ensure arguments are passed correctly.
# The main.py script's run() function uses asyncio.gather which should block.
# If this command exits, the container will stop.
DISPLAY=:99 /usr/local/bin/python potoken-generator.py --host "$HOST" --port "$PORT"

# If the script reaches here, it means the python server exited.
echo "[WARN] yt-session-generator: Python server process ended."
echo "[INFO] yt-session-generator: Cleaning up Xvfb."
kill $XVFBPID
wait $XVFBPID
echo "[INFO] yt-session-generator: Script finished."