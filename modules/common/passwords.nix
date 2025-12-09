{ config, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    keepassxc # Password manager
  ];
  home-manager.users.${config.username} = {
    programs.keepassxc = {
      enable = true;
      settings = {
        General.ConfigVersion = 2;

        Browser = {
          CustomProxyLocation = "";
          Enabled = true;
        };

        FdoSecrets.Enabled = true;

        GUI.TrayIconAppearance = "monochrome-light";

        PasswordGenerator = {
          AdditionalChars = "";
          ExcludedChars = "";
        };

        # Database locking configuration
        Security = {
          LockDatabaseIdle = true; # Enable locking after idle timeout
          LockDatabaseIdleSeconds = 43200; # Lock after 12 hours (12 * 60 * 60 seconds)
          LockDatabaseMinimize = false; # Disable locking when minimizing window
          LockDatabaseScreenLock = false; # Disable locking when screen locks
        };

        SSHAgent.Enabled = true;
      };
    };

    xdg.desktopEntries = {
      keepassxc = {
        name = "Password Manager";
        comment = "KeePassXC Cross-platform password manager";
        exec = "${pkgs.keepassxc}/bin/keepassxc";
        type = "Application";
      };
    };
  };
}
