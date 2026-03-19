{ config, pkgs, ... }:
let
  # Create a sudo wrapper script for backwards compatibility
  sudo-compat = pkgs.writeShellScriptBin "sudo" ''
    exec doas "''${@/--preserve-env*/}"
  '';
in
{
  security = {
    auditd.enable = true; # Enable linux auditing
    polkit.enable = true;

    # Disable sudo and use doas instead
    sudo.enable = false;

    # Configure doas
    doas = {
      enable = true;
      extraRules = [
        {
          users = [ config.username ];
          persist = true; # Keep authentication for 5 minutes by default
          keepEnv = true; # Preserve environment variables
        }
      ];
    };

    # Configure PAM to use Yubikey U2F (no password auth)
    pam = {
      services = {
        doas = {
          u2fAuth = true;
          unixAuth = false;
        };

        swaylock = {
          u2fAuth = true;
          unixAuth = false;
        };

        login = {
          u2fAuth = true;
          unixAuth = false;
        };

        polkit-1 = {
          u2fAuth = true;
          unixAuth = false;
        };
      };

      # Enable U2F authentication
      u2f = {
        enable = true;
        control = "sufficient"; # YubiKey touch alone is enough to authenticate
        settings = {
          cue = true; # Prompt to touch the key
          origin = "pam://nixos"; # Makes the key independent of the hardware
          authfile =
            let
              keys = pkgs.lib.concatStrings [
                ":tGvO5XWn+Ytz49zkZITTo9YWpFzO6XnZk3X5AuyDbJ5mo2w/0lv5d7Q/dRYYv+WEU8sGma90mClHnAYysNjkTQ==,jBm2zt1lSIF68gFdk/T6li5kGAxsZR4UHFJAqS3fQwKPOuqYt+iFGcGBV078iVj6O3GA0XpdI76N/nSAqvsZNA==,es256,+presence"
                ":1wsJRGnmP+8OvTlo+EZ+iPMGrWoFNU1pHGKaIshrWAvMoqkgy2nhOK/M/SCWeN068/ylCMLvyRiMfhzorQkwig==,VQlRxN/YmuwQ/brZyeRmJW+vWQLc+YajVOu68KGikGyBx+nB9e4X0FwxmZ5lZ87VF+iysDu4/UTf41OnRzDdog==,es256,+presence"
              ];
            in
            pkgs.writeText "u2f-mappings" ''
              ${config.username}${keys}
              root${keys}
            '';
        };
      };
    };
  };

  # Add sudo compatibility wrapper and pam_u2f tools
  environment.systemPackages = [
    sudo-compat
    pkgs.pam_u2f
  ];

  # Prevent imperative user/group changes (useradd, passwd, etc.)
  users.mutableUsers = false;

  services.passSecretService.enable = true;
  services.dbus.packages = [ pkgs.grc ];
}
