#!/usr/bin/env bash
# =============================================================================
# modules/10-packages.sh -- RPM and Flatpak package installation
# =============================================================================

MODULE_NAME="10-packages"

module_10_packages() {
  log_section "Module: Packages (RPM + Flatpak)"

  _install_chrome
  _install_bitwarden_gui
  _install_bitwarden_cli
  _install_multimedia
  _add_vscode_repo
  _install_rpms_from_list
  _setup_flathub
  _install_flatpaks_from_list
  _install_microsoft_fonts

  log_info "Updating font cache..."
  fc-cache -f
  log_success "Font cache updated."

  log_success "Module $MODULE_NAME completed."
}

_install_microsoft_fonts() {
    step "Installing Microsoft Core Fonts"

    if rpm -q msttcore-fonts-installer &>/dev/null; then
        skip "Microsoft Core Fonts already installed."
        return 0
    fi

    local rpm_tmp="$CACHE_DIR/msttcore-fonts-installer.rpm"

    curl -L \
        "https://downloads.sourceforge.net/project/mscorefonts2/rpms/msttcore-fonts-installer-2.6-1.noarch.rpm" \
        -o "$rpm_tmp" || {
            log_warn "Failed to download Microsoft fonts RPM."
            return 0
        }

    sudo rpm -i --nodigest --percent "$rpm_tmp" || \
        log_warn "Microsoft fonts installation failed (SourceForge instability)."

    ok "Microsoft Core Fonts processed."
}

_install_chrome() {
    step "Installing Google Chrome"
    dnf_install fedora-workstation-repositories
    dnf_install google-chrome-stable
    ok "Google Chrome installed."
}

_install_bitwarden_gui() {
    step "Installing Bitwarden (GUI)"

    local install_dir="/opt/bitwarden"
    local appimage="$install_dir/Bitwarden.AppImage"
    local desktop="$HOME/.local/share/applications/bitwarden.desktop"
    local temp_dir="$CACHE_DIR"

    if [[ -x "$appimage" ]]; then
        skip "Bitwarden GUI already installed"
        return 0
    fi

    mkdir -p "$temp_dir"
    run_as_root mkdir -p "$install_dir"

    curl -L \
        "https://vault.bitwarden.com/download/?app=desktop&platform=linux" \
        -o "$temp_dir/Bitwarden.AppImage"

    run_as_root mv "$temp_dir/Bitwarden.AppImage" "$appimage"
    run_as_root chmod +x "$appimage"

    run_as_root curl -L \
        https://raw.githubusercontent.com/bitwarden/clients/main/apps/desktop/resources/icons/256x256.png \
        -o "$install_dir/bitwarden.png"

    run_as_root ln -sf "$appimage" /usr/local/bin/bitwarden

    mkdir -p "$(dirname "$desktop")"
    cat > "$desktop" <<EOF
[Desktop Entry]
Name=Bitwarden
Exec=$appimage
Icon=$install_dir/bitwarden.png
Terminal=false
Type=Application
Categories=Utility;Security;
StartupNotify=true
EOF

    chmod +x "$desktop"

    ok "Bitwarden GUI installed."
}

_install_bitwarden_cli() {
    step "Installing Bitwarden CLI"

    local install_dir="/opt/bitwarden-cli"
    local temp_dir="$CACHE_DIR"

    if [[ -x "$install_dir/bw" ]]; then
        skip "Bitwarden CLI already installed"
        return 0
    fi

    mkdir -p "$temp_dir"
    run_as_root mkdir -p "$install_dir"

    curl -L \
        "https://vault.bitwarden.com/download/?app=cli&platform=linux" \
        -o "$temp_dir/bw.zip"

    unzip -q "$temp_dir/bw.zip" -d "$temp_dir"
    run_as_root mv "$temp_dir/bw" "$install_dir/"
    run_as_root chmod +x "$install_dir/bw"
    run_as_root ln -sf "$install_dir/bw" /usr/local/bin/bw

    ok "Bitwarden CLI installed."
}

# -----------------------------------------------------------------------------
_install_multimedia() {
    if [[ "${INSTALL_MULTIMEDIA:-true}" != "true" ]]; then
        skip "Multimedia install disabled in config"
        return
    fi
    step "Installing multimedia support (H.264, H.265, ffmpeg, codecs)"

    # -------------------------------------------------------------------------
    # Mesa freeworld — habilita H.264/H.265 na camada VA-API/VDPAU do Mesa
    # -------------------------------------------------------------------------
    run_as_root dnf swap -y mesa-va-drivers  mesa-va-drivers-freeworld  2>/dev/null || true
    run_as_root dnf swap -y mesa-vdpau-drivers mesa-vdpau-drivers-freeworld 2>/dev/null || true

    # -------------------------------------------------------------------------
    # VA-API Intel — i7-4510U é Haswell (4ª geração)
    # libva-intel-driver  → Haswell e anteriores (até 4ª gen) ← correto aqui
    # intel-media-driver  → Broadwell em diante (5ª gen+)     ← NÃO instalar
    # Instalar intel-media-driver no Haswell não quebra, mas VA-API não funciona
    # -------------------------------------------------------------------------
    dnf_install libva-intel-driver libva-utils

    # -------------------------------------------------------------------------
    # ffmpeg completo (RPM Fusion) — substitui o ffmpeg-free do Fedora
    # --allowerasing necessário pois ffmpeg conflita intencionalmente com ffmpeg-free
    # -------------------------------------------------------------------------
    run_as_root dnf swap -y ffmpeg-free ffmpeg --allowerasing 2>/dev/null || true

    # -------------------------------------------------------------------------
    # GStreamer + codecs
    # Excluindo PackageKit-gstreamer-plugin pois PackageKit foi desabilitado
    # -------------------------------------------------------------------------
    local multimedia_pkgs=(
        gstreamer1-plugins-base
        gstreamer1-plugins-good
        gstreamer1-plugins-good-extras
        gstreamer1-plugins-bad-free
        gstreamer1-plugins-bad-freeworld
        gstreamer1-plugins-ugly
        gstreamer1-plugin-openh264
        gstreamer1-plugin-libav
        libdvdread
        libdvdnav
        lame
        faac
        flac
        faad2
        libavcodec-freeworld
        x264
        x265
        vlc
    )
    dnf_install --exclude=PackageKit-gstreamer-plugin "${multimedia_pkgs[@]}"

    # -------------------------------------------------------------------------
    # Verificar VA-API após instalação (não fatal se falhar)
    # -------------------------------------------------------------------------
    if command -v vainfo &>/dev/null; then
        log_info "VA-API status:"
        vainfo 2>&1 | grep -E "Driver|VAProfile|error" | head -20 || true
    else
        log_warn "vainfo not found — instale 'libva-utils' para verificar VA-API manualmente"
    fi

    ok "Multimedia packages installed"
}

# -----------------------------------------------------------------------------
_add_vscode_repo() {
  step "Adding VSCode repository (Microsoft)"

  local vscode_repo="/etc/yum.repos.d/vscode.repo"

  if [[ ! -f "$vscode_repo" ]]; then
    run_as_root rpm --import https://packages.microsoft.com/keys/microsoft.asc
    run_as_root tee "$vscode_repo" > /dev/null << 'REPOEOF'
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
REPOEOF
    run_as_root dnf check-update --refresh 2>/dev/null || true
    log_info "VSCode repository added"
  else
    skip "VSCode repository already present"
  fi
}

# -----------------------------------------------------------------------------
_install_rpms_from_list() {
  step "Installing RPM packages from list"

  local list_file="${SCRIPT_DIR}/data/rpm-pkgs.list"
  if [[ ! -f "$list_file" ]]; then
    log_error "File not found: $list_file"
    return 1
  fi

  local pkgs=()
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^[[:space:]]*$ ]] && continue
    [[ "$line" =~ ^[[:space:]]*# ]]  && continue
    pkgs+=("${line%% *}")   # strip inline comments
  done < "$list_file"

  if [[ ${#pkgs[@]} -eq 0 ]]; then
    log_warn "No packages found in rpm-pkgs.list"
    return
  fi

  log_info "Total packages in list: ${#pkgs[@]}"
  dnf_install "${pkgs[@]}"
  ok "RPM packages installed"
}

# -----------------------------------------------------------------------------
_setup_flathub() {
  if [[ "${ENABLE_FLATHUB:-true}" != "true" ]]; then
    skip "Flathub disabled in config"
    return
  fi

  step "Configuring Flathub remote"

  dnf_install flatpak

  if ! flatpak remotes --columns=name 2>/dev/null | grep -qx "flathub"; then
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    ok "Flathub remote added"
  else
    skip "Flathub already configured"
  fi
}

# -----------------------------------------------------------------------------
_install_flatpaks_from_list() {
  if [[ "${ENABLE_FLATHUB:-true}" != "true" ]]; then
    skip "Flatpak disabled in config"
    return
  fi

  step "Installing Flatpak packages from list"

  local list_file="${SCRIPT_DIR}/data/flatpak-pkgs.list"
  if [[ ! -f "$list_file" ]]; then
    log_warn "flatpak-pkgs.list not found. Skipping."
    return
  fi

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^[[:space:]]*$ ]] && continue
    [[ "$line" =~ ^[[:space:]]*# ]]  && continue
    # Format: remote app_id
    read -r remote app_id <<< "$line"
    [[ -z "$remote" || -z "$app_id" ]] && continue
    flatpak_install "$remote" "$app_id"
  done < "$list_file"

  ok "Flatpak packages installed"
}

# Standalone entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  source "${SCRIPT_DIR}/utils.sh"
  source "${SCRIPT_DIR}/finitra-default.config"
  [[ -f "${HOME}/.config/finitra/finitra.config" ]] && \
    source "${HOME}/.config/finitra/finitra.config"
  module_10_packages
fi
