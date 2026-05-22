# ── env ───────────────────────────────────────────────────────────────────────
export PATH="$PATH:$HOME/go/bin:$HOME/.local/bin:$HOME/.venv/pentest/bin"
export GOPATH="$HOME/go"
export EDITOR=nvim
export PAGER=less
export LESS="-R"
export HISTSIZE=50000
export HISTFILESIZE=50000
export HISTCONTROL=ignoredups:erasedups

# ── prompt (everforest moss) ──────────────────────────────────────────────────
MOSS='\[\033[38;2;167;192;128m\]'   # #a7c080
TEAL='\[\033[38;2;131;192;146m\]'   # #83c092
GREY='\[\033[38;2;211;198;170m\]'   # #d3c6aa
DIM='\[\033[38;2;71;82;88m\]'       # #475258
RESET='\[\033[0m\]'

__git_branch() {
    git rev-parse --abbrev-ref HEAD 2>/dev/null | sed 's/^/ /'
}

PS1="${DIM}[${MOSS}\u${DIM}@${TEAL}\h${DIM}]${GREY}\w${MOSS}\$(__git_branch)${RESET} \$ "

# ── aliases ───────────────────────────────────────────────────────────────────
alias ls='ls --color=auto'
alias ll='ls -lah --color=auto'
alias la='ls -A --color=auto'
alias grep='grep --color=auto'
alias vi=nvim
alias vim=nvim
alias ip='ip -color=auto'
alias diff='diff --color=auto'

# pentest shortcuts
alias nse='ls /usr/share/nmap/scripts/ | grep'
alias httprobe-list='cat urls.txt | httprobe'
alias fuzz='ffuf -w /usr/share/seclists/Discovery/Web-Content/raft-medium-words.txt'
alias dns-brute='dnsx -silent -r /usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt'

# ── tmux autostart ────────────────────────────────────────────────────────────
if command -v tmux &>/dev/null && [[ -z "$TMUX" ]] && [[ "$TERM_PROGRAM" != "vscode" ]]; then
    tmux attach -t main 2>/dev/null || tmux new-session -s main
fi
