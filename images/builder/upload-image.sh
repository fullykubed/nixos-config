#!/usr/bin/env bash
# images/builder/upload-image.sh
# Build and upload the NixOS builder image to Hetzner Cloud
#
# Usage: ./images/builder/upload-image.sh        (builds then prompts for doas to upload)
#    or: doas ./images/builder/upload-image.sh   (if image already built)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TOKEN_FILE="/run/agenix/hetzner-api-token"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

cd "$REPO_ROOT"

IMAGE_DIR="/tmp/hetzner-images"
IMAGE_PATH="$IMAGE_DIR/builder.img.zst"

# Build image (nix build produces a zstd-compressed image)
if [[ "${_UPLOAD_SKIP_BUILD:-}" != "1" ]]; then
  echo -e "${YELLOW}Building builder image...${NC}"
  mkdir -p "$IMAGE_DIR"
  if [[ $EUID -eq 0 ]]; then
    REPO_OWNER=$(stat -c '%U' "$REPO_ROOT")
    chown "$REPO_OWNER" "$IMAGE_DIR"
    su "$REPO_OWNER" -c "cd '$REPO_ROOT' && nix build .#builder-image --print-build-logs --builders '' --out-link '$IMAGE_DIR/builder-result'"
  else
    nix build .#builder-image --print-build-logs --builders '' --out-link "$IMAGE_DIR/builder-result"
  fi
  cp "$IMAGE_DIR/builder-result/nixos.img.zst" "$IMAGE_PATH"
  rm -f "$IMAGE_DIR/builder-result"
fi

if [[ ! -f "$IMAGE_PATH" ]]; then
  echo -e "${RED}Error: Compressed image not found at $IMAGE_PATH${NC}" >&2
  exit 1
fi

# Upload requires root for token access
if [[ $EUID -ne 0 ]]; then
  echo -e "${YELLOW}Elevating to root for upload...${NC}"
  exec env _UPLOAD_SKIP_BUILD=1 doas "$0" "$@"
fi

if [[ ! -f "$TOKEN_FILE" ]]; then
  echo -e "${RED}Error: Hetzner API token not found at $TOKEN_FILE${NC}" >&2
  exit 1
fi

export HCLOUD_TOKEN
HCLOUD_TOKEN=$(cat "$TOKEN_FILE")

echo -e "${YELLOW}Uploading image to Hetzner Cloud...${NC}"
echo "This will create a temporary server, upload the image, and create a snapshot."
echo ""

UPLOAD_COMPLETE=false

cleanup_upload_server() {
  if [[ "$UPLOAD_COMPLETE" == true ]]; then
    return
  fi
  echo -e "\n${YELLOW}Interrupted — cleaning up temporary upload server...${NC}"
  local servers
  servers=$(hcloud server list -o json 2>/dev/null \
    | jaq -r '.[] | select(.name | startswith("hcloud-upload-image-")) | .name' || true)
  for name in $servers; do
    echo -e "${YELLOW}Deleting $name...${NC}"
    hcloud server delete "$name" 2>/dev/null || true
  done
}
trap cleanup_upload_server INT TERM EXIT

hcloud-upload-image upload \
  --image-path "$IMAGE_PATH" \
  --compression zstd \
  --architecture x86 \
  --location hel1 \
  --labels type=builder \
  --description "NixOS builder UEFI $(date +%Y-%m-%d)"

UPLOAD_COMPLETE=true
trap - INT TERM EXIT

echo ""
echo -e "${GREEN}Upload complete!${NC}"
echo ""
echo "The snapshot is labeled type=builder and will be used automatically by 'builders create'."
