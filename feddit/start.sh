#!/bin/bash
# Feddit Server Start Script
# 
# Starts the Feddit web server and mod CLI
# Exposes via Tailscale (private network only)
# Cost: $0.00 (Tier 0 — Node.js local)

set -e

FEDDIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PORT=${FEDDIT_PORT:-8888}

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║        🛡️  FEDDIT — Clandestine Forensic Education            ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Check Node.js
if ! command -v node &> /dev/null; then
  echo "❌ Node.js not found. Install it first:"
  echo "   apt-get install nodejs npm"
  exit 1
fi

# Make scripts executable
chmod +x "${FEDDIT_DIR}/mod-cli.sh"
chmod +x "${FEDDIT_DIR}/server.js"

echo "📍 Feddit directory: $FEDDIT_DIR"
echo "🔌 Port: $PORT"
echo "🌐 Tailscale: Enabled (private network only)"
echo ""

# Start server
echo "Starting Feddit server..."
cd "$FEDDIT_DIR"

# Run server in background, log to file
nohup node server.js > feddit-server.log 2>&1 &
SERVER_PID=$!

echo "✅ Feddit started (PID: $SERVER_PID)"
echo ""

# Check connectivity
sleep 1
if curl -s http://localhost:$PORT > /dev/null 2>&1; then
  echo "✅ Server responding on http://localhost:$PORT"
else
  echo "⚠️  Server may not be responding yet. Check logs:"
  echo "   tail -f $FEDDIT_DIR/feddit-server.log"
fi

echo ""
echo "📋 Next steps:"
echo "   1. Access via Tailscale IP (e.g., http://100.x.x.x:$PORT)"
echo "   2. Use mod-cli.sh to annotate breach records:"
echo "      ./mod-cli.sh list"
echo "      ./mod-cli.sh view <record>"
echo "      ./mod-cli.sh annotate <agent> <record> \"<note>\""
echo "   3. All mod actions logged to: mod-actions.jsonl"
echo "   4. Access log: access.jsonl"
echo ""
echo "To stop server:"
echo "   kill $SERVER_PID"
echo ""

# Show sample records
echo "📁 Available breach data directories:"
ls -d "$FEDDIT_DIR"/{forensics,wetwork,counters,disclaimer} 2>/dev/null | while read dir; do
  echo "   $(basename "$dir"): $(ls -1 "$dir" 2>/dev/null | wc -l) items"
done

echo ""
echo "🛡️  Nemesis is watching. Assume breach. Plan accordingly."
