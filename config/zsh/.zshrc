# ~/.zshrc: managed by the dotfiles repo (symlinked).
# Edit the copy in the repo, not this symlink target.

# ---------------------------------------------------------------------------
# Powerlevel10k instant prompt (keep near the top).
# ---------------------------------------------------------------------------
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Keep PATH/fpath entries unique (no duplicates as you re-source).
typeset -U path PATH fpath

# ---------------------------------------------------------------------------
# oh-my-zsh
# ---------------------------------------------------------------------------
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

# Behaviour preferences.
zstyle ':omz:update' mode disabled   # don't auto-update oh-my-zsh
DISABLE_AUTO_TITLE="true"            # let tmux/terminal manage the title
DISABLE_UNTRACKED_FILES_DIRTY="true" # faster git status in big repos
ZSH_DISABLE_COMPFIX="true"           # skip compaudit's permission scan on every start

# Plugin order matters: completions before compinit-dependent ones, and
# fast-syntax-highlighting should come last.
# Left out on purpose (slow at startup): pyenv (~0.75s, runs `pyenv init` + rehash;
# lazy-loaded below instead), gcloud (~0.35s), helm (spawns `helm completion` in
# the background on every shell; cached once below instead).
plugins=(
  git
  gh
  python
  jsontools
  docker
  kubectl
  aws
  dotenv
  colored-man-pages
  extract
  history-substring-search
  zsh-completions
  fzf-tab
  zsh-autosuggestions
  fast-syntax-highlighting
)

# zsh-completions needs its functions on fpath before compinit (run by OMZ).
fpath+=("$ZSH/custom/plugins/zsh-completions/src")

# Cache completions for faster shell startup.
ZSH_CACHE_DIR="${ZSH_CACHE_DIR:-$HOME/.cache/oh-my-zsh}"
[[ -d "$ZSH_CACHE_DIR/completions" ]] || mkdir -p "$ZSH_CACHE_DIR/completions"
fpath+=("$ZSH_CACHE_DIR/completions")
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "$ZSH_CACHE_DIR"

source "$ZSH/oh-my-zsh.sh"

# ---------------------------------------------------------------------------
# History search keybindings (history-substring-search plugin)
# ---------------------------------------------------------------------------
# Up/Down: search history by the text already typed.
bindkey "$terminfo[kcuu1]" history-beginning-search-backward
bindkey "$terminfo[kcud1]" history-beginning-search-forward
# Ctrl+P / Ctrl+N: substring search through history.
bindkey -M emacs '^P' history-substring-search-up
bindkey -M emacs '^N' history-substring-search-down

# ---------------------------------------------------------------------------
# Aliases
# ---------------------------------------------------------------------------
alias c="clear"
alias ips='ip4 && ip6 && ip0'
alias ip0='echo "- Local IP: $(ipconfig getifaddr en0)"'
alias ip4='echo "- IP v4: $(curl -s https://api.ipify.org)"'
alias ip6='echo "- IP v6: $(curl -s https://api64.ipify.org)"'

# Modern CLI tools: alias to the canonical names, accounting for Debian's
# alternative binary names (bat -> batcat, fd -> fdfind).
if command -v batcat >/dev/null 2>&1; then alias bat="batcat"; fi
if command -v fdfind >/dev/null 2>&1; then alias fd="fdfind"; fi
if command -v eza    >/dev/null 2>&1; then
  alias ls="eza --group-directories-first"
  alias ll="eza -lah --group-directories-first --git"
  alias tree="eza --tree"
fi

# ---------------------------------------------------------------------------
# Tool integrations (loaded only when the tool is present)
# ---------------------------------------------------------------------------
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init zsh)"
command -v direnv >/dev/null 2>&1 && eval "$(direnv hook zsh)"
command -v mise   >/dev/null 2>&1 && eval "$(mise activate zsh)"

# pyenv: put shims on PATH now; run the slow `pyenv init` only on first use.
if command -v pyenv >/dev/null 2>&1; then
  export PYENV_ROOT="${PYENV_ROOT:-$HOME/.pyenv}"
  path=("$PYENV_ROOT/shims" $path)
  pyenv() {
    unfunction pyenv
    eval "$(command pyenv init - --no-rehash zsh)"
    pyenv "$@"
  }
fi

# helm: generate its completion once instead of on every shell. Delete
# $ZSH_CACHE_DIR/completions/_helm after upgrading helm to refresh it.
if command -v helm >/dev/null 2>&1; then
  [[ -s "$ZSH_CACHE_DIR/completions/_helm" ]] \
    || helm completion zsh >| "$ZSH_CACHE_DIR/completions/_helm" 2>/dev/null
  alias h='helm'
fi

# gcloud: only add it to PATH (its slow completion script is skipped).
for _gcloud_sdk in /opt/homebrew/share/google-cloud-sdk /usr/local/share/google-cloud-sdk \
                   /usr/lib/google-cloud-sdk /usr/share/google-cloud-sdk "$HOME/google-cloud-sdk"; do
  [[ -f "$_gcloud_sdk/path.zsh.inc" ]] && { source "$_gcloud_sdk/path.zsh.inc"; break; }
done
unset _gcloud_sdk

# fzf key bindings & completion (path varies by platform/package).
[[ -f ~/.fzf.zsh ]] && source ~/.fzf.zsh
[[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ]] && source /usr/share/doc/fzf/examples/key-bindings.zsh

# corepack-managed package managers on PATH.
export PATH="$HOME/.local/bin:$PATH"

# ---------------------------------------------------------------------------
# Powerlevel10k prompt config.
# ---------------------------------------------------------------------------
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh

# ---------------------------------------------------------------------------
# Machine-local overrides; NOT tracked in this repo.
# Put work/secret/host-specific aliases, exports, and tool init in
# ~/.zshrc.local (e.g. company VPN paths, kube tokens, SDKMAN, nvm). It stays
# off GitHub while everything generic lives in this shared file.
# ---------------------------------------------------------------------------
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
