#!/usr/bin/env bash
# =============================================================================
# modules/30-desktop.sh -- GNOME Desktop and Accessibility
# Night Light, fixed workspaces, dark theme, text scale,
# Ptyxis terminal profile, LocalSearch tuning
# =============================================================================

MODULE_NAME="30-desktop"

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
)

module_30_desktop() {
  log_section "Module: GNOME Desktop and Accessibility"

  _apply_gnome_settings
  _disable_unnecessary_services
  _configure_ptyxis_profile
  _configure_localsearch
  _configure_gnome_extensions_deps
  _install_wallpapers

  log_success "Module $MODULE_NAME completed."
}

# -----------------------------------------------------------------------------
_disable_unnecessary_services() {
    step "Disable unnecessary services"
    local user="${SETUP_USER:-$USER}"

    # -------------------------------------------------------------------------
    # Helper: disable system service only if it exists and is enabled
    # -------------------------------------------------------------------------
    _disable_system_svc() {
        local svc="$1"
        if systemctl list-unit-files --no-legend "$svc" 2>/dev/null | grep -q "$svc"; then
            sudo systemctl disable --now "$svc" 2>/dev/null && \
                log_info "Disabled system service: $svc" || \
                log_warn "Could not disable: $svc (may already be inactive)"
        else
            log_info "Skipped (not found): $svc"
        fi
    }

    # Helper: disable user service only if it exists
    _disable_user_svc() {
        local svc="$1"
        if sudo -u "$user" systemctl --user list-unit-files --no-legend "$svc" 2>/dev/null | grep -q "$svc"; then
            sudo -u "$user" systemctl --user disable --now "$svc" 2>/dev/null && \
                log_info "Disabled user service: $svc" || \
                log_warn "Could not disable: $svc"
        else
            log_info "Skipped (not found): $svc"
        fi
    }

    # -------------------------------------------------------------------------
    # Helper: disable + mask system timer/service se existir
    # -------------------------------------------------------------------------
    _mask_system_unit() {
        local unit="$1"
        if systemctl list-unit-files --no-legend "$unit" 2>/dev/null | grep -q "$unit"; then
            sudo systemctl disable --now "$unit" 2>/dev/null || true
            sudo systemctl mask "$unit" 2>/dev/null && \
                log_info "Masked: $unit" || \
                log_warn "Could not mask: $unit"
        else
            log_info "Skipped (not found): $unit"
        fi
    }

    # -------------------------------------------------------------------------
    # DNF5 makecache — sincronização de metadados em background
    # No Fedora 41+ substituiu o dnf-makecache.timer do DNF4
    # Mascarar garante que updates de pacote não reativem
    # -------------------------------------------------------------------------
    _mask_system_unit "dnf5-makecache.timer"
    _mask_system_unit "dnf5-makecache.service"

    # -------------------------------------------------------------------------
    # GNOME initial setup — oneshot, já rodou após primeiro login
    # Desabilitar é seguro, apenas evita reexecução em edge cases
    # -------------------------------------------------------------------------
    _disable_system_svc "gnome-initial-setup-copy-worker.service"

    # -------------------------------------------------------------------------
    # Evolution Data Server — calendário/contatos, não usado em setup de dev
    # Seguro desabilitar: GNOME Shell não depende desses serviços
    # -------------------------------------------------------------------------
    _disable_user_svc "evolution-source-registry.service"
    _disable_user_svc "evolution-addressbook-factory.service"
    _disable_user_svc "evolution-calendar-factory.service"

    # -------------------------------------------------------------------------
    # GNOME Software autostart — no Fedora 43 não há mais gnome-software-service.service
    # O controle correto é via arquivo de autostart XDG
    # -------------------------------------------------------------------------
    local gnome_sw_autostart="/etc/xdg/autostart/org.gnome.Software.desktop"
    if [[ -f "$gnome_sw_autostart" ]]; then
        sudo rm -f "$gnome_sw_autostart" && \
            log_info "Removed GNOME Software autostart: $gnome_sw_autostart"
    else
        log_info "Skipped (not found): org.gnome.Software.desktop autostart"
    fi
    # Fallback: caso ainda exista como serviço de usuário em alguma variante
    _disable_user_svc "gnome-software-service.service"

    # -------------------------------------------------------------------------
    # ABRT — relatórios automáticos de crash
    # Existe no Fedora 43, seguro desabilitar em ambiente de dev
    # -------------------------------------------------------------------------
    local abrt_services=(
        "abrtd.service"
        "abrt-ccpp.service"
        "abrt-oops.service"
        "abrt-xorg.service"
        "abrt-journal-core.service"
    )
    for svc in "${abrt_services[@]}"; do
        _disable_system_svc "$svc"
    done

    log_success "Unnecessary services disabled"
    log_warn "Background auto-updates disabled. Update manually with: sudo dnf upgrade"
}

# -----------------------------------------------------------------------------
_apply_gnome_settings() {
  step "Applying GNOME settings"

  local settings_file="${SCRIPT_DIR}/data/gnome-settings.list"
  if [[ ! -f "$settings_file" ]]; then
    log_error "gnome-settings.list not found: $settings_file"
    return 1
  fi

  # Ensure a D-Bus session is available (needed when running via sudo/TTY)
  if ! sudo -u "${SETUP_USER:-$USER}" dbus-run-session gsettings list-schemas &>/dev/null; then
    log_warn "D-Bus session not available. Attempting with dbus-launch..."
    export DBUS_SESSION_BUS_ADDRESS
    DBUS_SESSION_BUS_ADDRESS=$(sudo -u "${SETUP_USER:-$USER}" \
      dbus-launch --exit-with-session bash -c 'echo $DBUS_SESSION_BUS_ADDRESS' 2>/dev/null || true)
  fi

  apply_gnome_settings_file "$settings_file"

  ok "GNOME settings applied"
}

# -----------------------------------------------------------------------------
_configure_localsearch() {
    step "Configuring LocalSearch (lightweight indexing)"
    local user="${SETUP_USER:-$USER}"
    local user_home
    user_home=$(getent passwd "$user" | cut -d: -f6)

    # -------------------------------------------------------------------------
    # Detect service generation
    # -------------------------------------------------------------------------
    local miners_service=""
    if sudo -u "$user" systemctl --user status localsearch-3.service &>/dev/null; then
        miners_service="localsearch3"
        log_info "Detected: localsearch3 (Fedora 41+)"
    elif sudo -u "$user" systemctl --user status tracker-miner-fs-3.service &>/dev/null; then
        miners_service="tracker3"
        log_info "Detected: tracker-miner-fs-3"
    else
        log_warn "Could not detect localsearch/tracker service. Applying gsettings only."
        miners_service="unknown"
    fi

    # -------------------------------------------------------------------------
    # Limit file indexing via gsettings
    # -------------------------------------------------------------------------
    if [[ "${LOCALSEARCH_DISABLE_FILES:-true}" == "true" ]]; then
        gs_set "org.freedesktop.Tracker3.Miner.Files" "index-single-directories"    "''" 2>/dev/null || true
        gs_set "org.freedesktop.Tracker3.Miner.Files" "index-recursive-directories" "''" 2>/dev/null || true
        gs_set "org.freedesktop.Tracker3.Miner.Files" "crawling-interval"           "-2" 2>/dev/null || true
        log_info "File indexing limited via gsettings"
    fi

    # Keep app search enabled (used by GNOME Shell and Nautilus)
    gs_set "org.gnome.desktop.search-providers" "disable-external" "false" 2>/dev/null || true

    # -------------------------------------------------------------------------
    # Disable heavy background miners (RSS, writeback, control, XDG portal)
    # Use mask to prevent DBus from silently reactivating them
    # -------------------------------------------------------------------------
    local to_disable=(
        "localsearch-miner@rss.service"
        "tracker-miner-rss-3.service"
    )

    # Services to mask entirely — heavy, not needed for dev workflow
    # localsearch-3.service is intentionally kept to preserve app search
    local to_mask=(
        "localsearch-writeback-3.service"
        "localsearch-control-3.service"
        "tinysparql-xdg-portal-3.service"
    )

    # Add generation-specific writeback/control variants
    if [[ "$miners_service" == "tracker3" ]]; then
        to_mask+=(
            "tracker-writeback-3.service"
        )
    fi

    for svc in "${to_disable[@]}"; do
        if sudo -u "$user" systemctl --user is-enabled "$svc" &>/dev/null; then
            sudo -u "$user" systemctl --user disable --now "$svc" 2>/dev/null || true
            log_info "Disabled: $svc"
        fi
    done

    for svc in "${to_mask[@]}"; do
        # mask only if not already masked
        if sudo -u "$user" systemctl --user is-enabled "$svc" 2>/dev/null | grep -qv "masked"; then
            sudo -u "$user" systemctl --user mask "$svc" 2>/dev/null || true
            log_info "Masked: $svc"
        fi
    done

    # -------------------------------------------------------------------------
    # Remove media/document extract rules (heavy on CPU/disk)
    # Preserves app-info rules so GNOME Shell app search keeps working
    # -------------------------------------------------------------------------
    local extract_rules_dir="/usr/share/localsearch3/extract-rules"
    local extract_backup_dir="/var/lib/localsearch3-extract-rules-backup"

    if [[ -d "$extract_rules_dir" ]]; then
        sudo mkdir -p "$extract_backup_dir"

        # Move only the heavy media/document rules; keep app-info rules
        local heavy_rule_patterns=(
            "*audio*"
            "*video*"
            "*image*"
            "*pdf*"
            "*msoffice*"
            "*odf*"
            "*png*"
            "*jpeg*"
            "*gif*"
            "*tiff*"
            "*mp3*"
            "*flac*"
        )

        for pattern in "${heavy_rule_patterns[@]}"; do
            # shellcheck disable=SC2086
            sudo find "$extract_rules_dir" -maxdepth 1 -iname $pattern -exec \
                mv -v {} "$extract_backup_dir/" \; 2>/dev/null && \
                log_info "Backed up extract rule: $pattern" || true
        done

        log_info "Heavy extract rules moved to $extract_backup_dir (app-info rules preserved)"
        log_warn "If dnf updates localsearch, re-run this step — rules may be restored by package manager"
    fi

    # -------------------------------------------------------------------------
    # Reset and clean localsearch/tracker database and cache
    # -------------------------------------------------------------------------
    if [[ "${LOCALSEARCH_RESET_DB:-true}" == "true" ]]; then
        if command -v localsearch3 &>/dev/null; then
            sudo -u "$user" localsearch3 reset --filesystem 2>/dev/null || true
            log_info "LocalSearch database reset"
        elif command -v tracker3 &>/dev/null; then
            sudo -u "$user" tracker3 reset --filesystem 2>/dev/null || true
            log_info "Tracker3 database reset"
        fi

        # Clean cache dirs for both naming conventions
        local cache_dirs=(
            "$user_home/.cache/tracker3"
            "$user_home/.cache/localsearch3"
            "$user_home/.local/share/tracker3"
            "$user_home/.local/share/localsearch3"
        )

        for cache_dir in "${cache_dirs[@]}"; do
            if [[ -d "$cache_dir" ]]; then
                rm -rf "$cache_dir"
                log_info "Removed cache: $cache_dir"
            fi
        done
    fi

    ok "LocalSearch configured (lightweight mode, app search preserved, media indexing disabled)"
}

# -----------------------------------------------------------------------------
_configure_ptyxis_profile() {
  step "Configuring Ptyxis terminal profile (font, palette, scrollback, opacity)"

  local user="${SETUP_USER:-$USER}"

  # Read the existing default profile UUID, or create a new profile
  local profile_uuid
  profile_uuid=$(sudo -u "$user" dconf read /org/gnome/Ptyxis/default-profile-uuid 2>/dev/null \
    | tr -d "'")

  if [[ -z "$profile_uuid" ]]; then
    log_info "No Ptyxis profile found. Creating default profile..."
    profile_uuid="finitra-default"

    sudo -u "$user" dconf write /org/gnome/Ptyxis/profile-uuids "['${profile_uuid}']"
    sudo -u "$user" dconf write /org/gnome/Ptyxis/default-profile-uuid "'${profile_uuid}'"
    sudo -u "$user" dconf write "/org/gnome/Ptyxis/Profiles/${profile_uuid}/label" "'Default'"
    log_info "Profile created with UUID: $profile_uuid"
  else
    log_info "Existing Ptyxis profile detected: $profile_uuid"
  fi

  local profile_path="/org/gnome/Ptyxis/Profiles/${profile_uuid}/"
  local schema="org.gnome.Ptyxis.Profile:${profile_path}"

  _ptyxis_set() {
    local key="$1" value="$2"
    if sudo -u "$user" gsettings set "$schema" "$key" "$value" 2>/dev/null; then
      log_success "Ptyxis profile: $key = $value"
    else
      log_warn "Ptyxis profile: failed to set $key = $value"
    fi
  }

  _ptyxis_set "palette"          "'${PTYXIS_PALETTE:-One Half Black}'"
  _ptyxis_set "use-system-font"  "${PTYXIS_USE_SYSTEM_FONT:-false}"
  _ptyxis_set "scrollback-lines" "${PTYXIS_SCROLLBACK_LINES:-10000}"
  _ptyxis_set "opacity"          "${PTYXIS_OPACITY:-1.0}"
  _ptyxis_set "bold-is-bright"   "${PTYXIS_BOLD_IS_BRIGHT:-true}"
  _ptyxis_set "login-shell"      "${PTYXIS_LOGIN_SHELL:-true}"

  if [[ "${PTYXIS_USE_SYSTEM_FONT:-false}" == "false" ]]; then
    _ptyxis_set "font-name" "'${PTYXIS_FONT_NAME:-JetBrains Mono 12}'"
  fi

  unset -f _ptyxis_set
  ok "Ptyxis profile configured"
}

# -----------------------------------------------------------------------------
_configure_gnome_extensions_deps() {
  step "Installing GNOME extensions dependencies"

  dnf_install \
    gnome-extensions-app \
    gnome-shell-extension-appindicator \
    gnome-tweaks

  ok "GNOME extension tools installed"
}

# -----------------------------------------------------------------------------
_install_wallpapers() {
    if [[ "${INSTALL_WALLPAPERS:-true}" != "true" ]]; then
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

    step "Installing wallpapers collection"
    mkdir -p "$collection_dir"

    if ! ask_yes_no "The wallpaper download may be very large. Proceed?" "n"; then
        skip "Wallpaper download skipped"
        return
    fi

    # Garantir git disponível
    if ! command -v git &>/dev/null; then
        log_info "Installing git (required for wallpaper download)..."
        sudo dnf install -y git
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

# Standalone entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  source "${SCRIPT_DIR}/utils.sh"
  source "${SCRIPT_DIR}/finitra-default.config"
  [[ -f "${SETUP_HOME}/.config/finitra/finitra.config" ]] && \
    source "${SETUP_HOME}/.config/finitra/finitra.config"
  module_30_desktop
fi
