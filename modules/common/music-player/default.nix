# Terminal-based Spotify client using spotify-player
# Uses librespot for playback, avoiding the Electron app's bundled ffmpeg CVEs
{
  config,
  pkgs,
  lib,
  ...
}:
{
  config = lib.mkIf (config.deviceType != "remote-builder") {
    home-manager.users.${config.username} = {
      programs.spotify-player = {
        enable = true;

        settings = {
          # Use wl-copy for Wayland clipboard
          copy_command = {
            command = "wl-copy";
            args = [ ];
          };

          # Device configuration
          device = {
            name = "spotify-player";
            device_type = "computer";
            volume = 100;
            bitrate = 320;
            audio_cache = true;
          };

          # Playback settings
          playback_window_position = "Bottom";

          # Enable media controls via MPRIS
          enable_media_control = true;

          # Enable streaming to other devices
          enable_streaming = "Always";

          # Cover image settings
          cover_img_length = 9;
          cover_img_width = 5;

          # Enable notify on track change
          enable_notify = true;
        };
      };

      # Ensure wl-clipboard is available for copy functionality
      home.packages = [ pkgs.wl-clipboard ];
    };
  };
}
