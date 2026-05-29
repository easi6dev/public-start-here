#!/usr/bin/env bash
#
# TADA Backend - WSL Setup Script (Phase 2)
# Installs DB services + CLI tools inside Ubuntu 24.04
# Called automatically by setup.ps1, or run manually: bash setup-wsl.sh
#

set -euo pipefail

# --- Helpers ---

step()  { echo -e "\n\033[36m==> $1\033[0m"; }
ok()    { echo -e "    \033[32m[OK]\033[0m $1"; }
skip()  { echo -e "    \033[33m[SKIP]\033[0m $1"; }
warn()  { echo -e "    \033[33m[WARN]\033[0m $1"; }

command_exists() { command -v "$1" &>/dev/null; }

# Helper: start/restart service with systemd or SysVinit fallback (WSL compat)
restart_service() {
    local svc="$1"
    sudo systemctl restart "$svc" 2>/dev/null || sudo service "$svc" restart 2>/dev/null || true
}

start_service() {
    local svc="$1"
    sudo systemctl enable --now "$svc" 2>/dev/null || sudo service "$svc" start 2>/dev/null || true
}

# --- APT repositories ---

step "Adding APT repositories"

# MongoDB 8.0
if [ ! -f /usr/share/keyrings/mongodb-server-8.0.gpg ]; then
    curl -fsSL https://www.mongodb.org/static/pgp/server-8.0.asc | \
        sudo gpg -o /usr/share/keyrings/mongodb-server-8.0.gpg --dearmor
    echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg ] https://repo.mongodb.org/apt/ubuntu noble/mongodb-org/8.0 multiverse" | \
        sudo tee /etc/apt/sources.list.d/mongodb-org-8.0.list > /dev/null
    ok "MongoDB 8.0 repo added"
else
    skip "MongoDB 8.0 repo already configured"
fi

# RabbitMQ + Erlang
if [ ! -f /usr/share/keyrings/com.rabbitmq.team.gpg ]; then
    sudo apt-get install -y curl gnupg apt-transport-https > /dev/null 2>&1

    curl -1sLf "https://keys.openpgp.org/vks/v1/by-fingerprint/0A9AF2115F4687BD29803A206B73A36E6026DFCA" | \
        sudo gpg --dearmor | sudo tee /usr/share/keyrings/com.rabbitmq.team.gpg > /dev/null
    curl -1sLf https://github.com/rabbitmq/signing-keys/releases/download/3.0/cloudsmith.rabbitmq-erlang.E495BB49CC4BBE5B.key | \
        sudo gpg --dearmor | sudo tee /usr/share/keyrings/rabbitmq.E495BB49CC4BBE5B.gpg > /dev/null
    curl -1sLf https://github.com/rabbitmq/signing-keys/releases/download/3.0/cloudsmith.rabbitmq-server.9F4587F226208342.key | \
        sudo gpg --dearmor | sudo tee /usr/share/keyrings/rabbitmq.9F4587F226208342.gpg > /dev/null

    sudo tee /etc/apt/sources.list.d/rabbitmq.list > /dev/null <<'RABBITEOF'
deb [arch=amd64 signed-by=/usr/share/keyrings/rabbitmq.E495BB49CC4BBE5B.gpg] https://ppa1.rabbitmq.com/rabbitmq/rabbitmq-erlang/deb/ubuntu noble main
deb-src [signed-by=/usr/share/keyrings/rabbitmq.E495BB49CC4BBE5B.gpg] https://ppa1.rabbitmq.com/rabbitmq/rabbitmq-erlang/deb/ubuntu noble main
deb [arch=amd64 signed-by=/usr/share/keyrings/rabbitmq.E495BB49CC4BBE5B.gpg] https://ppa2.rabbitmq.com/rabbitmq/rabbitmq-erlang/deb/ubuntu noble main
deb-src [signed-by=/usr/share/keyrings/rabbitmq.E495BB49CC4BBE5B.gpg] https://ppa2.rabbitmq.com/rabbitmq/rabbitmq-erlang/deb/ubuntu noble main
deb [arch=amd64 signed-by=/usr/share/keyrings/rabbitmq.9F4587F226208342.gpg] https://ppa1.rabbitmq.com/rabbitmq/rabbitmq-server/deb/ubuntu noble main
deb-src [signed-by=/usr/share/keyrings/rabbitmq.9F4587F226208342.gpg] https://ppa1.rabbitmq.com/rabbitmq/rabbitmq-server/deb/ubuntu noble main
deb [arch=amd64 signed-by=/usr/share/keyrings/rabbitmq.9F4587F226208342.gpg] https://ppa2.rabbitmq.com/rabbitmq/rabbitmq-server/deb/ubuntu noble main
deb-src [signed-by=/usr/share/keyrings/rabbitmq.9F4587F226208342.gpg] https://ppa2.rabbitmq.com/rabbitmq/rabbitmq-server/deb/ubuntu noble main
RABBITEOF
    ok "RabbitMQ + Erlang repos added"
else
    skip "RabbitMQ repos already configured"
fi

# --- APT install ---

step "Installing packages via apt"
sudo apt update -y

# Erlang
sudo apt install -y \
    erlang-base erlang-asn1 erlang-crypto erlang-eldap erlang-ftp erlang-inets \
    erlang-mnesia erlang-os-mon erlang-parsetools erlang-public-key \
    erlang-runtime-tools erlang-snmp erlang-ssl \
    erlang-syntax-tools erlang-tftp erlang-tools erlang-xmerl

# Services + utilities
sudo apt install -y --fix-missing \
    mongodb-org rabbitmq-server postgresql-16 postgresql-16-postgis-3 redis-server \
    unzip jq git openjdk-21-jdk build-essential zsh

ok "APT packages installed"

# --- Start PostgreSQL before configuring it ---

start_service postgresql

# --- PostgreSQL 16 setup ---

step "Configuring PostgreSQL 16"

# Create admin superuser
if sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='admin'" 2>/dev/null | grep -q 1; then
    skip "PostgreSQL admin user already exists"
else
    sudo -u postgres createuser -s admin
    ok "PostgreSQL admin superuser created"
fi

# Update pg_hba.conf for local trust access
PG_HBA="/etc/postgresql/16/main/pg_hba.conf"
if grep -q "^local.*admin.*trust" "$PG_HBA" 2>/dev/null; then
    skip "pg_hba.conf already configured for admin"
else
    sudo sed -i -E '/^local[[:space:]]+all[[:space:]]+postgres[[:space:]]+peer[[:space:]]*$/a local   all             admin                                   trust' "$PG_HBA"
    sudo sed -i -E 's/^host[[:space:]]+all[[:space:]]+all[[:space:]]+127\.0\.0\.1\/32[[:space:]]+scram-sha-256/host    all             all             127.0.0.1\/32            trust/' "$PG_HBA"
    restart_service postgresql
    ok "pg_hba.conf updated and PostgreSQL restarted"
fi

# --- RabbitMQ setup ---

step "Configuring RabbitMQ"

start_service rabbitmq-server

# Delayed message exchange plugin
RABBITMQ_PLUGIN_DIR="/usr/lib/rabbitmq/plugins"
if [ ! -d "$RABBITMQ_PLUGIN_DIR" ]; then
    RABBITMQ_PLUGIN_DIR=$(find /usr/lib/rabbitmq/lib -maxdepth 1 -name "rabbitmq_server-*" -type d 2>/dev/null | head -1)
    if [ -n "$RABBITMQ_PLUGIN_DIR" ]; then
        RABBITMQ_PLUGIN_DIR="$RABBITMQ_PLUGIN_DIR/plugins"
    fi
fi

if [ -n "$RABBITMQ_PLUGIN_DIR" ] && [ -d "$RABBITMQ_PLUGIN_DIR" ]; then
    if ! ls "$RABBITMQ_PLUGIN_DIR"/rabbitmq_delayed_message_exchange-*.ez &>/dev/null; then
        RABBITMQ_VER=$(sudo rabbitmqctl version 2>/dev/null | head -1)
        RABBITMQ_MINOR="${RABBITMQ_VER%.*}"
        RABBITMQ_MAJOR="${RABBITMQ_VER%%.*}"

        PLUGIN_VER=""
        if command_exists jq; then
            PLUGIN_VER=$(curl -sL "https://api.github.com/repos/rabbitmq/rabbitmq-delayed-message-exchange/releases" \
                | jq -r --arg ver "$RABBITMQ_MINOR" \
                    '[.[] | select(.tag_name | startswith("v" + $ver)) | .tag_name][0] // empty' \
                | sed 's/^v//')
            if [ -z "$PLUGIN_VER" ]; then
                PLUGIN_VER=$(curl -sL "https://api.github.com/repos/rabbitmq/rabbitmq-delayed-message-exchange/releases" \
                    | jq -r --arg ver "$RABBITMQ_MAJOR" \
                        '[.[] | select(.tag_name | startswith("v" + $ver)) | .tag_name][0] // empty' \
                    | sed 's/^v//')
            fi
        fi

        if [ -z "$PLUGIN_VER" ]; then
            PLUGIN_VER="4.0.2"
            warn "Could not detect compatible plugin version, using fallback $PLUGIN_VER"
        else
            ok "Detected RabbitMQ $RABBITMQ_VER, using plugin $PLUGIN_VER"
        fi

        curl -sL -o "/tmp/rabbitmq_delayed_message_exchange-${PLUGIN_VER}.ez" \
            "https://github.com/rabbitmq/rabbitmq-delayed-message-exchange/releases/download/v${PLUGIN_VER}/rabbitmq_delayed_message_exchange-${PLUGIN_VER}.ez"
        sudo cp "/tmp/rabbitmq_delayed_message_exchange-${PLUGIN_VER}.ez" "$RABBITMQ_PLUGIN_DIR/"
        rm "/tmp/rabbitmq_delayed_message_exchange-${PLUGIN_VER}.ez"
        ok "Delayed message exchange plugin $PLUGIN_VER installed"
    else
        skip "Delayed message exchange plugin already installed"
    fi
else
    warn "RabbitMQ plugin directory not found, skipping plugin install"
fi

sudo rabbitmq-plugins enable rabbitmq_delayed_message_exchange 2>/dev/null || true
sudo rabbitmq-plugins enable rabbitmq_management 2>/dev/null || true

# Bind to localhost only
if ! grep -q "listeners.tcp.1" /etc/rabbitmq/rabbitmq.conf 2>/dev/null; then
    sudo mkdir -p /etc/rabbitmq
    echo "listeners.tcp.1 = 127.0.0.1:5672" | sudo tee -a /etc/rabbitmq/rabbitmq.conf > /dev/null
    ok "RabbitMQ bound to 127.0.0.1:5672"
fi

restart_service rabbitmq-server
ok "RabbitMQ configured and restarted"

# --- AWS CLI ---

step "Installing AWS CLI"
if command_exists aws; then
    skip "AWS CLI already installed ($(aws --version 2>&1 | head -1))"
else
    curl -sL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
    unzip -qo /tmp/awscliv2.zip -d /tmp
    sudo /tmp/aws/install --update
    rm -rf /tmp/awscliv2.zip /tmp/aws
    ok "AWS CLI installed"
fi

# --- Homebrew ---

step "Installing Homebrew"
if command_exists brew; then
    skip "Homebrew already installed"
else
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    if ! grep -q "linuxbrew" ~/.bashrc 2>/dev/null; then
        echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> ~/.bashrc
    fi
    ok "Homebrew installed"
fi

# Force brew into PATH for current session (eval shellenv can be unreliable)
export HOMEBREW_PREFIX="/home/linuxbrew/.linuxbrew"
export HOMEBREW_CELLAR="$HOMEBREW_PREFIX/Cellar"
export HOMEBREW_REPOSITORY="$HOMEBREW_PREFIX/Homebrew"
export PATH="$HOMEBREW_PREFIX/bin:$HOMEBREW_PREFIX/sbin:$PATH"
export MANPATH="$HOMEBREW_PREFIX/share/man${MANPATH+:$MANPATH}:"
export INFOPATH="$HOMEBREW_PREFIX/share/info:${INFOPATH:-}"

if ! command_exists brew; then
    warn "brew not found in PATH after install — brew packages will be skipped"
else

    # --- Brew packages ---

    step "Installing CLI tools via brew"

    BREW_PACKAGES=(
        gh uv ktlint
        ripgrep fd fzf bat zoxide git-delta eza sd
    )

    for pkg in "${BREW_PACKAGES[@]}"; do
        if brew list "$pkg" &>/dev/null; then
            skip "$pkg"
        else
            brew install "$pkg" || warn "Failed to install $pkg"
        fi
    done

    # ActiveMQ (may not be available on Linux brew)
    if brew list activemq &>/dev/null; then
        skip "activemq"
    else
        if brew search --formula activemq 2>/dev/null | grep -q "^activemq$"; then
            brew install activemq || warn "Failed to install activemq"
        else
            warn "activemq formula not found in Homebrew — install manually"
        fi
    fi

fi

# --- nvm + Node.js ---

step "Installing nvm and Node.js LTS"
export NVM_DIR="$HOME/.nvm"
if [ -s "$NVM_DIR/nvm.sh" ]; then
    skip "nvm already installed"
else
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
    ok "nvm installed"
fi

# Load nvm for current session
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

if command_exists node; then
    skip "Node.js already installed ($(node --version))"
else
    nvm install --lts
    nvm use --lts
    ok "Node.js LTS installed ($(node --version))"
fi

# --- Python via uv ---

step "Installing Python via uv"
if command_exists brew && command_exists uv; then
    if uv python list --only-installed 2>/dev/null | grep -q "3.12"; then
        skip "Python 3.12 already installed via uv"
    else
        uv python install 3.12
        ok "Python 3.12 installed via uv"
    fi
else
    warn "uv not found — install Python manually"
fi

# --- Claude Code (native install) ---

step "Installing Claude Code"
if command_exists claude; then
    skip "Claude Code already installed"
else
    curl -fsSL https://claude.ai/install.sh | bash
    # Add ~/.local/bin to PATH if not already there
    if ! grep -q '\.local/bin' ~/.bashrc 2>/dev/null; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
    fi
    export PATH="$HOME/.local/bin:$PATH"
    ok "Claude Code installed"
fi

# --- Share gh auth from Windows via symlink ---

step "Sharing GitHub CLI auth from Windows"
WIN_USER=$(cmd.exe /C "echo %USERNAME%" 2>/dev/null | tr -d '\r')
WIN_GH_DIR="/mnt/c/Users/$WIN_USER/AppData/Roaming/GitHub CLI"

if [ -d "$WIN_GH_DIR" ]; then
    if [ -L "$HOME/.config/gh" ]; then
        skip "gh config already symlinked"
    else
        mkdir -p "$HOME/.config"
        rm -rf "$HOME/.config/gh" 2>/dev/null
        ln -sf "$WIN_GH_DIR" "$HOME/.config/gh"
        ok "gh auth shared from Windows (symlink)"
    fi
    if command_exists gh && gh auth status &>/dev/null; then
        ok "gh authenticated in WSL"
    else
        warn "gh symlink created but auth not detected — run 'gh auth login' in WSL if needed"
    fi
else
    warn "Windows gh config not found at $WIN_GH_DIR — run 'gh auth login' in Windows first"
fi

# --- Claude Code statusLine (shared with Windows via symlink) ---

step "Configuring Claude Code statusLine"

mkdir -p "$HOME/.claude"
SL_LINK="$HOME/.claude/statusline-command.sh"
WIN_SL="/mnt/c/Users/$WIN_USER/.claude/statusline-command.sh"

if [ -f "$WIN_SL" ]; then
    # Share the same file Windows uses (single source of truth). The script is cross-env:
    # the Windows-only PATH entries are harmless no-ops on WSL.
    if [ -L "$SL_LINK" ] && [ "$(readlink "$SL_LINK")" = "$WIN_SL" ]; then
        skip "statusline-command.sh already symlinked from Windows"
    else
        # Back up a pre-existing real file before replacing it with the symlink
        if [ -e "$SL_LINK" ] && [ ! -L "$SL_LINK" ]; then
            mv "$SL_LINK" "$SL_LINK.bak"
            ok "Backed up existing statusline-command.sh -> $SL_LINK.bak"
        fi
        ln -sfn "$WIN_SL" "$SL_LINK"
        ok "statusline-command.sh symlinked from Windows ($WIN_SL)"
    fi
else
    # Fallback: Windows file not present (e.g. running setup-wsl.sh standalone) — write a copy
    cat > "$SL_LINK" <<'SLEOF'
#!/bin/sh
# Make dependencies resolvable regardless of the spawn PATH. The Windows-only entries
# (/mingw64/bin, WinGet Links for jq) are harmless no-ops on WSL, where jq/git come from
# the normal Linux PATH.
export PATH="/usr/bin:/mingw64/bin:$HOME/AppData/Local/Microsoft/WinGet/Links:$PATH"
input=$(cat)
cwd=$(echo "$input" | jq -r '.cwd')
model=$(echo "$input" | jq -r '.model.display_name // empty')
ctx_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
effort=$(echo "$input" | jq -r '.effort.level // empty')
thinking=$(echo "$input" | jq -r '.thinking.enabled // false')

# Git branch: run against cwd so it works in any repo regardless of JSON fields
git_branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null)

# Shorten cwd to the last N path segments (change PATH_SEGMENTS to taste)
PATH_SEGMENTS=2
disp_cwd=$(printf '%s' "$cwd" | tr '\\' '/' | awk -F'/' -v n="$PATH_SEGMENTS" '{
  out=""; start=NF-n+1; if(start<1) start=1;
  for(i=start;i<=NF;i++){ if($i!=""){ out=(out=="")?$i:out"/"$i } }
  if(start>1) out=".../" out;
  print out
}')

# Base: user@host:cwd  (hostname without -s for portability)
short_host=$(hostname 2>/dev/null | cut -d. -f1)
printf '\033[01;32m%s@%s\033[00m:\033[01;34m%s\033[00m' "$(whoami)" "$short_host" "$disp_cwd"

if [ -n "$git_branch" ]; then printf ' \033[01;35m(%s)\033[00m' "$git_branch"; fi
if [ -n "$model" ]; then printf ' \033[01;36m[%s]\033[00m' "$model"; fi
if [ -n "$ctx_pct" ]; then ctx_int=$(printf '%.0f' "$ctx_pct"); printf ' \033[01;33m(%s%% ctx)\033[00m' "$ctx_int"; fi
if [ -n "$effort" ]; then printf ' \033[00;33m[effort:%s]\033[00m' "$effort"; fi
if [ "$thinking" = "true" ]; then printf ' \033[01;37m[thinking]\033[00m'; fi
SLEOF
    chmod +x "$SL_LINK"
    warn "Windows statusline not found at $WIN_SL — wrote a standalone WSL copy instead"
fi

# Merge statusLine into ~/.claude/settings.json (preserve other keys)
SL_SETTINGS="$HOME/.claude/settings.json"
SL_CMD="bash $HOME/.claude/statusline-command.sh"
if command_exists jq; then
    # Idempotent: skip the rewrite when statusLine already matches. Rewriting on every run
    # makes a live Claude Code hot-reload its statusLine unnecessarily.
    CUR_SL=$(jq -r '.statusLine.command // empty' "$SL_SETTINGS" 2>/dev/null)
    if [ "$CUR_SL" = "$SL_CMD" ]; then
        skip "statusLine already configured in settings.json"
    elif [ -f "$SL_SETTINGS" ]; then
        SL_TMP=$(mktemp)
        if jq --arg cmd "$SL_CMD" '.statusLine = {type:"command", command:$cmd}' "$SL_SETTINGS" > "$SL_TMP" 2>/dev/null; then
            mv "$SL_TMP" "$SL_SETTINGS"
            ok "statusLine merged into settings.json"
        else
            rm -f "$SL_TMP"
            warn "settings.json is not valid JSON — add statusLine manually"
        fi
    else
        jq -n --arg cmd "$SL_CMD" '{statusLine:{type:"command", command:$cmd}}' > "$SL_SETTINGS"
        ok "settings.json created with statusLine"
    fi
else
    warn "jq not found — skipping statusLine settings merge"
fi

# --- Claude Code CLAUDE.md (symlinked from Windows; Windows is the single source) ---

step "Configuring Claude Code CLAUDE.md"

mkdir -p "$HOME/.claude"
CM_LINK="$HOME/.claude/CLAUDE.md"
WIN_CM="/mnt/c/Users/$WIN_USER/.claude/CLAUDE.md"

if [ -f "$WIN_CM" ]; then
    if [ -L "$CM_LINK" ] && [ "$(readlink "$CM_LINK")" = "$WIN_CM" ]; then
        skip "CLAUDE.md already symlinked from Windows"
    else
        # Back up a pre-existing real file before replacing it with the symlink
        if [ -e "$CM_LINK" ] && [ ! -L "$CM_LINK" ]; then
            mv "$CM_LINK" "$CM_LINK.bak"
            ok "Backed up existing CLAUDE.md -> $CM_LINK.bak"
        fi
        ln -sfn "$WIN_CM" "$CM_LINK"
        ok "CLAUDE.md symlinked from Windows ($WIN_CM)"
    fi
else
    # No standalone fallback on purpose: Windows is the single source for this content,
    # so run setup.ps1 on Windows first (the combined flow always does).
    warn "Windows CLAUDE.md not found at $WIN_CM — run setup.ps1 on Windows first"
fi

# --- zsh + oh-my-zsh + plugins ---

step "Setting up zsh + oh-my-zsh"

if [ -d "$HOME/.oh-my-zsh" ]; then
    skip "oh-my-zsh already installed"
else
    RUNZSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    ok "oh-my-zsh installed"
fi

# Plugins
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

if [ -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
    skip "zsh-autosuggestions already installed"
else
    git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions" 2>/dev/null
    ok "zsh-autosuggestions installed"
fi

if [ -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
    skip "zsh-syntax-highlighting already installed"
else
    git clone https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" 2>/dev/null
    ok "zsh-syntax-highlighting installed"
fi

# Enable plugins in .zshrc
if grep -q "plugins=(git)" ~/.zshrc 2>/dev/null; then
    sed -i 's/plugins=(git)/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/' ~/.zshrc
    ok "Plugins enabled in .zshrc"
fi

# Copy PATH entries from .bashrc to .zshrc (brew, nvm, claude)
if ! grep -q "linuxbrew" ~/.zshrc 2>/dev/null; then
    cat >> ~/.zshrc << 'ZSHPATH'

# Homebrew
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

# nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Claude Code
export PATH="$HOME/.local/bin:$PATH"
ZSHPATH
    ok "PATH entries added to .zshrc (brew, nvm, claude)"
fi

# zoxide init (separate check since PATH block may already exist)
if ! grep -q "zoxide init" ~/.zshrc 2>/dev/null; then
    echo '' >> ~/.zshrc
    echo '# zoxide (smart cd, fasd replacement)' >> ~/.zshrc
    echo 'eval "$(zoxide init zsh)"' >> ~/.zshrc
    ok "zoxide init added to .zshrc"
fi

# Set zsh as default shell
if [ "$(basename "$SHELL")" != "zsh" ]; then
    sudo chsh -s "$(which zsh)" "$(whoami)"
    ok "Default shell changed to zsh"
else
    skip "zsh is already the default shell"
fi

# --- Start services ---

step "Starting services"
start_service postgresql
start_service mongod
start_service redis-server
start_service rabbitmq-server
if command_exists brew; then
    brew services start activemq 2>/dev/null || true
fi
ok "All services started"

# --- Health check ---

step "Verifying services"

check_service() {
    local name="$1"
    local svc="$2"
    if sudo systemctl is-active --quiet "$svc" 2>/dev/null; then
        ok "$name is running"
    elif sudo service "$svc" status &>/dev/null; then
        ok "$name is running"
    else
        warn "$name is NOT running — try: sudo service $svc start"
    fi
}

check_service "PostgreSQL 16"  postgresql
check_service "MongoDB 8.0"   mongod
check_service "Redis"          redis-server
check_service "RabbitMQ"       rabbitmq-server

if pgrep -f activemq >/dev/null 2>&1; then
    ok "ActiveMQ is running"
else
    warn "ActiveMQ is NOT running — try: brew services start activemq"
fi

# --- Done ---

step "WSL setup complete!"
echo ""
echo "  Service ports:"
echo "    - PostgreSQL 16  (localhost:5432)"
echo "    - MongoDB 8.0    (localhost:27017)"
echo "    - Redis           (localhost:6379)"
echo "    - RabbitMQ        (localhost:5672, management: localhost:15672)"
echo "    - ActiveMQ        (localhost:61616)"
echo ""
echo "  Next: run 'aws configure' to set up AWS credentials"
echo ""
