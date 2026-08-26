# git-clone-repo

Intelligent git repository cloner with URL mapping support.

Bash implementation of the PowerShell `Clone-GitRepo` function from [my-configs](https://github.com/your-repo/my-configs).

## Features

- ✅ Smart URL parsing (HTTPS, SSH, SCP-style, shorthand)
- ✅ Configurable URL prefix mappings
- ✅ Longest prefix matching
- ✅ Automatic directory structure creation
- ✅ Interactive mapping configuration (via fzf)
- ✅ View and remove mappings with `gcr mapping`
- ✅ Clone options: shallow, branch selection, SSH rewrite
- ✅ Dry-run preview mode
- ✅ Detailed error messages

## Installation

### Quick install

```bash
cd /path/to/my-scripts/git-clone-repo-tool
./install.sh
```

### Manual installation

```bash
# Create symlinks
ln -s /path/to/my-scripts/git-clone-repo-tool/git-clone-repo ~/.local/bin/git-clone-repo
ln -s /path/to/my-scripts/git-clone-repo-tool/gcr ~/.local/bin/gcr
ln -s /path/to/my-scripts/git-clone-repo-tool/completion.bash \
  ~/.local/share/bash-completion/completions/git-clone-repo

# Ensure ~/.local/bin is in PATH
export PATH="$HOME/.local/bin:$PATH"

# Source gcr to let clone commands change the current shell directory
source ~/.local/bin/gcr
```

## Configuration

### Config file location

Default: `$XDG_CONFIG_HOME/clone-mappings/config.ini` (typically `~/.config/clone-mappings/config.ini`)

### INI format

```ini
[prefix]
root = /path/to/directory

# Examples
[github.com]
root = ~/github

[github.com/anthropics]
root = ~/work/anthropic

[codeup.aliyun.com/6098a93e58f98c96956644dc]
root = ~/work/aliyun
```

### Prefix matching

The script uses **longest prefix matching**:

- `github.com/anthropics/sdk` → matches `[github.com/anthropics]` → `~/work/anthropic/sdk`
- `github.com/other/repo` → matches `[github.com]` → `~/github/other/repo`
- `codeup.aliyun.com/6098a93e58f98c96956644dc/project` → matches `[codeup.aliyun.com/6098a93e58f98c96956644dc]` → `~/work/aliyun/project`

### Interactive configuration

If no mapping exists, the script will prompt (via fzf) to create one:

```bash
git clone-repo https://newhost.com/owner/repo
# > Select prefix level to map:
#   1) newhost.com
#   2) newhost.com/owner
# > Root directory for 'newhost.com' [default: newhost]: /path/to/dir
```

### Manage mappings

`gcr` also provides mapping management commands. They use the same XDG-aware
configuration file as `git-clone-repo`.

```bash
# List mappings in configuration order
gcr mapping list

# Remove exactly one mapping (asks for confirmation)
gcr mapping remove github.com/anthropics

# Remove without prompting, for scripts
gcr mapping remove github.com/anthropics --yes
```

`list` prints a human-readable `PREFIX` / `ROOT` table. When no mappings are
configured, it prints `No mappings configured.`. `remove` only accepts an exact
prefix and leaves the config file, its directory, and unrelated sections intact.

## Usage

```bash
# Basic usage (clone and output directory path)
git clone-repo <url> [options]

# Auto-change directory after clone
gcr <url> [options]

# Manage URL-prefix mappings
gcr mapping <list|remove>

# Manual directory change
cd $(git clone-repo <url> [options])
```

### URL formats

```bash
# HTTPS
git clone-repo https://github.com/anthropics/anthropic-sdk-python

# SSH
git clone-repo git@github.com:anthropics/anthropic-sdk-python.git
git clone-repo ssh://git@github.com/anthropics/anthropic-sdk-python.git

# Shorthand (defaults to github.com)
git clone-repo anthropics/anthropic-sdk-python
```

### Options

```
-s, --shallow      Perform shallow clone (git clone --depth 1)
-b, --branch BR    Checkout specific branch after cloning
    --ssh          Rewrite HTTPS URL to SSH format
-n, --dry-run      Show what would be done without executing
-h, --help         Show help message
```

### Auto-change directory

After successful clone, you can automatically jump to the repository directory:

**Method 1: Use `gcr` wrapper function** (recommended)
```bash
# Clone and auto-change to directory
gcr https://github.com/anthropics/anthropic-sdk-python

# The gcr function wraps git-clone-repo and changes directory
# All options are passed through
gcr --shallow --ssh owner/repo
```

**Method 2: Command substitution**
```bash
# Clone and change directory in one command
cd $(git clone-repo https://github.com/anthropics/anthropic-sdk-python)
```

### Examples

```bash
# Basic clone (outputs directory path)
git clone-repo https://github.com/anthropics/anthropic-sdk-python
# Output: /home/god/work/anthropic/anthropic-sdk-python

# Clone and auto-change directory
gcr https://github.com/anthropics/anthropic-sdk-python
# Now in: /home/god/work/anthropic/anthropic-sdk-python

# Shallow clone with SSH
gcr --shallow --ssh owner/repo

# Clone specific branch
gcr -b develop git@host:owner/repo.git

# Preview without executing
git clone-repo --dry-run https://github.com/user/repo

# Combined options
gcr --shallow --branch main --ssh https://github.com/user/repo
```

## Directory structure

The script creates a directory structure based on the mapping and remaining URL segments:

```
URL: https://github.com/anthropics/anthropic-sdk-python
Mapping: [github.com/anthropics] → ~/work/anthropic

Result: ~/work/anthropic/anthropic-sdk-python/
        (remaining segment: anthropic-sdk-python, lowercased)
```

## How it works

1. **Parse URL**: Extract host and path segments
2. **Find mapping**: Look for longest matching prefix in config
3. **Build path**: Combine mapping root with remaining segments (lowercased)
4. **Clone**: Execute git clone or skip if directory exists

## Comparison with PowerShell version

| Feature | PowerShell | Bash |
|---------|-----------|------|
| URL parsing | ✅ | ✅ |
| Config format | JSON | INI |
| Config location | `$env:LOCALAPPDATA` | `$XDG_CONFIG_HOME` |
| Interactive selection | `Read-Host` | `fzf` |
| Shallow clone | ✅ | ✅ |
| SSH rewrite | ✅ | ✅ |
| Branch selection | ✅ | ✅ |
| Dry-run | ❌ | ✅ |
| Shell completion | ✅ | ✅ |

## Requirements

- Bash 4.0+
- Git
- fzf (for interactive mapping selection)
- Standard Unix tools (grep, sed, etc.)

## Troubleshooting

### "fzf is required for interactive mapping selection"

Install fzf:
```bash
# Ubuntu/Debian
sudo apt install fzf

# macOS
brew install fzf

# Or follow https://github.com/junegunn/fzf
```

Or create config file manually:
```bash
mkdir -p ~/.config/clone-mappings
cat > ~/.config/clone-mappings/config.ini << 'EOF'
[github.com]
root = ~/github
EOF
```

### "Not a git repository"

Ensure you have git installed and configured:
```bash
git --version
git config --global user.name "Your Name"
git config --global user.email "your@email.com"
```

## License

MIT

## Related

- PowerShell version: [my-configs/powershell/module/MyPsScripts/Git.psm1](https://github.com/your-repo/my-configs)
- Inspired by: [Clone-GitRepo](https://github.com/your-repo/my-configs/blob/master/powershell/module/MyPsScripts/Git.psm1)
