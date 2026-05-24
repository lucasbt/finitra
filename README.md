<div align="center">
   <img align="center" alt="Initora Logo" src="assets/initora.png" width="40%"/>	
	<p align="center">
    <br />
		<b>Automated setup • Performance tuned • Ready-to-code</b>
    <br />
  </p>
  <p align="center">
  <a href="https://fedoraproject.org/"><img src="https://img.shields.io/badge/Fedora-41+-blue?logo=fedora&logoColor=white" alt="Fedora"></a>
  <a href="https://www.gnu.org/software/bash/"><img src="https://img.shields.io/badge/Shell-Bash-4EAA25?logo=gnu-bash&logoColor=white" alt="Shell: Bash"></a>
  <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="License: MIT"></a>
</p>
  <h1></h1>
</div>

#### Fedora Workstation Bootstrap for Developers

**Initora** is a high-end, modular, and idempotent bootstrap toolkit designed to transform a fresh Fedora Workstation installation into a professional development powerhouse. It automates everything from kernel-level optimizations to high-level IDE configurations, ensuring a consistent and high-performance environment.

## ✨ Key Features

- **🎯 Modular Architecture:** Granular control over the setup process. Run specific modules or the full suite.
- **🚀 Performance-First:** DNF parallelization, I/O scheduler optimizations (NVMe/SATA), and kernel `sysctl` hardening.
- **💻 Polyglot Toolchain:** Automated management for Java (SDKMAN), Node.js (NVM), and more.
- **🤖 AI-Ready:** Built-in support for Gemini CLI, GitHub Copilot, Windsurf, Qwen Code, and OpenCode.
- **🎨 Visual Excellence:** Curated GNOME desktop experience with Nerd Fonts, Microsoft fonts, dark mode, and custom Ptyxis profiles.
- **📦 App Ecosystem:** Automated installation of VSCode, Google Chrome, Bitwarden, Obsidian, DBeaver, and more.
- **🛠 Idempotency:** Safely re-run any part of the script. It intelligently detects existing states to avoid redundant operations.

## 🚀 Quick Start

**IMPORTANT:** Install `git` if not already present *(ships with Fedora Workstation)*

```bash
sudo dnf install -y git
```

### 1. One-liner Installation
The easiest way to provision your system is by running the bootstrap script directly from the repository:

```bash
curl -fsSL https://raw.githubusercontent.com/lucasbt/initora/main/bootstrap.sh | bash
```

### 2. Manual Setup
If you want to inspect the code before running:

```bash
git clone https://github.com/lucasbt/initora ~/.local/share/initora
cd ~/.local/share/initora
bash bootstrap.sh
```


## 🛠 Usage & CLI

Initora provides a robust CLI interface. After installation, use the `initora` command.

| Command | Description |
| :--- | :--- |
| `initora` | Launches the GUM-based interactive module selector. |
| `initora install` | Executes all modules in sequential order. |
| `initora install -m ID` | Runs a specific module (e.g., `initora install -m 20`). |
| `initora list` | Displays all available modules and their descriptions. |
| `initora update` | Synchronizes the local repository with the remote source. |
| `initora config` | Opens your user configuration in the default `$EDITOR`. |
| `initora log` | Opens the execution log in an interactive viewer (`less`). |

## 📂 Structure of current repo

```text
.
├── bootstrap.sh            # Main entry point for installation
├── initora                 # CLI entry point for module management
├── initora-default.config  # Default configuration variables
├── utils.sh               # Shared helper functions
├── version                # Project version
├── data/                  # Data lists for automated installation
│   ├── flatpak-pkgs.list  # List of Flatpak applications
│   ├── gnome-settings.list # GSettings configuration list
│   └── rpm-pkgs.list      # List of DNF/RPM packages
└── modules/               # Modular setup scripts
    ├── 00-system.sh
    └── ...
```

## 📂 Modular Architecture

Initora is built on a series of specialized scripts located in the `modules/` directory:

### [00] System Base ([`00-system.sh`](modules/00-system.sh))
*Core system setup and repository configuration.*

- **DNF Tuning:** Configures parallel downloads and fastest mirror.
- **Repositories:** Enables RPM Fusion (Free/Non-free) and cleans unwanted repos.
- **Multimedia:** Full codec support (H.264/H.265/FFmpeg) with VA-API hardware acceleration.
- **Updates:** Full system upgrade and firmware (`fwupdmgr`) refresh.

### [10] Packages ([`10-packages.sh`](modules/10-packages.sh))
*Essential GUI applications and list-based management.*

- **Browsers:** Google Chrome stable with official repository.
- **Apps:** Obsidian (AppImage), Bitwarden (GUI & CLI), and VSCode Repo.
- **Bulk Install:** Processes `data/rpm-pkgs.list` and `data/flatpak-pkgs.list`.

### [20] Dev Tools ([`20-dev-tools.sh`](modules/20-dev-tools.sh))
*The developer's heart—toolchains, runtimes, and IDEs.*

- **Runtimes:** SDKMAN for Java (LTS) and NVM for Node.js.
- **AI Stack:** Gemini CLI, GitHub Copilot, Windsurf, and more.
- **Infra:** AWS CLI v2, kubectl, Podman (with Docker alias), and Podman Desktop.
- **IDE:** Deep VSCode configuration (settings.json, extensions, keybindings).
- **Shell:** Starship prompt with a customized, low-noise configuration.

### [30] Desktop ([`30-desktop.sh`](modules/30-desktop.sh))
*UX, UI, and visual accessibility.*

- **GNOME:** Night Light, fixed workspaces, text scaling, and optimized keybindings.
- **Terminal:** Professional Ptyxis profile setup (One Half Black palette).
- **Search:** LocalSearch (Tracker3) optimization for battery and performance.
- **Assets:** Nerd Fonts collection, Microsoft Core Fonts, and wallpaper collections.

### [40] Optimizations ([`40-optimizations.sh`](modules/40-optimizations.sh))
*Low-level system and hardware tuning.*

- **Kernel:** `sysctl` tuning for `swappiness`, `inotify` (for IDEs), and network.
- **SSD:** Weekly TRIM activation and I/O scheduler rules (NVMe/SATA).
- **Logs:** Limits `journald` disk usage and cleans up boot-time overhead.

## ⚙️ Customization

### Alter User Config
Settings are managed in `~/.config/initora/initora.config`. This file allows you to override any default variable found in [`initora-default.config`](initora-default.config). Use the CLI to edit it easily:
```bash
initora config
```

### Add RPM Package
To add new DNF packages, append them to [`data/rpm-pkgs.list`](data/rpm-pkgs.list). Each line should contain a single package name.

### Add Flatpak Package
To add new Flatpak applications, append them to [`data/flatpak-pkgs.list`](data/flatpak-pkgs.list).

**Format:** `remote app_id` (e.g., `flathub org.mozilla.firefox`)

### GNOME Settings
Custom GNOME settings can be added to [`data/gnome-settings.list`](data/gnome-settings.list).

**Format:** `schema key value` (e.g., `org.gnome.desktop.interface clock-show-date true`)

### Add New Module
Initora's engine is designed for easy extension. To add a new module, create a script in the `modules/` directory following the naming convention `NN-name.sh`.

**Minimal example:**
```bash
#!/usr/bin/env bash
module_50_extras() {
  log_section "Module: Extras"
  # your code here
  log_success "Module 50-extras completed."
}
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  source "${SCRIPT_DIR}/utils.sh"
  source "${SCRIPT_DIR}/initora-default.config"
  [[ -f "${SETUP_HOME}/.config/initora/initora.config" ]] && \
    source "${SETUP_HOME}/.config/initora/initora.config"
  module_50_extras
fi
```


## 🔍 Logs & Troubleshooting

Initora maintains a detailed execution log to help you track changes and debug issues.

### Interactive Log Viewer
The easiest way to view and search through logs is using the built-in command:
```bash
initora log
```
This opens the log file in `less`, starting at the most recent entries. Use `j`/`k` to scroll, `/` to search, and `q` to quit.

### View Real-time Logs
Monitor the installation process as it happens:
```bash
tail -f ~/.cache/initora/initora.log
```

### Log Location
The log file is stored at:
`~/.cache/initora/initora.log`

### Debugging Errors
If a module fails, the error handler will print a stack trace both to the terminal and the log file. You can quickly search for errors using:
```bash
grep "ERROR" ~/.cache/initora/initora.log
```

## 🔐 Security & Best Practices
- **Root Safety:** Scripts use `sudo` surgically only when necessary.
- **Backup:** Important system files (like `dnf.conf`) are backed up before modification.
- **Non-Intrusive:** Initora respects existing configurations where possible and focuses on adding value rather than forcing changes.

## 🤝 Contributing
Contributions are what make the open-source community an amazing place to learn, inspire, and create.

1. Fork the Project.
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`).
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`).
4. Push to the Branch (`git push origin feature/AmazingFeature`).
5. Open a Pull Request.

## 📜 License
Distributed under the MIT License. See [`LICENSE`](LICENSE) for more information.

---

*Maintained by [lucasbt](https://github.com/lucasbt) • Built for the Fedora Community*
