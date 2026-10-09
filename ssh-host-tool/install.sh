#!/usr/bin/env bash
#
# Install script for ssh-host
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${HOME}/.local/bin"
COMPLETION_DIR="${HOME}/.local/share/bash-completion/completions"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}Installing ssh-host...${NC}"

# Create directories if needed
mkdir -p "$BIN_DIR"
mkdir -p "$COMPLETION_DIR"

# Create symlinks
ln -sf "$SCRIPT_DIR/ssh-host" "$BIN_DIR/ssh-host"
ln -sf "$SCRIPT_DIR/completion.bash" "$COMPLETION_DIR/ssh-host"

echo -e "${GREEN}✓ Installed ssh-host to $BIN_DIR${NC}"
echo -e "${GREEN}✓ Installed completion script to $COMPLETION_DIR${NC}"

# Verify
echo -e "\n${BLUE}Verifying installation...${NC}"
"$BIN_DIR/ssh-host" --help | head -5
if [[ ":$PATH:" == *":$BIN_DIR:"* ]]; then
  echo -e "${GREEN}✓ $BIN_DIR is in PATH${NC}"
else
  echo -e "${RED}✗ $BIN_DIR is not in PATH${NC}"
  echo "  Add 'export PATH=\"\$HOME/.local/bin:\$PATH\"' to your ~/.bashrc"
fi

echo -e "\n${GREEN}Installation complete!${NC}"
echo -e "\nUsage:"
echo -e "  ${BLUE}ssh-host <name>${NC}          # Show the host's config block"
echo -e "  ${BLUE}ssh-host -e <name>${NC}       # Show effective config (ssh -G) as a table"
echo -e "  ${BLUE}ssh-host -l${NC}              # List all host names"
echo -e "\nHelp: ${BLUE}ssh-host --help${NC}"
