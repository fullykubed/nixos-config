# Thunar is a GUI file manager that is Wayland compatible

{
  config,
  pkgs,
  ...
}:
{
  environment.systemPackages = with pkgs; [
    ranger # TUI file manager
    ueberzug # image previewer for ranger
    poppler-utils # pdf util suite (used for pdf previews)
    ffmpegthumbnailer # previews for videos
    odt2txt # previews for open office files
    exiftool # tool for working with files in the file manager
    mediainfo # tool for working with files in the file manager
    pandoc # document conversion
  ];

  environment.sessionVariables = {
    # Disable loading default settings for ranger
    RANGER_LOAD_DEFAULT_RC = "FALSE";
  };

  home-manager.users.${config.username} = {

    xdg = {
      configFile = {
        ranger = {
          source = ./config;
          recursive = true;
        };
      };
    };

    programs.zsh.shellAliases = {
      e = "ranger";
    };
  };

}
