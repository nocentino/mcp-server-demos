#!/bin/zsh

BINARY="$HOME/Library/Application Support/mcp-servers/fusion-mcp/fusion-mcp-server-darwin-arm64"

xattr -d com.apple.quarantine "$BINARY"
chmod +x "$BINARY"
