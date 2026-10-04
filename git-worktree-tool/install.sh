#!/usr/bin/env bash
#
# Install script for gwt (Git Worktree Manager)
#
# gwt must be *sourced* (not executed) so it can `cd` the current shell and
# register the gwtb/gwtd functions. This installer symlinks the script into
# ~/.local/bin; add `source "$HOME/.local/bin/gwt"` to your ~/.bashrc to load
# it in every interactive shell.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${HOME}/.local/bin"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Installing gwt...${NC}"

# Create directory if needed
mkdir -p "$BIN_DIR"

# Create symlink
ln -sf "$SCRIPT_DIR/gwt" "$BIN_DIR/gwt"

echo -e "${GREEN}✓ Linked gwt -> $BIN_DIR/gwt${NC}"

# Verify (gwt must be sourced, so run it in a sourcing subshell)
echo -e "\n${BLUE}Verifying installation...${NC}"
if bash -c "source '$BIN_DIR/gwt' --version" 2>/dev/null | grep -q "gwt version"; then
  echo -e "${GREEN}✓ gwt sources correctly${NC}"
else
  echo -e "${RED}✗ Failed to source gwt${NC}"
fi

if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
  echo -e "${RED}! $BIN_DIR is not in PATH${NC}"
  echo "  Add 'export PATH=\"\$HOME/.local/bin:\$PATH\"' to your ~/.bashrc"
fi

echo -e "\n${GREEN}Installation complete!${NC}"
echo -e "\n${BLUE}gwt must be sourced.${NC} Add this line to your ~/.bashrc:"
echo -e "  ${BLUE}source \"\$HOME/.local/bin/gwt\"${NC}"
echo -e "\nUsage:"
echo -e "  ${BLUE}gwt <branch>${NC}   # create/switch to a worktree for <branch>"
echo -e "  ${BLUE}gwtb${NC}           # toggle between main repo and last worktree"
echo -e "  ${BLUE}gwtd${NC}           # remove current worktree (keep local branch)"
