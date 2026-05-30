#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="${HOME}/.local/bin"
SCRIPT_NAME="ktk-init"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_SRC="$REPO_DIR/cli/ktk-init.sh"
CONFIG_DIR="$HOME/.config/ktk-init"
CONFIG_FILE="$CONFIG_DIR/config"

mkdir -p "$INSTALL_DIR" "$CONFIG_DIR"
cp "$SCRIPT_SRC" "$INSTALL_DIR/$SCRIPT_NAME"
chmod +x "$INSTALL_DIR/$SCRIPT_NAME"

# Write config pointing to local repo templates
cat > "$CONFIG_FILE" <<EOF
# ktk-init configuration
#
# TEMPLATES_SOURCE options:
#   local:/path/to/templates
#   git:https://github.com/ismaelkotake/kotaketech-initializer
TEMPLATES_SOURCE=local:$REPO_DIR/templates
EOF

echo "✓ $SCRIPT_NAME installed at $INSTALL_DIR/$SCRIPT_NAME"
echo "✓ Config written to $CONFIG_FILE (templates: $REPO_DIR/templates)"
echo ""

if ! echo "$PATH" | grep -q "$INSTALL_DIR"; then
  echo "Add $INSTALL_DIR to your PATH if it is not there yet:"
  echo ""
  echo "  echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.bashrc && source ~/.bashrc"
  echo ""
  echo "  # or for zsh:"
  echo "  echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.zshrc && source ~/.zshrc"
fi
