# public-start-here

Windows PC setup automation for TADA backend developers.

## Quick Start

### Opening PowerShell as Administrator

- **Fastest**: Press `Win + X` → click **Terminal (Admin)**
- **Search**: Press `Win` → type `powershell` → click **Run as Administrator**
- **Start menu**: Right-click Windows Terminal → **Run as Administrator**

Then run:

```powershell
irm https://raw.githubusercontent.com/easi6dev/public-start-here/main/setup.ps1 | iex
```

This will automatically:

1. **Phase 1** — Install Windows apps and CLI tools via winget
2. **Phase 2** — Install WSL Ubuntu 24.04 and set up services
3. **Phase 3** — Authenticate with GitHub and clone all backend repositories to `~/backend/`

## Reset

To undo everything and start fresh:

```powershell
irm https://raw.githubusercontent.com/easi6dev/public-start-here/main/reset.ps1 | iex
```

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

### Windows — CLI Tools

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

### WSL Ubuntu 24.04 — Services

- **PostgreSQL 16** — Primary relational database, with PostGIS extension
- **MongoDB 8.0** — Document database for flexible schema storage
- **Redis** — In-memory cache and message broker
- **RabbitMQ** — Message queue with delayed message exchange plugin and management UI
- **ActiveMQ** — Message broker for legacy service communication (installed via brew)

### WSL Ubuntu 24.04 — CLI Tools (via brew)

- **gh** — GitHub CLI
- **node** — Node.js runtime
- **python3** — Python runtime
- **uv** — Python package manager
- **ktlint** — Kotlin linter
- **ripgrep, fd, fzf, bat** — Fast search and file tools
- **zoxide, git-delta, eza, sd** — Terminal productivity tools

## Manual steps after setup

1. **Reboot** if this was your first WSL install, then re-run the script
2. **Set credential environment variables** — `GITHUB_USERNAME`, `GITHUB_TOKEN`, `AWS_ACCESS_KEY`, `aws_secret_access_key`, `GOOGLE_APPLICATION_CREDENTIALS`
3. **Enable Docker Desktop WSL integration** — Settings > Resources > WSL Integration > Ubuntu-24.04
4. **Run `aws configure`** to set up AWS credentials
