# ~/.zshrc — managed by the dotfiles repo (symlinked).
# Edit the copy in the repo, not this symlink target.

# ---------------------------------------------------------------------------
# Powerlevel10k instant prompt (keep near the top).
# ---------------------------------------------------------------------------
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ---------------------------------------------------------------------------
# oh-my-zsh
# ---------------------------------------------------------------------------
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

# Plugin order matters: completions before compinit-dependent ones, and
# fast-syntax-highlighting should come last.
plugins=(
  git
  gh
  python
  jsontools
  docker
  kubectl
  helm
  pyenv
  aws
  gcloud
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

source "$ZSH/oh-my-zsh.sh"

# ---------------------------------------------------------------------------
# Aliases
# ---------------------------------------------------------------------------
alias c="clear"

# Modern CLI tools — alias to the canonical names, accounting for Debian's
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
command -v pyenv  >/dev/null 2>&1 && eval "$(pyenv init - 2>/dev/null)"

# fzf key bindings & completion (path varies by platform/package).
[[ -f ~/.fzf.zsh ]] && source ~/.fzf.zsh
[[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ]] && source /usr/share/doc/fzf/examples/key-bindings.zsh

# corepack-managed package managers on PATH.
export PATH="$HOME/.local/bin:$PATH"

# ---------------------------------------------------------------------------
# Powerlevel10k prompt config.
# ---------------------------------------------------------------------------
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh
