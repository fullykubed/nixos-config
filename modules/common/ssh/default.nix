{ config, ... }:
{
  home-manager.users.${config.username} = {
    services.ssh-agent.enable = true;

    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;
    };

    home.file.".ssh/config".force = true;

    # Home Manager symlinks ~/.ssh/config into the nix store.  OpenSSH
    # rejects symlinks whose apparent permissions are too open (lrwxrwxrwx).
    # Replace the symlink with a regular copy after every activation so SSH
    # works everywhere, including bubblewrap sandboxes that bind-mount ~/.ssh.
    home.activation.fixSshConfigPermissions = {
      after = [ "linkGeneration" ];
      before = [ ];
      data = ''
        if [ -L "$HOME/.ssh/config" ]; then
          TARGET="$(readlink -f "$HOME/.ssh/config")"
          rm "$HOME/.ssh/config"
          cp "$TARGET" "$HOME/.ssh/config"
          chmod 600 "$HOME/.ssh/config"
        fi
      '';
    };
  };
}
