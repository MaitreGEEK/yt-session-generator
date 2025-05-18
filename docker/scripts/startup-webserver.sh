#!/bin/sh
set -e

echo "[yt-session-generator] Preparing to start web server..."
PORT=${PORT:-3000}
HOST="0.0.0.0"

echo "[yt-session-generator] Xvfb dimensions: ${XVFB_WHD:-1280x720x16}"
echo "[yt-session-generator] Target host: $HOST"
echo "[yt-session-generator] Target port: $PORT"

echo "[yt-session-generator] Starting Xvfb..."
Xvfb :99 -ac -screen 0 "${XVFB_WHD:-1280x720x16}" -nolisten tcp > /dev/null 2>&1 &
XVFBPID=$!
sleep 3

echo "[yt-session-generator] Launching Python server: potoken-generator.py --host $HOST --port $PORT"

# Create a small Python wrapper to run the server and catch exceptions
cat <<EOF > /app/run_server.py
import sys
import potoken_generator.main
try:
    # We need to simulate command line args for main.py's argparse
    # sys.argv will be ['potoken_generator/main.py', '--host', '0.0.0.0', '--port', '3000'] for example
    # The main.py directly calls args_parse() which reads from sys.argv.
    # So, we need to ensure sys.argv is set up as if these were command line args.
    # The startup.sh already calls potoken-generator.py with these args.
    # What main.py does is: args = args_parse() -> run(..., port=args.port, bind_address=args.bind)
    # The script itself potoken-generator.py calls potoken_generator.main.main()
    # So the args are already passed to it.
    # Let's just ensure there's detailed logging from python if it exits.
    print("[Python Wrapper] Attempting to start potoken_generator.main.main()", flush=True)
    potoken_generator.main.main() # This should pick up --host and --port from the command line
    print("[Python Wrapper] potoken_generator.main.main() exited cleanly.", flush=True)
except Exception as e:
    print(f"[Python Wrapper] ERROR: {e}", file=sys.stderr, flush=True)
    import traceback
    traceback.print_exc()
    sys.exit(1)
EOF

chmod +x /app/run_server.py

# Run the main script using the command as before
# The potoken-generator.py script itself should call main.main()
DISPLAY=:99 python potoken-generator.py --host "$HOST" --port "$PORT"

echo "[yt-session-generator] Python server process ended. Cleaning up Xvfb."
kill $XVFBPID
wait $XVFBPID
echo "[yt-session-generator] Startup script finished."