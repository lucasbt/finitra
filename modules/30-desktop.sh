#!/usr/bin/env bash

MODULE_NAME="30-desktop"

FONTS=(
  "FiraCode" "JetBrainsMono" "Hack" "Meslo"
  "SourceCodePro" "UbuntuMono" "CascadiaCode"
)

WALLS_FOLDERS=(
  "tile" "retro" "radium" "nord" "mountain"
  "monochrome" "digital" "lightbulb"
  "solarized" "spam" "unsorted"
)

# -----------------------------------------------------------------------------
# Helpers essenciais (SEM duplicação)
# -----------------------------------------------------------------------------
run_user() {
    local user="${SETUP_USER:-$USER}"
    sudo -u "$user" \
      DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u "$user")/bus" \
      "$@"
}

system_disable() {
    systemctl disable --now "$1" 2>/dev/null || true
    systemctl mask "$1" 2>/dev/null || true
}

user_disable() {
    run_user systemctl --user disable --now "$1" 2>/dev/null || true
}

# -----------------------------------------------------------------------------
module_30_desktop() {
    log_section "Module: GNOME Desktop"

    apply_gnome_settings
    configure_keybindings
    disable_services
    configure_localsearch
    configure_ptyxis
    install_extensions
    install_wallpapers
    install_fonts
    install_microsoft_fonts

    log_success "Module completed"
}

# -----------------------------------------------------------------------------
apply_gnome_settings() {
    step "GNOME settings"

    local file="${SCRIPT_DIR}/data/gnome-settings.list"
    [[ -f "$file" ]] || { log_error "missing gnome settings"; return 1; }

    apply_gnome_settings_file "$file"

    ok "GNOME settings applied"
}

# -----------------------------------------------------------------------------
configure_keybindings() {
    step "Keybindings"

    run_user gsettings set \
      org.gnome.settings-daemon.plugins.media-keys custom-keybindings \
      "['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/ck0/','/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/ck1/']"

    run_user gsettings set \
      org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/ck0/ \
      name "Terminal"

    run_user gsettings set \
      org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/ck0/ \
      command "ptyxis"

    run_user gsettings set \
      org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/ck0/ \
      binding "<Super>t"

    run_user gsettings set \
      org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/ck1/ \
      name "Screenshot"

    run_user gsettings set \
      org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/ck1/ \
      command "flatpak run be.alexandervanhee.gradia --screenshot=INTERACTIVE"

    run_user gsettings set \
      org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/ck1/ \
      binding "<Super>Print"

    ok "Keybindings applied"
}

# -----------------------------------------------------------------------------
disable_services()
{
    step "Disabling services"

    system_disable "dnf5-makecache.timer"
    system_disable "dnf5-makecache.service"
    system_disable "NetworkManager-wait-online.service"
    system_disable "gnome-remote-desktop.service"

    system_disable "abrtd.service"
    system_disable "abrt-oops.service"
    system_disable "abrt-vmcore.service"
    system_disable "abrt-xorg.service"
    system_disable "abrt-journal-core.service"

    system_disable "ModemManager.service"

    user_disable "evolution-source-registry.service"
    user_disable "evolution-addressbook-factory.service"
    user_disable "evolution-calendar-factory.service"

    ok "Services disabled"
}

# -----------------------------------------------------------------------------
configure_localsearch()
{
    step "LocalSearch lightweight mode"

    run_user gsettings set org.freedesktop.Tracker3.Miner.Files index-single-directories "[]"
    run_user gsettings set org.freedesktop.Tracker3.Miner.Files index-recursive-directories "[]"

    user_disable "localsearch-miner@rss.service"
    user_disable "tracker-miner-rss-3.service"

    user_disable "localsearch-writeback-3.service"
    user_disable "localsearch-control-3.service"
    user_disable "tinysparql-xdg-portal-3.service"

    ok "LocalSearch tuned"
}

# -----------------------------------------------------------------------------
configure_ptyxis()
{
    step "Ptyxis"

    local user="${SETUP_USER:-$USER}"

    local uuid
    uuid=$(run_user dconf read /org/gnome/Ptyxis/default-profile-uuid 2>/dev/null | tr -d "'")

    [[ -z "$uuid" ]] && { log_warn "no ptyxis profile"; return; }

    local path="/org/gnome/Ptyxis/Profiles/${uuid}/"

    run_user gsettings set org.gnome.Ptyxis.Profile:${path} palette "'One Half Black'"
    run_user gsettings set org.gnome.Ptyxis.Profile:${path} scrollback-lines 10000
    run_user gsettings set org.gnome.Ptyxis.Profile:${path} opacity 1.0

    ok "Ptyxis configured"
}

# -----------------------------------------------------------------------------
install_extensions()
{
    step "GNOME extensions"

    dnf_install \
      gnome-extensions-app \
      gnome-tweaks \
      gnome-shell-extension-appindicator \
      gnome-shell-extension-caffeine \
      gnome-shell-extension-just-perfection

    ok "Extensions installed"
}

# -----------------------------------------------------------------------------
install_wallpapers()
{
    [[ "${INSTALL_WALLPAPERS:-false}" != "true" ]] && return

    step "Wallpapers"

    local repo="https://github.com/lucasbt/walls"
    local tmp="${CACHE_DIR}/walls"

    rm -rf "$tmp"
    git clone --filter=blob:none --no-checkout "$repo" "$tmp"

    pushd "$tmp" >/dev/null

    git sparse-checkout init --cone

    for f in "${WALLS_FOLDERS[@]}"; do
        git sparse-checkout set "$f"
    done

    git checkout HEAD

    popd >/dev/null
    rm -rf "$tmp"

    ok "Wallpapers installed"
}

# -----------------------------------------------------------------------------
install_fonts()
{
    step "Nerd Fonts"

    local dir="$HOME/.local/share/fonts/nerd"
    mkdir -p "$dir"

    local url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download"

    for f in "${FONTS[@]}"; do
        curl -fLo "/tmp/$f.zip" "$url/$f.zip"
        unzip -o "/tmp/$f.zip" -d "$dir" >/dev/null
        rm "/tmp/$f.zip"
    done

    fc-cache -fv >/dev/null

    ok "Fonts installed"
}

# -----------------------------------------------------------------------------
install_microsoft_fonts()
{
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