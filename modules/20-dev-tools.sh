#!/usr/bin/env bash
# =============================================================================
# modules/20-dev-tools.sh -- Development Tools
# Java 21/25, Maven, Gradle, Starship, Podman
# =============================================================================

MODULE_NAME="20-dev-tools"

module_20_dev_tools() {
  log_section "Module: Development Tools"

  # ── 1. Build dependencies (compilação de runtimes a partir do fonte)
  log_info "Installing build dependencies for runtimes..."
  dnf_install \
    gcc gcc-c++ make \
    openssl-devel bzip2-devel libffi-devel zlib-devel \
    sqlite-devel readline-devel \
    xz-devel tk-devel \
    libuuid-devel

  # ── 2. Controle de versão (outros passos podem clonar repositórios)
  _install_git

  # ── 3. Gerenciadores de runtime (devem existir antes de instalar qualquer runtime)
  _install_sdkman

  # ── 4. Runtimes
  _install_sdkman_runtimes   # Java 21 LTS + Java 25, Maven, Gradle
  _install_nvm               # Node.js LTS + pacotes npm globais

  # ── 5. Infraestrutura de containers (IDEs podem se conectar ao socket Docker)
  _configure_podman
  _install_podman_desktop

  # ── 6. IDEs (IntelliJ requer Java 21 já instalado)
  _install_ides

  # ── 7. Ferramentas CLI de infraestrutura
  _install_kubectl
  _install_awscli

  # ── 8. Clientes de API REST (mesmo propósito, agrupados)
  _install_insomnia
  _install_postman

  # ── 9. Utilitários GUI (sem interdependências entre si)
  _install_dbeaver  # banco de dados
  _install_drawio   # diagramas
  _install_typora   # editor Markdown

  # ── 10. Shell prompt (cosmético; não bloqueia nenhum outro passo)
  _install_starship

  # ── 11. AI CLI Tools
  _install_ai_cli_tools      # Gemini CLI + OpenCode

  log_success "Module $MODULE_NAME completed."
}


# =============================================================================
# 2. Controle de versão
# =============================================================================

_install_git() {
    step "Installing Git"
    dnf_install git git-lfs git-delta meld
    git config --global credential.helper 'cache --timeout=14400000'
    ok "Git installed and configured"
}


# =============================================================================
# 3. Gerenciadores de runtime
# =============================================================================

_install_sdkman() {
  step "Installing SDKMAN (SDK version manager)"

  local user="${SETUP_USER:-$USER}"
  local user_home="${SETUP_HOME:-$HOME}"
  local sdkman_dir="${user_home}/.sdkman"
  local sdkman_init="${sdkman_dir}/bin/sdkman-init.sh"

  if [[ -d "$sdkman_dir" ]]; then
    skip "SDKMAN already installed at $sdkman_dir"
  else
    log_info "Downloading and installing SDKMAN..."
    sudo -u "$user" bash -c 'curl -s "https://get.sdkman.io" | bash' || {
      log_error "Failed to install SDKMAN via curl"
      return 1
    }
    ok "SDKMAN installed"
  fi

  _ensure_sdkman_bashrc "$user" "$user_home"
}

_ensure_sdkman_bashrc() {
  local user="$1"
  local user_home="$2"
  local bashrc="${user_home}/.bashrc"
  local sdkman_init="${user_home}/.sdkman/bin/sdkman-init.sh"

  if ! grep -qF 'sdkman-init.sh' "$bashrc" 2>/dev/null; then
    sudo -u "$user" bash -c "cat >> \"$bashrc\"" << EOF

# SDKMAN -- SDK version manager
export SDKMAN_DIR="${user_home}/.sdkman"
[[ -s "${sdkman_init}" ]] && source "${sdkman_init}"
EOF
    log_info "SDKMAN activation added to .bashrc"
  else
    skip "SDKMAN already present in .bashrc"
  fi
}


# =============================================================================
# 4. Runtimes
# =============================================================================

# ── Helpers internos do SDKMAN ────────────────────────────────────────────────

_sdk_latest_java() {
  local major="$1"
  local dist="$2"
  local user="${SETUP_USER:-$USER}"
  local user_home="${SETUP_HOME:-$HOME}"
  local sdkman_init="${user_home}/.sdkman/bin/sdkman-init.sh"

  sudo -u "$user" bash -c "
    source \"${sdkman_init}\" 2>/dev/null
    sdk list java 2>/dev/null \
      | grep -E \"\|\s+${dist}\s+\|\" \
      | grep -E \"\|\s+${major}\.\" \
      | grep -Ev \"local\s*\||installed\s*\|\" \
      | awk -F'|' '{gsub(/[[:space:]]/, \"\", \$NF); print \$NF}' \
      | grep -v \"^\$\" \
      | sort -t. -k1,1n -k2,2n -k3,3n \
      | tail -1
  "
}

_sdk_install_java() {
  local user="$1"
  local user_home="$2"
  local java_id="$3"
  local major="$4"
  local sdkman_init="${user_home}/.sdkman/bin/sdkman-init.sh"

  if sudo -u "$user" bash -c "ls \"${user_home}/.sdkman/candidates/java/\" 2>/dev/null" \
      | grep -qx "$java_id"; then
    skip "Java ${major} already installed: $java_id"
  else
    log_info "Installing Java ${major}: $java_id"
    sudo -u "$user" bash -c "
      source \"${sdkman_init}\" 2>/dev/null
      sdk install java \"${java_id}\"
    " || {
      log_error "Failed to install Java ${major}: $java_id"
      return 1
    }
    ok "Java ${major} installed: $java_id"
  fi
}

# ── Instalação dos runtimes via SDKMAN ────────────────────────────────────────

_install_sdkman_runtimes() {
  step "Installing runtimes via SDKMAN (may take a while on first run)"

  local user="${SETUP_USER:-$USER}"
  local user_home="${SETUP_HOME:-$HOME}"
  local sdkman_init="${user_home}/.sdkman/bin/sdkman-init.sh"

  if [[ ! -s "$sdkman_init" ]]; then
    log_error "SDKMAN not found at $sdkman_init. Skipping runtime installation."
    return 1
  fi

  # ── Java 21 LTS
  log_info "Detecting latest Java 21 Temurin..."
  local java21_id
  java21_id=$(_sdk_latest_java "21" "tem")

  if [[ -n "$java21_id" ]]; then
    _sdk_install_java "$user" "$user_home" "$java21_id" "21"
    sudo -u "$user" bash -c "
      source \"${sdkman_init}\" 2>/dev/null
      sdk default java \"${java21_id}\"
    "
    log_info "Java 21 set as default: $java21_id"
  else
    log_warn "Java 21 Temurin not detected automatically."
    log_warn "Check manually: sdk list java | grep '21.*tem'"
    java21_id="21-tem"
  fi

  # ── Java 25
  log_info "Detecting latest Java 25 Temurin..."
  local java25_id
  java25_id=$(_sdk_latest_java "25" "tem")

  if [[ -n "$java25_id" ]]; then
    _sdk_install_java "$user" "$user_home" "$java25_id" "25"
  else
    log_warn "Java 25 Temurin not detected automatically."
    log_warn "Check manually: sdk list java | grep '25.*tem'"
    java25_id="25-tem"
  fi

  # ── Maven e Gradle
  log_info "Installing Maven and Gradle via SDKMAN..."
  sudo -u "$user" bash -c "
    source \"${sdkman_init}\" 2>/dev/null
    sdk install maven  2>/dev/null || true
    sdk install gradle 2>/dev/null || true
  "
  ok "SDKMAN runtimes installed — Java 21: ${java21_id} | Java 25: ${java25_id}"
}


# ── NVM + Node.js LTS ─────────────────────────────────────────────────────────

_install_nvm() {
  local user="${SETUP_USER:-$USER}"
  local user_home="${SETUP_HOME:-$HOME}"
  local nvm_dir="${user_home}/.nvm"
  local bashrc="${user_home}/.bashrc"

  step "Installing NVM (latest)"

  log_info "Querying latest NVM release from GitHub..."
  local nvm_ver
  nvm_ver=$(curl -fsSL https://api.github.com/repos/nvm-sh/nvm/releases/latest \
    | grep -oP '"tag_name":\s*"\K([^"]+)')

  if [[ -z "$nvm_ver" ]]; then
    log_error "Unable to identify the latest NVM version on GitHub"
    return 1
  fi
  log_info "Latest NVM release: ${nvm_ver}"

  if [[ ! -d "$nvm_dir" ]]; then
    log_info "Downloading and installing NVM ${nvm_ver}..."
    sudo -u "$user" bash -c \
      "curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/${nvm_ver}/install.sh | bash" || {
        log_error "Failed to install NVM"
        return 1
      }
    ok "NVM ${nvm_ver} installed"
  else
    skip "NVM already installed at ${nvm_dir}"
  fi

  # Garante que o bloco de inicialização esteja no .bashrc
  if ! grep -qF 'NVM_DIR' "$bashrc" 2>/dev/null; then
    sudo -u "$user" bash -c "cat >> \"$bashrc\"" << EOF

# NVM -- Node Version Manager
export NVM_DIR="${nvm_dir}"
[[ -s "\$NVM_DIR/nvm.sh" ]] && source "\$NVM_DIR/nvm.sh"
[[ -s "\$NVM_DIR/bash_completion" ]] && source "\$NVM_DIR/bash_completion"
EOF
    log_info "NVM activation added to .bashrc"
  else
    skip "NVM already present in .bashrc"
  fi

  # Instala/usa Node.js LTS e pacotes globais dentro do contexto do usuário
  log_info "Installing Node.js LTS via NVM..."
  sudo -u "$user" bash -c "
    export NVM_DIR=\"${nvm_dir}\"
    [[ -s \"\$NVM_DIR/nvm.sh\" ]] && source \"\$NVM_DIR/nvm.sh\"
    nvm install --lts 2>/dev/null || true
    nvm use     --lts 2>/dev/null || true
    nvm alias default 'lts/*'    2>/dev/null || true
  " || {
    log_error "Failed to install Node.js LTS"
    return 1
  }

  log_info "Installing global npm packages..."
  sudo -u "$user" bash -c "
    export NVM_DIR=\"${nvm_dir}\"
    [[ -s \"\$NVM_DIR/nvm.sh\" ]] && source \"\$NVM_DIR/nvm.sh\"
    npm install -g npm@latest typescript ts-node prettier eslint 2>/dev/null
  " || log_warn "Some npm packages failed to install — continuing."

  ok "Node.js LTS and NVM installed"
}

# =============================================================================
# AI CLI Tools (Gemini CLI + OpenCode)
# =============================================================================
 
# Agregador — ponto único de entrada para os dois instaladores
_install_ai_cli_tools() {
  _install_gemini_cli
  _install_opencode
}
 
# ── Gemini CLI (via npm — requer Node.js/NVM) ─────────────────────────────────
 
_install_gemini_cli() {
  local user="${SETUP_USER:-$USER}"
  local user_home="${SETUP_HOME:-$HOME}"
  local nvm_dir="${user_home}/.nvm"
 
  step "Installing Gemini CLI"
 
  if sudo -u "$user" bash -c "
      export NVM_DIR=\"${nvm_dir}\"
      [[ -s \"\$NVM_DIR/nvm.sh\" ]] && source \"\$NVM_DIR/nvm.sh\"
      command -v gemini &>/dev/null
    "; then
    skip "Gemini CLI already installed"
    return
  fi
 
  log_info "Installing @google/gemini-cli via npm..."
  sudo -u "$user" bash -c "
    export NVM_DIR=\"${nvm_dir}\"
    [[ -s \"\$NVM_DIR/nvm.sh\" ]] && source \"\$NVM_DIR/nvm.sh\"
    npm install -g @google/gemini-cli 2>/dev/null
  " || {
    log_error "Failed to install Gemini CLI"
    return 1
  }
 
  ok "Gemini CLI installed"
}
 
# ── OpenCode (binário Go via script oficial) ──────────────────────────────────
 
_install_opencode() {
  local user="${SETUP_USER:-$USER}"
  local user_home="${SETUP_HOME:-$HOME}"
  local bin_dir="${user_home}/.local/bin"
 
  step "Installing OpenCode"
 
  if sudo -u "$user" bash -c "command -v opencode &>/dev/null"; then
    skip "OpenCode already installed: $(sudo -u "$user" opencode --version 2>/dev/null)"
    return
  fi
 
  log_info "Downloading and installing OpenCode via install script..."
  sudo -u "$user" bash -c "
    mkdir -p \"${bin_dir}\"
    OPENCODE_INSTALL_DIR=\"${bin_dir}\" \
      curl -fsSL https://opencode.ai/install | bash
  " || {
    log_error "Failed to install OpenCode"
    return 1
  }
 
  ok "OpenCode installed"
}

# =============================================================================
# 5. Infraestrutura de containers
# =============================================================================

_configure_podman() {
  step "Configuring Podman"

  local user="${SETUP_USER:-$USER}"
  local user_home="${SETUP_HOME:-$HOME}"

  dnf_install podman podman-compose podman-docker buildah skopeo containers-common

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
    loginctl enable-linger "$USER" 2>/dev/null || true
    sudo -u "$user" systemctl --user enable --now podman.socket 2>/dev/null || true
    log_info "Podman socket enabled for user $user"
  fi

  sudo mkdir -p /etc/containers
  sudo tee /etc/containers/registries.conf.d/99-dev.conf > /dev/null << 'EOF'
[[registry]]
prefix   = "docker.io"
location = "docker.io"

[[registry]]
prefix   = "ghcr.io"
location = "ghcr.io"

[[registry]]
prefix   = "quay.io"
location = "quay.io"
EOF

  dnf_install fuse-overlayfs 2>/dev/null || true
  mkdir -p ~/.config/containers
  cat > ~/.config/containers/storage.conf << 'EOF'
[storage]
driver = "overlay"

[storage.options.overlay]
mount_program = "/usr/bin/fuse-overlayfs"
EOF


  ok "Podman installed and configured"
}

# -----------------------------------------------------------------------------
_install_podman_desktop() {
    if [[ "${INSTALL_PODMAN_DESKTOP:-true}" != "true" ]]; then
        skip "Podman Desktop install disabled in config"
        return
    fi
 
    step "Installing Podman Desktop"
 
    local install_dir="${PODMAN_DESKTOP_INSTALL_DIR:-/opt/podman-desktop}"
    local desktop_dir="/usr/local/share/applications"
    local icon_dir="/usr/local/share/icons"
    local symlink="/usr/local/bin/podman-desktop"
 
    if [[ -L "$symlink" && -x "$(readlink -f "$symlink")" ]]; then
        skip "Podman Desktop already installed"
        return
    fi
 
    # -------------------------------------------------------------------------
    # Resolve a versão mais recente e o asset correto para Linux x64
    # O nome do asset mudou na v1.25: pode ser .tar.gz (sem arch) ou -x64.tar.gz
    # A API retorna todos os assets — filtra pelo padrão excluindo arm64
    # -------------------------------------------------------------------------
    log_info "Fetching latest Podman Desktop release..."
    local api_response
    api_response=$(curl -fsSL --max-time 15 \
        "https://api.github.com/repos/podman-desktop/podman-desktop/releases/latest")
 
    if [[ -z "$api_response" ]]; then
        log_error "Could not reach GitHub API"
        return 1
    fi
 
    local latest_tag
    latest_tag=$(echo "$api_response" \
        | grep '"tag_name"' | head -1 \
        | sed 's/.*"tag_name": *"\(.*\)".*/\1/')
 
    # Busca URL do asset: .tar.gz para linux x64 (exclui arm64)
    local tarball_url
    tarball_url=$(echo "$api_response" \
        | grep '"browser_download_url"' \
        | grep '\.tar\.gz"' \
        | grep -v 'arm64' \
        | head -1 \
        | sed 's/.*"browser_download_url": *"\(.*\)".*/\1/')
 
    if [[ -z "$latest_tag" || -z "$tarball_url" ]]; then
        log_error "Could not resolve Podman Desktop download URL"
        return 1
    fi
 
    local version="${latest_tag#v}"
    local tarball="${CACHE_DIR}/podman-desktop-${version}.tar.gz"
 
    log_info "Latest version: ${version}"
    log_info "Asset: $(basename "$tarball_url")"
 
    # -------------------------------------------------------------------------
    # Download e extração
    # -------------------------------------------------------------------------
    log_info "Downloading Podman Desktop..."
    if ! curl -fsSL --retry 3 --retry-delay 5 --max-time 300 \
            --progress-bar "$tarball_url" -o "$tarball"; then
        log_error "Failed to download Podman Desktop"
        rm -f "$tarball"
        return 1
    fi
 
    sudo mkdir -p "$install_dir"
    log_info "Extracting to ${install_dir}..."
    sudo tar -xzf "$tarball" --strip-components=1 -C "$install_dir"
    rm -f "$tarball"
 
    # -------------------------------------------------------------------------
    # Localiza o binário principal dentro do diretório extraído
    # -------------------------------------------------------------------------
    local binary
    binary=$(find "$install_dir" -maxdepth 1 -type f -name "podman-desktop" | head -1)
 
    if [[ -z "$binary" ]]; then
        log_error "Could not find 'podman-desktop' binary in ${install_dir}"
        return 1
    fi
 
    sudo chmod +x "$binary"
    sudo ln -sf "$binary" "$symlink"
    log_info "Symlink created: $symlink → $binary"
 
    # -------------------------------------------------------------------------
    # Ícone — busca no diretório extraído antes de tentar download
    # -------------------------------------------------------------------------
    sudo mkdir -p "$icon_dir"
    local icon_path="${icon_dir}/podman-desktop.png"
    local bundled_icon
    bundled_icon=$(find "$install_dir" -maxdepth 3 \
        \( -name "*.png" -o -name "*.svg" \) \
        | grep -i "icon\|logo\|podman" | head -1)
 
    if [[ -n "$bundled_icon" ]]; then
        sudo cp "$bundled_icon" "$icon_path"
        log_info "Icon copied from bundle: $(basename "$bundled_icon")"
    else
        sudo curl -fsSL --max-time 10 \
            "https://raw.githubusercontent.com/podman-desktop/podman-desktop/main/buildResources/icon.png" \
            -o "$icon_path" 2>/dev/null || \
            icon_path="podman-desktop"
        log_info "Icon downloaded from repository"
    fi
 
    # -------------------------------------------------------------------------
    # Entrada .desktop — sem autostart, apenas launcher no menu de aplicativos
    # -------------------------------------------------------------------------
    sudo mkdir -p "$desktop_dir"
    sudo tee "${desktop_dir}/podman-desktop.desktop" > /dev/null << EOF
[Desktop Entry]
Name=Podman Desktop
Comment=Manage containers and Kubernetes with Podman
Exec=${binary} %U
Icon=${icon_path}
Terminal=false
Type=Application
Categories=Development;System;
StartupWMClass=Podman Desktop
EOF
 
    update-desktop-database "$desktop_dir" 2>/dev/null || true
 
    ok "Podman Desktop ${version} installed → ${binary}"
}


# =============================================================================
# 6. IDEs
# =============================================================================

_install_ides() {
  step "Installing IntelliJ"

  # IntelliJ
  if command -v idea &>/dev/null || [[ -x /opt/intellij/bin/idea.sh ]]; then
    skip "IntelliJ already installed"
  else
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
  fi

  # Zed
  local zed_bin="$SETUP_HOME/.local/bin/zed"

  if [[ -x "$zed_bin" ]] || command -v zed &>/dev/null; then
      skip "Zed already installed"
  else
      step "Installing Zed editor"
      curl -fsSL https://zed.dev/install.sh | sh || {
          log_error "Failed to install Zed"
          return 1
      }
      ok "Zed installed"
  fi

  _configure_vscode
  
}

_configure_vscode() {
  local user="${SETUP_USER:-$USER}"
  local user_home="${SETUP_HOME:-$HOME}"
  local settings_dir="${user_home}/.config/Code/User"
  local sdkman_candidates="${user_home}/.sdkman/candidates/java"
 
  step "Configuring VS Code (extensions + settings)"
 
  # ── Dependência: VS Code precisa estar instalável via 'code'
  if ! command -v code &>/dev/null; then
    log_warn "VS Code ('code') not found in PATH — skipping configuration"
    return
  fi
 
  # ── Detectar IDs das instalações Java gerenciadas pelo SDKMAN
  local java21_id java25_id java21_path java25_path
  java21_id=$(ls "$sdkman_candidates" 2>/dev/null | grep '^21\.' | sort -t. -k1,1n -k2,2n -k3,3n | tail -1)
  java25_id=$(ls "$sdkman_candidates" 2>/dev/null | grep '^25\.' | sort -t. -k1,1n -k2,2n -k3,3n | tail -1)
 
  if [[ -z "$java21_id" ]]; then
    log_warn "Java 21 not found in SDKMAN candidates — java.configuration.runtimes may be incomplete"
    java21_id="21-tem"  # fallback para evitar JSON inválido
  fi
  if [[ -z "$java25_id" ]]; then
    log_warn "Java 25 not found in SDKMAN candidates — java.configuration.runtimes may be incomplete"
    java25_id="25-tem"
  fi
 
  java21_path="${sdkman_candidates}/${java21_id}"
  java25_path="${sdkman_candidates}/${java25_id}"
  log_info "Java 21 path: ${java21_path}"
  log_info "Java 25 path: ${java25_path}"
 
  # ── Extensões
  log_info "Installing VS Code extensions..."
  local extensions=(
    "redhat.java"
    "vscjava.vscode-java-pack"
    "vscjava.vscode-maven"
    "vscjava.vscode-gradle"
    "vscjava.vscode-spring-initializr"
    "ms-vscode-remote.remote-containers"
    "anthropic.claude-code"
    "eamodio.gitlens"
    "mhutchie.git-graph"
    "streetsidesoftware.code-spell-checker"
    "streetsidesoftware.code-spell-checker-portuguese-brazilian"
    "usernamehw.errorlens"
    "gruntfuggly.todo-tree"
    "mechatroner.rainbow-csv"
    "zhuangtongfa.material-theme"
    "PKief.material-icon-theme"
    "esbenp.prettier-vscode"
    "dbaeumer.vscode-eslint"
    "sonarsource.sonarlint-vscode"
    "humao.rest-client"
    "redhat.vscode-yaml"
    "tamasfe.even-better-toml"
  )
 
  for ext in "${extensions[@]}"; do
    sudo -u "$user" code --install-extension "$ext" --force 2>/dev/null || \
      log_warn "Failed to install extension: ${ext}"
  done
 
  # ── settings.json (variáveis de Java expandidas aqui, por isso sem aspas no delimitador)
  sudo -u "$user" mkdir -p "$settings_dir"
  sudo -u "$user" tee "${settings_dir}/settings.json" > /dev/null << VSCODE_SETTINGS
{
  "workbench.colorTheme": "Material Theme Darker High Contrast",
  "workbench.iconTheme": "material-icon-theme",
  "workbench.startupEditor": "none",
  "workbench.editor.enablePreview": false,
  "workbench.list.smoothScrolling": false,
  "workbench.tree.indent": 16,
  "workbench.activityBar.location": "top",
 
  "editor.fontFamily": "'JetBrains Mono', 'Fira Code', monospace",
  "editor.fontSize": 14,
  "editor.lineHeight": 1.6,
  "editor.fontLigatures": true,
  "editor.letterSpacing": 0.3,
  "editor.cursorStyle": "line",
  "editor.cursorBlinking": "smooth",
  "editor.cursorSmoothCaretAnimation": "off",
  "editor.smoothScrolling": false,
 
  "editor.minimap.enabled": false,
  "editor.renderWhitespace": "boundary",
  "editor.renderControlCharacters": false,
  "editor.occurrencesHighlight": "off",
  "editor.selectionHighlight": false,
  "editor.codeLens": false,
  "editor.hover.delay": 800,
  "editor.suggest.localityBonus": true,
  "editor.suggest.preview": false,
  "editor.quickSuggestionsDelay": 300,
  "editor.inlayHints.enabled": "offUnlessPressed",
  "editor.bracketPairColorization.enabled": true,
  "editor.guides.bracketPairs": "active",
  "diffEditor.ignoreTrimWhitespace": true,
  "search.exclude": {
    "**/node_modules": true,
    "**/target": true,
    "**/build": true,
    "**/.gradle": true,
    "**/.git": true
  },
  "files.watcherExclude": {
    "**/.git/objects/**": true,
    "**/.git/subtree-cache/**": true,
    "**/node_modules/**": true,
    "**/target/**": true,
    "**/build/**": true
  },
 
  "editor.formatOnSave": true,
  "editor.formatOnPaste": false,
  "editor.tabSize": 4,
  "editor.insertSpaces": true,
  "editor.trimAutoWhitespace": true,
  "files.trimTrailingWhitespace": true,
  "files.insertFinalNewline": true,
  "editor.wordWrap": "off",
  "editor.rulers": [100, 120],
  "editor.linkedEditing": true,
 
  "terminal.integrated.defaultProfile.linux": "bash",
  "terminal.integrated.fontFamily": "'JetBrains Mono'",
  "terminal.integrated.fontSize": 13,
  "terminal.integrated.lineHeight": 1.2,
  "terminal.integrated.cursorStyle": "line",
  "terminal.integrated.scrollback": 10000,
  "terminal.integrated.gpuAcceleration": "on",
  "terminal.integrated.enableBell": false,
 
  "git.enableSmartCommit": true,
  "git.confirmSync": false,
  "git.autofetch": true,
  "git.autofetchPeriod": 180,
  "gitlens.codeLens.enabled": false,
  "gitlens.hovers.currentLine.over": "line",
 
  "java.configuration.runtimes": [
    {
      "name": "JavaSE-21",
      "path": "${java21_path}",
      "default": true
    },
    {
      "name": "JavaSE-25",
      "path": "${java25_path}"
    }
  ],
  "java.jdt.ls.java.home": "${java21_path}",
  "java.compile.nullAnalysis.mode": "automatic",
  "java.saveActions.organizeImports": true,
  "java.cleanup.actionsOnSave": [
    "qualifyMembers",
    "qualifyStaticMembers",
    "addOverride",
    "addDeprecated",
    "stringConcatToTextBlock",
    "invertEquals",
    "addFinalModifier",
    "instanceofPatternMatch",
    "lambdaExpression",
    "switchExpression"
  ],
  "java.test.defaultConfig": "junit5",
  "spring-boot.ls.problem.application-properties.UNKNOWN_PROPERTY_KEY": "WARNING",
 
  "docker.environment": {
    "DOCKER_HOST": "unix:///run/user/1000/podman/podman.sock"
  },
  "docker.showStartPage": false,
 
  "errorLens.enabledDiagnosticLevels": ["error", "warning"],
  "errorLens.delay": 1000,
  "errorLens.followCursor": "closestProblem",
 
  "files.autoSave": "onFocusChange",
  "files.autoSaveDelay": 1000,
 
  "telemetry.telemetryLevel": "off",
  "redhat.telemetry.enabled": false,
 
  "accessibility.signals.sounds.volume": 0,
  "editor.accessibilitySupport": "off",
 
  "claude.autoApproveTools": false,
  "claude.preferredModel": "claude-sonnet-4-6"
}
VSCODE_SETTINGS
 
  # ── keybindings.json (aspas simples no delimitador = sem expansão de variáveis)
  sudo -u "$user" tee "${settings_dir}/keybindings.json" > /dev/null << 'KEYBINDINGS'
[
  { "key": "ctrl+`",         "command": "workbench.action.terminal.toggleTerminal" },
  { "key": "ctrl+shift+`",   "command": "workbench.action.terminal.new" },
  { "key": "ctrl+w",         "command": "workbench.action.closeActiveEditor" },
  { "key": "alt+left",       "command": "workbench.action.previousEditor" },
  { "key": "alt+right",      "command": "workbench.action.nextEditor" },
  { "key": "alt+up",         "command": "editor.action.moveLinesUpAction" },
  { "key": "alt+down",       "command": "editor.action.moveLinesDownAction" },
  { "key": "shift+alt+down", "command": "editor.action.copyLinesDownAction" },
  { "key": "ctrl+shift+o",   "command": "java.action.organizeImports" },
  { "key": "ctrl+shift+f",   "command": "editor.action.formatDocument" },
  { "key": "ctrl+b",         "command": "workbench.action.toggleSidebarVisibility" }
]
KEYBINDINGS
 
  ok "VS Code configured — Java 21: ${java21_id} · Java 25: ${java25_id}"
}

# =============================================================================
# 7. Ferramentas CLI de infraestrutura
# =============================================================================

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

_install_awscli() {
    local zip_file="${CACHE_DIR}/awscliv2.zip"
    local extract_dir="${CACHE_DIR}/awscli-extracted"
    local install_dir="/usr/local/aws-cli"
    local bin_dir="/usr/local/bin"

    # Versão instalada
    local current_version=""
    if command -v aws &>/dev/null; then
        current_version=$(aws --version 2>&1 | awk -F/ '{print $2}' | awk '{print $1}')
    fi

    step "Checking AWS CLI"

    cached_download \
        "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" \
        "$zip_file"

    rm -rf "$extract_dir"
    unzip -q "$zip_file" -d "$extract_dir"

    local new_version
    new_version=$("$extract_dir/aws/dist/aws" --version 2>&1 | awk -F/ '{print $2}' | awk '{print $1}')

    if [[ "$current_version" == "$new_version" && -n "$current_version" ]]; then
        skip "AWS CLI already at latest version ($current_version)"
        rm -rf "$extract_dir"
        return
    fi

    step "Installing/Updating AWS CLI to $new_version"

    sudo "$extract_dir/aws/install" \
        --install-dir "$install_dir" \
        --bin-dir "$bin_dir" \
        ${current_version:+--update}

    rm -rf "$extract_dir"

    ok "AWS CLI now at $new_version"
}


# =============================================================================
# 8. Clientes de API REST
# =============================================================================

_install_insomnia() {
    step "Installing Insomnia"
    log_info "Querying latest Insomnia release from GitHub..."

    local tag github_version installed_version
    # Pegar a última release do GitHub
    tag=$(curl -s https://api.github.com/repos/Kong/insomnia/releases/latest \
        | grep -oP '"tag_name":\s*"\K([^"]+)')
    if [[ -z "$tag" ]]; then
        log_error "Unable to identify the latest Insomnia version on GitHub"
        return 1
    fi

    # Normalizar versão: remove prefixo 'core@' se existir
    github_version="${tag#core@}"
    log_info "Latest Insomnia release: ${github_version}"

    # Verificar versão instalada no sistema
    installed_version=$(rpm -q --qf '%{VERSION}\n' insomnia 2>/dev/null || echo "")
    if [[ "$installed_version" == "$github_version" ]]; then
        skip "Insomnia already installed (${installed_version})"
        return
    fi

    # Se chegou aqui, precisa instalar/atualizar
    step "Installing/Updating Insomnia"
    local rpm_asset rpm_file
    rpm_asset=$(curl -s "https://api.github.com/repos/Kong/insomnia/releases/tags/${tag}" \
        | grep -oP 'browser_download_url":\s*"\K([^"]*Insomnia\.Core[^"]*\.rpm)')
    rpm_file="${CACHE_DIR}/$(basename "$rpm_asset")"

    # Baixar RPM só se necessário
    if [[ ! -f "$rpm_file" ]]; then
        log_info "Downloading Insomnia RPM..."
        curl -L "$rpm_asset" -o "$rpm_file"
    else
        log_info "Using cached Insomnia RPM: $rpm_file"
    fi

    # Instalar via DNF
    dnf_install "$rpm_file"
    ok "Insomnia installed/updated to ${github_version}"
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


# =============================================================================
# 9. Utilitários GUI
# =============================================================================

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
        | grep -oP 'browser_download_url":\s*"\K([^"]*x86_64\.rpm)')

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

    dnf_install "$rpm_file"
    ok "DBeaver Community installed (${tag})"
}

_install_drawio() {
    step "Installing draw.io desktop"

    if rpm -q draw.io &>/dev/null; then
      skip "draw.io already installed"
      return
    fi
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

    dnf_install "$rpm_file"
    ok "draw.io installed (${tag})"
}

_install_typora() {
    local install_dir="$SETUP_HOME/.local/share/typora"
    local bin_link="$SETUP_HOME/.local/bin/typora"
    local desktop_file="$SETUP_HOME/.local/share/applications/typora.desktop"
    local archive="${CACHE_DIR}/typora.tar.gz"

    if [[ -x "$bin_link" ]] || [[ -x "$install_dir/Typora" ]] || command -v typora &>/dev/null; then
        skip "Typora already installed"
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


# =============================================================================
# 10. Shell prompt
# =============================================================================

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
$directory\
$git_branch\
$git_status\
$java\
$nodejs\
$python\
$golang\
$aws\
$docker_context\
$cmd_duration\
$line_break\
$character"""

add_newline = true

[character]
success_symbol = '[❯](bold green)'
error_symbol   = '[❯](bold red)'

[directory]
style             = 'bold fg:201'
truncation_length = 3
truncate_to_repo  = true
format            = '[$path]($style)[$read_only]($read_only_style) '

[git_branch]
symbol = 'git '
style  = 'bold fg:117'
format = 'on [$symbol$branch]($style) '

[git_status]
format     = '([$all_status$ahead_behind]($style) )'
style      = 'bold fg:11'
conflicted = '⚠'
ahead      = '⇡${count}'
behind     = '⇣${count}'
diverged   = '⇕⇡${ahead_count}⇣${behind_count}'
untracked  = '?${count}'
modified   = '!${count}'
staged     = '+${count}'
deleted    = '✘${count}'

[git_commit]
tag_symbol = " tag "

[java]
symbol = 'java '
style  = 'bold fg:33'
format = 'via [$symbol($version)]($style) '

[nodejs]
symbol = 'nodejs '
style  = 'bold green'
format = 'via [$symbol($version)]($style) '

[python]
symbol = "python "
format = "via [$symbol$version]($style) "
style  = "bold fg:6"

[golang]
symbol = "golang "
format = "via [$symbol$version]($style) "
style  = "bold fg:3"

[aws]
symbol = "aws "
format = 'on [$symbol($profile )(\($region\) )]($style)'
style = 'bold fg:202'

[docker_context]
symbol          = 'docker '
style           = 'bold blue'
format          = 'via [$symbol$context]($style) '
only_with_files = true

[cmd_duration]
min_time          = 2000
format            = 'took [$duration](bold yellow) '
show_milliseconds = false

[time]
disabled = true

[battery]
disabled = true
TOMLEOF
    ok "Starship initial config created"
  else
    skip "starship.toml already exists"
  fi
}


# =============================================================================
# Standalone entry point
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  source "${SCRIPT_DIR}/utils.sh"
  source "${SCRIPT_DIR}/finitra-default.config"
  [[ -f "${SETUP_HOME}/.config/finitra/finitra.config" ]] && \
    source "${SETUP_HOME}/.config/finitra/finitra.config"
  module_20_dev_tools
fi