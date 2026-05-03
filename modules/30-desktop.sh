#!/usr/bin/env bash
# =============================================================================
# modules/30-desktop.sh -- GNOME Desktop and Accessibility
# =============================================================================

MODULE_NAME="30-desktop"

FONTS=(
  "FiraCode"
  "JetBrainsMono"
  "Hack"
  "Meslo"
  "SourceCodePro"
  "UbuntuMono"
  "CascadiaCode"
)

WALLS_FOLDERS=(
  "tile" "retro" "radium" "nord" "mountain"
  "monochrome" "digital" "lightbulb"
  "solarized" "spam" "unsorted"
)

# -----------------------------------------------------------------------------
# FIX CRÍTICO: garante DBUS para gsettings/dconf
# -----------------------------------------------------------------------------
export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u ${SETUP_USER:-$USER})/bus"

# -----------------------------------------------------------------------------
module_30_desktop() {
  log_section "Module: GNOME Desktop and Accessibility"

  _apply_gnome_settings
  _disable_unnecessary_services
  _configure_ptyxis_profile
  _configure_localsearch
  _configure_gnome_extensions_deps
  _install_wallpapers
  _install_fonts
  _install_microsoft_fonts

  log_success "Module $MODULE_NAME completed."
}

# -----------------------------------------------------------------------------
_disable_unnecessary_services() {
    step "Disable unnecessary services"

    local user="${SETUP_USER:-$USER}"
    local user_home
    user_home=$(getent passwd "$user" | cut -d: -f6)

    _disable_system_svc() {
        systemctl disable --now "$1" 2>/dev/null || true
    }

    _disable_user_svc() {
        sudo -u "$user" systemctl --user disable --now "$1" 2>/dev/null || true
    }

    _mask_system_unit() {
        systemctl disable --now "$1" 2>/dev/null || true
        systemctl mask "$1" 2>/dev/null || true
    }

    _mask_system_unit "dnf5-makecache.timer"
    _mask_system_unit "dnf5-makecache.service"
    _mask_system_unit "NetworkManager-wait-online.service"

    for svc in abrtd.service abrt-oops.service abrt-vmcore.service abrt-xorg.service abrt-journal-core.service; do
        _disable_system_svc "$svc"
    done

    _disable_system_svc "ModemManager.service"
    _disable_system_svc "gnome-remote-desktop.service"

    # tracker3 stop seguro
    if command -v tracker3 &>/dev/null; then
        sudo -u "$user" tracker3 daemon -t 2>/dev/null || true
    fi

    mkdir -p "$user_home/.config/autostart"

    cat > "$user_home/.config/autostart/tracker-disable.desktop" << 'EOF'
[Desktop Entry]
Hidden=true
X-GNOME-Autostart-enabled=false
EOF

    _disable_user_svc "evolution-source-registry.service"
    _disable_user_svc "evolution-addressbook-factory.service"
    _disable_user_svc "evolution-calendar-factory.service"

    log_success "Unnecessary services disabled"
}

# -----------------------------------------------------------------------------
_apply_gnome_settings() {
  step "Applying GNOME settings"

  local settings_file="${SCRIPT_DIR}/data/gnome-settings.list"
  [[ -f "$settings_file" ]] || { log_error "missing gnome settings"; return 1; }

  apply_gnome_settings_file "$settings_file"

  _configure_custom_keybinding

  ok "GNOME settings applied"
}

# -----------------------------------------------------------------------------
_configure_custom_keybinding(){
    log_info "Apply custom keybindings..."

    local user="${SETUP_USER:-$USER}"

    run_gsettings() {
        sudo -u "$user" \
          DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
          gsettings "$@"
    }

    run_gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings \
      "['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/ck0/','/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/ck1/']"

    run_gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/ck0/ name "Terminal"
    run_gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/ck0/ command "ptyxis"
    run_gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/ck0/ binding "<Super>t"

    run_gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/ck1/ name "Gradia Screenshot"
    run_gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/ck1/ command "flatpak run be.alexandervanhee.gradia --screenshot=INTERACTIVE"
    run_gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/ck1/ binding "<Super>Print"
}

# -----------------------------------------------------------------------------
_configure_localsearch() {
    step "Configuring LocalSearch"

    local user="${SETUP_USER:-$USER}"

    sudo -u "$user" gsettings set org.freedesktop.Tracker3.Miner.Files index-single-directories "[]"
    sudo -u "$user" gsettings set org.freedesktop.Tracker3.Miner.Files index-recursive-directories "[]"

    sudo -u "$user" systemctl --user disable --now localsearch-miner@rss.service 2>/dev/null || true
    sudo -u "$user" systemctl --user disable --now tracker-miner-rss-3.service 2>/dev/null || true

    ok "LocalSearch configured"
}

# -----------------------------------------------------------------------------
_configure_ptyxis_profile() {
  step "Configuring Ptyxis"

  local user="${SETUP_USER:-$USER}"

  local uuid
  uuid=$(sudo -u "$user" dconf read /org/gnome/Ptyxis/default-profile-uuid 2>/dev/null | tr -d "'")

  [[ -z "$uuid" ]] && { log_warn "No Ptyxis profile"; return; }

  local path="/org/gnome/Ptyxis/Profiles/${uuid}/"

  sudo -u "$user" DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
    gsettings set org.gnome.Ptyxis.Profile:${path} palette "'One Half Black'" 2>/dev/null || true

  sudo -u "$user" DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
    gsettings set org.gnome.Ptyxis.Profile:${path} scrollback-lines 10000 2>/dev/null || true

  ok "Ptyxis configured"
}

# -----------------------------------------------------------------------------
_configure_gnome_extensions_deps() {
  step "GNOME extensions"

  dnf_install \
    gnome-extensions-app \
    gnome-shell-extension-appindicator \
    gnome-tweaks \
    gnome-shell-extension-caffeine \
    gnome-shell-extension-auto-move-windows \
    gnome-shell-extension-just-perfection \
    gnome-shell-extension-no-overview \
    gnome-shell-extension-user-theme

  ok "Extensions installed"
}

# -----------------------------------------------------------------------------
_install_wallpapers() {
    if [[ "${INSTALL_WALLPAPERS:-false}" != "true" ]]; then
        skip "Wallpaper install disabled"
        return
    fi

    local collection_dir="${WALLPAPERS_DIR}/collection"
    local repo="https://github.com/lucasbt/walls"
    local tmp="${CACHE_DIR}/walls-repo"

    [[ -d "$collection_dir" && -n "$(ls -A "$collection_dir" 2>/dev/null)" ]] && {
        skip "Wallpapers already exist"
        return
    }

    step "Installing wallpapers"

    if ! ask_yes_no "The wallpaper download may be very large. Proceed?" "n"; then
        skip "Wallpaper skipped"
        return
    fi

    rm -rf "$tmp"
    git clone --filter=blob:none --no-checkout "$repo" "$tmp"

    git -C "$tmp" sparse-checkout init --cone

    local failed=()

    for f in "${WALLS_FOLDERS[@]}"; do
        if git -C "$tmp" sparse-checkout set "$f" \
           && git -C "$tmp" checkout HEAD -- "$f"; then

            mv "$tmp/$f" "$collection_dir/" 2>/dev/null || failed+=("$f")
        else
            failed+=("$f")
        fi
    done

    rm -rf "$tmp"

    [[ ${#failed[@]} -gt 0 ]] && log_warn "Failed: ${failed[*]}"

    ok "Wallpapers installed"
}

# -----------------------------------------------------------------------------
_install_fonts() {
    step "Nerd Fonts"

    local dir="$HOME/.local/share/fonts/nerd"
    mkdir -p "$dir"

    local url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download"

    for f in "${FONTS[@]}"; do
        curl -fLo "/tmp/$f.zip" "$url/$f.zip" || continue
        unzip -o "/tmp/$f.zip" -d "$dir" >/dev/null
        rm "/tmp/$f.zip"
    done

    fc-cache -fv >/dev/null

    ok "Fonts installed"
}

# -----------------------------------------------------------------------------
_install_microsoft_fonts() {
    [[ "${INSTALL_MICROSOFT_FONTS:-true}" != "true" ]] && return

    step "Microsoft fonts"

    dnf_install cabextract

    local url="https://downloads.sourceforge.net/project/mscorefonts2/rpms/msttcore-fonts-installer-2.6-1.noarch.rpm"
    local rpm="/tmp/mscorefonts.rpm"

    curl -fLo "$rpm" "$url"
    sudo rpm -i --nosignature --nodigest "$rpm" || true

    ok "Microsoft fonts installed"
}

# -----------------------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

  source "${SCRIPT_DIR}/utils.sh"

  set -a
  source "${SCRIPT_DIR}/finitra-default.config"
  [[ -f "${SETUP_HOME}/.config/finitra/finitra.config" ]] && \
    source "${SETUP_HOME}/.config/finitra/finitra.config"
  set +a

  module_30_desktop
fi