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
