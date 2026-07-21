#!/usr/bin/env bash
# migrations/0002-bash-completion.sh
#
# Installs bash completion for users who already have initora installed,
# since starting with this version bootstrap.sh does this automatically
# on new installs.
#
# The completion script is versioned in the repo at completions/initora-completion.bash
# and, by the time this migration runs (inside `initora update`), the repo
# at ${SCRIPT_DIR} has already been updated -- so it's already available.

migration_0002_bash_completion() {
  log_info "Installing bash autocomplete for initora..."

  local completion_src="${SCRIPT_DIR}/completions/initora-completion.bash"
  local completion_dest_dir="${SETUP_HOME}/.local/share/bash-completion/completions"
  local completion_dest="${completion_dest_dir}/initora"

  if [[ ! -f "$completion_src" ]]; then
    log_error "Completion script not found at: ${completion_src}"
    return 1
  fi

  mkdir -p "$completion_dest_dir"
  cp -f "$completion_src" "$completion_dest"

  log_success "Autocomplete installed at: ${completion_dest}"
  log_info "Open a new terminal (or run: source ${completion_dest}) to enable it."

  if ! rpm -q bash-completion &>/dev/null; then
    log_warn "Package 'bash-completion' not detected -- completion may not"
    log_warn "load automatically. Install it with: sudo dnf install bash-completion"
  fi

  return 0
}