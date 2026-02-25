#!/usr/bin/env bash
# =============================================================================
# bootstrap.sh -- Quick installer for finitra
#
# Finitra — Fedora Workstation Bootstrap for Developers
# Bootstrap your Developer Fedora Workstation
#
# Usage (as a regular user, not root):
#   curl -fsSL https://raw.githubusercontent.com/lucasbt/finitra/main/bootstrap.sh | bash
#   -- ou --
#   bash bootstrap.sh
# =============================================================================
set -euo pipefail

REPO_URL="${FINITRA_REPO:-https://github.com/lucasbt/finitra}"
INSTALL_DIR="${HOME}/.local/share/finitra"
BIN_DIR="${HOME}/.local/bin"
BIN_PATH="${BIN_DIR}/finitra"
CONFIG_DIR="${HOME}/.config/finitra"
CONFIG_FILE="${CONFIG_DIR}/finitra.config"

# --- Colors ---
CLR_RESET='\033[0m'
CLR_RED='\033[0;31m'
CLR_GREEN='\033[0;32m'
CLR_YELLOW='\033[1;33m'
CLR_BLUE='\033[0;34m'
CLR_CYAN='\033[0;36m'
CLR_BOLD='\033[1m'

info()  { echo -e "${CLR_BLUE}[finitra]${CLR_RESET} $*"; }
ok()    { echo -e "${CLR_GREEN}[finitra]${CLR_RESET} ✔ $*"; }
warn()  { echo -e "${CLR_YELLOW}[finitra]${CLR_RESET} ⚠ $*"; }
err()   { echo -e "${CLR_RED}[finitra]${CLR_RESET} ✖ $*" >&2; }

_print_banner() {
  clear
  echo ""
  echo -e "${CLR_BOLD}${CLR_CYAN}  ███████╗██╗███╗   ██╗██╗████████╗██████╗  █████╗ ${CLR_RESET}"
  echo -e "${CLR_BOLD}${CLR_CYAN}  ██╔════╝██║████╗  ██║██║╚══██╔══╝██╔══██╗██╔══██╗${CLR_RESET}"
  echo -e "${CLR_BOLD}${CLR_CYAN}  █████╗  ██║██╔██╗ ██║██║   ██║   ██████╔╝███████║${CLR_RESET}"
  echo -e "${CLR_BOLD}${CLR_CYAN}  ██╔══╝  ██║██║╚██╗██║██║   ██║   ██╔══██╗██╔══██║${CLR_RESET}"
  echo -e "${CLR_BOLD}${CLR_CYAN}  ██║     ██║██║ ╚████║██║   ██║   ██║  ██║██║  ██║${CLR_RESET}"
  echo -e "${CLR_BOLD}${CLR_CYAN}  ╚═╝     ╚═╝╚═╝  ╚═══╝╚═╝   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝${CLR_RESET}"
  echo ""
  echo -e "  ${CLR_BOLD}Fedora Workstation Bootstrap for Developers${CLR_RESET}"
  echo -e "  Bootstrap your Developer Fedora Workstation"
  echo ""
}

# =============================================================================
# 1. Install required dependencies with user approval
# =============================================================================
_install_deps() {
  local deps=(git curl whiptail)
  local missing=()

  for dep in "${deps[@]}"; do
    command -v "$dep" &>/dev/null || missing+=("$dep")
  done

  if [[ ${#missing[@]} -eq 0 ]]; then
    ok "All dependencies already satisfied: ${deps[*]}"
    return
  fi

  echo ""
  echo -e "${CLR_BOLD}The following dependencies need to be installed:${CLR_RESET}"
  for pkg in "${missing[@]}"; do
    echo -e "  ${CLR_YELLOW}•${CLR_RESET} $pkg"
  done
  echo ""
  echo -e "  Command that will be executed:"
  echo -e "  ${CLR_BOLD}sudo dnf install -y ${missing[*]}${CLR_RESET}"
  echo ""

  read -rp "$(echo -e "${CLR_BOLD}Install now? [Y/n]:${CLR_RESET} ")" answer
  answer="${answer:-S}"

  if [[ "${answer^^}" != "O" ]]; then
    err "Dependency installation declined. Aborting."
    exit 1
  fi

  sudo dnf install -y "${missing[@]}" || {
    err "Failed to install dependencies. Check your connection and try again."
    exit 1
  }
  ok "Dependencies installed: ${missing[*]}"
}

# =============================================================================
# 2. Detect execution source and manage clone/update
# =============================================================================
_setup_repo() {
  local script_source
  script_source="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || echo "")"

  if [[ -n "$script_source" && -f "${script_source}/finitra" ]]; then
    info "Detectado clone local em: $script_source"
    INSTALL_DIR="$script_source"
    return
  fi

  if [[ ! -d "$INSTALL_DIR/.git" ]]; then
    info "Cloning repository to $INSTALL_DIR"
    mkdir -p "$(dirname "$INSTALL_DIR")"
    git clone "$REPO_URL" "$INSTALL_DIR"
    ok "Repository cloned"
    return
  fi

  # Check for local uncommitted changes
  local has_local_changes=false
  if ! git -C "$INSTALL_DIR" diff --quiet 2>/dev/null || \
     ! git -C "$INSTALL_DIR" diff --cached --quiet 2>/dev/null; then
    has_local_changes=true
  fi

  if [[ "$has_local_changes" == "true" ]]; then
    echo ""
    warn "Local uncommitted changes detected in:"
    warn "  $INSTALL_DIR"
    echo ""
    git -C "$INSTALL_DIR" status --short
    echo ""
    echo -e "${CLR_BOLD}What would you like to do?${CLR_RESET}"
    echo -e "  ${CLR_YELLOW}[O]${CLR_RESET} Overwrite -- discard local changes and update from remote"
    echo -e "  ${CLR_YELLOW}[A]${CLR_RESET} Abort    -- keep local changes and cancel bootstrap"
    echo ""
    read -rp "$(echo -e "${CLR_BOLD}Choice [O/A]:${CLR_RESET} ")" answer
    answer="${answer:-A}"

    if [[ "${answer^^}" != "O" ]]; then
      warn "Bootstrap aborted. Local changes preserved."
      exit 0
    fi

    info "Discarding local changes and updating from remote..."
    git -C "$INSTALL_DIR" fetch origin
    git -C "$INSTALL_DIR" reset --hard origin/main
    git -C "$INSTALL_DIR" clean -fd
    ok "Repository updated (local changes discarded)"
  else
    info "Updating existing repository in $INSTALL_DIR"
    git -C "$INSTALL_DIR" pull --ff-only
    ok "Repository updated"
  fi
}

# =============================================================================
# 3. Set up user configuration file
# =============================================================================
_setup_config() {
  mkdir -p "$CONFIG_DIR"

  if [[ ! -f "$CONFIG_FILE" ]]; then
    info "Creating user config at $CONFIG_FILE"
    cp "${INSTALL_DIR}/finitra-default.config" "$CONFIG_FILE"

    local current_user="${SUDO_USER:-$USER}"
    local current_home
    current_home=$(eval echo "~$current_user")

    sed -i "s|SETUP_USER=\".*\"|SETUP_USER=\"${current_user}\"|" "$CONFIG_FILE" 2>/dev/null || true
    sed -i "s|SETUP_HOME=.*|SETUP_HOME=\"${current_home}\"|" "$CONFIG_FILE" 2>/dev/null || true

    ok "Config created. Edit $CONFIG_FILE to customize."
  else
    warn "Existing config preserved: $CONFIG_FILE"
  fi
}

# =============================================================================
# 4. Install binary to ~/.local/bin/finitra and configure alias
# =============================================================================
_setup_bin_and_alias() {
  # Set executable permissions
  chmod +x "${INSTALL_DIR}/finitra"
  chmod +x "${INSTALL_DIR}/utils.sh"
  find "${INSTALL_DIR}/modules" -name "*.sh" -exec chmod +x {} \;

  # Create ~/.local/bin if it does not exist
  mkdir -p "$BIN_DIR"

  # Install (or update) the binary symlink
  if [[ -L "$BIN_PATH" || -f "$BIN_PATH" ]]; then
    rm -f "$BIN_PATH"
  fi
  ln -s "${INSTALL_DIR}/finitra" "$BIN_PATH"
  ok "Binário disponível em: $BIN_PATH"

  # Ensure ~/.local/bin is in PATH
  local bashrc="${HOME}/.bashrc"
  if ! grep -qF 'PATH="$HOME/.local/bin:$PATH"' "$bashrc" 2>/dev/null && \
     ! grep -qF '$HOME/.local/bin' "$bashrc" 2>/dev/null; then
    echo "" >> "$bashrc"
    echo '# ~/.local/bin no PATH' >> "$bashrc"
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$bashrc"
    info "~/.local/bin added to PATH in .bashrc"
  fi

  # Alias curto: fi -> finitra
  if ! grep -qF 'alias fi=' "$bashrc" 2>/dev/null; then
    echo "" >> "$bashrc"
    echo "# finitra — Fedora Workstation Bootstrap for Developers" >> "$bashrc"
    echo "alias fi='finitra'" >> "$bashrc"
    ok "Alias 'fi' added to .bashrc"
  else
    warn "Alias 'fi' already present in .bashrc -- not changed"
  fi
}

# =============================================================================
# Main
# =============================================================================
main() {
  echo ""
  echo -e "${CLR_BOLD}${CLR_BLUE}  finitra — Fedora Workstation Bootstrap for Developers${CLR_RESET}"
  echo ""

  _print_banner
  _install_deps
  _setup_repo
  _setup_config
  _setup_bin_and_alias

  echo ""
  ok "Bootstrap concluído!"
  echo ""
  echo -e "  Execute o setup com:"
  echo -e "  ${CLR_GREEN}finitra${CLR_RESET}  (after reopening the terminal)"
  echo ""
  echo -e "  Or with the short alias:"
  echo -e "  ${CLR_GREEN}fi${CLR_RESET}  (short alias)"
  echo ""
}

main "$@"
