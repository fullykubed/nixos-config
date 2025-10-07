{ config, pkgs, ... }:
let
  # Create an FHS environment for Firefox to bypass system allocator
  firefox-fhs = pkgs.buildFHSEnv {
    name = "firefox";
    targetPkgs = pkgs: [ pkgs.firefox ];
    runScript = "firefox";
  };
in
{
  environment.systemPackages = with pkgs; [
    firefox-fhs # Firefox in isolated FHS environment
    chromium
  ];

  home-manager.users.${config.username} = {
    xdg.mimeApps = {
      defaultApplications = {
        "x-scheme-handler/http" = [ "firefox.desktop" ];
        "x-scheme-handler/https" = [ "firefox.desktop" ];
        "x-scheme-handler/chrome" = [ "firefox.desktop" ];
        "text/html" = [ "firefox.desktop" ];
        "application/x-extension-htm" = [ "firefox.desktop" ];
        "application/x-extension-html" = [ "firefox.desktop" ];
        "application/x-extension-shtml" = [ "firefox.desktop" ];
        "application/xhtml+xml" = [ "firefox.desktop" ];
        "application/x-extension-xhtml" = [ "firefox.desktop" ];
        "application/x-extension-xht" = [ "firefox.desktop" ];
      };
    };

    xdg.desktopEntries = {
      firefox = {
        name = "Firefox";
        comment = "Firefox";
        exec = "${firefox-fhs}/bin/firefox";
        type = "Application";
      };
      chrome = {
        name = "Chrome";
        comment = "Chrome";
        exec = "${pkgs.chromium}/bin/chromium";
        type = "Application";
      };
    };
  };
}
