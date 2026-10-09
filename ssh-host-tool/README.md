# ssh-host

Show a host's full configuration from `~/.ssh/config`.

- Default output is the raw `Host <name>` block as written in the config,
  followed by option lines inherited from other matching patterns (e.g. `Host *`).
- `-e/--effective` shows the fully resolved configuration from `ssh -G`
  rendered as an aligned two-column table.
- `-l/--list` lists all configured host names.
- `-F/--config` uses an alternate config file (e.g. `~/.ssh/config1`).
- With no argument and [fzf](https://github.com/junegunn/fzf) installed,
  hosts can be picked interactively with a live config preview.

## Install

```bash
./install.sh
```

Symlinks `ssh-host` into `~/.local/bin` and the completion into
`~/.local/share/bash-completion/completions/ssh-host` (lazy-loaded by
bash-completion, no bashrc changes needed).

## Usage

```bash
ssh-host hlm                   # Show "Host hlm" block + inherited options
ssh-host -e hlm                # Fully resolved config (ssh -G) as a table
ssh-host -l                    # List all configured host names
ssh-host -F ~/.ssh/config1 hlm # Use an alternate config file
ssh-host                       # Pick a host interactively (fzf)
```
