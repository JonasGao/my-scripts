# bash completion for mihomoctl

_mihomoctl_completion() {
    local cur prev words cword
    _init_completion || return

    local CONFIG_DIR
    if [ -f "${HOME}/.config/mihomo/config-dir.conf" ]; then
        CONFIG_DIR=$(cat "${HOME}/.config/mihomo/config-dir.conf" 2>/dev/null)
    else
        CONFIG_DIR="/etc/mihomo"
    fi

    local MANUAL_CONFIG_DIR="${CONFIG_DIR}/manual"
    local CONFIG_REPO_DIR="${CONFIG_DIR}/profiles"
    local SOURCES_FILE="${XDG_DATA_HOME:-$HOME/.local/share}/mihomo/sources.conf"

    # User-Agent presets
    local ua_presets="clash clashmeta mihomo surge quantumult shadowrocket mozilla chrome curl"

    # Main commands
    local main_commands="install uninstall start stop restart status logs enable disable config ui -h --help -v --verbose --list-ua"

    # Handle specific cases
    case "${prev}" in
        mihomoctl)
            COMPREPLY=($( compgen -W "${main_commands}" -- "${cur}"))
            return 0
            ;;

        -f | --force)
            # After -f, next could be install/uninstall command
            COMPREPLY=($( compgen -W "${main_commands}" -- "${cur}"))
            return 0
            ;;

        --config-dir)
            # Directory completion
            _filedir -d
            return 0
            ;;

        install)
            case "${cur}" in
                -*)
                    COMPREPLY=($( compgen -W "-f --force --config-dir" -- "${cur}"))
                    ;;
            esac
            return 0
            ;;

        uninstall)
            case "${cur}" in
                -*)
                    COMPREPLY=($( compgen -W "-f" -- "${cur}"))
                    ;;
            esac
            return 0
            ;;

        logs)
            # Can be: logs [lines] [-f|--follow]
            case "${prev}" in
                logs)
                    # Number or -f/--follow
                    if [[ ${cur} =~ ^[0-9]*$   ]]; then
                        COMPREPLY=($( compgen -W "-f --follow 10 20 50 100 200 500" -- "${cur}"))
                    else
                        COMPREPLY=($( compgen -W "-f --follow" -- "${cur}"))
                    fi
                    ;;
                -f | --follow)
                    # Nothing after -f
                    ;;
                *)
                    # After number, suggest -f/--follow
                    COMPREPLY=($( compgen -W "-f --follow" -- "${cur}"))
                    ;;
            esac
            return 0
            ;;

        config)
            local config_subcommands="add remove list download select create edit show"
            COMPREPLY=($( compgen -W "${config_subcommands}" -- "${cur}"))
            return 0
            ;;

        ui)
            local ui_subcommands="install update status uninstall"
            COMPREPLY=($( compgen -W "${ui_subcommands}" -- "${cur}"))
            return 0
            ;;

        --list-ua)
            # No arguments after --list-ua
            return 0
            ;;
    esac

    # Handle config subcommands
    local i
    for i in "${!words[@]}"; do
        if [[ ${words[$i]} == "config"   ]]; then
            local config_cmd="${words[i + 1]}"

            case "${config_cmd}" in
                add)
                    # add <name> <url|path>
                    # If at name position, no completion
                    # If at path position, file completion
                    local word_count=$((cword - i - 1))
                    if [ "$word_count" -eq 2 ]; then
                        _filedir
                    fi
                    return 0
                    ;;

                remove | edit)
                    # remove/edit <name> - complete with available configs
                    local configs=""

                    # Add sources
                    if [ -f "$SOURCES_FILE" ]; then
                        configs+=" $(cut -d'|' -f1 "$SOURCES_FILE")"
                    fi

                    # Add manual configs
                    if [ -d "$MANUAL_CONFIG_DIR" ]; then
                        for f in "$MANUAL_CONFIG_DIR"/*.yaml; do
                            [ -f "$f" ] && configs+=" $(basename "$f" .yaml)"
                        done
                    fi

                    # Add downloaded profiles (basename without timestamp suffix for easier reference)
                    if [ -d "$CONFIG_REPO_DIR" ]; then
                        for f in "$CONFIG_REPO_DIR"/*.yaml; do
                            [ -f "$f" ] && configs+=" $(basename "$f" .yaml)"
                        done
                    fi

                    COMPREPLY=($( compgen -W "${configs}" -- "${cur}"))
                    return 0
                    ;;

                download)
                    # download <source> [--ua|--user-agent <preset|custom>] [--list-ua]
                    local word_count=$((cword - i - 1))

                    # Check if previous word is --ua/--user-agent
                    if [[ ${prev} == "--ua"   ]] || [[ ${prev} == "--user-agent"   ]]; then
                        COMPREPLY=($( compgen -W "${ua_presets}" -- "${cur}"))
                        return 0
                    fi

                    # Get available sources
                    local sources=""
                    if [ -f "$SOURCES_FILE" ]; then
                        sources=$(cut -d'|' -f1 "$SOURCES_FILE")
                    fi

                    # Options for download
                    local download_opts="--ua --user-agent --list-ua"

                    case "${cur}" in
                        --*)
                            COMPREPLY=($( compgen -W "${download_opts}" -- "${cur}"))
                            return 0
                            ;;
                        *)
                            # Source name or option
                            if [ "$word_count" -eq 1 ]; then
                                # First positional arg: source name
                                COMPREPLY=($( compgen -W "${sources}" -- "${cur}"))
                            else
                                # After source: can be options
                                COMPREPLY=($( compgen -W "${download_opts}" -- "${cur}"))
                            fi
                            return 0
                            ;;
                    esac
                    ;;

                select)
                    # select [name_or_path] - complete with configs or file paths
                    local configs=""

                    # Add manual configs
                    if [ -d "$MANUAL_CONFIG_DIR" ]; then
                        for f in "$MANUAL_CONFIG_DIR"/*.yaml; do
                            [ -f "$f" ] && configs+=" $(basename "$f" .yaml)"
                        done
                    fi

                    # Add downloaded profiles
                    if [ -d "$CONFIG_REPO_DIR" ]; then
                        for f in "$CONFIG_REPO_DIR"/*.yaml; do
                            [ -f "$f" ] && configs+=" $(basename "$f" .yaml)"
                        done
                    fi

                    # Also allow file path completion
                    if [[ ${cur} == /*   ]] || [[ ${cur} == .*   ]]; then
                        _filedir
                    else
                        COMPREPLY=($( compgen -W "${configs}" -- "${cur}"))
                    fi
                    return 0
                    ;;

                create)
                    # create <name> - no completion for new name
                    return 0
                    ;;

                list | show)
                    # No further arguments
                    return 0
                    ;;
            esac
            break
        fi
    done

    # Default: complete with main commands
    COMPREPLY=($( compgen -W "${main_commands}" -- "${cur}"))
}

complete -F _mihomoctl_completion mihomoctl
