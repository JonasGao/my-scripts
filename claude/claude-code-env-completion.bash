#!/usr/bin/env bash
# Bash completion for claude-code-env

_cce_profiles_dir() {
	local config_dir="${CLAUDE_CODE_ENV_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/claude-code-env}"
	echo "$config_dir/profiles"
}

_cce_list_profiles() {
	local profiles_dir
	profiles_dir="$(_cce_profiles_dir)"
	shopt -s nullglob
	local files=("$profiles_dir"/*.env)
	shopt -u nullglob

	local profiles=()
	for f in "${files[@]}"; do
		profiles+=("$(basename "$f" .env)")
	done
	printf '%s\n' "${profiles[@]}"
}

_cce_complete() {
	local cur prev words cword
	_init_completion || return

	local profiles_dir
	profiles_dir="$(_cce_profiles_dir)"

	# First word: complete commands
	if [[ $cword -eq 1 ]]; then
		mapfile -t COMPREPLY < <(compgen -W 'run list ls add new edit default set-default rm remove delete init path help --help -h' -- "$cur")
		return
	fi

	local cmd="${words[1]}"

	case "$cmd" in
	run)
		# After 'run': complete profile or flags
		case "$prev" in
		-n | --no-skip-permissions)
			mapfile -t COMPREPLY < <(compgen -W '--' -- "$cur")
			return
			;;
		run)
			# First arg after 'run': profile or flag
			mapfile -t COMPREPLY < <(compgen -W "$(_cce_list_profiles) -n --no-skip-permissions --" -- "$cur")
			return
			;;
		*)
			# Profile already given, complete flags
			if [[ -f "$profiles_dir/${prev}.env" ]]; then
				mapfile -t COMPREPLY < <(compgen -W '-n --no-skip-permissions --' -- "$cur")
				return
			fi
			# Complete remaining profiles or flags
			mapfile -t COMPREPLY < <(compgen -W "$(_cce_list_profiles) -n --no-skip-permissions --" -- "$cur")
			return
			;;
		esac
		;;
	list | ls)
		# 'list' takes no args
		COMPREPLY=()
		return
		;;
	add | new)
		# 'add <profile> [--no-edit] [--force]'
		case "$prev" in
		add | new)
			COMPREPLY=() # New profile name, no completion
			return
			;;
		--no-edit | --force | -h | --help)
			mapfile -t COMPREPLY < <(compgen -W '--no-edit --force -h --help' -- "$cur")
			return
			;;
		*)
			# After profile name
			mapfile -t COMPREPLY < <(compgen -W '--no-edit --force -h --help' -- "$cur")
			return
			;;
		esac
		;;
	edit)
		# 'edit <profile>'
		case "$prev" in
		edit)
			mapfile -t COMPREPLY < <(compgen -W "$(_cce_list_profiles)" -- "$cur")
			return
			;;
		esac
		COMPREPLY=()
		return
		;;
	default | set-default)
		# 'default [profile]'
		case "$prev" in
		default | set-default)
			mapfile -t COMPREPLY < <(compgen -W "$(_cce_list_profiles)" -- "$cur")
			return
			;;
		esac
		COMPREPLY=()
		return
		;;
	rm | remove | delete)
		# 'rm <profile>'
		case "$prev" in
		rm | remove | delete)
			mapfile -t COMPREPLY < <(compgen -W "$(_cce_list_profiles)" -- "$cur")
			return
			;;
		esac
		COMPREPLY=()
		return
		;;
	init)
		# 'init' takes no args
		COMPREPLY=()
		return
		;;
	path)
		# 'path [profile]'
		case "$prev" in
		path)
			mapfile -t COMPREPLY < <(compgen -W "$(_cce_list_profiles)" -- "$cur")
			return
			;;
		esac
		COMPREPLY=()
		return
		;;
	help | --help | -h)
		COMPREPLY=()
		return
		;;
	*)
		# Unknown command - treat as profile for run
		mapfile -t COMPREPLY < <(compgen -W "$(_cce_list_profiles) -n --no-skip-permissions --" -- "$cur")
		return
		;;
	esac
}

complete -F _cce_complete cc
