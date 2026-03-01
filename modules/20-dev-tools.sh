#!/usr/bin/env bash
# =============================================================================
# modules/20-dev-tools.sh -- Development Tools
# mise, Java 21/25, Node LTS, Python latest, Go latest, Starship, Podman
# =============================================================================

MODULE_NAME="20-dev-tools"

module_20_dev_tools() {
  log_section "Module: Development Tools"

  _install_git
  _install_ides
  _install_typora
  _install_kubectl
  _install_awscli
  _install_mise
  _configure_mise_global
  _mise_install_runtimes
  _install_insomnia
  _install_postman
  _install_drawio
  _install_dbeaver
  _configure_podman
  _install_starship

  log_success "Module $MODULE_NAME completed."
}


# -----------------------------------------------------------------------------
_install_typora() {
    local install_dir="$SETUP_HOME/.local/share/typora"
    local bin_link="$SETUP_HOME/.local/bin/typora"
    local desktop_file="$SETUP_HOME/.local/share/applications/typora.desktop"
    local archive="${CACHE_DIR}/typora.tar.gz"

    if command -v typora &>/dev/null; then
        local ver
        ver=$(cat "$install_dir/version" 2>/dev/null || echo "unknown")
        skip "Typora already installed ($ver)"
        return
    fi

    step "Installing Typora (portable tarball)"
    mkdir -p "$install_dir" "$SETUP_HOME/.local/bin"

    cached_download \
        "https://typora.io/linux/Typora-linux-x64.tar.gz" \
        "$archive"

    if ! tar -xzf "$archive" -C "$install_dir" --strip-components=2; then
        log_error "Failed to extract Typora archive"
        return 1
    fi

    ln -sf "$install_dir/Typora" "$bin_link"
    log_info "Created symlink: $bin_link → $install_dir/Typora"

    mkdir -p "$(dirname "$desktop_file")"
    cat > "$desktop_file" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Typora
Exec=$bin_link %f
Icon=$install_dir/resources/assets/icon/icon_256x256@2x.png
Terminal=false
Categories=Utility;TextEditor;Markdown;
StartupNotify=true
EOF
    chmod +x "$desktop_file"

    ok "Typora installed"
}

# -----------------------------------------------------------------------------
_install_drawio() {
    step "Installing draw.io desktop"
    log_info "Querying latest draw.io release from GitHub..."

    local tag
    tag=$(curl -s https://api.github.com/repos/jgraph/drawio-desktop/releases/latest \
        | grep -oP '"tag_name":\s*"\K([^"]+)')

    if [[ -z "$tag" ]]; then
        log_error "Unable to identify the latest draw.io version on GitHub"
        return 1
    fi
    log_info "Latest draw.io release: $tag"

    local rpm_asset
    rpm_asset=$(curl -s "https://api.github.com/repos/jgraph/drawio-desktop/releases/tags/${tag}" \
        | grep -oP 'browser_download_url":\s*"\K([^"]*x86_64[^"]*\.rpm)')

    if [[ -z "$rpm_asset" ]]; then
        log_error "Could not find .rpm asset for release $tag"
        return 1
    fi
    log_info "RPM asset found: $rpm_asset"

    local rpm_file="${CACHE_DIR}/$(basename "${rpm_asset}")"

    if [[ ! -f "$rpm_file" ]]; then
        log_info "Downloading draw.io RPM..."
        curl -L "$rpm_asset" -o "$rpm_file"
    else
        log_info "Using cached draw.io RPM: $rpm_file"
    fi

    sudo dnf install -y "$rpm_file"
    ok "draw.io installed (${tag})"
}

# -----------------------------------------------------------------------------
_install_dbeaver() {
    if command -v dbeaver &>/dev/null; then
        skip "DBeaver already installed"
        return
    fi

    step "Installing DBeaver Community"
    log_info "Querying latest DBeaver release from GitHub..."

    local tag
    tag=$(curl -s https://api.github.com/repos/dbeaver/dbeaver/releases/latest \
        | grep -oP '"tag_name":\s*"\K([^"]+)')

    if [[ -z "$tag" ]]; then
        log_error "Unable to identify the latest DBeaver version on GitHub"
        return 1
    fi
    log_info "Latest DBeaver release: $tag"

    local rpm_asset
    rpm_asset=$(curl -s "https://api.github.com/repos/dbeaver/dbeaver/releases/tags/${tag}" \
        | grep -oP 'browser_download_url":\s*"\K([^"]*stable\.x86_64\.rpm)')

    if [[ -z "$rpm_asset" ]]; then
        log_error "Could not find .rpm asset for release $tag"
        return 1
    fi
    log_info "RPM asset found: $rpm_asset"

    local rpm_file="${CACHE_DIR}/$(basename "${rpm_asset}")"

    if [[ ! -f "$rpm_file" ]]; then
        log_info "Downloading DBeaver RPM..."
        curl -L "$rpm_asset" -o "$rpm_file"
    else
        log_info "Using cached DBeaver RPM: $rpm_file"
    fi

    sudo dnf install -y "$rpm_file"
    ok "DBeaver Community installed (${tag})"
}

# -----------------------------------------------------------------------------
_install_awscli() {
    # -------------------------------------------------------------------------
    # AWS CLI v2 não tem pacote RPM oficial — instalação via zip da Amazon
    # O instalador suporta --update para reuso da função em upgrades
    # -------------------------------------------------------------------------
    local zip_file="${CACHE_DIR}/awscliv2.zip"
    local extract_dir="${CACHE_DIR}/awscli-extracted"
    local install_dir="/usr/local/aws-cli"
    local bin_dir="/usr/local/bin"

    # Garantir unzip disponível (dependência do instalador)
    if ! command -v unzip &>/dev/null; then
        log_info "Installing unzip (required by AWS CLI installer)..."
        sudo dnf install -y unzip
    fi

    if ! command -v aws &>/dev/null; then
        step "Installing AWS CLI v2"

        cached_download \
            "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" \
            "$zip_file"

        rm -rf "$extract_dir"
        unzip -q "$zip_file" -d "$extract_dir"

        sudo "$extract_dir/aws/install" \
            --install-dir "$install_dir" \
            --bin-dir "$bin_dir"

        ok "AWS CLI $(aws --version 2>&1 | awk '{print $1}') installed"
    else
        step "Updating AWS CLI v2"
        log_info "Current version: $(aws --version 2>&1)"

        cached_download \
            "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" \
            "$zip_file"

        rm -rf "$extract_dir"
        unzip -q "$zip_file" -d "$extract_dir"

        sudo "$extract_dir/aws/install" \
            --install-dir "$install_dir" \
            --bin-dir "$bin_dir" \
            --update

        ok "AWS CLI updated to $(aws --version 2>&1 | awk '{print $1}')"
    fi

    # Limpar arquivos extraídos (zip permanece no cache para reuso)
    rm -rf "$extract_dir"
}

_install_git() {
    step "Installing Git"
    dnf_install git git-lfs git-delta meld
    git config --global credential.helper 'cache --timeout=14400000'
    ok "Git installed and configured"
}

# ------------------------------------------------------------
# IDEs
# ------------------------------------------------------------
_install_ides() {
  step "Installing IntelliJ"

  # IntelliJ
  if [ ! -d /opt/intellij ]; then
      local json url tar
      json=$(curl -s "https://data.services.jetbrains.com/products/releases?code=IIC&latest=true&type=release")
      url=$(echo "$json" | jq -r '.IIC[0].downloads.linux.link')
      tar="$CACHE_DIR/intellij.tar.gz"

      cached_download "$url" "$tar"

      sudo mkdir -p /opt/intellij
      sudo tar -xzf "$tar" -C /opt/intellij --strip-components=1

      sudo tee /usr/share/applications/intellij.desktop >/dev/null <<EOF
[Desktop Entry]
Name=IntelliJ IDEA Community
Exec=/opt/intellij/bin/idea.sh
Icon=/opt/intellij/bin/idea.svg
Type=Application
Categories=Development;IDE;
StartupWMClass=IntelliJ
EOF
    ok "IntelliJ Installed"
  else
    skip "IntelliJ already installed"
  fi

  # Zed
  if ! command -v zed &>/dev/null; then
      step "Installing Zed editor"
      curl -f https://zed.dev/install.sh | sh
      ok "Zed installed"
  else
      skip "Zed already installed"
  fi
}

_install_kubectl() {
  step "Installing kubectl"
  if ! command -v kubectl &>/dev/null; then      
      local ver bin
      ver=$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)
      bin="$CACHE_DIR/kubectl"
      cached_download \
          "https://storage.googleapis.com/kubernetes-release/release/${ver}/bin/linux/amd64/kubectl" \
          "$bin"
      sudo install "$bin" /usr/local/bin/kubectl
      ok "kubectl installed"
  else
      skip "kubectl already installed"
  fi
}

_install_postman() {
  step "Installing Postman"
  local install_dir="/opt/postman"
  local archive="${CACHE_DIR}/postman-linux-x64.tar.gz"

  if [[ ! -d "$install_dir" ]]; then
      log_info "Downloading Postman..."
      curl -L "https://dl.pstmn.io/download/latest/linux64" -o "$archive"
      log_info "Installing Postman to ${install_dir}..."
      sudo rm -rf "$install_dir"
      sudo mkdir -p "$install_dir"
      sudo tar -xzf "$archive" -C /opt
      sudo mv /opt/Postman "$install_dir"
      sudo chown -R "$USER:$USER" "$install_dir"
      ok "Postman installed"
  else
      skip "Postman already installed"
  fi

  # Desktop entry (user-level, GNOME friendly)
  local desktop_file="$SETUP_HOME/.local/share/applications/postman.desktop"
  if [[ ! -f "$desktop_file" ]]; then
      log_info "Creating Postman desktop entry..."
      mkdir -p "$SETUP_HOME/.local/share/applications"
      cat > "$desktop_file" <<EOF
[Desktop Entry]
Encoding=UTF-8
Name=Postman
Comment=API Development Environment
Exec=${install_dir}/app/Postman %U
Icon=${install_dir}/app/resources/app/assets/icon.png
Terminal=false
Type=Application
Categories=Development;
StartupWMClass=Postman
EOF
      ok "Postman desktop entry created"
  else
      skip "Postman desktop entry already exists"
  fi
}

# -----------------------------------------------------------------------------
_install_insomnia() {
    step "Installing Insomnia"
    log_info "Querying latest Insomnia release from GitHub..."

    local tag
    tag=$(curl -s https://api.github.com/repos/Kong/insomnia/releases/latest \
        | grep -oP '"tag_name":\s*"\K([^"]+)')

    if [[ -z "$tag" ]]; then
        log_error "Unable to identify the latest Insomnia version on GitHub"
        return 1
    fi
    log_info "Latest Insomnia release: $tag"

    local rpm_asset
    rpm_asset=$(curl -s "https://api.github.com/repos/Kong/insomnia/releases/tags/${tag}" \
        | grep -oP 'browser_download_url":\s*"\K([^"]*Insomnia\.Core[^"]*\.rpm)')

    if [[ -z "$rpm_asset" ]]; then
        log_error "Could not find .rpm asset for release $tag"
        return 1
    fi

    local rpm_file="${CACHE_DIR}/$(basename "${rpm_asset}")"

    if [[ ! -f "$rpm_file" ]]; then
        log_info "Downloading Insomnia RPM..."
        curl -L "$rpm_asset" -o "$rpm_file"
    else
        log_info "Using cached Insomnia RPM: $rpm_file"
    fi

    dnf_install "$rpm_file"
    ok "Insomnia installed (${tag})"
}

# -----------------------------------------------------------------------------
_install_mise() {
  step "Installing mise (runtime version manager)"

  local user="${SETUP_USER:-$USER}"
  local user_home="${SETUP_HOME:-$HOME}"
  local mise_bin="${user_home}/.local/bin/mise"

  if [[ -x "$mise_bin" ]]; then
    local current_ver
    current_ver=$(sudo -u "$user" "$mise_bin" --version 2>/dev/null | head -1)
    skip "mise already installed: $current_ver"
  else
    log_info "Downloading and installing mise..."
    sudo -u "$user" bash -c 'curl https://mise.run | sh' || {
      log_error "Failed to install mise via curl"
      return 1
    }
    ok "mise installed"
  fi

  _ensure_mise_bashrc "$user" "$user_home"
}

_ensure_mise_bashrc() {
  local user="$1"
  local user_home="$2"
  local bashrc="${user_home}/.bashrc"

  local mise_activate='eval "$(~/.local/bin/mise activate bash)"'
  if ! grep -qF 'mise activate bash' "$bashrc" 2>/dev/null; then
    sudo -u "$user" bash -c "echo '' >> \"$bashrc\""
    sudo -u "$user" bash -c "echo '# mise -- runtime version manager' >> \"$bashrc\""
    sudo -u "$user" bash -c "echo '$mise_activate' >> \"$bashrc\""
    log_info "mise activation added to .bashrc"
  else
    skip "mise already present in .bashrc"
  fi
}

# -----------------------------------------------------------------------------
_configure_mise_global() {
  step "Writing ~/.config/mise/config.toml (global runtimes)"

  local user="${SETUP_USER:-$USER}"
  local config_file="${SETUP_HOME:-$HOME}/.config/mise/config.toml"

  sudo -u "$user" mkdir -p "$(dirname "$config_file")"

  local desired_content
  desired_content=$(cat << TOMLEOF
# ============================================================
# ~/.config/mise/config.toml -- Global runtimes managed by mise
# ============================================================
[tools]
java = ["${MISE_JAVA_21:-java@21}", "${MISE_JAVA_25:-java@25}"]
node = "${MISE_NODE:-node@lts}"
python = "${MISE_PYTHON:-python@latest}"
go = "${MISE_GOLANG:-go@latest}"

[settings]
experimental = true
TOMLEOF
)

  if [[ -f "$config_file" ]] && diff <(echo "$desired_content") "$config_file" &>/dev/null; then
    skip "mise config.toml is already up to date"
  else
    echo "$desired_content" | sudo -u "$user" tee "$config_file" > /dev/null
    ok "mise config.toml updated"
  fi
}

# -----------------------------------------------------------------------------
_mise_install_runtimes() {
  step "Installing runtimes via mise (may take a while on first run)"

  local user="${SETUP_USER:-$USER}"
  local user_home="${SETUP_HOME:-$HOME}"
  local mise="${user_home}/.local/bin/mise"

  if [[ ! -x "$mise" ]]; then
    log_error "mise not found at $mise. Skipping runtime installation."
    return 1
  fi

  # Build dependencies needed to compile runtimes from source
  log_info "Installing build dependencies for runtimes..."
  dnf_install \
    gcc gcc-c++ make \
    openssl-devel bzip2-devel libffi-devel zlib-devel \
    sqlite-devel readline-devel \
    xz-devel tk-devel \
    libuuid-devel

  log_info "Running: mise install (all versions from config.toml)"
  sudo -u "$user" "$mise" install --yes 2>&1 | tee -a "${LOG_FILE:-/tmp/finitra.log}" || {
    log_warn "mise install returned non-zero. Check the log for details."
  }

  # Set java 21 as the global default (for IDE compatibility)
  local java21="${MISE_JAVA_21:-java@21}"
  log_info "Setting $java21 as global default..."
  sudo -u "$user" "$mise" use --global "$java21" 2>/dev/null || true

  _configure_java_home "$user" "${SETUP_HOME:-$HOME}"

  ok "mise runtimes installed"
}

_configure_java_home() {
  local user="$1"
  local user_home="$2"
  local bashrc="${user_home}/.bashrc"

  if ! grep -qF 'JAVA_HOME' "$bashrc" 2>/dev/null; then
    sudo -u "$user" bash -c "cat >> \"$bashrc\"" << 'JAVAEOF'

# Dynamic JAVA_HOME via mise (IDE compatibility)
if command -v mise &>/dev/null; then
  export JAVA_HOME="$(mise where java 2>/dev/null)"
fi
JAVAEOF
    log_info "JAVA_HOME configured in .bashrc"
  else
    skip "JAVA_HOME already present in .bashrc"
  fi
}

# -----------------------------------------------------------------------------
_configure_podman() {
  step "Configuring Podman"

  local user="${SETUP_USER:-$USER}"
  local user_home="${SETUP_HOME:-$HOME}"

  if ! has_cmd podman && ! is_rpm_installed podman; then
    log_info "Podman not found. Installing..."
    dnf_install podman podman-compose podman-docker
  else
    skip "Podman already installed: $(podman --version 2>/dev/null)"
  fi

  # Add docker=podman alias for developer convenience
  if [[ "${PODMAN_DOCKER_ALIAS:-true}" == "true" ]]; then
    local bashrc="${user_home}/.bashrc"
    if ! grep -qF 'alias docker=podman' "$bashrc" 2>/dev/null; then
      cat >> "$bashrc" << 'PODMANEOF'

# Podman as a Docker drop-in replacement
alias docker=podman
alias docker-compose='podman compose'
PODMANEOF
      ok "docker=podman alias added to .bashrc"
    else
      skip "docker=podman alias already present"
    fi
  fi

  # Enable Podman socket for IDEs that expect /var/run/docker.sock
  if ! sudo -u "$user" systemctl --user is-enabled podman.socket &>/dev/null; then
    sudo -u "$user" systemctl --user enable --now podman.socket 2>/dev/null || true
    log_info "Podman socket enabled for user $user"
  fi

  ok "Podman configured"
}

# -----------------------------------------------------------------------------
_install_starship() {
  if [[ "${INSTALL_STARSHIP:-true}" != "true" ]]; then
    skip "Starship disabled in config"
    return
  fi

  step "Installing Starship (modern shell prompt)"

  local user="${SETUP_USER:-$USER}"
  local user_home="${SETUP_HOME:-$HOME}"

  if [[ -x "/usr/local/bin/starship" ]]; then
    skip "Starship already installed: $(starship --version 2>/dev/null)"
  else
    log_info "Downloading and installing Starship..."
    curl -sS https://starship.rs/install.sh | run_as_root sh -s -- --yes --bin-dir /usr/local/bin || {
      log_error "Failed to install Starship"
      return 1
    }
    ok "Starship installed"
  fi

  local bashrc="${user_home}/.bashrc"
  if ! grep -qF 'starship init bash' "$bashrc" 2>/dev/null; then
    cat >> "$bashrc" << 'STAREOF'

# Starship -- modern dev-focused shell prompt
eval "$(starship init bash)"
STAREOF
    log_info "Starship activation added to .bashrc"
  else
    skip "Starship already present in .bashrc"
  fi

  local starship_cfg="${user_home}/.config/starship.toml"
  if [[ ! -f "$starship_cfg" ]]; then
    sudo -u "$user" mkdir -p "$(dirname "$starship_cfg")"
    sudo -u "$user" tee "$starship_cfg" > /dev/null << 'TOMLEOF'
# starship.toml -- finitra default (dev-focused, low visual noise)
format = """
$username\
$hostname\
$directory\
$git_branch\
$git_status\
$java\
$nodejs\
$python\
$golang\
$docker_context\
$cmd_duration\
$line_break\
$character"""

[character]
success_symbol = "[❯](bold green)"
error_symbol   = "[❯](bold red)"

[directory]
truncation_length = 4
truncate_to_repo  = true

[git_branch]
symbol = " "
format = "[$symbol$branch]($style) "
style  = "bold purple"

[git_status]
format = '([\[$all_status$ahead_behind\]]($style) )'
style  = "bold yellow"

[java]
symbol = " "
format = "[$symbol$version]($style) "
style  = "bold red"

[nodejs]
symbol = " "
format = "[$symbol$version]($style) "
style  = "bold green"

[python]
symbol = " "
format = "[$symbol$version]($style) "
style  = "bold yellow"

[golang]
symbol = " "
format = "[$symbol$version]($style) "
style  = "bold cyan"

[cmd_duration]
min_time = 2_000
format   = "[$duration]($style) "
style    = "bold yellow"
TOMLEOF
    ok "Starship initial config created"
  else
    skip "starship.toml already exists"
  fi
}

# Standalone entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  source "${SCRIPT_DIR}/utils.sh"
  source "${SCRIPT_DIR}/finitra-default.config"
  [[ -f "${SETUP_HOME}/.config/finitra/finitra.config" ]] && \
    source "${SETUP_HOME}/.config/finitra/finitra.config"
  module_20_dev_tools
fi
