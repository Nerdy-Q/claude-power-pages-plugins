#!/usr/bin/env bash
# install.sh — One-time setup for the pp CLI dispatcher.
#
# What this does:
#   1. Symlinks bin/pp into ~/.local/bin/ (or BIN_DIR if you set it)
#   2. Creates the config dir at ~/.config/nq-pp-sync/
#   3. Prints PATH guidance if ~/.local/bin/ isn't already in PATH
#   4. Tells you to run `pp setup` next
#
# Usage:
#   ./install.sh                    # symlink to ~/.local/bin/pp
#   BIN_DIR=/usr/local/bin ./install.sh   # different bin dir

set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_SOURCE="$PLUGIN_DIR/bin/pp"
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
BIN_TARGET="$BIN_DIR/pp"
CONFIG_DIR="${PP_CONFIG_DIR:-$HOME/.config/nq-pp-sync}"

if [ -t 1 ]; then
    BOLD=$'\033[1m'; GRN=$'\033[32m'; YLW=$'\033[33m'; RST=$'\033[0m'
else
    BOLD=""; GRN=""; YLW=""; RST=""
fi

[ -f "$BIN_SOURCE" ] || { echo "ERROR: $BIN_SOURCE not found" >&2; exit 1; }

# 1. Ensure pp is executable
chmod +x "$BIN_SOURCE"

# 2. Create bin dir + symlink
mkdir -p "$BIN_DIR"
if [ -L "$BIN_TARGET" ] || [ -f "$BIN_TARGET" ]; then
    echo "${YLW}⚠${RST} $BIN_TARGET already exists. Replacing."
    rm -f "$BIN_TARGET"
fi
ln -s "$BIN_SOURCE" "$BIN_TARGET"
echo "${GRN}✓${RST} Symlinked: $BIN_TARGET -> $BIN_SOURCE"

# 3. Create config dir
mkdir -p "$CONFIG_DIR/projects"
touch "$CONFIG_DIR/aliases"
echo "${GRN}✓${RST} Config dir: $CONFIG_DIR"

# 4. PATH check
if ! echo "$PATH" | tr ':' '\n' | grep -qx "$BIN_DIR"; then
    echo
    echo "${YLW}⚠${RST} $BIN_DIR is not in your PATH."
    echo "Add this to your shell rc (~/.zshrc, ~/.bashrc):"
    echo
    echo "${BOLD}  export PATH=\"$BIN_DIR:\$PATH\"${RST}"
    echo
    echo "Then reload your shell or run: source ~/.zshrc"
fi

# 5. Verify pp runs
if "$BIN_TARGET" help >/dev/null 2>&1; then
    echo "${GRN}✓${RST} pp is callable"
else
    echo "${YLW}⚠${RST} pp installed but failed to run. Check: $BIN_TARGET help"
fi

echo
echo "${BOLD}Next:${RST}"
echo "  pp setup           # auto-detect Power Pages projects on this machine"
echo "  pp list            # see what's registered"
echo "  pp help            # full command reference"
