#!/usr/bin/env bash
# ==============================================================================
# DeskPulse Startup Script (Rust Enterprise Edition)
# ==============================================================================

set -e
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
cd "$DIR"

BINARY="$DIR/agent/target/release/deskpulse-agent"
if [ ! -f "$BINARY" ]; then
    BINARY="$DIR/agent/target/debug/deskpulse-agent"
fi

if [ -f "$BINARY" ]; then
    echo "🦀 Khởi động DeskPulse Agent (Rust)..."
    exec "$BINARY" "$@"
else
    echo "⚙️ Đang biên dịch DeskPulse Rust Agent lần đầu..."
    cd "$DIR/agent"
    cargo build --release
    exec "$DIR/agent/target/release/deskpulse-agent" "$@"
fi
