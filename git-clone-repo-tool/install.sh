#!/usr/bin/env bash
#
# Install script for git-clone-repo
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${HOME}/.local/bin"
COMPLETION_DIR="${HOME}/.local/share/bash-completion/completions"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Installing git-clone-repo...${NC}"

# Create directories if needed
mkdir -p "$BIN_DIR"
mkdir -p "$COMPLETION_DIR"

# Create symlinks
ln -sf "$SCRIPT_DIR/git-clone-repo" "$BIN_DIR/git-clone-repo"
ln -sf "$SCRIPT_DIR/completion.bash" "$COMPLETION_DIR/git-clone-repo"

echo -e "${GREEN}✓ Installed git-clone-repo to $BIN_DIR${NC}"
echo -e "${GREEN}✓ Installed completion script to $COMPLETION_DIR${NC}"

# Verify
echo -e "\n${BLUE}Verifying installation...${NC}"
if command -v git-clone-repo &>/dev/null; then
  echo -e "${GREEN}✓ git-clone-repo is in PATH${NC}"
  git-clone-repo --help | head -5
else
  echo -e "${RED}✗ $BIN_DIR is not in PATH${NC}"
  echo "  Add 'export PATH=\"\$HOME/.local/bin:\$PATH\"' to your ~/.bashrc"
fi

echo -e "\n${GREEN}Installation complete!${NC}"
echo -e "Usage: ${BLUE}git clone-repo <url>${NC}"
echo -e "Help:  ${BLUE}git-clone-repo --help${NC}"