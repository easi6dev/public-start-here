# TADA Windows Setup

Windows PC setup automation for TADA backend developers.

---

## 👉 Which step are you on?

### 🟢 [First time? Start here](#first-time-setup) — Fresh Windows PC, never ran this script before

### 🔄 [Just rebooted? Continue here](#after-reboot) — Already ran the script, rebooted, now what?

---

## First time setup

1. Open **PowerShell as Administrator**
   - **Fastest**: `Win + X` → **Terminal (Admin)**
   - **Or**: `Win` key → type `powershell` → click **Run as Administrator**

2. Paste this and press Enter:

```powershell
irm "https://raw.githubusercontent.com/easi6dev/public-start-here/main/setup.ps1?t=$(Get-Random)" | iex
```

3. The script will install everything automatically. When it's done, it will ask you to **reboot**.
4. After reboot, this page will open in your browser. Go to [After reboot](#after-reboot) below.

---

## After reboot

The hard part is done! All your apps and tools are already installed. Now we just need to finish WSL setup.

1. Open **PowerShell as Administrator** again
   - `Win + X` → **Terminal (Admin)**

2. Paste the **same command** again:

```powershell
irm "https://raw.githubusercontent.com/easi6dev/public-start-here/main/setup.ps1?t=$(Get-Random)" | iex
```

3. Don't worry — everything already installed will be **skipped automatically**. Only these remain:
   - WSL Ubuntu 24.04 services (PostgreSQL, MongoDB, Redis, RabbitMQ, ActiveMQ)
   - CLI tools in WSL (gh, rg, fd, bat, etc.)
   - GitHub authentication + backend repo cloning

4. Grab a coffee and wait for it to finish.

---

## Reset

To undo everything and start fresh:

```powershell
irm "https://raw.githubusercontent.com/easi6dev/public-start-here/main/reset.ps1?t=$(Get-Random)" | iex
```

---

## What gets installed

### Windows — GUI Apps

- **IntelliJ IDEA Ultimate** — Primary IDE for Kotlin/Spring backend development
- **DataGrip** — Database IDE for querying PostgreSQL, MongoDB, Redis
- **JetBrains Toolbox** — Manages JetBrains IDE installations and updates
- **Fork** — Git GUI client for visual branch management and diffs
- **Docker Desktop** — Container runtime, uses WSL 2 backend on Windows
- **Claude** — AI assistant desktop app
- **Slack** — Team communication
- **Figma** — UI/UX design collaboration tool
- **Google Chrome** — Web browser for development and testing
- **Postman** — API testing and debugging tool
- **MongoDB Compass** — GUI for browsing and querying MongoDB databases
- **Android Studio** — IDE for Android app development and emulator
- **1Password** — Password manager
- **Cloudflare WARP** — VPN client (team configuration required separately)
- **PowerToys** — Microsoft productivity tools (PowerToys Run, FancyZones, Color Picker, etc.)

### Windows — CLI Tools

- **PowerShell 7** — Modern cross-platform PowerShell (faster than built-in 5.1)
- **Git** — Version control
- **Node.js LTS** — JavaScript runtime, required for Claude Code and frontend tools
- **OpenJDK 21** — Java runtime for Kotlin/Spring Boot projects
- **GitHub CLI (gh)** — GitHub operations from the terminal (auth, PRs, repo management)
- **jq** — JSON processor for parsing API responses in scripts
- **AWS CLI** — AWS service management (S3, ECR, ECS, etc.)
- **Python 3.12** — Python runtime for scripting and tooling
- **uv** — Ultra-fast Python package manager (pip/venv replacement)
- **ripgrep (rg)** — Fast text search across files (grep replacement)
- **fd** — Fast file finder (find replacement)
- **fzf** — Fuzzy finder for interactive file/history search
- **bat** — File viewer with syntax highlighting (cat replacement)
- **zoxide** — Smart directory jumper that learns your habits (cd replacement)
- **delta** — Syntax-highlighted git diff viewer
- **eza** — Modern file lister with colors and git status (ls replacement)
- **sd** — Intuitive find-and-replace tool (sed replacement)
- **ktlint** — Kotlin code linter and formatter
- **Claude Code** — AI coding assistant CLI (native install)
  - statusLine pre-configured (`user@host:dir [model] (ctx%)`) via Git Bash — no per-person setup needed
- **flipper-server** — Mobile debugging tool, browser-based (`npx flipper-server` to run)

### Windows — Developer Settings (auto-configured)

- **File extensions visible** — Prevents `.wslconfig.txt` mistakes
- **Hidden files visible** — Shows `.git`, `.env`, `.vscode` in Explorer
- **Full path in title bar** — Shows absolute path in Explorer window
- **Explorer opens to "This PC"** — Drives view instead of recent files
- **Developer Mode enabled** — Create symlinks without admin privileges
- **Long Paths enabled** — Removes 260-char path limit (node_modules, Java)
- **ExecutionPolicy RemoteSigned** — Allows running local dev scripts (nvm, venv, etc.)

### WSL Ubuntu 24.04 — Services

- **PostgreSQL 16** — Primary relational database, with PostGIS extension
- **MongoDB 8.0** — Document database for flexible schema storage
- **Redis** — In-memory cache and message broker
- **RabbitMQ** — Message queue with delayed message exchange plugin and management UI
- **ActiveMQ** — Message broker for legacy service communication (installed via brew)

### WSL Ubuntu 24.04 — Runtime Version Managers

- **nvm** — Node.js version manager (`nvm install 20`, `nvm use 18`)
- **Node.js LTS** — Installed via nvm, easily switchable per project
- **uv** — Python version and package manager (`uv python install 3.12`, `uv venv`)
- **Python 3.12** — Installed via uv, no separate pyenv needed

### WSL Ubuntu 24.04 — Shell

- **zsh** — Default shell (replaces bash)
- **oh-my-zsh** — Zsh framework with themes and plugin management
- **zsh-autosuggestions** — Fish-like command suggestions as you type
- **zsh-syntax-highlighting** — Real-time syntax highlighting in terminal
- **Claude Code statusLine** — symlinked to the Windows `statusline-command.sh`, so both environments share one file (edit once, both update)

### WSL Ubuntu 24.04 — CLI Tools (via brew)

- **gh** — GitHub CLI
- **ktlint** — Kotlin linter
- **ripgrep, fd, fzf, bat** — Fast search and file tools
- **zoxide, git-delta, eza, sd** — Terminal productivity tools

## Optional extras

### Mac-style keyboard (Ctrl ↔ Alt swap)

If you're used to Mac keyboard shortcuts, this configures PowerToys to:
- **Ctrl ↔ Alt swap** — Use your thumb for shortcuts (like Command on Mac)
- **Caps Lock → 한/영** — Tap to switch Korean/English
- **Left Alt + Space → 한/영** — Mac-style IME toggle

```powershell
irm "https://raw.githubusercontent.com/easi6dev/public-start-here/main/optional/mac-keyboard.ps1?t=$(Get-Random)" | iex
```

After running, restart PowerToys (system tray → right-click → Restart). To undo, open PowerToys > Keyboard Manager > delete all remappings.

## Manual steps after setup

1. **Set credential environment variables** — `GITHUB_USERNAME`, `GITHUB_TOKEN`
2. **Enable Docker Desktop WSL integration** — Settings > Resources > WSL Integration > Ubuntu-24.04
3. **Configure Cloudflare WARP** — Follow the team VPN setup guide
