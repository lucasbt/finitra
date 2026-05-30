#!/usr/bin/env bash
# =============================================================================
# modules/30-desktop.sh -- GNOME Desktop Customization and Accessibility
#
# Tasks:
#   - System Settings: Night Light, dark theme, text scaling, and window buttons.
#   - Productivity: Fixed workspaces, custom keybindings, and service optimization.
#   - Terminal: Deep Ptyxis terminal profile configuration (fonts, colors, shell).
#   - Search: LocalSearch (Tracker3) tuning for lightweight indexing.
#   - Assets: Installs Nerd Fonts, Microsoft fonts, and curated wallpaper collections.
#   - GNOME Extensions: Installs essential tools (Tweaks, Caffeine, AppIndicator).
# =============================================================================

MODULE_NAME="30-desktop"

# -----------------------------------------------------------------------------
# Helper: run command as user with proper GNOME DBus session
# -----------------------------------------------------------------------------
_run_as_user() {
    local user="$1"
    shift

    local uid
    uid=$(id -u "$user")

    sudo -u "$user" \
        XDG_RUNTIME_DIR="/run/user/$uid" \
        DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" \
        "$@"
}

# Font list
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
	"tile"
	"retro"
	"radium"
	"nord"
	"mountain"
	"monochrome"
	"digital"
	"lightbulb"
	"solarized"
	"spam"
	"unsorted"
  "colorful"
  "jackb"
  "gruvbox"
)

module_30_desktop() {
  log_section "Module: GNOME Desktop and Accessibility"

  _apply_gnome_settings
  _disable_unnecessary_services
  _configure_ptyxis_profile
  _configure_localsearch
  _install_wallpapers
  _install_fonts
  _install_microsoft_fonts

  log_success "Module $MODULE_NAME completed."
}

# -----------------------------------------------------------------------------
_apply_gnome_settings() {
  step "Applying GNOME settings"

  local settings_file="${SCRIPT_DIR}/data/gnome-settings.list"
  if [[ ! -f "$settings_file" ]]; then
    log_error "gnome-settings.list not found: $settings_file"
    return 1
  fi

  apply_gnome_settings_file "$settings_file"

  _configure_custom_keybinding

  ok "GNOME settings applied"
}

# -----------------------------------------------------------------------------
_configure_custom_keybinding(){
    step "Apply custom keybindings..."

    _run_as_user "$SETUP_USER" gsettings set \
      org.gnome.settings-daemon.plugins.media-keys \
      custom-keybindings \
      "['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/ck0/','/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/ck1/']" || true

    # ck0 — Terminal (Ptyxis)
    _run_as_user "$SETUP_USER" gsettings set \
      org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/ck0/ \
      name "Terminal" || true

    _run_as_user "$SETUP_USER" gsettings set \
      org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/ck0/ \
      command "ptyxis" || true

    _run_as_user "$SETUP_USER" gsettings set \
      org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/ck0/ \
      binding "<Super>t" || true

    # ck1 — Screenshot com annotation via Gradia
    _run_as_user "$SETUP_USER" gsettings set \
      org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/ck1/ \
      name "Gradia Screenshot" || true

    _run_as_user "$SETUP_USER" gsettings set \
      org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/ck1/ \
      command "flatpak run be.alexandervanhee.gradia --screenshot=INTERACTIVE" || true

    _run_as_user "$SETUP_USER" gsettings set \
      org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/ck1/ \
      binding "<Super>Print" || true

    ok "Custom keybindings applied"
}

# -----------------------------------------------------------------------------
_disable_unnecessary_services() {
    step "Disable unnecessary services"
    local user="${SETUP_USER:-$USER}"
    local user_home
    user_home=$(getent passwd "$user" | cut -d: -f6)

    _disable_system_svc() {
        local svc="$1"
        if systemctl list-unit-files --no-legend "$svc" 2>/dev/null | grep -q "$svc"; then
            sudo systemctl disable --now "$svc" 2>/dev/null || true
        fi
    }

    _disable_user_svc() {
        local svc="$1"
        _run_as_user "$user" systemctl --user disable --now "$svc" 2>/dev/null || true
    }

    _mask_system_unit() {
        local unit="$1"
        systemctl list-unit-files --no-legend "$unit" 2>/dev/null | grep -q "$unit" && \
            sudo systemctl mask "$unit" 2>/dev/null || true
    }

    _mask_system_unit "dnf5-makecache.timer"
    _mask_system_unit "dnf5-makecache.service"
    _mask_system_unit "NetworkManager-wait-online.service"

    for svc in "abrtd.service" "abrt-ccpp.service" "abrt-oops.service"; do
        _disable_system_svc "$svc"
    done

    _disable_system_svc "ModemManager.service"
    _disable_system_svc "gnome-remote-desktop.service"

    unset -f _disable_system_svc _disable_user_svc _mask_system_unit
    ok "Unnecessary services disabled"
}

# -----------------------------------------------------------------------------
_configure_ptyxis_profile() {
  step "Configuring Ptyxis terminal profile"

  local user="${SETUP_USER:-$USER}"

  local profile_uuid
  profile_uuid=$(_run_as_user "$user" dconf read /org/gnome/Ptyxis/default-profile-uuid 2>/dev/null | tr -d "'")

  if [[ -z "$profile_uuid" || "$profile_uuid" == "''" ]]; then
    log_warn "No default Ptyxis profile found. Skipping."
    return 0
  fi

  local profile_path="/org/gnome/Ptyxis/Profiles/${profile_uuid}/"
  local schema="org.gnome.Ptyxis.Profile:${profile_path}"

  _ptyxis_set() {
    local key="$1"
    local value="$2"

    gsettings set "$schema" "$key" "$value" 2>/dev/null || \
    _run_as_user "$user" dconf write "${profile_path}${key}" "$value" 2>/dev/null || true
  }

  _ptyxis_set "palette" "'${PTYXIS_PALETTE:-One Half Black}'"
  _ptyxis_set "scrollback-lines" "${PTYXIS_SCROLLBACK_LINES:-10000}"
  _ptyxis_set "opacity" "${PTYXIS_OPACITY:-1.0}"
  _ptyxis_set "bold-is-bright" "${PTYXIS_BOLD_IS_BRIGHT:-true}"
  _ptyxis_set "login-shell" "${PTYXIS_LOGIN_SHELL:-true}"

  if [[ "${PTYXIS_USE_SYSTEM_FONT:-false}" == "false" ]]; then
    _ptyxis_set "font-name" "'${PTYXIS_FONT_NAME:-JetBrains Mono 12}'"
  fi

  echo 'Defaults pwfeedback' | sudo EDITOR='tee -a' visudo

  unset -f _ptyxis_set
  ok "Ptyxis terminal profile configured"
}

# -----------------------------------------------------------------------------
_configure_localsearch() {
    step "Configuring LocalSearch (lightweight indexing)"
    local user="${SETUP_USER:-$USER}"

    gs_set() {
        _run_as_user "$user" gsettings set "$1" "$2" "$3" 2>/dev/null || true
    }

    gs_set "org.freedesktop.Tracker3.Miner.Files" "index-single-directories" "[]"
    gs_set "org.freedesktop.Tracker3.Miner.Files" "index-recursive-directories" "[]"
    gs_set "org.freedesktop.Tracker3.Miner.Files" "crawling-interval" "-2"

    ok "LocalSearch configured"
}

# -----------------------------------------------------------------------------
_install_wallpapers() {
    step "Installing wallpapers collection"
    if [[ "${INSTALL_WALLPAPERS:-false}" != "true" ]]; then
        skip "Wallpaper install disabled in config"
        return
    fi

    local collection_dir="${WALLPAPERS_DIR}/collection"
    local walls_repo="https://github.com/lucasbt/walls"
    local temp_dir="${CACHE_DIR}/walls-repo"

    # Considera instalado se o diretório existir e não estiver vazio
    if [[ -d "$collection_dir" && -n "$(ls -A "$collection_dir" 2>/dev/null)" ]]; then
        skip "Wallpapers collection already exists"
        return
    fi
    
    mkdir -p "$collection_dir"

    if ! ask_yes_no "The wallpaper download may be very large. Proceed?" "n"; then
        skip "Wallpaper download skipped"
        return
    fi

    log_info "Cloning wallpapers repository (sparse, no blobs)..."
    rm -rf "$temp_dir"
    git clone --filter=blob:none --no-checkout "$walls_repo" "$temp_dir"

    pushd "$temp_dir" > /dev/null || return 1

    git sparse-checkout init --cone

    local failed=()
    for folder in "${WALLS_FOLDERS[@]}"; do
        log_info "Downloading folder: $folder"
        if git sparse-checkout set "$folder" && git checkout HEAD; then
            mv "$folder" "$collection_dir/"
            log_info "Installed: $folder → $collection_dir"
        else
            log_warn "Failed to download folder: $folder"
            failed+=("$folder")
        fi
    done

    popd > /dev/null
    rm -rf "$temp_dir"

    if [[ ${#failed[@]} -gt 0 ]]; then
        log_warn "Some folders failed to download: ${failed[*]}"
    fi

    ok "Wallpapers installed to $collection_dir"
}

# -----------------------------------------------------------------------------
_install_fonts() {
    step "Installing Nerd Fonts collection"
    local fonts_nerd_url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download"

    local fonts_dir="$HOME/.local/share/fonts/nerd-fonts"
    mkdir -p "$fonts_dir"

    # Considera instalado se o diretório existir e não estiver vazio
    if [[ -d "$fonts_dir" && -n "$(ls -A "$fonts_dir" 2>/dev/null)" ]]; then
        skip "Nerd Fonts collection already exists"
        return
    fi
    
    mkdir -p "$fonts_dir"

    log_info "Download Nerd Fonts..."
    for font in "${FONTS[@]}"; do
        zip_file="${font}.zip"
        url="${fonts_nerd_url}/${zip_file}"
        log_info "Download $font..."
        curl -fLo "/tmp/${zip_file}" "$url"
        log_info "Extract $font..."
        unzip -o "/tmp/${zip_file}" -d "$fonts_dir" >/dev/null
        rm "/tmp/${zip_file}"
    done

    log_info "Updating fonts cache..."
    fc-cache -fv >/dev/null

    ok "Nerd Fonts installed to $fonts_dir"
}

# -----------------------------------------------------------------------------
_install_microsoft_fonts() {
    step "Installing Microsoft core fonts"
    if [[ "${INSTALL_MICROSOFT_FONTS:-true}" != "true" ]]; then
        skip "Microsoft fonts install disabled in config"
        return
    fi    
 
    local sentinel="/usr/share/fonts/msttcore/arial.ttf"
    if [[ -f "$sentinel" ]]; then
        skip "Microsoft fonts already installed"
        return
    fi
 
    local installer_url="https://downloads.sourceforge.net/project/mscorefonts2/rpms/msttcore-fonts-installer-2.6-1.noarch.rpm"
    local installer_rpm="${CACHE_DIR}/msttcore-fonts-installer.rpm"
 
    dnf_install cabextract
 
    log_info "Downloading msttcore-fonts-installer..."
    if curl -fsSL --retry 3 --retry-delay 5 --max-time 60 \
            -o "$installer_rpm" "$installer_url"; then
        sudo rpm -i --nosignature --nodigest "$installer_rpm" && \
            sudo fc-cache -f /usr/share/fonts/msttcore 2>/dev/null || true
        rm -f "$installer_rpm"
        ok "Microsoft fonts installed"
    else
        rm -f "$installer_rpm" 2>/dev/null || true
        log_warn "Could not download Microsoft fonts after 3 attempts"
        log_warn "To install manually later:"
        log_warn "  sudo dnf install cabextract xorg-x11-font-utils"
        log_warn "  sudo rpm -i --nosignature --nodigest '$installer_url'"
    fi
}

# -----------------------------------------------------------------------------
# Standalone entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

  source "${SCRIPT_DIR}/utils.sh"

  # Exporta automaticamente todas as variáveis carregadas
  set -a
  source "${SCRIPT_DIR}/initora-default.config"
  [[ -f "${SETUP_HOME}/.config/initora/initora.config" ]] && \
    source "${SETUP_HOME}/.config/initora/initora.config"
  set +a

  module_30_desktop
fi