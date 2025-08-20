# See https://nixos.wiki/wiki/PipeWire

{ config, pkgs, ... }:
{
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.configPackages = [
      (pkgs.writeTextDir "share/wireplumber/wireplumber.conf.d/51-audio-rules.conf" ''
        monitor.alsa.rules = [
          {
            matches = [
              {
                # Disable Scarlett Solo as output sink
                node.name = "~alsa_output.usb-Focusrite_Scarlett_Solo.*"
              }
            ]
            actions = {
              update-props = {
                node.disabled = true
              }
            }
          }
          {
            matches = [
              {
                # FiiO K3 - Highest priority
                node.name = "~alsa_output.usb-GuangZhou_FiiO_Electronics_Co._Ltd_FiiO_K3-.*"
              }
            ]
            actions = {
              update-props = {
                priority.driver = 2000
                priority.session = 2000
              }
            }
          }
          {
            matches = [
              {
                # Other USB audio devices
                node.name = "~alsa_output.usb-.*"
              }
            ]
            actions = {
              update-props = {
                priority.driver = 1000
                priority.session = 1000
              }
            }
          }
          {
            matches = [
              {
                # Built-in audio - Lowest priority
                node.name = "~alsa_output.pci-.*"
              }
            ]
            actions = {
              update-props = {
                priority.driver = 500
                priority.session = 500
              }
            }
          }
        ]
      '')
    ];
  };
  environment.systemPackages = with pkgs; [
    pavucontrol # For controlling audio sinks
    helvum # Controlling pipewire
    playerctl # For media player controls
  ];

  # Fix USB audio devices after suspend/resume
  systemd.services.usb-audio-reset = {
    description = "Reset USB audio devices after resume";
    after = [
      "suspend.target"
      "hibernate.target"
      "hybrid-sleep.target"
    ];
    wantedBy = [
      "suspend.target"
      "hibernate.target"
      "hybrid-sleep.target"
    ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "usb-audio-reset" ''
        echo "Starting USB audio device reset after resume..."
        ${pkgs.coreutils}/bin/sleep 2

        for auth_file in /sys/bus/usb/devices/*/authorized; do
          device_dir="''${auth_file%/*}"
          
          # Check if this is a FiiO device
          is_fiio=0
          if [ -f "$device_dir/product" ]; then
            if ${pkgs.ripgrep}/bin/rg -qi "fiio|k3" "$device_dir/product" 2>/dev/null; then
              is_fiio=1
            fi
          fi
          
          if [ -f "$device_dir/manufacturer" ]; then
            if ${pkgs.ripgrep}/bin/rg -qi "fiio|guangzhou" "$device_dir/manufacturer" 2>/dev/null; then
              is_fiio=1
            fi
          fi
          
          if [ "$is_fiio" -eq 1 ]; then
            echo "Found FiiO device at $device_dir"
            if [ -f "$device_dir/product" ]; then
              echo "  Product: $(cat "$device_dir/product")"
            fi
            if [ -f "$device_dir/manufacturer" ]; then
              echo "  Manufacturer: $(cat "$device_dir/manufacturer")"
            fi
            
            echo "Resetting device..."
            echo 0 > "$auth_file"
            ${pkgs.coreutils}/bin/sleep 0.5
            echo 1 > "$auth_file"
            echo "Device reset complete"
          fi
        done

        echo "USB audio reset service completed"
      '';
      RemainAfterExit = false;
    };
  };
}
