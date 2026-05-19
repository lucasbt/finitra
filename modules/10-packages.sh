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
  _install_obsidian
  _add_vscode_repo
  _install_rpms_from_list
  _setup_flathub
  _install_flatpaks_from_list
  
  log_info "Updating font cache..."
  fc-cache -f
  log_success "Font cache updated."

  log_success "Module $MODULE_NAME completed."
}

_install_chrome() {
    step "Installing Google Chrome"
    dnf_install fedora-workstation-repositories
    sudo dnf config-manager setopt google-chrome.name="Google Chrome"
    dnf_install google-chrome-stable
    ok "Google Chrome installed."
}

# -----------------------------------------------------------------------------
_install_obsidian() {
    step "Installing Obsidian"
 
    local install_dir="${OBSIDIAN_INSTALL_DIR:-/opt/obsidian}"
    local desktop_dir="${XDG_DATA_HOME:-/usr/local/share}/applications"
    local icon_dir="${XDG_DATA_HOME:-/usr/local/share}/icons"
    local symlink="/usr/local/bin/obsidian"
 
    # Detecta instalação existente pelo symlink
    if [[ -L "$symlink" && -x "$(readlink -f "$symlink")" ]]; then
        skip "Obsidian already installed"
        return
    fi
 
    # -------------------------------------------------------------------------
    # Resolve a versão mais recente via GitHub API (sem token necessário)
    # -------------------------------------------------------------------------
    log_info "Fetching latest Obsidian release..."
    local latest_tag
    latest_tag=$(curl -fsSL --max-time 15 \
        "https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest" \
        | grep '"tag_name"' \
        | head -1 \
        | sed 's/.*"tag_name": *"\(.*\)".*/\1/')
 
    if [[ -z "$latest_tag" ]]; then
        log_error "Could not resolve latest Obsidian version from GitHub API"
        return 1
    fi
 
    local version="${latest_tag#v}"
    local appimage_url="https://github.com/obsidianmd/obsidian-releases/releases/download/${latest_tag}/Obsidian-${version}.AppImage"
    local dest="${install_dir}/Obsidian-${version}.AppImage"
 
    log_info "Latest version: $version"
 
    # -------------------------------------------------------------------------
    # Download do AppImage
    # -------------------------------------------------------------------------
    sudo mkdir -p "$install_dir" "$desktop_dir" "$icon_dir"
 
    log_info "Downloading Obsidian AppImage..."
    if ! sudo curl -fL --retry 3 --retry-delay 5 --max-time 120 \
            --progress-bar "$appimage_url" -o "$dest"; then
        log_error "Failed to download Obsidian AppImage"
        return 1
    fi
 
    sudo chmod +x "$dest"
    sudo ln -sf "$dest" "$symlink"
    log_info "Symlink created: $symlink → $dest"
 
    # -------------------------------------------------------------------------
    # Ícone SVG oficial (opcional — falha não é bloqueante)
    # -------------------------------------------------------------------------
    local icon_path="${icon_dir}/obsidian.svg"
    if ! sudo curl -fsSL --max-time 10 \
            "https://obsidian.md/favicon.svg" -o "$icon_path" 2>/dev/null; then
        log_warn "Icon download failed (optional — app will use system fallback)"
        icon_path="obsidian"   # fallback para nome de ícone do tema
    fi
 
    # -------------------------------------------------------------------------
    # Entrada .desktop para integração com o GNOME Shell
    # -------------------------------------------------------------------------
    sudo tee "${desktop_dir}/obsidian.desktop" > /dev/null << EOF
[Desktop Entry]
Name=Obsidian
Comment=A powerful knowledge base that works on local Markdown files
Exec=${dest} %u
Icon=${icon_path}
Terminal=false
Type=Application
Categories=Office;TextEditor;
MimeType=x-scheme-handler/obsidian;
StartupWMClass=obsidian
EOF
 
    update-desktop-database "$desktop_dir" 2>/dev/null || true
 
    ok "Obsidian ${version} installed → ${dest}"
}


_install_bitwarden_gui() {
    step "Installing Bitwarden (GUI)"

    local install_dir="/opt/bitwarden"
    local appimage="$install_dir/Bitwarden.AppImage"
    local desktop="$SETUP_HOME/.local/share/applications/bitwarden.desktop"
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
    run_as_root dnf check-update --refresh --repo=code 2>/dev/null || true
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
  [[ -f "${SETUP_HOME}/.config/finitra/finitra.config" ]] && \
    source "${SETUP_HOME}/.config/finitra/finitra.config"
  module_10_packages
fi
