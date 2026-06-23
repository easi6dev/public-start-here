#!/usr/bin/env bash
#
# TADA Backend - macOS Setup Script
# Run: /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/easi6dev/public-start-here/main/mac/setup.sh)"
#
# macOS port of the Windows setup.ps1 + setup-wsl.sh pair. On macOS there is no WSL:
# the GUI apps, CLI tools, AND the DB/MQ services all run natively, so everything that
# Windows split across "Phase 1 (Windows)" and "Phase 2 (WSL)" collapses into this one
# Homebrew-based script. Idempotent: re-running skips anything already in place.
#

set -uo pipefail   # NOTE: no -e — like the originals, we want a failed step to warn and continue.

# --- Version banner (bump on every change; lets you tell a cached run from the latest) ---
SETUP_VERSION="2026-06-23.1"

# --- Helpers ---

step()  { printf '\n\033[36m==> %s\033[0m\n' "$1"; }
ok()    { printf '    \033[32m[OK]\033[0m %s\n' "$1"; }
skip()  { printf '    \033[33m[SKIP]\033[0m %s\n' "$1"; }
warn()  { printf '    \033[33m[WARN]\033[0m %s\n' "$1"; }
info()  { printf '    %s\n' "$1"; }

command_exists() { command -v "$1" &>/dev/null; }

printf '\033[36mTADA mac/setup.sh  version %s\033[0m\n' "$SETUP_VERSION"

# --- Guard: macOS only, and NOT root (Homebrew refuses to run as root) ---

if [ "$(uname -s)" != "Darwin" ]; then
    warn "This script is for macOS. For Windows use setup.ps1; inside WSL use setup-wsl.sh."
    exit 1
fi
if [ "$(id -u)" = "0" ]; then
    warn "Do NOT run this as root / with sudo. Homebrew refuses root. Re-run as your normal user."
    exit 1
fi

ARCH="$(uname -m)"   # arm64 (Apple Silicon) or x86_64 (Intel)

# --- Keep the machine awake for the duration (no sleep/display-off mid-install) ---
# caffeinate -dimsu holds display+system awake; -w ties it to THIS script's PID so it
# auto-releases when the script exits (success, failure, or Ctrl-C). Best-effort.
caffeinate -dimsu -w "$$" &>/dev/null &

# --- Xcode Command Line Tools (git, clang, etc. — Homebrew needs them) ---

step "Checking Xcode Command Line Tools"
if xcode-select -p &>/dev/null; then
    skip "Xcode Command Line Tools already installed"
else
    info "Triggering Xcode Command Line Tools install (a GUI dialog will appear) ..."
    xcode-select --install &>/dev/null || true
    warn "Finish the Command Line Tools install in the dialog, then re-run this script."
    warn "Waiting for the install to complete before continuing ..."
    until xcode-select -p &>/dev/null; do sleep 10; done
    ok "Xcode Command Line Tools installed"
fi

# --- Homebrew ---

step "Installing Homebrew"
if command_exists brew; then
    skip "Homebrew already installed"
else
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    ok "Homebrew installed"
fi

# Put brew on PATH for THIS session (the shellenv line is persisted into .zprofile below).
# Apple Silicon: /opt/homebrew ; Intel: /usr/local
if [ -x /opt/homebrew/bin/brew ]; then
    BREW_PREFIX="/opt/homebrew"
elif [ -x /usr/local/bin/brew ]; then
    BREW_PREFIX="/usr/local"
else
    warn "brew not found after install — aborting."
    exit 1
fi
eval "$("$BREW_PREFIX/bin/brew" shellenv)"

# Persist brew shellenv into ~/.zprofile (macOS default login shell is zsh)
if ! grep -q "brew shellenv" "$HOME/.zprofile" 2>/dev/null; then
    printf '\n# Homebrew\neval "$(%s/bin/brew shellenv)"\n' "$BREW_PREFIX" >> "$HOME/.zprofile"
    ok "Homebrew shellenv added to ~/.zprofile"
fi

export HOMEBREW_NO_AUTO_UPDATE=1   # speed up the many install calls below

# Helper: install a cask app (GUI), skipping if already present
install_cask() {
    local id="$1" name="$2"
    if brew list --cask "$id" &>/dev/null; then
        skip "$name already installed"
    else
        info "Installing $name ..."
        if brew install --cask "$id"; then ok "$name installed"; else warn "$name install may have failed"; fi
    fi
}

# Helper: install a formula (CLI), skipping if already present
install_formula() {
    local id="$1" name="$2"
    if brew list --formula "$id" &>/dev/null; then
        skip "$name already installed"
    else
        info "Installing $name ..."
        if brew install "$id"; then ok "$name installed"; else warn "$name install may have failed"; fi
    fi
}

# --- GUI applications (brew cask) ---

step "Installing GUI applications via Homebrew Cask"

# id|Name   (cask token = macOS equivalent of the Windows winget id)
GUI_APPS=(
    "intellij-idea|IntelliJ IDEA Ultimate"
    "datagrip|DataGrip"
    "jetbrains-toolbox|JetBrains Toolbox"
    "fork|Fork"
    "docker-desktop|Docker Desktop"
    "claude|Claude"
    "slack|Slack"
    "figma|Figma"
    "google-chrome|Google Chrome"
    "postman|Postman"
    "mongodb-compass|MongoDB Compass"
    "android-studio|Android Studio"
    "1password|1Password"
    "cloudflare-warp|Cloudflare WARP"
)
for entry in "${GUI_APPS[@]}"; do
    install_cask "${entry%%|*}" "${entry#*|}"
done

# NOTE: PowerToys has no macOS equivalent and is intentionally omitted. macOS covers its
# main features natively (Spotlight/Raycast for PowerToys Run, Rectangle/built-in tiling
# for FancyZones, Digital Color Meter for Color Picker).

# --- CLI tools (brew formulae) ---

step "Installing CLI tools via Homebrew"

# Node is installed via nvm (below), Python via uv (below) — matching setup-wsl.sh.
# PowerShell 7 is omitted (Windows-only need); install with `brew install --cask powershell` if you want it.
CLI_FORMULAE=(
    "git|Git"
    "openjdk@21|OpenJDK 21"
    "gh|GitHub CLI"
    "jq|jq"
    "awscli|AWS CLI"
    "uv|uv"
    "ripgrep|ripgrep (rg)"
    "fd|fd"
    "fzf|fzf"
    "bat|bat"
    "zoxide|zoxide"
    "git-delta|delta"
    "eza|eza"
    "sd|sd"
    "ktlint|ktlint"
)
for entry in "${CLI_FORMULAE[@]}"; do
    install_formula "${entry%%|*}" "${entry#*|}"
done

# openjdk@21 is keg-only; symlink it so `java` is on PATH and tools can find JAVA_HOME.
if brew list --formula openjdk@21 &>/dev/null; then
    sudo ln -sfn "$BREW_PREFIX/opt/openjdk@21/libexec/openjdk.jdk" \
        "/Library/Java/JavaVirtualMachines/openjdk-21.jdk" 2>/dev/null \
        && ok "OpenJDK 21 linked into /Library/Java/JavaVirtualMachines" \
        || warn "Could not link OpenJDK 21 system-wide (run the ln -sfn manually if needed)"
fi

# --- Database / message services (native via brew, NO WSL) ---

step "Installing database & message services"

install_formula "postgresql@16" "PostgreSQL 16"
install_formula "postgis" "PostGIS"
install_formula "redis" "Redis"
install_formula "rabbitmq" "RabbitMQ"
install_formula "activemq" "ActiveMQ"

# MongoDB lives in a tap
if brew list --formula mongodb-community@8.0 &>/dev/null; then
    skip "MongoDB 8.0 already installed"
else
    brew tap mongodb/brew 2>/dev/null || true
    info "Installing MongoDB 8.0 ..."
    if brew install mongodb-community@8.0; then ok "MongoDB 8.0 installed"; else warn "MongoDB install may have failed"; fi
fi

# --- Start services (brew services) ---

step "Starting services"
brew services start postgresql@16 2>/dev/null && ok "PostgreSQL started" || warn "PostgreSQL start failed"
brew services start mongodb-community@8.0 2>/dev/null && ok "MongoDB started" || warn "MongoDB start failed"
brew services start redis 2>/dev/null && ok "Redis started" || warn "Redis start failed"
brew services start rabbitmq 2>/dev/null && ok "RabbitMQ started" || warn "RabbitMQ start failed"
brew services start activemq 2>/dev/null && ok "ActiveMQ started" || warn "ActiveMQ start failed"

# Give PostgreSQL a moment to accept connections before configuring it
sleep 3

# --- PostgreSQL setup (admin superuser + trust auth on localhost) ---
# Mirrors setup-wsl.sh: create an 'admin' superuser and switch local/loopback auth to trust
# so backend services connect without a password in dev. brew runs postgres as the current
# macOS user (not a 'postgres' OS user), so we connect to the default 'postgres' db as $USER.

step "Configuring PostgreSQL 16"

PSQL="$BREW_PREFIX/opt/postgresql@16/bin/psql"
[ -x "$PSQL" ] || PSQL="psql"

if "$PSQL" -d postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='admin'" 2>/dev/null | grep -q 1; then
    skip "PostgreSQL admin user already exists"
else
    if "$PSQL" -d postgres -c "CREATE ROLE admin SUPERUSER LOGIN" 2>/dev/null; then
        ok "PostgreSQL admin superuser created"
    else
        warn "Could not create admin role — is PostgreSQL running? (brew services list)"
    fi
fi

PG_HBA="$BREW_PREFIX/var/postgresql@16/pg_hba.conf"
if [ -f "$PG_HBA" ]; then
    if grep -qE '^\s*host\s+all\s+all\s+127\.0\.0\.1/32\s+trust' "$PG_HBA"; then
        skip "pg_hba.conf already set to trust on 127.0.0.1"
    else
        cp "$PG_HBA" "$PG_HBA.bak.$(date +%s 2>/dev/null || echo bak)" 2>/dev/null || true
        # Loopback (IPv4 + IPv6) -> trust
        sed -i '' -E 's#^([[:space:]]*host[[:space:]]+all[[:space:]]+all[[:space:]]+127\.0\.0\.1/32[[:space:]]+).*#\1trust#' "$PG_HBA" 2>/dev/null || true
        sed -i '' -E 's#^([[:space:]]*host[[:space:]]+all[[:space:]]+all[[:space:]]+::1/128[[:space:]]+).*#\1trust#' "$PG_HBA" 2>/dev/null || true
        brew services restart postgresql@16 2>/dev/null || true
        ok "pg_hba.conf set to trust on loopback and PostgreSQL restarted"
    fi
else
    warn "pg_hba.conf not found at $PG_HBA — configure trust auth manually"
fi

# --- RabbitMQ: delayed message exchange plugin + management UI ---

step "Configuring RabbitMQ"

if command_exists rabbitmq-plugins; then
    PLUGIN_DIR="$BREW_PREFIX/opt/rabbitmq/plugins"
    if ls "$PLUGIN_DIR"/rabbitmq_delayed_message_exchange-*.ez &>/dev/null; then
        skip "Delayed message exchange plugin already installed"
    elif [ -d "$PLUGIN_DIR" ]; then
        RMQ_VER="$(rabbitmqctl version 2>/dev/null | head -1)"
        RMQ_MINOR="${RMQ_VER%.*}"
        PLUGIN_VER=""
        if command_exists jq; then
            PLUGIN_VER=$(curl -sL "https://api.github.com/repos/rabbitmq/rabbitmq-delayed-message-exchange/releases" \
                | jq -r --arg ver "$RMQ_MINOR" '[.[] | select(.tag_name | startswith("v" + $ver)) | .tag_name][0] // empty' \
                | sed 's/^v//')
        fi
        [ -z "$PLUGIN_VER" ] && PLUGIN_VER="4.0.2" && warn "Could not detect plugin version, using fallback $PLUGIN_VER"
        if curl -sL -o "/tmp/rmq_delayed-${PLUGIN_VER}.ez" \
            "https://github.com/rabbitmq/rabbitmq-delayed-message-exchange/releases/download/v${PLUGIN_VER}/rabbitmq_delayed_message_exchange-${PLUGIN_VER}.ez"; then
            cp "/tmp/rmq_delayed-${PLUGIN_VER}.ez" "$PLUGIN_DIR/" && rm -f "/tmp/rmq_delayed-${PLUGIN_VER}.ez"
            ok "Delayed message exchange plugin $PLUGIN_VER installed"
        else
            warn "Could not download delayed message exchange plugin"
        fi
    else
        warn "RabbitMQ plugin dir not found ($PLUGIN_DIR) — skipping plugin"
    fi
    rabbitmq-plugins enable rabbitmq_delayed_message_exchange 2>/dev/null || true
    rabbitmq-plugins enable rabbitmq_management 2>/dev/null || true
    brew services restart rabbitmq 2>/dev/null || true
    ok "RabbitMQ plugins enabled (delayed exchange + management UI)"
else
    warn "rabbitmq-plugins not on PATH — skipped plugin config"
fi

# --- nvm + Node.js LTS ---

step "Installing nvm and Node.js LTS"
export NVM_DIR="$HOME/.nvm"
if [ -s "$NVM_DIR/nvm.sh" ]; then
    skip "nvm already installed"
else
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
    ok "nvm installed"
fi
# shellcheck disable=SC1090
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

if command_exists node; then
    skip "Node.js already installed ($(node --version))"
else
    nvm install --lts && nvm use --lts && ok "Node.js LTS installed ($(node --version))"
fi

# --- Python via uv ---

step "Installing Python via uv"
if command_exists uv; then
    if uv python list --only-installed 2>/dev/null | grep -q "3.12"; then
        skip "Python 3.12 already installed via uv"
    else
        uv python install 3.12 && ok "Python 3.12 installed via uv"
    fi
else
    warn "uv not found — install Python manually"
fi

# --- Claude Code (native install) ---

step "Installing Claude Code"
export PATH="$HOME/.local/bin:$PATH"
if command_exists claude; then
    skip "Claude Code already installed"
else
    curl -fsSL https://claude.ai/install.sh | bash
    ok "Claude Code installed"
fi

# --- ccstatusline (statusLine renderer; npm global, pinned) ---

step "Installing ccstatusline (npm global, pinned)"
CCS_VERSION="2.2.21"
if command_exists npm; then
    if npm list -g ccstatusline 2>/dev/null | grep -q "ccstatusline@$CCS_VERSION"; then
        skip "ccstatusline@$CCS_VERSION already installed"
    elif npm install -g "ccstatusline@$CCS_VERSION" >/dev/null 2>&1; then
        ok "ccstatusline@$CCS_VERSION installed"
    else
        warn "ccstatusline install failed — run 'npm install -g ccstatusline@$CCS_VERSION' manually"
    fi
else
    warn "npm not found — skipping ccstatusline (re-run after nvm sets up Node)"
fi

# ccstatusline reads <home>/.config/ccstatusline/settings.json on every platform.
# On macOS this machine IS the source of truth (no Windows to symlink to).
step "Configuring ccstatusline config"
mkdir -p "$HOME/.config/ccstatusline"
CCS_CONFIG="$HOME/.config/ccstatusline/settings.json"
if [ -f "$CCS_CONFIG" ]; then
    skip "ccstatusline settings.json already exists (leaving as-is)"
else
    cat > "$CCS_CONFIG" <<'SLEOF'
{
  "version": 3,
  "lines": [
    [
      { "id": "5", "type": "git-branch", "color": "magenta", "metadata": { "hideNoGit": "false", "linkToRepo": "true" } },
      { "id": "2", "type": "separator" },
      { "id": "7", "type": "git-changes", "color": "yellow" },
      { "id": "4", "type": "separator" },
      { "id": "3", "type": "context-percentage", "color": "brightWhite", "metadata": { "display": "slider", "inverse": "false" } },
      { "id": "6", "type": "separator" },
      { "id": "1", "type": "model", "color": "white", "rawValue": true },
      { "id": "3d6fd313-5c1d-4325-a07b-b7641f508e39", "type": "separator" },
      { "id": "6b910852-e5e2-4122-9ec1-5b4075c0d3a4", "type": "thinking-effort", "color": "white", "rawValue": true },
      { "id": "53ea675f-f197-4276-a796-cccc5e1e314a", "type": "separator" },
      { "id": "6b88f7b2-200d-432c-aa86-48f0e71eaffa", "type": "version", "rawValue": false }
    ],
    [
      { "id": "f3867b87-675a-4850-814b-41d0a86866a3", "type": "current-working-dir", "rawValue": true, "metadata": { "fishStyle": "true" } },
      { "id": "277277f5-c646-4e0b-9d1e-f71f0f52032d", "type": "separator" },
      { "id": "d4173979-e3a0-4d05-8018-003a6d43fe2a", "type": "claude-account-email" }
    ],
    [
      { "id": "26a6ec7a-8106-4acc-b6ff-0de7d753f448", "type": "session-usage", "rawValue": false, "metadata": { "display": "slider" } },
      { "id": "60591cec-b59d-468e-8b71-056e02fba825", "type": "separator" },
      { "id": "8bc27bf1-cb4e-4a61-b69a-29e5722f9d1c", "type": "weekly-usage", "metadata": { "display": "slider" } }
    ]
  ],
  "flexMode": "full",
  "compactThreshold": 60,
  "colorLevel": 2,
  "inheritSeparatorColors": false,
  "globalBold": false,
  "gitCacheTtlSeconds": 5,
  "minimalistMode": false,
  "powerline": { "enabled": false, "separators": [""], "separatorInvertBackground": [false], "startCaps": [], "endCaps": [], "autoAlign": false, "continueThemeAcrossLines": false },
  "installation": { "method": "pinned", "installedVersion": "2.2.21" }
}
SLEOF
    ok "ccstatusline settings.json written"
fi

# Merge statusLine into ~/.claude/settings.json. Node comes from nvm, which Claude Code's
# minimal command PATH won't have, so wrap in a login shell so nvm is sourced first.
mkdir -p "$HOME/.claude"
SL_SETTINGS="$HOME/.claude/settings.json"
SL_CMD="zsh -lc 'ccstatusline'"
if command_exists jq; then
    CUR_SL=$(jq -r '.statusLine.command // empty' "$SL_SETTINGS" 2>/dev/null || true)
    if [ "$CUR_SL" = "$SL_CMD" ]; then
        skip "statusLine already configured in settings.json"
    elif [ -f "$SL_SETTINGS" ]; then
        SL_TMP=$(mktemp)
        if jq --arg cmd "$SL_CMD" '.statusLine = {type:"command", command:$cmd, padding:0, refreshInterval:10}' "$SL_SETTINGS" > "$SL_TMP" 2>/dev/null; then
            mv "$SL_TMP" "$SL_SETTINGS"; ok "statusLine merged into settings.json"
        else
            rm -f "$SL_TMP"; warn "settings.json is not valid JSON — add statusLine manually"
        fi
    else
        jq -n --arg cmd "$SL_CMD" '{statusLine:{type:"command", command:$cmd, padding:0, refreshInterval:10}}' > "$SL_SETTINGS"
        ok "settings.json created with statusLine"
    fi
else
    warn "jq not found — skipping statusLine settings merge"
fi

# --- Claude Code CLAUDE.md (team defaults, managed block) ---
# Marker-bounded so re-runs are idempotent and any user content outside the markers is kept.

step "Configuring Claude Code CLAUDE.md"
CLAUDE_MD="$HOME/.claude/CLAUDE.md"
MD_START="<!-- TADA-TEAM-DEFAULTS:START (managed by mac/setup.sh - do not edit inside) -->"
MD_END="<!-- TADA-TEAM-DEFAULTS:END -->"
MD_TMP_BODY=$(cat <<'MDEOF'
<MOST_IMPORTANT_RULE>
Behavioral guidelines to reduce common LLM coding mistakes, derived from Andrej Karpathy's observations on LLM coding pitfalls.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" -> "Write tests for invalid inputs, then make them pass"
- "Fix the bug" -> "Write a test that reproduces it, then make it pass"
- "Refactor X" -> "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] -> verify: [check]
2. [Step] -> verify: [check]
3. [Step] -> verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.
</MOST_IMPORTANT_RULE>

<TERMINOLOGY>
- **CO Region**: US Colorado State
- **Slack Workspace URL**: `https://mvllabs.slack.com/`
- **Jira URL**: `https://mvlchain.atlassian.net/`
</TERMINOLOGY>

<CLI_Tools>
- Use `rg` instead of `grep` for faster text searches
- Use `fd` instead of `find` for file lookups
- Use `bat` instead of `cat` for file viewing
- Use `eza` instead of `ls` for directory listing
- Use `sd` instead of `sed` for text replacement
- Use `delta` for git diff viewing
- Use `fzf` for interactive fuzzy finding
- Use `zoxide` (`z`) instead of `cd` for directory navigation
</CLI_Tools>
MDEOF
)
MANAGED_BLOCK="$MD_START
$MD_TMP_BODY
$MD_END"

EXISTING_MD=""
[ -f "$CLAUDE_MD" ] && EXISTING_MD="$(cat "$CLAUDE_MD")"
# Strip any prior managed block, then append exactly one fresh block.
CLEANED_MD="$(printf '%s' "$EXISTING_MD" | sed '/<!-- TADA-TEAM-DEFAULTS:START/,/TADA-TEAM-DEFAULTS:END -->/d')"
CLEANED_MD="$(printf '%s' "$CLEANED_MD" | sed -e :a -e '/^\n*$/{$d;N;ba}' 2>/dev/null || printf '%s' "$CLEANED_MD")"
if [ -n "$CLEANED_MD" ]; then
    printf '%s\n\n%s\n' "$CLEANED_MD" "$MANAGED_BLOCK" > "$CLAUDE_MD"
else
    printf '%s\n' "$MANAGED_BLOCK" > "$CLAUDE_MD"
fi
ok "Team defaults written to $CLAUDE_MD"

# --- git defaults ---

step "Configuring git defaults"
# macOS commits LF, checks out as-is (Unix default), matching setup-wsl.sh.
git config --global core.autocrlf input
ok "core.autocrlf=input"

if command_exists delta; then
    if [ "$(git config --global core.pager 2>/dev/null)" = "delta" ]; then
        skip "delta already configured as git pager"
    else
        git config --global core.pager "delta"
        git config --global interactive.diffFilter "delta --color-only"
        git config --global delta.navigate true
        git config --global delta.line-numbers true
        git config --global alias.rawdiff "--no-pager diff"
        ok "delta set as git diff pager (use 'git rawdiff' for plain format)"
    fi
else
    warn "delta not found on PATH — skipped git pager config"
fi

# --- zsh: oh-my-zsh + plugins + PATH/init (zsh is already the macOS default shell) ---

step "Setting up zsh + oh-my-zsh"
if [ -d "$HOME/.oh-my-zsh" ]; then
    skip "oh-my-zsh already installed"
else
    RUNZSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    ok "oh-my-zsh installed"
fi

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
if [ -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
    skip "zsh-autosuggestions already installed"
else
    git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions" 2>/dev/null && ok "zsh-autosuggestions installed"
fi
if [ -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
    skip "zsh-syntax-highlighting already installed"
else
    git clone https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" 2>/dev/null && ok "zsh-syntax-highlighting installed"
fi
if grep -q "^plugins=(git)$" "$HOME/.zshrc" 2>/dev/null; then
    sed -i '' 's/^plugins=(git)$/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/' "$HOME/.zshrc"
    ok "Plugins enabled in .zshrc"
fi

# nvm + Claude Code PATH + zoxide init in .zshrc (brew shellenv already in .zprofile)
if ! grep -q 'NVM_DIR' "$HOME/.zshrc" 2>/dev/null; then
    cat >> "$HOME/.zshrc" <<'ZSHPATH'

# nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Claude Code
export PATH="$HOME/.local/bin:$PATH"
ZSHPATH
    ok "nvm + Claude Code PATH added to .zshrc"
fi
if ! grep -q "zoxide init" "$HOME/.zshrc" 2>/dev/null; then
    printf '\n# zoxide (smart cd)\neval "$(zoxide init zsh)"\n' >> "$HOME/.zshrc"
    ok "zoxide init added to .zshrc"
fi

# --- Fork command-line launcher (macOS) ---
# `fork [path]` opens the Fork.app GUI at a directory (default: current). On macOS this is
# just `open -a Fork <dir>` — no path translation needed (unlike the WSL/Git Bash versions).

step "Configuring Fork command-line launcher"
FORK_SH="$HOME/.fork.sh"
cat > "$FORK_SH" <<'FORKEOF'
# Managed by mac/setup.sh — open Fork.app at a path (default: current dir). Do not edit.
fork() {
    local target="${1:-.}"
    local abs
    abs="$(cd "$target" 2>/dev/null && pwd)" || { echo "fork: no such directory: $1" >&2; return 1; }
    open -a Fork "$abs"
}
FORKEOF
ok "Wrote $FORK_SH"
for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
    if [ -f "$rc" ] && ! grep -q '\.fork\.sh' "$rc"; then
        printf '\n# Fork CLI launcher\n[ -f "$HOME/.fork.sh" ] && . "$HOME/.fork.sh"\n' >> "$rc"
        ok "Sourced .fork.sh from $(basename "$rc")"
    else
        skip ".fork.sh already sourced from $(basename "$rc")"
    fi
done

# --- macOS developer-friendly Finder settings ---
# Equivalents of the Windows Explorer tweaks in setup.ps1.

step "Configuring macOS Finder developer settings"
defaults write NSGlobalDomain AppleShowAllExtensions -bool true      # show all file extensions
defaults write com.apple.finder AppleShowAllFiles -bool true         # show hidden files (.git, .env)
defaults write com.apple.finder ShowPathbar -bool true               # path bar at bottom
defaults write com.apple.finder ShowStatusBar -bool true             # status bar
defaults write com.apple.finder _FXShowPosixPathInTitle -bool true   # full POSIX path in title
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"  # search current folder by default
killall Finder 2>/dev/null || true
ok "Finder set to show extensions, hidden files, path bar, and full path in title"

# --- /etc/hosts: host.docker.internal -> 127.0.0.1 ---
# Backend configs sometimes use host.docker.internal as the DB/MQ host. Native macOS services
# bind to 127.0.0.1, so map the name to loopback (idempotent). Needs sudo to edit /etc/hosts.

step "Configuring /etc/hosts (host.docker.internal -> 127.0.0.1)"
if grep -qE '^\s*127\.0\.0\.1\s+host\.docker\.internal\s*$' /etc/hosts 2>/dev/null; then
    skip "host.docker.internal already mapped to 127.0.0.1"
else
    if printf '127.0.0.1 host.docker.internal\n' | sudo tee -a /etc/hosts >/dev/null 2>&1; then
        sudo dscacheutil -flushcache 2>/dev/null || true
        sudo killall -HUP mDNSResponder 2>/dev/null || true
        ok "host.docker.internal mapped to 127.0.0.1 (DNS cache flushed)"
    else
        warn "Could not edit /etc/hosts — add manually: 127.0.0.1 host.docker.internal"
    fi
fi

# --- GitHub auth + git identity + clone backend repos ---

step "GitHub authentication and git identity"
export PATH="$BREW_PREFIX/bin:$PATH"
if ! command_exists gh; then
    warn "GitHub CLI not found — skipping auth/clone. Install gh and re-run."
else
    if gh auth status &>/dev/null; then
        ok "GitHub already authenticated"
    else
        info "A browser will open to authenticate with GitHub ..."
        gh auth login --hostname github.com --git-protocol https --web || warn "gh auth login did not complete"
    fi

    if gh auth status &>/dev/null; then
        gh auth setup-git 2>/dev/null && ok "git uses GitHub CLI for github.com credentials" || true

        # git identity (prefill from the authenticated account; press Enter to accept)
        GIT_NAME="$(git config --global user.name 2>/dev/null || true)"
        GIT_EMAIL="$(git config --global user.email 2>/dev/null || true)"
        if [ -n "$GIT_NAME" ] && [ -n "$GIT_EMAIL" ]; then
            skip "git identity already set (name='$GIT_NAME', email='$GIT_EMAIL')"
        else
            GH_NAME="$(gh api user --jq '.name // .login' 2>/dev/null || true)"
            GH_EMAIL="$(gh api user --jq '.email // empty' 2>/dev/null || true)"
            info "Tip: use a non-Korean (English / romanized) name for the git author."
            read -r -p "    git user.name [${GH_NAME}]: " IN_NAME;  IN_NAME="${IN_NAME:-$GH_NAME}"
            read -r -p "    git user.email [${GH_EMAIL}]: " IN_EMAIL; IN_EMAIL="${IN_EMAIL:-$GH_EMAIL}"
            [ -n "$IN_NAME" ]  && git config --global user.name  "$IN_NAME"
            [ -n "$IN_EMAIL" ] && git config --global user.email "$IN_EMAIL"
            ok "git identity set (name='$IN_NAME', email='$IN_EMAIL')"
        fi

        # Clone backend repos via the team clone script in the private repo.
        # The Windows flow runs teams/server/clone-repos.ps1; on macOS we prefer a .sh variant
        # if the team publishes one, else fall back to the PowerShell script via `pwsh`.
        step "Cloning backend repositories"
        if gh api "repos/easi6dev/start-here/contents/teams/server/clone-repos.sh" --jq '.content' >/tmp/clone-repos.b64 2>/dev/null; then
            base64 --decode -i /tmp/clone-repos.b64 > /tmp/clone-repos.sh 2>/dev/null || base64 -d /tmp/clone-repos.b64 > /tmp/clone-repos.sh
            rm -f /tmp/clone-repos.b64
            bash /tmp/clone-repos.sh && ok "Backend repos cloned" || warn "clone-repos.sh reported errors"
        else
            warn "No clone-repos.sh in easi6dev/start-here/teams/server — clone manually:"
            info "gh repo clone easi6dev/start-here && cd start-here/teams/server && (run the team clone script)"
        fi
    else
        warn "Not authenticated with GitHub — skipped clone. Run 'gh auth login' and re-run."
    fi
fi

# --- Done ---

step "Setup complete!"
cat <<'DONE'

  Service ports (native, all on localhost):
    - PostgreSQL 16  (localhost:5432)
    - MongoDB 8.0    (localhost:27017)
    - Redis           (localhost:6379)
    - RabbitMQ        (localhost:5672, management UI: http://localhost:15672)
    - ActiveMQ        (localhost:61616)

  Manage services with: brew services list | brew services restart <name>

  Things to do manually:
    1. Restart your terminal (or: source ~/.zshrc) so PATH / aliases take effect.
    2. Docker Desktop — open it once to finish first-run setup.
    3. Cloudflare WARP — configure with the team VPN settings:
         https://mvlchain.cloudflareaccess.com/#/Launcher
    4. IntelliJ IDEA — sign in to your JetBrains account, open a backend project to verify.
    5. Set GITHUB_USERNAME / GITHUB_TOKEN if your backend build needs them (PAT with repo + read:packages).
    6. Run 'aws configure' to set up AWS credentials.

DONE
