{ pkgs, ... }:
{
  systemd.services.builder-volume-mount = {
    description = "Mount persistent Hetzner Cloud Volume for ccache";
    after = [ "secrets-ready.target" ];
    requires = [ "secrets-ready.target" ];
    before = [ "nix-daemon.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    path = with pkgs; [
      util-linux
      coreutils
      e2fsprogs
      systemd # for systemd-tmpfiles
    ];
    script = ''
      # Find the attached Hetzner Cloud Volume
      VOLUME_DEV=$(echo /dev/disk/by-id/scsi-0HC_Volume_*)
      if [[ ! -b "$VOLUME_DEV" ]]; then
        echo "No Hetzner Cloud Volume found, using root filesystem for ccache"
        exit 0
      fi

      echo "Found volume device: $VOLUME_DEV"

      # First use: create ext4 filesystem
      if ! blkid -s TYPE -o value "$VOLUME_DEV" &>/dev/null; then
        echo "No filesystem found, creating ext4..."
        mkfs.ext4 "$VOLUME_DEV"
      fi

      # Mount the volume
      mkdir -p /var/cache/ccache
      if ! mountpoint -q /var/cache/ccache; then
        mount "$VOLUME_DEV" /var/cache/ccache
      fi

      # Set ownership and permissions
      chown root:nixbld /var/cache/ccache
      chmod 0775 /var/cache/ccache

      # Re-run tmpfiles to write ccache.conf onto the mounted volume
      systemd-tmpfiles --create --prefix=/var/cache/ccache
    '';
  };
}
