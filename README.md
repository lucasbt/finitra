# finitra

**Fedora Workstation Bootstrap for Developers**

> Bootstrap your Developer Fedora Workstation

Fedora bootstrap and development environment provisioning toolkit.
Modular and idempotent post-install setup for **Fedora 41+ Workstation**,
focused on performance, visual accessibility, and developer tooling.

## Target hardware

- Dell Notebook, Intel Core i7-4510U
- 16 GB RAM, 256 GB SSD

## Quick start

```bash
# Install git if not already present (ships with Fedora Workstation)
sudo dnf install -y git

# Clone the repository
git clone https://github.com/SEU_USUARIO/finitra ~/.local/share/finitra
cd ~/.local/share/finitra

# Run bootstrap (installs deps, configures env, creates alias)
bash bootstrap.sh
```

## Usage

```bash
# Interactive menu
finitra

# Short alias
fi

# Run all modules in sequence
finitra install
finitra install --all
finitra -ia

# Run a specific module (by number or name)
finitra install --module 30
finitra install -m 30
finitra -i -m 30

finitra install --module desktop
finitra install -m desktop
finitra -i -m desktop

# List available modules
finitra list

# Self-update from remote repository
finitra update

# Open user config in $EDITOR
finitra config
```

## Structure

```
finitra/
├── finitra                      <- Main executable (symlink: ~/.local/bin/finitra)
├── bootstrap.sh                 <- Initial setup and binary installation
├── finitra-default.config       <- All defaults (do not edit -- override in user config)
├── utils.sh                     <- Shared functions (gs_set, dnf_install, run_as_root, ...)
├── version                      <- Project version
│
├── modules/
│   ├── 00-system.sh             <- DNF tuning, RPM Fusion, ZRAM, system update (REQUIRED)
│   ├── 10-packages.sh           <- VSCode repo, rpm-pkgs.list, flatpak-pkgs.list, multimedia
│   ├── 20-dev-tools.sh          <- mise, Java 21/25, Node, Python, Go, Podman, Starship
│   ├── 30-desktop.sh            <- GNOME settings, Night Light, workspaces, Ptyxis, LocalSearch
│   └── 40-optimizations.sh      <- sysctl, I/O scheduler, TRIM, journald, dnf-makecache
│
└── data/
    ├── rpm-pkgs.list            <- Editable RPM package list
    ├── flatpak-pkgs.list        <- Editable Flatpak list (format: remote app_id)
    └── gnome-settings.list      <- GNOME gsettings (format: schema key value)
```

## Customization

### User config

The bootstrap creates `~/.config/finitra/finitra.config` automatically.
To edit it:

```bash
finitra config
# or directly:
$EDITOR ~/.config/finitra/finitra.config
```

Key variables:

| Variable | Default | Description |
|---|---|---|
| `SETUP_USER` | auto-detected | Target user for user-level configs |
| `GNOME_NIGHT_LIGHT_TEMPERATURE` | `3700` | Night Light color temperature (Kelvin) |
| `GNOME_NUM_WORKSPACES` | `4` | Number of fixed workspaces |
| `GNOME_TEXT_SCALE` | `1.15` | GNOME text scaling factor |
| `VM_SWAPPINESS` | `10` | Kernel swap aggressiveness |
| `MISE_JAVA_21` | `java@21` | Java LTS version via mise |
| `PTYXIS_PALETTE` | `One Half Black` | Ptyxis terminal color palette |
| `PTYXIS_FONT_NAME` | `JetBrains Mono 12` | Ptyxis terminal font |

### Add RPM packages

Edit `data/rpm-pkgs.list`, one package per line:

```
# My new package
my-package
```

### Add Flatpak packages

Edit `data/flatpak-pkgs.list` with format `remote app_id`:

```
flathub org.inkscape.Inkscape
```

### Add GNOME settings

Edit `data/gnome-settings.list` with format `schema key value`.
Values support `${VAR}` references from the config file:

```
org.gnome.desktop.interface gtk-theme '${GNOME_GTK_THEME}'
```

### Add a new module

1. Create `modules/NN-name.sh` (NN = ordering prefix, e.g. `50-extras.sh`)
2. Define function `module_NN_name()` inside the file
3. The main script auto-discovers it on next run

Minimal example:

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
  source "${SCRIPT_DIR}/finitra-default.config"
  module_50_extras
fi
```

## Idempotency

The script is safe to run multiple times:
packages already installed are skipped, settings already applied are verified
before re-applying, and repositories are not duplicated.

## Log

```bash
tail -f ~/.cache/finitra/finitra.log
```
