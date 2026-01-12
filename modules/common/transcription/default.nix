{
  config,
  pkgs,
  lib,
  ...
}:
let
  voxtype = pkgs.rustPlatform.buildRustPackage rec {
    pname = "voxtype";
    version = "0.4.12";

    src = pkgs.fetchFromGitHub {
      owner = "peteonrails";
      repo = "voxtype";
      rev = "v${version}";
      hash = "sha256-rMTfLvllr2zn+799+YTgE53Ve0khdE9FPaLtxF2pk58=";
    };

    cargoHash = "sha256-VbqHyOA0BA8PpFrOvdaHi3Bv3IuTXhnlsOfrmNH6FHU=";

    nativeBuildInputs = with pkgs; [
      pkg-config
      cmake # Required for whisper-rs/whisper.cpp build
      rustPlatform.bindgenHook # Provides libclang for whisper-rs bindgen
      git # Required by whisper.cpp/ggml CMake
    ];

    buildInputs = with pkgs; [
      alsa-lib
      openssl
    ];

    env = {
      OPENSSL_NO_VENDOR = "1";
    };

    meta = with lib; {
      description = "Push-to-talk voice-to-text for Wayland";
      homepage = "https://github.com/peteonrails/voxtype";
      license = licenses.mit;
      platforms = platforms.linux;
      mainProgram = "voxtype";
    };
  };
in
{
  # Add voxtype and wtype to system packages
  environment.systemPackages = [
    voxtype
    pkgs.wtype
  ];

  home-manager.users.${config.username} = {
    # Download whisper model if not present
    home.activation.voxtype-model = {
      after = [ "writeBoundary" ];
      before = [ ];
      data = ''
        ${voxtype}/bin/voxtype setup --download || true
      '';
    };

    # Systemd user service for voxtype daemon
    systemd.user.services.voxtype = {
      Unit = {
        Description = "VoxType push-to-talk voice-to-text daemon";
        Documentation = "https://github.com/peteonrails/voxtype";
        PartOf = [ "sway-session.target" ];
        After = [
          "sway-session.target"
          "pipewire.service"
          "pipewire-pulse.service"
        ];
      };
      Service = {
        Type = "simple";
        ExecStart = "${voxtype}/bin/voxtype daemon";
        Environment = [
          "PATH=${
            lib.makeBinPath [
              pkgs.wtype
              pkgs.wl-clipboard
              pkgs.which
            ]
          }"
        ];
        Restart = "on-failure";
        RestartSec = 5;
        StandardOutput = "journal";
        StandardError = "journal";
      };
      Install = {
        WantedBy = [ "sway-session.target" ];
      };
    };

    xdg.configFile."voxtype/config.toml".text = ''
      state_file = "auto"

      [hotkey]
      enabled = false
      key = "SCROLLLOCK"
      mode = "push_to_talk"

      [audio]
      device = "default"
      sample_rate = 16000
      max_duration_secs = 300

      [whisper]
      backend = "local"
      model = "tiny.en"
      language = "en"
      translate = false

      [output]
      mode = "type"
      fallback_to_clipboard = true
      type_delay_ms = 0

      [output.notification]
      on_start = false
      on_stop = false
      on_error = true

      [text]
      spoken_punctuation = true
    '';
  };
}
