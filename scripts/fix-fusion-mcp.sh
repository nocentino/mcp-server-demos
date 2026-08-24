#!/bin/zsh
# Clear the macOS quarantine flag and set the exec bit on a freshly downloaded
# Fusion MCP server binary. Only needed right after downloading a new release —
# an already-working install does not need this.
#
# Usage: ./fix-fusion-mcp.sh [path-to-binary]

set -euo pipefail

BINARY="${1:-$HOME/Library/Application Support/mcp-servers/fusion-mcp/fusion-mcp-server-darwin-arm64}"

if [[ ! -f "$BINARY" ]]; then
  print -u2 "not found: $BINARY"
  exit 1
fi

xattr -d com.apple.quarantine "$BINARY" 2>/dev/null || true
chmod +x "$BINARY"
print "ready: $BINARY"
