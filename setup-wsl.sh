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

# zoxide (smart cd, fasd replacement)
eval "$(zoxide init zsh)"
ZSHPATH
    ok "PATH entries added to .zshrc (brew, nvm, claude, zoxide)"
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
