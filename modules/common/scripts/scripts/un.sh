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
SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_NAME

# ------------------------------------------------------------------------------
# Output Helpers
# ------------------------------------------------------------------------------

info()  { echo ":: $*"; }
warn()  { echo ":: Warning: $*" >&2; }
error() { echo ":: Error: $*" >&2; exit 1; }

# Run a command as the original (non-root) user
as_user() {
  if [[ -n "${DOAS_USER:-}" ]]; then
    runuser -u "$DOAS_USER" -- "$@"
  else
    "$@"
  fi
}

# ------------------------------------------------------------------------------
# Help Text
# ------------------------------------------------------------------------------

show_help() {
  cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

NixOS rebuild script with performance-optimized defaults.

Options:
  -b, --boot            Rebuild boot configuration only
  -t, --test            Test configuration without making it permanent
  -B, --builders N      Use N regular remote builders (0 to disable all, default: all configured)
  -P, --big-builders N  Use N big-parallel remote builders (default: all configured)
  -j, --jobs N          Set max concurrent derivation builds (default: 1)
  -o, --offline         Build without network access (use local store only)
  -S, --no-substituters Skip all binary cache lookups (build everything locally)
  -u, --update          Update flake inputs before rebuilding
  -s, --stop-on-error   Stop on first build failure (override keep-going)
  -h, --help            Show this help message

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
  $SCRIPT_NAME -B 3 -P 1     # Use 3 regular + 1 big-parallel builder
  $SCRIPT_NAME -B 0          # Disable all remote builders (both types)
  $SCRIPT_NAME -s            # Stop on first failure for debugging
  $SCRIPT_NAME -t            # Test config (activates but doesn't survive reboot)
  $SCRIPT_NAME -S            # Skip binary cache queries (faster with custom stdenv)
EOF
}

# ------------------------------------------------------------------------------
# Repository Discovery
# ------------------------------------------------------------------------------

is_nixos_config_repo() {
  local dir="$1"
  [[ -f "$dir/flake.nix" ]] && [[ -d "$dir/modules" ]]
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
  local search_homes=("$HOME")
  [[ -n "${DOAS_USER:-}" ]] && search_homes+=("$(eval echo "~$DOAS_USER")")
  local home dir
  for home in "${search_homes[@]}"; do
    for dir in "$home/repos/nixos-config" "$home/nixos-config"; do
      if is_nixos_config_repo "$dir"; then
        echo "$dir"
        return 0
      fi
    done
  done

  return 1
}

# ------------------------------------------------------------------------------
# Git Helpers
# ------------------------------------------------------------------------------

init_git_repo_for_flake() {
  local target_dir="$1"
  git -C "$target_dir" init -q
  git -C "$target_dir" config user.email "nixos-rebuild@localhost"
  git -C "$target_dir" config user.name "nixos-rebuild"
  git -C "$target_dir" add -A
  git -C "$target_dir" commit --no-gpg-sign -q -m "nixos-rebuild snapshot"
}

# ------------------------------------------------------------------------------
# Configuration Copying
# ------------------------------------------------------------------------------

copy_config_to_nixos_dir() {
  local repo_root="$1"

  info "Copying configuration to $NIXOS_CONFIG_DIR..."

  rm -rf "$NIXOS_CONFIG_DIR"
  mkdir -p "$NIXOS_CONFIG_DIR"

  if git -C "$repo_root" rev-parse --git-dir &>/dev/null; then
    # Fast path: use git archive
    git -C "$repo_root" archive --format=tar HEAD | tar -xf - -C "$NIXOS_CONFIG_DIR"
  else
    # Fallback: plain copy
    cp -r "$repo_root/." "$NIXOS_CONFIG_DIR/"
    rm -rf "$NIXOS_CONFIG_DIR/.git" "$NIXOS_CONFIG_DIR/.direnv" "$NIXOS_CONFIG_DIR/.idea"
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

  # Split args on "--" separator: nix_flags -- rebuild_flags
  local nix_flags=()
  local rebuild_flags=()
  local past_separator=false
  for arg in "$@"; do
    if [[ "$arg" == "--" ]]; then
      past_separator=true
    elif [[ "$past_separator" == true ]]; then
      rebuild_flags+=("$arg")
    else
      nix_flags+=("$arg")
    fi
  done

  # In impure mode, build as user then activate as root
  if [[ "$impure_mode" == true ]]; then
    run_nixos_rebuild_split "$rebuild_cmd" "$flake_path" "$hostname" "$use_nom" "${nix_flags[@]}"
  else
    run_nixos_rebuild_direct "$rebuild_cmd" "$flake_path" "$hostname" "$use_nom" "${nix_flags[@]}" "${rebuild_flags[@]}"
  fi
}

# Build and switch in one command (for copy mode where root owns the repo)
run_nixos_rebuild_direct() {
  local rebuild_cmd="$1"
  local flake_path="$2"
  local hostname="$3"
  local use_nom="$4"
  shift 4
  local all_flags=("$@")

  if [[ "$use_nom" == true ]] && command -v nom &>/dev/null; then
    info "Using nix-output-monitor for progress display..."
    nixos-rebuild "$rebuild_cmd" "${all_flags[@]}" --flake "$flake_path#$hostname" --log-format internal-json -v |& nom --json
  else
    [[ "$use_nom" == true ]] && warn_nom_missing
    nixos-rebuild "$rebuild_cmd" "${all_flags[@]}" --flake "$flake_path#$hostname"
  fi
}

# Build then switch (for impure mode)
run_nixos_rebuild_split() {
  local rebuild_cmd="$1"
  local flake_path="$2"
  local hostname="$3"
  local use_nom="$4"
  shift 4
  local nix_flags=("$@")

  local flake_attr="$flake_path#nixosConfigurations.$hostname.config.system.build.toplevel"

  info "Building as ${DOAS_USER:-$(whoami)}..."

  # Build as the original user (nix daemon handles the actual building)
  if [[ "$use_nom" == true ]] && command -v nom &>/dev/null; then
    info "Using nix-output-monitor for progress display..."
    as_user nix build --no-link "${nix_flags[@]}" "$flake_attr" --log-format internal-json -v |& nom --json
  else
    [[ "$use_nom" == true ]] && warn_nom_missing
    as_user nix build --no-link "${nix_flags[@]}" "$flake_attr"
  fi

  # Get the output path (instant since already built, suppress warnings)
  local system_path
  system_path=$(as_user nix build --print-out-paths --no-link "${nix_flags[@]}" "$flake_attr" 2>/dev/null)

  if [[ -z "$system_path" ]]; then
    error "Build failed - no output path"
  fi

  info "Build complete: $system_path"
  info "Activating configuration..."

  case "$rebuild_cmd" in
    switch)
      nix-env -p /nix/var/nix/profiles/system --set "$system_path"
      "$system_path/bin/switch-to-configuration" switch
      ;;
    boot)
      nix-env -p /nix/var/nix/profiles/system --set "$system_path"
      "$system_path/bin/switch-to-configuration" boot
      ;;
    test)
      "$system_path/bin/switch-to-configuration" test
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
      -t|--test)       TEST_MODE=true ;;
      -B|--builders)   shift; BUILDER_COUNT="$1" ;;
      -P|--big-builders) shift; BIG_BUILDER_COUNT="$1" ;;
      -j|--jobs)       shift; MAX_JOBS="$1" ;;
      -o|--offline)    OFFLINE_MODE=true ;;
      -S|--no-substituters) NO_SUBSTITUTERS=true ;;
      -s|--stop-on-error) STOP_ON_ERROR=true ;;
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
  if [[ "$BOOT_MODE" == true ]] && [[ "$TEST_MODE" == true ]]; then
    error "Cannot use --boot and --test together"
  fi
}

# ------------------------------------------------------------------------------
# Main
# ------------------------------------------------------------------------------

main() {
  # Default values (performance-optimized)
  BOOT_MODE=false
  TEST_MODE=false
  OFFLINE_MODE=false
  STOP_ON_ERROR=false
  NO_SUBSTITUTERS=false
  UPDATE_MODE=false
  IMPURE_MODE=true
  USE_NOM=true
  MAX_JOBS="1"
  BUILDER_COUNT=""      # Empty = use all configured builders
  BIG_BUILDER_COUNT=""  # Empty = use all configured big builders

  parse_args "$@"
  validate_options

  # Re-exec as root upfront so privileged operations don't prompt mid-build
  if [[ $EUID -ne 0 ]]; then
    exec doas "$0" "$@"
  fi

  # Allow git to access user-owned repositories when running as root
  export GIT_CONFIG_COUNT=1
  export GIT_CONFIG_KEY_0=safe.directory
  export GIT_CONFIG_VALUE_0='*'

  # Find repository root
  local repo_root
  repo_root="$(find_repo_root)" || error "Could not find nixos-config repository root. Run from within the repository."
  info "Using repository root: $repo_root"

  # Update flake inputs if requested
  if [[ "$UPDATE_MODE" == true ]]; then
    info "Updating flake inputs..."
    as_user nix flake update --flake "$repo_root"
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
  if [[ "$TEST_MODE" == true ]]; then
    rebuild_cmd="test"
    info "Testing configuration for: $hostname (will not survive reboot)"
  elif [[ "$BOOT_MODE" == true ]]; then
    rebuild_cmd="boot"
    info "Rebuilding boot configuration for: $hostname"
  else
    rebuild_cmd="switch"
    info "Rebuilding and switching configuration for: $hostname"
  fi

  # Build flags (work with both nix build and nixos-rebuild)
  local nix_flags=()
  [[ "$OFFLINE_MODE" == true ]] && nix_flags+=(--offline) && info "Building in offline mode"
  [[ "$NO_SUBSTITUTERS" == true ]] && nix_flags+=(--option substitute false) && info "Skipping binary cache lookups"
  [[ "$STOP_ON_ERROR" == true ]] && nix_flags+=(--no-keep-going) && info "Stopping on first build failure"
  [[ "$IMPURE_MODE" == true ]] && nix_flags+=(--impure)
  nix_flags+=(--max-jobs "$MAX_JOBS")
  [[ "$MAX_JOBS" != "1" ]] && info "Max concurrent builds: $MAX_JOBS"

  # Handle builders flags (-B for regular, -P for big-parallel)
  if [[ -n "$BUILDER_COUNT" ]] || [[ -n "$BIG_BUILDER_COUNT" ]]; then
    if [[ "${BUILDER_COUNT:-}" == "0" ]] && [[ -z "$BIG_BUILDER_COUNT" ]]; then
      # -B 0 with no -P: disable all remote builders
      nix_flags+=(--builders "")
      info "Remote builders disabled"
    else
      local builder_list=""

      # Generate regular builder entries (no big-parallel feature)
      local regular_n="${BUILDER_COUNT:-}"
      if [[ -n "$regular_n" ]] && [[ "$regular_n" -gt 0 ]]; then
        for i in $(seq 1 "$regular_n"); do
          if [[ -n "$builder_list" ]]; then
            builder_list+="; "
          fi
          builder_list+="ssh://remotebuild@builder-$i x86_64-linux /root/.ssh/builder-key 4 1 nixos-test,kvm,benchmark"
        done
      fi

      # Generate big-parallel builder entries (supports big-parallel, accepts any job)
      local big_n="${BIG_BUILDER_COUNT:-}"
      if [[ -n "$big_n" ]] && [[ "$big_n" -gt 0 ]]; then
        for i in $(seq 1 "$big_n"); do
          if [[ -n "$builder_list" ]]; then
            builder_list+="; "
          fi
          builder_list+="ssh://remotebuild@big-builder-$i x86_64-linux /root/.ssh/builder-key 1 1 nixos-test,big-parallel,kvm,benchmark"
        done
      fi

      if [[ -z "$builder_list" ]]; then
        nix_flags+=(--builders "")
        info "Remote builders disabled"
      else
        nix_flags+=(--builders "$builder_list")
        local msg=""
        [[ -n "$regular_n" ]] && [[ "$regular_n" -gt 0 ]] && msg="${regular_n} regular"
        if [[ -n "$big_n" ]] && [[ "$big_n" -gt 0 ]]; then
          [[ -n "$msg" ]] && msg+=" + "
          msg+="${big_n} big-parallel"
        fi
        info "Using ${msg} builder(s)"
      fi
    fi
  fi

  # Additional flags for nixos-rebuild only
  local rebuild_flags=(--accept-flake-config)
  if [[ "$BOOT_MODE" == false ]] && [[ "$UPDATE_MODE" == false ]] && [[ "$OFFLINE_MODE" == false ]]; then
    rebuild_flags+=(--no-reexec)
  fi

  # Execute rebuild
  run_nixos_rebuild "$rebuild_cmd" "$flake_path" "$hostname" "$USE_NOM" "$IMPURE_MODE" "${nix_flags[@]}" -- "${rebuild_flags[@]}"
}

main "$@"
