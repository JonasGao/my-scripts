#!/usr/bin/env bash
# Bash completion for ccxw (claude-code-worktree-env)

_ccw_profiles_dir() {
	local config_dir="${CLAUDE_CODE_ENV_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/claude-code-env}"
	echo "$config_dir/profiles"
}

_ccw_list_profiles() {
	local profiles_dir
	profiles_dir="$(_ccw_profiles_dir)"
	shopt -s nullglob
	local files=("$profiles_dir"/*.env)
	shopt -u nullglob

	local profiles=()
	for f in "${files[@]}"; do
		profiles+=("$(basename "$f" .env)")
	done
	printf '%s\n' "${profiles[@]}"
}

_ccw_complete() {
	local cur prev words cword
	_init_completion || return

	local profiles_dir
	profiles_dir="$(_ccw_profiles_dir)"

	# After --: suggest common claude arguments
	if [[ "$prev" == "--" ]]; then
		mapfile -t COMPREPLY < <(compgen -W '--model --permission-mode --resume --verbose --print --output-format --allowedTools --disallowed-tools' -- "$cur")
		return
	fi

	# First word: profile, -w, -r, -n, --, or passthrough subcommands
	if [[ $cword -eq 1 ]]; then
		mapfile -t COMPREPLY < <(compgen -W "$(_ccw_list_profiles) -w -r -n -- list ls add edit view default rm cp rename path help" -- "$cur")
		return
	fi

	# Subsequent words: profile, flags, or passthrough subcommand arguments
	case "$prev" in
	-w | --worktree)
		# Worktree name is free-form
		COMPREPLY=()
		return
		;;
	-r | --resume)
		# Session ID / search term - no completion available
		COMPREPLY=()
		return
		;;
	-n | --no-skip-permissions)
		mapfile -t COMPREPLY < <(compgen -W "$(_ccw_list_profiles) -w -r --" -- "$cur")
		return
		;;
	esac

	# After a profile, offer remaining flags
	if [[ -f "$profiles_dir/${prev}.env" ]]; then
		mapfile -t COMPREPLY < <(compgen -W '-w -r -n --' -- "$cur")
		return
	fi

	# Default: offer profiles and flags
	mapfile -t COMPREPLY < <(compgen -W "$(_ccw_list_profiles) -w -r -n --" -- "$cur")
}

complete -F _ccw_complete ccxw
