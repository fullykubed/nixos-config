{ pkgs, ... }:
{
  # Mount persistent Hetzner Cloud Volume before stateful services start
  systemd.services.controller-volume-mount = {
    description = "Mount persistent Hetzner Cloud Volume";
    after = [ "secrets-ready.target" ];
    requires = [ "secrets-ready.target" ];
    before = [
      "headscale.service"
      "caddy.service"
      "postgresql.service"
      "niks3.service"
      "controller-dns-update.service"
    ];
    requiredBy = [
      "headscale.service"
      "caddy.service"
      "postgresql.service"
      "niks3.service"
      "controller-dns-update.service"
    ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    path = with pkgs; [
      util-linux
      coreutils
      cryptsetup
      e2fsprogs
    ];
    script = ''
      # Find the attached Hetzner Cloud Volume (only one is ever attached)
      VOLUME_DEV=$(echo /dev/disk/by-id/scsi-0HC_Volume_*)
      if [[ ! -b "$VOLUME_DEV" ]]; then
        echo "ERROR: No Hetzner Cloud Volume found at /dev/disk/by-id/scsi-0HC_Volume_*" >&2
        exit 1
      fi

      LUKS_KEY="/run/controller-volume-key"
      MAPPER_NAME="controller-data"
      MAPPER_DEV="/dev/mapper/$MAPPER_NAME"

      # Verify key file exists
      if [[ ! -f "$LUKS_KEY" ]]; then
        echo "ERROR: LUKS key not found at $LUKS_KEY" >&2
        exit 1
      fi

      # First boot: format with LUKS2, then create filesystem
      if ! cryptsetup isLuks "$VOLUME_DEV"; then
        echo "First boot: formatting volume with LUKS2..."
        cryptsetup luksFormat --batch-mode --key-file "$LUKS_KEY" "$VOLUME_DEV"
      fi

      cryptsetup open --type luks --key-file "$LUKS_KEY" "$VOLUME_DEV" "$MAPPER_NAME"

      # Create ext4 if the LUKS container has no filesystem yet
      if ! blkid -s TYPE -o value "$MAPPER_DEV" &>/dev/null; then
        echo "No filesystem found inside LUKS container, creating ext4..."
        mkfs.ext4 "$MAPPER_DEV"
      fi

      # Mount the decrypted volume
      mkdir -p /mnt/data
      if ! mountpoint -q /mnt/data; then
        mount "$MAPPER_DEV" /mnt/data
      fi

      # Create subdirectories with correct ownership (first boot)
      mkdir -p /mnt/data/headscale
      mkdir -p /mnt/data/postgresql
      mkdir -p /mnt/data/caddy

      chown headscale:headscale /mnt/data/headscale
      chown postgres:postgres /mnt/data/postgresql
      chown caddy:caddy /mnt/data/caddy

      # Seed headscale noise key from cloud-init (first boot only)
      if [[ ! -f /mnt/data/headscale/noise_private.key ]] && [[ -f /run/headscale-noise-key ]]; then
        cp /run/headscale-noise-key /mnt/data/headscale/noise_private.key
        chown headscale:headscale /mnt/data/headscale/noise_private.key
        chmod 0400 /mnt/data/headscale/noise_private.key
      fi

      # Bind-mount subdirs to service state directories
      mkdir -p /var/lib/headscale /var/lib/postgresql /var/lib/caddy

      if ! mountpoint -q /var/lib/headscale; then
        mount --bind /mnt/data/headscale /var/lib/headscale
      fi
      if ! mountpoint -q /var/lib/postgresql; then
        mount --bind /mnt/data/postgresql /var/lib/postgresql
      fi
      if ! mountpoint -q /var/lib/caddy; then
        mount --bind /mnt/data/caddy /var/lib/caddy
      fi
    '';
  };
}
