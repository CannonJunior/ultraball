#!/bin/bash
set -e
PORT=7777
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "====================================="
echo "  ULTRABALL Game Launcher"
echo "====================================="
# Kill stale processes on port
PORT_PID=$(lsof -ti:$PORT 2>/dev/null || echo "")
if [ ! -z "$PORT_PID" ]; then
    echo "Killing process on port $PORT..."
    kill -9 $PORT_PID 2>/dev/null || true
    sleep 1
fi
STALE_PIDS=$(ps aux | grep -E 'flutter.*(run|web-server|web-port)' | grep -v grep | awk '{print $2}' || true)
if [ ! -z "$STALE_PIDS" ]; then
    echo "$STALE_PIDS" | xargs kill -9 2>/dev/null || true
    sleep 1
fi
GAME_DIR="$PROJECT_DIR/ultraball_game"
cd "$GAME_DIR"
flutter pub get
echo "Starting Ultraball on http://localhost:$PORT"
flutter run -d web-server --web-port=$PORT --web-hostname=localhost
