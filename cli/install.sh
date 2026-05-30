#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="${HOME}/.local/bin"
SCRIPT_NAME="ktk-init"
SCRIPT_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/ktk-init.sh"

mkdir -p "$INSTALL_DIR"
cp "$SCRIPT_SRC" "$INSTALL_DIR/$SCRIPT_NAME"
chmod +x "$INSTALL_DIR/$SCRIPT_NAME"

echo "✓ $SCRIPT_NAME instalado em $INSTALL_DIR/$SCRIPT_NAME"
echo ""

if ! echo "$PATH" | grep -q "$INSTALL_DIR"; then
  echo "Adicione ao seu PATH (se ainda não estiver):"
  echo ""
  echo "  echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.bashrc && source ~/.bashrc"
  echo ""
  echo "  # ou para zsh:"
  echo "  echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.zshrc && source ~/.zshrc"
fi
