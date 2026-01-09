{ config, pkgs, ... }:
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

    polarity = "dark";

    # Base16 color scheme
    base16Scheme = "${pkgs.base16-schemes}/share/themes/tokyo-city-dark.yaml";

    # Wallpaper - stylix will generate theme colors from this image
    # image = /path/to/your/wallpaper.jpg;

    # Font configuration
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
    };

    # Font sizes
    fonts.sizes = {
      applications = 11;
      terminal = 12;
      desktop = 10;
      popups = 10;
    };

    # Cursor configuration
    cursor = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Ice";
      size = 24;
    };

    # Application-specific settings
    targets = {
      # Enable theming for various applications
      # firefox.enable = true;
    };
  };
}
