#!/usr/bin/env bash

# Parse command line arguments
BOOT_MODE=false
OFFLINE_MODE=false
UPDATE_MODE=false

while [[ $# -gt 0 ]]; do
  case $1 in
  -b | --boot)
    BOOT_MODE=true
    shift
    ;;
  -o | --offline)
    OFFLINE_MODE=true
    shift
    ;;
  -u | --update)
    UPDATE_MODE=true
    shift
    ;;
  -h | --help)
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -b, --boot      Rebuild boot configuration only"
    echo "  -o, --offline   Build without network access (use local store only)"
    echo "  -u, --update    Update flake inputs before rebuilding"
    echo "  -h, --help      Show this help message"
    echo ""
    echo "Without options, rebuilds and switches to the new configuration"
    echo "with --fast flag (skips channel updates)"
    exit 0
    ;;
  *)
    echo "Unknown option: $1"
    echo "Run '$0 --help' for usage information"
    exit 1
    ;;
  esac
done

# Find the repository root
# Try multiple methods to locate the nixos-config repository
find_repo_root() {
  # Method 1: Check if we're in a git repository
  if git rev-parse --show-toplevel &>/dev/null; then
    local git_root="$(git rev-parse --show-toplevel)"
    # Verify this is the nixos-config repo by checking for flake.nix
    if [[ -f "$git_root/flake.nix" ]] && [[ -f "$git_root/configuration.nix" ]]; then
      echo "$git_root"
      return 0
    fi
  fi

  # Method 2: Check current directory and parents for flake.nix
  local check_dir="$(pwd)"
  while [[ "$check_dir" != "/" ]]; do
    if [[ -f "$check_dir/flake.nix" ]] && [[ -f "$check_dir/configuration.nix" ]]; then
      echo "$check_dir"
      return 0
    fi
    check_dir="$(dirname "$check_dir")"
  done

  # Method 3: Check if script is in expected location
  local script_dir="$(dirname "$(realpath "$0")")"
  local potential_root="$(realpath "$script_dir/../../../..")"
  if [[ -f "$potential_root/flake.nix" ]] && [[ -f "$potential_root/configuration.nix" ]]; then
    echo "$potential_root"
    return 0
  fi

  # Method 4: Default fallback - check common locations
  for dir in "$HOME/repos/nixos-config" "$HOME/nixos-config"; do
    if [[ -f "$dir/flake.nix" ]] && [[ -f "$dir/configuration.nix" ]]; then
      echo "$dir"
      return 0
    fi
  done

  return 1
}

REPO_ROOT="$(find_repo_root)"
if [[ -z "$REPO_ROOT" ]]; then
  echo "Error: Could not find nixos-config repository root"
  echo "Please run this script from within the nixos-config repository"
  exit 1
fi

echo "Using repository root: $REPO_ROOT"

# Copy the local system configuration project to the OS etc directory;
# Change ownership to root
sudo rsync \
  -r \
  -p \
  --usermap=$USER:root \
  --exclude=.idea \
  --exclude=.direnv \
  "$REPO_ROOT/" /etc/nixos

# Get current hostname for flake target
HOSTNAME=$(hostname)

# Update flake inputs if requested
if [[ "$UPDATE_MODE" == true ]]; then
  if [[ "$OFFLINE_MODE" == true ]]; then
    echo "Error: Cannot update flake inputs in offline mode"
    exit 1
  fi
  echo "Updating flake inputs..."
  cd /etc/nixos && sudo nix flake update
fi

# Build the rebuild command
if [[ "$BOOT_MODE" == true ]]; then
  REBUILD_CMD="boot"
  echo "Rebuilding boot configuration for: $HOSTNAME"
else
  REBUILD_CMD="switch"
  echo "Rebuilding and switching configuration for: $HOSTNAME"
fi

# Add offline flag if requested
if [[ "$OFFLINE_MODE" == true ]]; then
  BUILD_FLAGS="--offline"
  echo "Building in offline mode (no network access)"
else
  # Default to --fast for switch mode when not offline and not updating
  if [[ "$BOOT_MODE" == false ]] && [[ "$UPDATE_MODE" == false ]]; then
    BUILD_FLAGS="--fast"
  else
    BUILD_FLAGS=""
  fi
fi

# Execute the rebuild
sudo nixos-rebuild $REBUILD_CMD $BUILD_FLAGS --flake "/etc/nixos#$HOSTNAME"
