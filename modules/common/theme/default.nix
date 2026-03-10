{ config, pkgs, ... }:
let
  scheme = ./tokyo-city-dark.yaml;
  fonts = {
    monospace = {
      package = pkgs.nerd-fonts.jetbrains-mono;
      name = "JetBrainsMono Nerd Font";
    };
    sansSerif = {
      package = pkgs.noto-fonts;
      name = "Noto Sans";
    };
    serif = {
      package = pkgs.noto-fonts;
      name = "Noto Serif";
    };
    emoji = {
      package = pkgs.noto-fonts-color-emoji;
      name = "Noto Color Emoji";
    };
    sizes = {
      applications = 11;
      terminal = 12;
      desktop = 10;
      popups = 10;
    };
  };
  cursor = {
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Ice";
    size = 24;
  };
in
{
  # Font packages - moved from wayland module
  fonts = {
    packages = with pkgs; [
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-color-emoji
      font-awesome
      source-han-sans
      source-han-sans
      source-han-serif
      nerd-fonts.jetbrains-mono
      nerd-fonts.fira-code
      nerd-fonts.droid-sans-mono
      nerd-fonts.hack
    ];
    fontconfig.defaultFonts = {
      serif = [
        "Noto Serif"
        "Source Han Serif"
      ];
      sansSerif = [
        "Noto Sans"
        "Source Han Sans"
      ];
      emoji = [
        "Noto Color Emoji"
      ];
    };
  };

  stylix = {
    enable = true;
    homeManagerIntegration.autoImport = false;
    polarity = "dark";
    base16Scheme = scheme;
    inherit fonts;
    inherit cursor;

  };
  home-manager.users.${config.username} = {
    stylix = {
      enable = true;
      polarity = "dark";
      base16Scheme = scheme;
      inherit fonts;
      inherit cursor;
      targets = {
        tmux.enable = false;
      };
    };
  };
}
