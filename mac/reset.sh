#!/usr/bin/env bash
#
# TADA Backend - macOS Reset Script
# Removes everything installed by mac/setup.sh so you can start fresh.
# Run: /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/easi6dev/public-start-here/main/mac/reset.sh)"
#

set -uo pipefail

step()  { printf '\n\033[36m==> %s\033[0m\n' "$1"; }
ok()    { printf '    \033[32m[OK]\033[0m %s\n' "$1"; }
skip()  { printf '    \033[33m[SKIP]\033[0m %s\n' "$1"; }
warn()  { printf '    \033[33m[WARN]\033[0m %s\n' "$1"; }
info()  { printf '    %s\n' "$1"; }

command_exists() { command -v "$1" &>/dev/null; }

if [ "$(uname -s)" != "Darwin" ]; then warn "macOS only."; exit 1; fi
if [ "$(id -u)" = "0" ]; then warn "Do NOT run as root."; exit 1; fi

# --- Confirm ---
printf '\n\033[31m============================================\033[0m\n'
printf '\033[31m  TADA Backend (macOS) - FULL RESET\033[0m\n'
printf '\033[31m============================================\033[0m\n\n'
cat <<'WHAT'
This will remove:
  - All Homebrew cask GUI apps and CLI tools installed by setup.sh
  - DB/MQ services (PostgreSQL, MongoDB, Redis, RabbitMQ, ActiveMQ) — stopped & uninstalled
  - Claude Code + ccstatusline config (statusLine key, ~/.config/ccstatusline)
  - CLAUDE.md team-defaults block (your own content is kept)
  - fork/zoxide/nvm shell snippets from ~/.zshrc / ~/.bashrc / ~/.zprofile
  - git global config (autocrlf, delta pager)
  - host.docker.internal line from /etc/hosts

It does NOT remove: Homebrew itself, oh-my-zsh, ~/backend repos (delete manually if desired).
WHAT
read -r -p "Press Enter to continue, or Ctrl+C to cancel: " _

if ! command_exists brew; then warn "Homebrew not found — most steps will be skipped."; fi

# --- Stop & uninstall services ---
step "Stopping and removing services"
for svc in postgresql@16 mongodb-community@8.0 redis rabbitmq activemq; do
    brew services stop "$svc" 2>/dev/null || true
done
for f in postgresql@16 postgis mongodb-community@8.0 redis rabbitmq activemq; do
    if brew list --formula "$f" &>/dev/null; then brew uninstall --force "$f" 2>/dev/null && ok "$f removed" || warn "could not remove $f"; else skip "$f not installed"; fi
done

# --- Uninstall CLI formulae ---
step "Removing CLI tools"
CLI_FORMULAE=(git openjdk@21 gh jq awscli uv ripgrep fd fzf bat zoxide git-delta eza sd ktlint)
for f in "${CLI_FORMULAE[@]}"; do
    if brew list --formula "$f" &>/dev/null; then brew uninstall --force "$f" 2>/dev/null && ok "$f removed" || warn "could not remove $f"; else skip "$f not installed"; fi
done

# --- Uninstall GUI casks ---
step "Removing GUI applications"
GUI_CASKS=(intellij-idea datagrip jetbrains-toolbox fork docker-desktop claude slack figma google-chrome postman mongodb-compass android-studio 1password cloudflare-warp)
for c in "${GUI_CASKS[@]}"; do
    if brew list --cask "$c" &>/dev/null; then brew uninstall --cask --force "$c" 2>/dev/null && ok "$c removed" || warn "could not remove $c"; else skip "$c not installed"; fi
done

# --- Claude Code ---
step "Removing Claude Code"
if command_exists claude; then claude /uninstall 2>/dev/null || rm -f "$HOME/.local/bin/claude"; ok "Claude Code uninstalled"; else skip "Claude Code not found"; fi

# --- ccstatusline config + statusLine key ---
step "Removing ccstatusline config"
[ -d "$HOME/.config/ccstatusline" ] && rm -rf "$HOME/.config/ccstatusline" && ok "ccstatusline config removed" || skip "ccstatusline config not found"
SL="$HOME/.claude/settings.json"
if [ -f "$SL" ] && command_exists jq; then
    T=$(mktemp); if jq 'del(.statusLine)' "$SL" > "$T" 2>/dev/null; then mv "$T" "$SL"; ok "statusLine key removed from settings.json"; else rm -f "$T"; fi
fi

# --- CLAUDE.md team-defaults block (keep user content) ---
step "Removing CLAUDE.md team-defaults block"
CM="$HOME/.claude/CLAUDE.md"
if [ -f "$CM" ]; then
    sed -i '' '/<!-- TADA-TEAM-DEFAULTS:START/,/TADA-TEAM-DEFAULTS:END -->/d' "$CM" && ok "team-defaults block removed (your content kept)"
else skip "CLAUDE.md not found"; fi

# --- Shell snippets ---
step "Removing fork/zoxide/nvm shell snippets"
rm -f "$HOME/.fork.sh" && ok "removed ~/.fork.sh" || true
for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
    [ -f "$rc" ] || continue
    sed -i '' -e '/# Fork CLI launcher/d' -e '/\.fork\.sh/d' \
              -e '/# zoxide (smart cd)/d' -e '/zoxide init zsh/d' "$rc" 2>/dev/null || true
done
ok "fork/zoxide snippets stripped from rc files"
info "nvm / Homebrew shellenv lines left in ~/.zshrc / ~/.zprofile (remove by hand if you also uninstall them)"

# --- git config ---
step "Removing git delta/autocrlf config"
for k in core.pager interactive.diffFilter delta.navigate delta.line-numbers alias.rawdiff core.autocrlf; do
    git config --global --unset "$k" 2>/dev/null || true
done
ok "git pager/autocrlf config removed"

# --- /etc/hosts ---
step "Removing host.docker.internal from /etc/hosts"
if grep -qE '^\s*127\.0\.0\.1\s+host\.docker\.internal\s*$' /etc/hosts 2>/dev/null; then
    sudo sed -i '' '/^[[:space:]]*127\.0\.0\.1[[:space:]]\{1,\}host\.docker\.internal[[:space:]]*$/d' /etc/hosts 2>/dev/null \
        && ok "host.docker.internal line removed" || warn "could not edit /etc/hosts"
else skip "no host.docker.internal line"; fi

step "Reset complete!"
info "Homebrew, oh-my-zsh, and ~/backend repos were left in place — remove manually if you want a bare machine."
