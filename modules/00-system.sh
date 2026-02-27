#!/usr/bin/env bash
# =============================================================================
# modules/00-system.sh -- System base (REQUIRED)
# Configures DNF, RPM Fusion, ZRAM, and runs the initial system update
# =============================================================================

MODULE_NAME="00-system"

module_00_system() {
  log_section "Module: System Base"

  _configure_dnf
  _system_update
  _add_rpmfusion
  _install_base_packages
  _check_zram
  _setup_directories

  log_success "Module $MODULE_NAME completed."
}

# -----------------------------
# Firmware
# -----------------------------
#
_configure_firmware() {
  step "Updating firmware"
  if [ "${FEDORALAUNCH_INSTALL_PROPRIETARY_FIRMWARE}" != true ]; then
      skip "Skipping firmware updates."
      return
  fi

  dnf_install linux-firmware
  sudo fwupdmgr refresh --force || true
  sudo fwupdmgr update || true

  ok "Firmware updated."
}

# -----------------------------------------------------------------------------
_configure_dnf() {
  step "Configuring DNF for better performance"

  local dnf_conf="/etc/dnf/dnf.conf"
  run_as_root backup_file "$dnf_conf"

  local max_p="${DNF_MAX_PARALLEL:-10}"
  local keepcache="${DNF_KEEPCACHE:-false}"

  # Idempotent: remove existing entries then re-add
  for param in \
    "max_parallel_downloads=${max_p}" \
    "fastestmirror=True" \
    "defaultyes=True" \
    "color=always" \
    "metadata_expire=never" \
    "install_weak_deps=False" \
    "clean_requirements_on_remove=True" \
    "keepcache=${keepcache}"; do
    local key="${param%%=*}"
    run_as_root sed -i "/^${key}=/d" "$dnf_conf"
    echo "$param" | run_as_root tee -a "$dnf_conf" > /dev/null
  done

  ok "DNF configured"
}

# -----------------------------------------------------------------------------
_add_rpmfusion() {
  step "Adding RPM Fusion repositories"

  local fedora_ver
  fedora_ver=$(rpm -E %fedora)

  if [[ "${ENABLE_RPMFUSION_FREE:-true}" == "true" ]]; then
    if ! dnf repolist --enabled 2>/dev/null | grep -q "rpmfusion-free"; then
      log_info "Installing RPM Fusion Free..."
      run_as_root dnf install -y \
        "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${fedora_ver}.noarch.rpm"
    else
      skip "RPM Fusion Free already present"
    fi
  fi

  if [[ "${ENABLE_RPMFUSION_NONFREE:-true}" == "true" ]]; then
    if ! dnf repolist --enabled 2>/dev/null | grep -q "rpmfusion-nonfree"; then
      log_info "Installing RPM Fusion Non-Free..."
      run_as_root dnf install -y \
        "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${fedora_ver}.noarch.rpm"
    else
      skip "RPM Fusion Non-Free already present"
    fi
  fi

  run_as_root dnf install -y \
    rpmfusion-free-release-tainted \
    rpmfusion-nonfree-release-tainted \
    rpmfusion-free-appstream-data \
    rpmfusion-nonfree-appstream-data 2>/dev/null || true

  ok "RPM Fusion configured"
}

# -----------------------------------------------------------------------------
_system_update() {
  step "Updating system packages"
  run_as_root dnf upgrade -y --refresh
  run_as_root dnf group upgrade core -y
  ok "System updated"
}

# -----------------------------------------------------------------------------
_check_zram() {
  step "Checking ZRAM configuration"

  # Fedora 33+ ships zram-generator (systemd-zram-generator) by default
  if is_rpm_installed "zram-generator" || is_rpm_installed "systemd-zram-generator"; then
    local zram_active
    zram_active=$(zramctl 2>/dev/null | grep -c "^/dev/zram" || echo 0)
    if [[ "$zram_active" -gt 0 ]]; then
      ok "ZRAM already active: $(zramctl 2>/dev/null)"
    else
      log_info "zram-generator installed but inactive -- checking config..."
      local zram_conf="/etc/systemd/zram-generator.conf"
      if [[ ! -f "$zram_conf" ]]; then
        run_as_root tee "$zram_conf" > /dev/null << 'ZRAMEOF'
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
ZRAMEOF
        log_info "ZRAM config created. Reboot to activate."
      fi
    fi
  else
    log_info "zram-generator not found. Installing..."
    dnf_install zram-generator
    if [[ ! -f "/etc/systemd/zram-generator.conf" ]]; then
      run_as_root tee /etc/systemd/zram-generator.conf > /dev/null << 'ZRAMEOF'
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
ZRAMEOF
    fi
    run_as_root systemctl daemon-reload
    run_as_root systemctl start /dev/zram0 2>/dev/null || true
    ok "ZRAM installed and configured"
  fi
}

# -----------------------------------------------------------------------------
_setup_directories() {
  step "Creating setup directories"
  local user_home="${SETUP_HOME:-$HOME}"
  local dirs=(
    "$user_home/.local/share/finitra"
    "$user_home/.config/finitra"
    "$user_home/.cache/finitra"
    "$user_home/.config/mise"
  )
  for d in "${dirs[@]}"; do
    [[ -d "$d" ]] || sudo -u "${SETUP_USER:-$USER}" mkdir -p "$d"
  done
  ok "Directories ready"
}


#
# -----------------------------
# Base Packages
# -----------------------------
#
_install_base_packages() {
  step "Installing essential dependencies"

  dnf_install \
      flatpak curl wget git unzip tar gzip ca-certificates gnupg \
      dnf-plugins-core lsb-release dconf-editor util-linux \
      fontconfig fzf gnome-keyring libgnome-keyring \
      fedora-workstation-repositories openssl

  ok "Base packages installed."
}

# Standalone entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  source "${SCRIPT_DIR}/utils.sh"
  source "${SCRIPT_DIR}/finitra-default.config"
  [[ -f "${SETUP_HOME}/.config/finitra/finitra.config" ]] && \
    source "${SETUP_HOME}/.config/finitra/finitra.config"
  module_00_system
fi
