# TADA macOS Setup

macOS PC setup automation for TADA backend developers — the macOS port of the Windows
[`setup.ps1`](../setup.ps1) + [`setup-wsl.sh`](../setup-wsl.sh) flow.

> **Why one script instead of two?** On Windows the services run inside WSL, so setup is split
> into a Windows half (`setup.ps1`) and a Linux half (`setup-wsl.sh`). macOS is already Unix —
> the GUI apps, CLI tools, **and** the DB/MQ services all run natively via Homebrew — so it all
> lives in a single [`setup.sh`](setup.sh). No WSL, no reboot, no two-step dance.

---

## First time setup

1. Open **Terminal** (`Cmd + Space` → type `Terminal`).
2. Paste this and press Enter:

   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/easi6dev/public-start-here/main/mac/setup.sh)"
   ```

3. You may be prompted for your macOS password (sudo, for `/etc/hosts` + service config) and
   to authorize GitHub in your browser.
4. When it finishes, **restart your terminal** (or `source ~/.zshrc`).

The script is idempotent — re-run it any time; anything already installed is skipped.

---

## Reset

To undo everything and start fresh:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/easi6dev/public-start-here/main/mac/reset.sh)"
```

---

## What gets installed

### GUI Apps (Homebrew Cask)

IntelliJ IDEA Ultimate, DataGrip, JetBrains Toolbox, Fork, Docker Desktop, Claude, Slack,
Figma, Google Chrome, Postman, MongoDB Compass, Android Studio, 1Password, Cloudflare WARP.

> **PowerToys** has no macOS equivalent and is omitted — macOS covers its main features
> natively (Spotlight/Raycast ≈ PowerToys Run, Rectangle/built-in tiling ≈ FancyZones,
> Digital Color Meter ≈ Color Picker).

### CLI Tools (Homebrew)

Git, OpenJDK 21, GitHub CLI (`gh`), `jq`, AWS CLI, `uv`, ripgrep, fd, fzf, bat, zoxide,
delta (`git-delta`), eza, sd, ktlint. Node.js LTS via **nvm**, Python 3.12 via **uv**,
Claude Code via the native installer, `ccstatusline` (pinned npm global).

> **PowerShell 7** is omitted (it was a Windows-only need). `brew install --cask powershell`
> if you want it.

### Services (native via Homebrew — no WSL)

| Service       | Port                              |
| ------------- | --------------------------------- |
| PostgreSQL 16 | `localhost:5432` (+ PostGIS)      |
| MongoDB 8.0   | `localhost:27017`                 |
| Redis         | `localhost:6379`                  |
| RabbitMQ      | `localhost:5672` (UI `:15672`)    |
| ActiveMQ      | `localhost:61616`                 |

Managed with `brew services` (auto-start at login). PostgreSQL gets an `admin` superuser and
loopback `trust` auth; RabbitMQ gets the delayed-message-exchange plugin + management UI.

```bash
brew services list              # see status
brew services restart redis     # restart one
```

### Shell & dev settings

- **zsh** is already the macOS default → oh-my-zsh + `zsh-autosuggestions` +
  `zsh-syntax-highlighting`, zoxide init, nvm, and Claude Code on PATH (in `~/.zshrc`;
  Homebrew shellenv in `~/.zprofile`).
- **Claude Code**: shared team `CLAUDE.md` defaults (managed block) + `ccstatusline` statusLine.
- **git**: `core.autocrlf=input`, delta as the diff pager (`git rawdiff` for plain).
- **Fork CLI**: `fork [path]` opens Fork.app at a directory (default: current).
- **Finder**: show file extensions, hidden files, path bar, full POSIX path in title.
- **`/etc/hosts`**: `host.docker.internal → 127.0.0.1` so backend configs using that host resolve to the native services.

---

## Manual steps after setup

1. **Docker Desktop** — open it once to finish first-run setup.
2. **Cloudflare WARP** — configure with the team VPN settings
   (launcher: https://mvlchain.cloudflareaccess.com/#/Launcher).
3. **IntelliJ IDEA** — sign in to your JetBrains account; open a backend project to verify.
4. **Environment variables** — set `GITHUB_USERNAME` / `GITHUB_TOKEN` if your build needs them
   (PAT with `repo` + `read:packages`).
5. **AWS** — run `aws configure`.

---

## Differences from the Windows setup

| Windows / WSL                                   | macOS                                                        |
| ----------------------------------------------- | ------------------------------------------------------------ |
| `winget` + WSL `apt` + Linuxbrew                | Homebrew (cask + formula) for everything                     |
| Two scripts + reboot (`setup.ps1`/`setup-wsl.sh`) | One `setup.sh`, no reboot                                  |
| WSL VM hosts the DB/MQ services                 | Services run natively via `brew services`                    |
| systemd / WSL autostart logon task              | `brew services` (launchd) auto-start at login                |
| Mac-style keyboard remap (`optional/mac-keyboard.ps1`) | N/A — it's already a Mac                              |
| PowerToys, PowerShell 7, Windows Terminal, registry, `.wslconfig` | omitted / native macOS equivalents          |
