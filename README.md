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

1. **Phase 1** — Install Windows apps (IntelliJ, Docker Desktop, Chrome, Slack, etc.) and CLI tools via winget
2. **Phase 2** — Install WSL Ubuntu 24.04 and set up services (PostgreSQL, MongoDB, Redis, RabbitMQ, ActiveMQ)
3. **Phase 3** — Authenticate with GitHub and clone all backend repositories to `~/backend/`

## Reset

To undo everything and start fresh:

```powershell
irm https://raw.githubusercontent.com/easi6dev/public-start-here/main/reset.ps1 | iex
```

## What gets installed

### Windows (winget)

| GUI Apps | CLI Tools |
|----------|-----------|
| IntelliJ IDEA Ultimate | Git |
| DataGrip | Node.js LTS |
| JetBrains Toolbox | OpenJDK 21 |
| Fork | GitHub CLI |
| Docker Desktop | jq |
| Claude | AWS CLI |
| Slack | Python 3.12 |
| Figma | uv |
| Google Chrome | ripgrep, fd, fzf, bat |
| Postman | zoxide, delta, eza, sd |
| MongoDB Compass | ktlint |
| Android Studio | Claude Code |
| 1Password | |

### WSL Ubuntu 24.04 (services)

PostgreSQL 16, MongoDB 8.0, Redis, RabbitMQ (+ delayed message exchange), ActiveMQ

### WSL Ubuntu 24.04 (CLI tools via brew)

gh, node, python3, uv, ktlint, ripgrep, fd, fzf, bat, zoxide, git-delta, eza, sd

## Manual steps after setup

1. **Reboot** if this was your first WSL install, then re-run the script
2. **Set credential environment variables** — `GITHUB_USERNAME`, `GITHUB_TOKEN`, `AWS_ACCESS_KEY`, `aws_secret_access_key`, `GOOGLE_APPLICATION_CREDENTIALS`
3. **Enable Docker Desktop WSL integration** — Settings > Resources > WSL Integration > Ubuntu-24.04
4. **Run `aws configure`** to set up AWS credentials
