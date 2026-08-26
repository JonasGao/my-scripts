# bash completion for git-clone-repo

_git_clone_repo() {
  local cur prev words cword
  _init_completion || return

  if [[ "${words[1]:-}" == "mapping" ]]; then
    if [[ $cword -eq 2 ]]; then
      COMPREPLY=($(compgen -W "list remove --help" -- "${cur}"))
      return
    fi

    if [[ "${words[2]:-}" == "remove" ]]; then
      if [[ "${cur}" == -* ]]; then
        COMPREPLY=($(compgen -W "--yes --help" -- "${cur}"))
      else
        local config_file="${XDG_CONFIG_HOME:-$HOME/.config}/clone-mappings/config.ini"
        local prefixes
        prefixes=$(sed -n 's/^\[\([^]]*\)\].*/\1/p' "$config_file" 2>/dev/null)
        COMPREPLY=($(compgen -W "$prefixes" -- "${cur}"))
      fi
      return
    fi

    return
  fi

  case "${prev}" in
    -b|--branch)
      # No completion for branch name (could query git in future)
      return
      ;;
  esac

  # Complete options
  if [[ "${cur}" == -* ]]; then
    COMPREPLY=($(compgen -W "\
      -s --shallow \
      -b --branch \
      --ssh \
      -n --dry-run \
      -h --help" -- "${cur}"))
    return
  fi

  # If we already have a URL, don't suggest more arguments
  local url_count=0
  for word in "${words[@]}"; do
    case "${word}" in
      -*) ;;
      git-clone-repo) ;;
      *) ((url_count++)) ;;
    esac
  done

  if [[ ${url_count} -ge 1 ]]; then
    return
  fi

  # Could add URL completion here (from history, git remotes, etc.)
}

# Shell function wrapper that automatically changes directory after clone
# Usage: gcr <url> [options]
gcr() {
  if [[ "${1:-}" == "mapping" ]]; then
    shift
    if declare -F gcr_mapping &>/dev/null; then
      gcr_mapping "$@"
    else
      command gcr mapping "$@"
    fi
    return $?
  fi

  local target
  target=$(git-clone-repo "$@")
  if [[ -n "$target" && -d "$target" ]]; then
    cd "$target"
  fi
}

# Register completion for both direct call and git subcommand
complete -F _git_clone_repo git-clone-repo
complete -F _git_clone_repo gcr

# If using as git subcommand, also register for git
if command -v __git_complete &>/dev/null; then
  __git_complete git-clone-repo _git_clone_repo
fi
