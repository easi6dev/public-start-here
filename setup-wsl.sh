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
    unzip jq git openjdk-21-jdk build-essential

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
        curl -sL -o /tmp/rabbitmq_delayed_message_exchange-4.0.2.ez \
            https://github.com/rabbitmq/rabbitmq-delayed-message-exchange/releases/download/v4.0.2/rabbitmq_delayed_message_exchange-4.0.2.ez
        sudo cp /tmp/rabbitmq_delayed_message_exchange-4.0.2.ez "$RABBITMQ_PLUGIN_DIR/"
        rm /tmp/rabbitmq_delayed_message_exchange-4.0.2.ez
        ok "Delayed message exchange plugin installed"
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
    echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> ~/.bashrc
    ok "Homebrew installed"
fi

eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" 2>/dev/null || true

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
    ok "Claude Code installed"
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

# --- Done ---

step "WSL setup complete!"
echo ""
echo "  Services running:"
echo "    - PostgreSQL 16  (localhost:5432)"
echo "    - MongoDB 8.0    (localhost:27017)"
echo "    - Redis           (localhost:6379)"
echo "    - RabbitMQ        (localhost:5672, management: localhost:15672)"
echo "    - ActiveMQ        (localhost:61616)"
echo ""
echo "  Next: run 'aws configure' to set up AWS credentials"
echo ""
