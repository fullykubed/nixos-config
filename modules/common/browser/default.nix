{ config, pkgs, ... }:
let
  # Create an FHS environment for Firefox to bypass system allocator
  firefox-fhs = pkgs.buildFHSEnv {
    name = "firefox";
    targetPkgs = pkgs: [
      pkgs.firefox
      pkgs.tridactyl-native
    ];
    runScript = "firefox";
  };
in
{
  environment.systemPackages = with pkgs; [
    firefox-fhs # Firefox in isolated FHS environment
    chromium
  ];

  home-manager.users.${config.username} = {
    home.file.".mozilla/native-messaging-hosts/tridactyl.json".source =
      "${pkgs.tridactyl-native}/lib/mozilla/native-messaging-hosts/tridactyl.json";

    xdg = {
      configFile."tridactyl/tridactylrc".text = ''
        " Tridactyl configuration file

        " Clear existing configuration
        sanitise tridactyllocal tridactylsync

        " Use vim-style navigation
        bind j scrollline 5
        bind k scrollline -5
        bind h scrollpx -50
        bind l scrollpx 50

        " Tab management
        bind J tabnext
        bind K tabprev
        bind x tabclose
        bind u undo

        " Ctrl-F should user the browser's native find
        unbind <C-f>

        " Opening pages
        bind O fillcmdline bmarks

        " Cmdline navigation
        bind --mode=ex <C-j> ex.next_completion
        bind --mode=ex <C-k> ex.prev_completion

        " Search
        bind / fillcmdline find
        bind ? noh " Clears the search
        bind n findnext 1
        bind N findnext -1

        " Misc settings
        set smoothscroll true
        set completionfuzziness 1

        " Use external editor
        set editorcmd nvim
      '';

      mimeApps.defaultApplications = {
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

      desktopEntries = {
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
  };
}
