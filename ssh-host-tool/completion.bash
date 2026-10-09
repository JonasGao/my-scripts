# bash completion for ssh-host

_ssh_host() {
  local cur prev words cword
  _init_completion || return

  case "$prev" in
    -F|--config)
      _filedir
      return
      ;;
  esac

  # Complete options
  if [[ "$cur" == -* ]]; then
    COMPREPLY=($(compgen -W "\
      -e --effective \
      -l --list \
      -F --config \
      -h --help" -- "$cur"))
    return
  fi

  # Complete a host name for the first positional argument only
  local positional=0 word
  for word in "${words[@]:1}"; do
    [[ "$word" == -* ]] || ((positional++))
  done
  ((positional > 1)) && return

  local hosts
  hosts=$(ssh-host --list 2>/dev/null)
  [[ -n "$hosts" ]] && COMPREPLY=($(compgen -W "$hosts" -- "$cur"))
}

complete -F _ssh_host ssh-host
