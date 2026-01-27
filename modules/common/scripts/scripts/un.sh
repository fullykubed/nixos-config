#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# NixOS Rebuild Script (un.sh)
# Fast NixOS configuration rebuilding with sensible defaults
# ==============================================================================

# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------

readonly NIXOS_CONFIG_DIR="/etc/nixos"
readonly SCRIPT_NAME="$(basename "$0")"

# ------------------------------------------------------------------------------
# Output Helpers
# ------------------------------------------------------------------------------

info()  { echo ":: $*"; }
warn()  { echo ":: Warning: $*" >&2; }
error() { echo ":: Error: $*" >&2; exit 1; }

# ------------------------------------------------------------------------------
# Help Text
# ------------------------------------------------------------------------------

show_help() {
  cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

NixOS rebuild script with performance-optimized defaults.

Options:
  -b, --boot        Rebuild boot configuration only
  -o, --offline     Build without network access (use local store only)
  -u, --update      Update flake inputs before rebuilding
  -h, --help        Show this help message

Options to disable defaults:
  --no-impure, --copy  Copy config to $NIXOS_CONFIG_DIR instead of building directly
  --no-nom             Disable nix-output-monitor

Defaults (for speed):
  - Impure mode is ON: builds directly from repo without copying
  - Nom is ON: pipes output through nix-output-monitor

Examples:
  $SCRIPT_NAME               # Fast rebuild with nom (default)
  $SCRIPT_NAME --no-nom      # Fast rebuild without nom
  $SCRIPT_NAME --copy        # Copy to $NIXOS_CONFIG_DIR first (old behavior)
  $SCRIPT_NAME -u -b         # Update flake inputs and rebuild boot config
EOF
}

# ------------------------------------------------------------------------------
# Repository Discovery
# ------------------------------------------------------------------------------

is_nixos_config_repo() {
  local dir="$1"
  [[ -f "$dir/flake.nix" ]] && [[ -f "$dir/configuration.nix" ]]
}

find_repo_root() {
  # Method 1: Check if we're in a git repository
  if git rev-parse --show-toplevel &>/dev/null; then
    local git_root
    git_root="$(git rev-parse --show-toplevel)"
    if is_nixos_config_repo "$git_root"; then
      echo "$git_root"
      return 0
    fi
  fi

  # Method 2: Walk up directory tree
  local check_dir
  check_dir="$(pwd)"
  while [[ "$check_dir" != "/" ]]; do
    if is_nixos_config_repo "$check_dir"; then
      echo "$check_dir"
      return 0
    fi
    check_dir="$(dirname "$check_dir")"
  done

  # Method 3: Relative to script location
  local script_dir potential_root
  script_dir="$(dirname "$(realpath "$0")")"
  potential_root="$(realpath "$script_dir/../../../..")"
  if is_nixos_config_repo "$potential_root"; then
    echo "$potential_root"
    return 0
  fi

  # Method 4: Common locations
  local dir
  for dir in "$HOME/repos/nixos-config" "$HOME/nixos-config"; do
    if is_nixos_config_repo "$dir"; then
      echo "$dir"
      return 0
    fi
  done

  return 1
}

# ------------------------------------------------------------------------------
# Git Helpers
# ------------------------------------------------------------------------------

init_git_repo_for_flake() {
  local target_dir="$1"
  doas git -C "$target_dir" init -q
  doas git -C "$target_dir" config user.email "nixos-rebuild@localhost"
  doas git -C "$target_dir" config user.name "nixos-rebuild"
  doas git -C "$target_dir" add -A
  doas git -C "$target_dir" commit --no-gpg-sign -q -m "nixos-rebuild snapshot"
}

# ------------------------------------------------------------------------------
# Configuration Copying
# ------------------------------------------------------------------------------

copy_config_to_nixos_dir() {
  local repo_root="$1"

  info "Copying configuration to $NIXOS_CONFIG_DIR..."

  doas rm -rf "$NIXOS_CONFIG_DIR"
  doas mkdir -p "$NIXOS_CONFIG_DIR"

  if git -C "$repo_root" rev-parse --git-dir &>/dev/null; then
    # Fast path: use git archive
    git -C "$repo_root" archive --format=tar HEAD | doas tar -xf - -C "$NIXOS_CONFIG_DIR"
  else
    # Fallback: plain copy
    doas cp -r "$repo_root/." "$NIXOS_CONFIG_DIR/"
    doas rm -rf "$NIXOS_CONFIG_DIR/.git" "$NIXOS_CONFIG_DIR/.direnv" "$NIXOS_CONFIG_DIR/.idea"
  fi

  init_git_repo_for_flake "$NIXOS_CONFIG_DIR"
}

# ------------------------------------------------------------------------------
# Build Execution
# ------------------------------------------------------------------------------

run_nixos_rebuild() {
  local rebuild_cmd="$1"
  local flake_path="$2"
  local hostname="$3"
  local use_nom="$4"
  local impure_mode="$5"
  shift 5
  local build_flags=("$@")

  # In impure mode, build as user (who owns the repo) then switch as root
  # This avoids git ownership issues when running doas
  if [[ "$impure_mode" == true ]]; then
    run_nixos_rebuild_split "$rebuild_cmd" "$flake_path" "$hostname" "$use_nom" "${build_flags[@]}"
  else
    run_nixos_rebuild_direct "$rebuild_cmd" "$flake_path" "$hostname" "$use_nom" "${build_flags[@]}"
  fi
}

# Build and switch in one command (for copy mode where root owns the repo)
run_nixos_rebuild_direct() {
  local rebuild_cmd="$1"
  local flake_path="$2"
  local hostname="$3"
  local use_nom="$4"
  shift 4
  local build_flags=("$@")

  if [[ "$use_nom" == true ]] && command -v nom &>/dev/null; then
    info "Using nix-output-monitor for progress display..."
    doas nixos-rebuild "$rebuild_cmd" "${build_flags[@]}" --flake "$flake_path#$hostname" |& nom
  else
    [[ "$use_nom" == true ]] && warn_nom_missing
    doas nixos-rebuild "$rebuild_cmd" "${build_flags[@]}" --flake "$flake_path#$hostname"
  fi
}

# Build as user, switch as root (for impure mode where user owns the repo)
run_nixos_rebuild_split() {
  local rebuild_cmd="$1"
  local flake_path="$2"
  local hostname="$3"
  local use_nom="$4"
  shift 4
  local build_flags=("$@")

  local flake_attr="$flake_path#nixosConfigurations.$hostname.config.system.build.toplevel"

  info "Building as user (to avoid git ownership issues)..."

  # Build with nom for visual progress (if available)
  if [[ "$use_nom" == true ]] && command -v nom &>/dev/null; then
    info "Using nix-output-monitor for progress display..."
    nix build --no-link "$flake_attr" |& nom
  else
    [[ "$use_nom" == true ]] && warn_nom_missing
    nix build --no-link "$flake_attr"
  fi

  # Get the output path (instant since already built, suppress warnings)
  local system_path
  system_path=$(nix build --print-out-paths --no-link "$flake_attr" 2>/dev/null)

  if [[ -z "$system_path" ]]; then
    error "Build failed - no output path"
  fi

  info "Build complete: $system_path"
  info "Activating configuration as root..."

  # Activate as root
  case "$rebuild_cmd" in
    switch)
      doas nix-env -p /nix/var/nix/profiles/system --set "$system_path"
      doas "$system_path/bin/switch-to-configuration" switch
      ;;
    boot)
      doas nix-env -p /nix/var/nix/profiles/system --set "$system_path"
      doas "$system_path/bin/switch-to-configuration" boot
      ;;
    test)
      doas "$system_path/bin/switch-to-configuration" test
      ;;
    *)
      error "Unknown rebuild command: $rebuild_cmd"
      ;;
  esac
}

warn_nom_missing() {
  warn "nom (nix-output-monitor) not found, falling back to standard output"
  warn "Install nom with: nix profile install nixpkgs#nix-output-monitor"
}

# ------------------------------------------------------------------------------
# Argument Parsing
# ------------------------------------------------------------------------------

parse_args() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      -b|--boot)       BOOT_MODE=true ;;
      -o|--offline)    OFFLINE_MODE=true ;;
      -u|--update)     UPDATE_MODE=true ;;
      -i|--impure)     IMPURE_MODE=true ;;
      --no-impure|--copy) IMPURE_MODE=false ;;
      -n|--nom)        USE_NOM=true ;;
      --no-nom)        USE_NOM=false ;;
      -h|--help)       show_help; exit 0 ;;
      *)               error "Unknown option: $1. Run '$SCRIPT_NAME --help' for usage." ;;
    esac
    shift
  done
}

validate_options() {
  if [[ "$UPDATE_MODE" == true ]] && [[ "$OFFLINE_MODE" == true ]]; then
    error "Cannot update flake inputs in offline mode"
  fi
}

# ------------------------------------------------------------------------------
# Main
# ------------------------------------------------------------------------------

main() {
  # Default values (performance-optimized)
  BOOT_MODE=false
  OFFLINE_MODE=false
  UPDATE_MODE=false
  IMPURE_MODE=true
  USE_NOM=true

  parse_args "$@"
  validate_options

  # Find repository root
  local repo_root
  repo_root="$(find_repo_root)" || error "Could not find nixos-config repository root. Run from within the repository."
  info "Using repository root: $repo_root"

  # Update flake inputs if requested
  if [[ "$UPDATE_MODE" == true ]]; then
    info "Updating flake inputs..."
    nix flake update --flake "$repo_root"
  fi

  # Determine flake path
  local flake_path
  if [[ "$IMPURE_MODE" == true ]]; then
    flake_path="$repo_root"
    info "Building directly from $repo_root (impure mode)"
  else
    copy_config_to_nixos_dir "$repo_root"
    flake_path="$NIXOS_CONFIG_DIR"
  fi

  # Get hostname
  local hostname
  hostname=$(hostname)

  # Determine rebuild command
  local rebuild_cmd
  if [[ "$BOOT_MODE" == true ]]; then
    rebuild_cmd="boot"
    info "Rebuilding boot configuration for: $hostname"
  else
    rebuild_cmd="switch"
    info "Rebuilding and switching configuration for: $hostname"
  fi

  # Build flags array
  local build_flags=(--accept-flake-config)

  [[ "$OFFLINE_MODE" == true ]] && build_flags+=(--offline) && info "Building in offline mode"
  [[ "$IMPURE_MODE" == true ]] && build_flags+=(--impure)

  # Add --no-reexec for faster switch (when not updating)
  if [[ "$BOOT_MODE" == false ]] && [[ "$UPDATE_MODE" == false ]] && [[ "$OFFLINE_MODE" == false ]]; then
    build_flags+=(--no-reexec)
  fi

  # Execute rebuild
  run_nixos_rebuild "$rebuild_cmd" "$flake_path" "$hostname" "$USE_NOM" "$IMPURE_MODE" "${build_flags[@]}"
}

main "$@"
