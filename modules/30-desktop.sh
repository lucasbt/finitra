#!/usr/bin/env bash
# =============================================================================
# modules/30-desktop.sh -- GNOME Desktop and Accessibility
# Night Light, fixed workspaces, dark theme, text scale,
# Ptyxis terminal profile, LocalSearch tuning
# =============================================================================

MODULE_NAME="30-desktop"

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
)

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
    # ABRT — relatórios automáticos de crash
    # Existe no Fedora 43, seguro desabilitar em ambiente de dev
    # -------------------------------------------------------------------------
    local abrt_services=(
        "abrtd.service"
        "abrt-ccpp.service"
        "abrt-oops.service"
        "abrt-vmcore.service"
        "abrt-xorg.service"
        "abrt-journal-core.service"
    )
    for svc in "${abrt_services[@]}"; do
        _disable_system_svc "$svc"
    done

    # -------------------------------------------------------------------------
    # ModemManager — gerenciador de banda larga móvel
    # Seguro desabilitar em máquinas sem modem/SIM
    # -------------------------------------------------------------------------
    _disable_system_svc "ModemManager.service"

    # -------------------------------------------------------------------------
    # NetworkManager-wait-online — atrasa boot em 15-20s aguardando rede
    # Mascarar evita que seja reativado por dependência de outros serviços
    # -------------------------------------------------------------------------
    _mask_system_unit "NetworkManager-wait-online.service"

    # -------------------------------------------------------------------------
    # GNOME Remote Desktop — não usado em ambiente de dev local
    # -------------------------------------------------------------------------
    _disable_system_svc "gnome-remote-desktop.service"

    # -------------------------------------------------------------------------
    # Tracker legado (v1/v2) — indexação pesada de arquivos
    # Presente em sistemas que fizeram upgrade de versões anteriores
    # O LocalSearch/Tracker3 é tratado separadamente em _configure_localsearch
    # -------------------------------------------------------------------------
    local tracker_legacy_services=(
        "tracker-store.service"
        "tracker-miner-fs.service"
    )
    for svc in "${tracker_legacy_services[@]}"; do
        _disable_system_svc "$svc"
    done

    # Encerrar daemon do tracker3 se estiver rodando
    if command -v tracker3 &>/dev/null; then
        sudo -u "$user" tracker3 daemon -t 2>/dev/null || true
        log_info "Tracker3 daemon stopped"
    fi

    # Impedir autostart do tracker via arquivo XDG
    local tracker_autostart="${user_home}/.config/autostart/tracker-disable.desktop"
    sudo -u "$user" mkdir -p "${user_home}/.config/autostart"
    sudo -u "$user" bash -c "cat > '${tracker_autostart}'" << 'EOF'
[Desktop Entry]
Hidden=true
X-GNOME-Autostart-enabled=false
EOF
    log_info "Tracker autostart suppressed: $tracker_autostart"

    # -------------------------------------------------------------------------
    # Evolution Data Server — calendário/contatos, não usado em setup de dev
    # Seguro desabilitar: GNOME Shell não depende desses serviços
    # -------------------------------------------------------------------------
    _disable_user_svc "evolution-source-registry.service"
    _disable_user_svc "evolution-addressbook-factory.service"
    _disable_user_svc "evolution-calendar-factory.service"

    # -------------------------------------------------------------------------
    # Autostart XDG — entradas desnecessárias que aumentam tempo de login
    # e consumo de RAM sem benefício em ambiente de desenvolvimento
    # -------------------------------------------------------------------------
    local autostart_remove=(
        # Instalador live — irrelevante pós-instalação
        "/etc/xdg/autostart/liveinst-setup.desktop"
        # Orca (leitor de tela) — desabilitar se não usar acessibilidade
        "/etc/xdg/autostart/orca-autostart.desktop"
        # Applet de relatórios de problema (ABRT/GNOME)
        "/etc/xdg/autostart/org.freedesktop.problems.applet.desktop"
        # Evolution — alarmes de calendário
        "/etc/xdg/autostart/org.gnome.Evolution-alarm-notify.desktop"
        # Notificações de disco (DiskUtility)
        "/etc/xdg/autostart/org.gnome.SettingsDaemon.DiskUtilityNotify.desktop"
        # SPICE VD Agent — apenas necessário em VMs SPICE
        "/etc/xdg/autostart/spice-vdagent.desktop"
        # LocalSearch (Tracker3) — indexação gerenciada em _configure_localsearch
        "/etc/xdg/autostart/localsearch-3.desktop"
    )

    # GNOME Software autostarta no boot e pode consumir até ~900 MB de RAM
    local gnome_sw_autostart="/etc/xdg/autostart/org.gnome.Software.desktop"
    if [[ -f "$gnome_sw_autostart" ]]; then
        autostart_remove+=("$gnome_sw_autostart")
    fi

    for entry in "${autostart_remove[@]}"; do
        if [[ -f "$entry" ]]; then
            sudo rm -f "$entry" && \
                log_info "Removed autostart: $(basename "$entry")" || \
                log_warn "Could not remove: $entry"
        else
            log_info "Skipped (not found): $(basename "$entry")"
        fi
    done

    # Fallback: caso gnome-software-service ainda exista como serviço de usuário
    _disable_user_svc "gnome-software-service.service"

    unset -f _disable_system_svc _disable_user_svc _mask_system_unit

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
    gnome-tweaks \
    gnome-shell-extension-caffeine \
    gnome-shell-extension-auto-move-windows \
    gnome-shell-extension-just-perfection \
    gnome-shell-extension-no-overview \
    gnome-shell-extension-user-theme

  ok "GNOME extension tools installed"
}

# -----------------------------------------------------------------------------
_install_wallpapers() {
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

    step "Installing wallpapers collection"
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
    local fonts_nerd_url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download"

    local fonts_dir="$HOME/.local/share/fonts/nerd-fonts"
    mkdir -p "$fonts_dir"

    # Considera instalado se o diretório existir e não estiver vazio
    if [[ -d "$fonts_dir" && -n "$(ls -A "$fonts_dir" 2>/dev/null)" ]]; then
        skip "Nerd Fonts collection already exists"
        return
    fi

    step "Installing Nerd Fonts collection"
    mkdir -p "$fonts_dir"

    log_info "Download Nerd Fonts..."
    for font in "${FONTS[@]}"; do
        zip_file="${font}.zip"
        url="${fonts_nerd_url}/${zip_file}"
        log "Download $font..."
        curl -fLo "/tmp/${zip_file}" "$url"
        log "Extract $font..."
        unzip -o "/tmp/${zip_file}" -d "$fonts_dir" >/dev/null
        rm "/tmp/${zip_file}"
    done

    log_info "Updating fonts cache..."
    fc-cache -fv >/dev/null

    ok "Nerd Fonts installed to $fonts_dir"
}

# -----------------------------------------------------------------------------
_install_microsoft_fonts() {
    if [[ "${INSTALL_MICROSOFT_FONTS:-true}" != "true" ]]; then
        skip "Microsoft fonts install disabled in config"
        return
    fi
 
    step "Installing Microsoft core fonts"
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
        sudo dnf install -y "$installer_rpm" && \
            sudo fc-cache -f /usr/share/fonts/msttcore 2>/dev/null || true
        rm -f "$installer_rpm"
        ok "Microsoft fonts installed"
    else
        rm -f "$installer_rpm" 2>/dev/null || true
        log_warn "Could not download Microsoft fonts after 3 attempts"
        log_warn "To install manually later:"
        log_warn "  sudo dnf install '$installer_url'"
    fi
}


# Standalone entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

  source "${SCRIPT_DIR}/utils.sh"

  # Exporta automaticamente todas as variáveis carregadas
  set -a
  source "${SCRIPT_DIR}/finitra-default.config"
  [[ -f "${SETUP_HOME}/.config/finitra/finitra.config" ]] && \
    source "${SETUP_HOME}/.config/finitra/finitra.config"
  set +a

  module_30_desktop
fi