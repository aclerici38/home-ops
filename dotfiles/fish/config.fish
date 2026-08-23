# Managed by mise ([dotfiles] in .mise.toml). Edit here, not in ~/.config.

set -gx MISE_GLOBAL_CONFIG_FILE $HOME/home-ops/.mise.toml

alias k kubectl
alias ll 'ls -lah'
alias t talosctl

if status is-interactive
    set fish_greeting

    abbr -a drs "mise bootstrap -C ~/home-ops"

    # Activate the mise version pinned by `aqua:jdx/mise` in [tools] rather than
    # whichever mise happens to be first on PATH, so the pin is authoritative.
    set -l _aqua_mise_dir $HOME/.local/share/mise/installs/aqua-jdx-mise
    if test -d $_aqua_mise_dir
        set -l _ver (command ls $_aqua_mise_dir | sort -V | tail -1)
        if test -n "$_ver"; and test -x $_aqua_mise_dir/$_ver/mise/bin/mise
            $_aqua_mise_dir/$_ver/mise/bin/mise activate fish | source
        else
            mise activate fish | source
        end
    else
        mise activate fish | source
    end

    # Must follow mise activation: both binaries come from [tools].
    command -q atuin; and atuin init fish | source
    command -q direnv; and direnv hook fish | source
end
