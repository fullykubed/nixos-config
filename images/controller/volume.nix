{ pkgs, ... }:
{
  # Mount persistent Hetzner Cloud Volume before stateful services start
  systemd.services.controller-volume-mount = {
    description = "Mount persistent Hetzner Cloud Volume";
    after = [ "cloud-init.service" ];
    before = [
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
    ];
    script = ''
      # Find the attached Hetzner Cloud Volume (only one is ever attached)
      VOLUME_DEV=$(echo /dev/disk/by-id/scsi-0HC_Volume_*)
      if [[ ! -b "$VOLUME_DEV" ]]; then
        echo "ERROR: No Hetzner Cloud Volume found at /dev/disk/by-id/scsi-0HC_Volume_*" >&2
        exit 1
      fi

      # Mount the volume
      mkdir -p /mnt/data
      if ! mountpoint -q /mnt/data; then
        mount "$VOLUME_DEV" /mnt/data
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
