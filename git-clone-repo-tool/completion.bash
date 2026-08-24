# bash completion for git-clone-repo

_git_clone_repo() {
  local cur prev words cword
  _init_completion || return

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

# Register completion for both direct call and git subcommand
complete -F _git_clone_repo git-clone-repo

# If using as git subcommand, also register for git
if command -v __git_complete &>/dev/null; then
  __git_complete git-clone-repo _git_clone_repo
fi