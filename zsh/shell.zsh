# Shell behaviour defaults, ported from Omarchy default/bash/{shell,inputrc} + fzf init.
# Sourced first by omarchy.zsh. Stock zsh keeps 1000 lines of history, completes
# case-sensitively, and turns on vi keys whenever EDITOR mentions vi (nvim does).

# Keys: emacs like Omarchy's bash (Ctrl-A/E/R/W), Up/Down search by what is typed
bindkey -e
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search '^[OA' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search '^[OB' down-line-or-beginning-search
bindkey '^[[1;5D' backward-word '^[[1;5C' forward-word

# History: big, shared live across tmux tabs, no dups, leading space = not saved
HISTFILE="${HISTFILE:-$HOME/.zsh_history}"
HISTSIZE=32768
SAVEHIST=32768
setopt extended_history share_history hist_ignore_dups hist_ignore_space
setopt hist_expire_dups_first hist_reduce_blanks

# Completion: case-insensitive, arrow-key menu, coloured like ls
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' menu select
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
setopt complete_in_word always_to_end

# Misc: `# comments` work in pasted commands, no bell
setopt interactive_comments no_beep

# fzf: Ctrl-R fuzzy history, Ctrl-T files, Alt-C directories
command -v fzf >/dev/null && source <(fzf --zsh)
