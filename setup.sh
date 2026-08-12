#!/usr/bin/env bash
# Nityanand's VM bootstrap — bashrc, gh, Claude Code, hf, gpustat.
# Usage (on any Linux/macOS box):
#   curl -fsSL https://nityanandmathur.com/setup.sh | bash
# Safe to re-run. Installs only; auth (gh auth login / claude / hf auth login) is interactive afterward.
set -euo pipefail

log()  { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mWARN\033[0m %s\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

# Prefer sudo when not root; no-op when already root.
if [ "$(id -u)" -eq 0 ]; then
  SUDO=""
else
  SUDO="sudo"
fi

# ---------------------------------------------------------------------------
# 1. bashrc / zshrc managed block
# ---------------------------------------------------------------------------
install_bashrc() {
  case "$(basename "${SHELL:-/bin/bash}")" in
    zsh) RC_FILE="${RC_FILE:-$HOME/.zshrc}"; SH=zsh ;;
    *)   RC_FILE="${RC_FILE:-$HOME/.bashrc}"; SH=bash ;;
  esac

  BEGIN="# >>> nm-bashrc (managed by setup-bashrc skill) >>>"
  END="# <<< nm-bashrc (managed by setup-bashrc skill) <<<"

  read -r -d '' COMMON <<'EOF' || true
# --- List files aliases ---
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
list() {
    total=0
    printf "%-50s %s\n" "Directory" "Count"
    for d in ./*; do
        if [ -d "$d" ]; then
            count=$(find "$d" -type f | wc -l)
            printf "%-50s %s\n" "$d" "$count"
            total=$((total + count))
        fi
    done
    printf "%-50s\n" "------------------------------------"
    printf "%-50s %s\n" "Total" "$total"
}

# --- GPUstat aliases ---
alias gs='gpustat'
alias wgs='watch -d gpustat'

# --- TMUX aliases ---
alias tls='tmux ls'
ta() { tmux attach -t "$1"; }

# --- DU alias ---
alias dus='du -sh * | sort -hr'

# --- Ensure common install paths ---
export PATH="$HOME/.local/bin:$HOME/.claude/bin:$PATH"
EOF

  if [ "$SH" = zsh ]; then
    read -r -d '' PROMPT <<'EOF' || true

# --- Prompt with git branch (zsh) ---
autoload -Uz vcs_info
precmd() { vcs_info }
zstyle ':vcs_info:git:*' formats '(%b)'
setopt PROMPT_SUBST
PROMPT='%F{green}%n:%F{blue}%~%f ${vcs_info_msg_0_}%# '
EOF
  else
    read -r -d '' PROMPT <<'EOF' || true

# --- Prompt with git branch (bash) ---
git_branch() { git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/(\1)/'; }
export PS1="\[\e]0;\u@\h: \w\a\]${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u:\[\033[01;34m\]\w\[\033[00m\] \$(git_branch)\$ "
EOF
  fi

  BLOCK="$COMMON
$PROMPT"
  touch "$RC_FILE"

  if grep -qF "$BEGIN" "$RC_FILE"; then
    tmp="$(mktemp)"
    awk -v b="$BEGIN" -v e="$END" '$0==b{s=1} s==0{print} $0==e{s=0}' "$RC_FILE" > "$tmp"
    printf '%s\n%s\n%s\n' "$BEGIN" "$BLOCK" "$END" >> "$tmp"
    mv "$tmp" "$RC_FILE"
    log "Updated managed block in $RC_FILE ($SH)"
  else
    cp "$RC_FILE" "${RC_FILE}.bak.$(date +%Y%m%d%H%M%S)"
    printf '\n%s\n%s\n%s\n' "$BEGIN" "$BLOCK" "$END" >> "$RC_FILE"
    log "Added managed block to $RC_FILE ($SH, backup made)"
  fi
}

# ---------------------------------------------------------------------------
# 2. GitHub CLI (gh)
# ---------------------------------------------------------------------------
install_gh() {
  if have gh; then
    log "gh already installed: $(gh --version | head -1)"
    return 0
  fi

  log "Installing GitHub CLI (gh)..."
  if have brew; then
    brew install gh
  elif have apt-get; then
    $SUDO apt-get update -qq
    $SUDO apt-get install -y -qq curl ca-certificates gnupg >/dev/null
    $SUDO mkdir -p -m 755 /etc/apt/keyrings
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      | $SUDO tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
    $SUDO chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      | $SUDO tee /etc/apt/sources.list.d/github-cli.list >/dev/null
    $SUDO apt-get update -qq
    $SUDO apt-get install -y -qq gh
  elif have dnf; then
    $SUDO dnf install -y gh
  elif have yum; then
    $SUDO yum install -y gh
  else
    warn "No supported package manager for gh — install manually: https://cli.github.com/"
    return 1
  fi
  log "gh installed: $(gh --version | head -1)"
}

# ---------------------------------------------------------------------------
# 3. Claude Code CLI
# ---------------------------------------------------------------------------
install_claude() {
  export PATH="$HOME/.local/bin:$HOME/.claude/bin:$PATH"
  if have claude; then
    log "claude already installed: $(claude --version 2>/dev/null || echo present)"
    return 0
  fi
  log "Installing Claude Code CLI..."
  curl -fsSL https://claude.ai/install.sh | bash
  export PATH="$HOME/.local/bin:$HOME/.claude/bin:$PATH"
  if have claude; then
    log "claude installed: $(claude --version 2>/dev/null || echo ok)"
  else
    warn "claude binary not on PATH yet — open a new shell or: source ~/.bashrc"
  fi
}

# ---------------------------------------------------------------------------
# 4. Hugging Face CLI (hf)
# ---------------------------------------------------------------------------
install_hf() {
  export PATH="$HOME/.local/bin:$PATH"
  if have hf; then
    log "hf already installed: $(hf version 2>/dev/null || hf --version 2>/dev/null || echo present)"
    return 0
  fi
  log "Installing Hugging Face CLI (hf)..."
  curl -LsSf https://hf.co/cli/install.sh | bash
  export PATH="$HOME/.local/bin:$PATH"
  if have hf; then
    log "hf installed: $(hf version 2>/dev/null || echo ok)"
  else
    warn "hf binary not on PATH yet — open a new shell or: source ~/.bashrc"
  fi
}

# ---------------------------------------------------------------------------
# 5. gpustat
# ---------------------------------------------------------------------------
install_gpustat() {
  if have gpustat; then
    log "gpustat already installed: $(gpustat --version 2>/dev/null || echo present)"
    return 0
  fi

  log "Installing gpustat..."
  if have pip3; then
    pip3 install --user -q gpustat
  elif have pip; then
    pip install --user -q gpustat
  elif have python3; then
    python3 -m pip install --user -q gpustat
  elif have brew; then
    brew install gpustat || brew install pipx && pipx install gpustat
  else
    warn "No pip found — install Python/pip, then: pip install gpustat"
    return 1
  fi

  export PATH="$HOME/.local/bin:$PATH"
  if have gpustat; then
    log "gpustat installed: $(gpustat --version 2>/dev/null || echo ok)"
  else
    warn "gpustat installed but not on PATH — ensure ~/.local/bin is on PATH"
  fi
}

# ---------------------------------------------------------------------------
main() {
  log "Nityanand VM setup starting..."
  install_bashrc
  install_gh || true
  install_claude || true
  install_hf || true
  install_gpustat || true

  echo
  log "Done."
  echo "  source ~/.bashrc   # or ~/.zshrc — pick up aliases + PATH"
  echo "  gh auth login"
  echo "  claude             # first run authenticates"
  echo "  hf auth login"
}

main "$@"
