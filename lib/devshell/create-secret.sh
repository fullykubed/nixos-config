#!/usr/bin/env bash
# mnemonic: [c]reate [s]ecret
# Encrypt a value with YubiKey recipients and store it as an agenix secret.
# Usage: create-secret <name> [--value <string>] [--file <path>] [--force] [--no-rekey]

REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null)}" || { echo ":: Error: not in a git repository" >&2; exit 1; }
export REPO_ROOT
cd "$REPO_ROOT" || exit

info()  { echo ":: $*" >&2; }
error() { echo ":: Error: $*" >&2; exit 1; }

# ------------------------------------------------------------------------------
# Argument parsing
# ------------------------------------------------------------------------------

SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_NAME

show_help() {
  cat << EOF >&2
Usage: $SCRIPT_NAME <name> [OPTIONS]

Encrypt a value with YubiKey recipients and store it as secrets/<name>.age.

The secret value is read from (checked in order):
  1. --value flag (inline string)
  2. --file flag (read from file path)
  3. stdin (if piped)
  4. interactive prompt (masked input)

Options:
  -v, --value <string>  Provide the secret value inline
  -i, --file <path>     Read the secret value from a file
  -f, --force           Overwrite existing secret without prompting
      --no-rekey        Skip running agenix rekey after creating the secret
  -h, --help            Show this help message

Examples:
  $SCRIPT_NAME github-token --value ghp_xxxxxxxxxxxx
  $SCRIPT_NAME db-password --file /tmp/password.txt
  echo "my-secret" | $SCRIPT_NAME api-key
  $SCRIPT_NAME new-token                          # interactive prompt
EOF
}

SECRET_NAME=""
SECRET_VALUE=""
SECRET_FILE=""
FORCE=false
REKEY=true

while [[ $# -gt 0 ]]; do
  case $1 in
    -v|--value)   shift; SECRET_VALUE="$1" ;;
    -i|--file)    shift; SECRET_FILE="$1" ;;
    -f|--force)   FORCE=true ;;
    --no-rekey)   REKEY=false ;;
    -h|--help)    show_help; exit 0 ;;
    -*)           error "unknown option: $1" ;;
    *)
      if [[ -z "$SECRET_NAME" ]]; then
        SECRET_NAME="$1"
      else
        error "unexpected argument: $1"
      fi
      ;;
  esac
  shift
done

[[ -n "$SECRET_NAME" ]] || { show_help; error "secret name is required"; }

# Strip .age suffix if the user included it
SECRET_NAME="${SECRET_NAME%.age}"

# ------------------------------------------------------------------------------
# Read secret value
# ------------------------------------------------------------------------------

read_secret() {
  if [[ -n "$SECRET_VALUE" ]]; then
    # Value provided inline
    return
  fi

  if [[ -n "$SECRET_FILE" ]]; then
    [[ -f "$SECRET_FILE" ]] || error "file not found: $SECRET_FILE"
    SECRET_VALUE=$(cat "$SECRET_FILE")
    return
  fi

  if [[ ! -t 0 ]]; then
    # stdin is piped
    SECRET_VALUE=$(cat)
    return
  fi

  # Interactive prompt
  info "Enter secret value (input is hidden):"
  read -rs SECRET_VALUE
  echo >&2
  [[ -n "$SECRET_VALUE" ]] || error "empty secret value"
}

read_secret
[[ -n "$SECRET_VALUE" ]] || error "empty secret value"

# ------------------------------------------------------------------------------
# Check for existing secret
# ------------------------------------------------------------------------------

OUTPUT_PATH="secrets/${SECRET_NAME}.age"

if [[ -f "$OUTPUT_PATH" ]] && [[ "$FORCE" != true ]]; then
  info "$OUTPUT_PATH already exists."
  read -rp ":: Overwrite? [y/N] " confirm
  case $confirm in
    y|Y|yes) ;;
    *)       error "aborted" ;;
  esac
fi

# ------------------------------------------------------------------------------
# Collect YubiKey recipients
# ------------------------------------------------------------------------------

RECIPIENTS=()
for pubkey in yubikeys/*.pub; do
  [[ -f "$pubkey" ]] || error "no YubiKey public keys found in yubikeys/"
  recipient=$(grep -oP 'age1\S+' "$pubkey") || continue
  RECIPIENTS+=(-r "$recipient")
done
[[ ${#RECIPIENTS[@]} -gt 0 ]] || error "no age recipients found in yubikeys/*.pub"

# ------------------------------------------------------------------------------
# Encrypt and write
# ------------------------------------------------------------------------------

TMP_FILE=$(mktemp)
cleanup() { rm -f "$TMP_FILE"; }
trap cleanup EXIT

printf '%s\n' "$SECRET_VALUE" | rage -e "${RECIPIENTS[@]}" -o "$TMP_FILE"

mkdir -p "$(dirname "$OUTPUT_PATH")"
cp "$TMP_FILE" "$OUTPUT_PATH"
git add "$OUTPUT_PATH"

info "Created $OUTPUT_PATH"

# ------------------------------------------------------------------------------
# Rekey
# ------------------------------------------------------------------------------

if [[ "$REKEY" == true ]]; then
  info "Rekeying secrets..."
  agenix rekey
  info ""
  info "Done. Next step:"
  info "  git add $OUTPUT_PATH secrets/rekeyed/"
else
  info ""
  info "Done (rekey skipped). Next steps:"
  info "  agenix rekey"
  info "  git add $OUTPUT_PATH secrets/rekeyed/"
fi

# Emit the output path on stdout for scripting
echo "$OUTPUT_PATH"
