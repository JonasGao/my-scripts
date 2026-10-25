#!/usr/bin/env bash
#
# Install script for cleanup-orphan-branches
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${HOME}/.local/bin"
OLD_LINK="${BIN_DIR}/cleanup-orphan-branches.sh"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

echo -e "${BLUE}Installing cleanup-orphan-branches...${NC}"

mkdir -p "$BIN_DIR"
ln -sf "$SCRIPT_DIR/cleanup-orphan-branches" "$BIN_DIR/cleanup-orphan-branches"

echo -e "${GREEN}✓ Linked cleanup-orphan-branches -> $BIN_DIR/cleanup-orphan-branches${NC}"

if [ -e "$OLD_LINK" ] || [ -L "$OLD_LINK" ]; then
  echo -e "${YELLOW}! 发现旧入口 $OLD_LINK（bash 版残留）${NC}"
  echo -e "  新命令为 cleanup-orphan-branches，确认不再需要后可执行:"
  echo -e "  ${BLUE}rm $OLD_LINK${NC}"
fi

echo -e "\n${BLUE}Verifying installation...${NC}"
if command -v cleanup-orphan-branches &>/dev/null; then
  echo -e "${GREEN}✓ cleanup-orphan-branches is in PATH${NC}"
else
  echo -e "${RED}✗ $BIN_DIR is not in PATH${NC}"
  echo "  Add 'export PATH=\"\$HOME/.local/bin:\$PATH\"' to your ~/.bashrc"
fi

echo -e "\n${GREEN}Installation complete!${NC}"
echo -e "\nUsage:"
echo -e "  ${BLUE}cleanup-orphan-branches${NC}              # 当前仓库，终端交互"
echo -e "  ${BLUE}cleanup-orphan-branches <路径> --web${NC}  # 网页勾选删除"
echo -e "  ${BLUE}cleanup-orphan-branches --dry-run${NC}     # 只预览不执行"
echo -e "\nHelp: ${BLUE}cleanup-orphan-branches --help${NC}"
