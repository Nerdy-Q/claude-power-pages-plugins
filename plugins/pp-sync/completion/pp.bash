# Bash completion for the `pp` CLI (NerdyQ pp-sync plugin)
#
# Install:
#   sudo cp pp.bash /etc/bash_completion.d/pp     (system-wide)
#   cp pp.bash ~/.bash_completion.d/pp            (per-user)
# Or source directly from .bashrc:
#   source /path/to/pp.bash
#
# After install, restart the shell or:  source ~/.bashrc

_pp_completion() {
    local cur prev words cword
    _init_completion -n : 2>/dev/null || {
        cur="${COMP_WORDS[COMP_CWORD]}"
        prev="${COMP_WORDS[COMP_CWORD-1]}"
        words=("${COMP_WORDS[@]}")
        cword=$COMP_CWORD
    }

    local subcommands="setup list ls show switch use status down d up u doctor commit solution-down sol-down solution-up sol-up sync-pages audit project alias help"
    local config_dir="${PP_CONFIG_DIR:-$HOME/.config/nq-pp-sync}"

    # Collect project names + aliases for completion
    _pp_projects() {
        local projects=""
        if [[ -d "$config_dir/projects" ]]; then
            projects=$(find "$config_dir/projects" -maxdepth 1 -name "*.conf" 2>/dev/null \
                | sed 's|.*/||; s|\.conf$||')
        fi
        local aliases=""
        if [[ -f "$config_dir/aliases" ]]; then
            aliases=$(cut -d= -f1 "$config_dir/aliases" 2>/dev/null)
        fi
        echo "$projects $aliases"
    }

    # Subcommand at position 1
    if [[ $cword -eq 1 ]]; then
        COMPREPLY=( $(compgen -W "$subcommands" -- "$cur") )
        return 0
    fi

    # Position 2: argument depends on subcommand
    case "${COMP_WORDS[1]}" in
        down|d|up|u|doctor|switch|use|show|sync-pages|audit|solution-down|sol-down|solution-up|sol-up)
            # First arg is a project name
            if [[ $cword -eq 2 ]]; then
                COMPREPLY=( $(compgen -W "$(_pp_projects)" -- "$cur") )
                return 0
            fi
            ;;
        project)
            # Subcommand: add | edit | remove | list
            if [[ $cword -eq 2 ]]; then
                COMPREPLY=( $(compgen -W "add edit remove rm list ls" -- "$cur") )
                return 0
            fi
            # Project arg for edit/remove
            if [[ $cword -eq 3 ]]; then
                case "${COMP_WORDS[2]}" in
                    edit|remove|rm)
                        COMPREPLY=( $(compgen -W "$(_pp_projects)" -- "$cur") )
                        return 0
                        ;;
                esac
            fi
            ;;
        alias)
            # Subcommand: add | list
            if [[ $cword -eq 2 ]]; then
                COMPREPLY=( $(compgen -W "add list ls" -- "$cur") )
                return 0
            fi
            # `alias add <new-alias> <project>` — project completion at position 4
            if [[ $cword -eq 4 && "${COMP_WORDS[2]}" = "add" ]]; then
                COMPREPLY=( $(compgen -W "$(_pp_projects)" -- "$cur") )
                return 0
            fi
            ;;
    esac

    # Position 3+: flags for some subcommands
    case "${COMP_WORDS[1]}" in
        down|d)
            COMPREPLY=( $(compgen -W "--no-clean" -- "$cur") )
            ;;
        up|u)
            COMPREPLY=( $(compgen -W "--validate-only --force-bulk --bulk-threshold=" -- "$cur") )
            ;;
        sync-pages)
            COMPREPLY=( $(compgen -W "base-to-localized localized-to-base" -- "$cur") )
            ;;
        audit)
            COMPREPLY=( $(compgen -W "--severity --exit-code --json -o --output" -- "$cur") )
            # Severity values
            if [[ "$prev" = "--severity" ]]; then
                COMPREPLY=( $(compgen -W "ERROR WARN INFO" -- "$cur") )
            fi
            ;;
    esac

    return 0
}

complete -F _pp_completion pp
