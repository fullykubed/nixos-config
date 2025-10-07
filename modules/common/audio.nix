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
                # Configure BRIO webcam microphone with normal priority
                node.name = "~alsa_input.usb-046d_Logitech_BRIO.*"
              }
            ]
            actions = {
              update-props = {
                priority.driver = 1000
                priority.session = 1000
                node.description = "BRIO Webcam Microphone"
              }
            }
          }
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
    alsa-utils # For amixer and alsamixer
  ];

  # Set Scarlett Solo input gain
  systemd.services.scarlett-solo-gain = {
    description = "Set Scarlett Solo input gain";
    after = [
      "multi-user.target"
      "sound.target"
    ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "scarlett-gain" ''
        # Wait for device to be available
        ${pkgs.coreutils}/bin/sleep 2

        # Find Scarlett Solo card number
        for card in /proc/asound/card*; do
          if [ -f "$card/id" ] && grep -q "Gen" "$card/id" 2>/dev/null; then
            CARD_NUM=$(basename "$card" | sed 's/card//')
            echo "Found Scarlett Solo on card $CARD_NUM"
            
            # Set PCM capture volume to maximum (if control exists)
            ${pkgs.alsa-utils}/bin/amixer -c "$CARD_NUM" set 'PCM Capture' 100% unmute 2>/dev/null || true
            ${pkgs.alsa-utils}/bin/amixer -c "$CARD_NUM" set 'Mic' 100% unmute 2>/dev/null || true
            ${pkgs.alsa-utils}/bin/amixer -c "$CARD_NUM" set 'Capture' 100% unmute 2>/dev/null || true
            
            # List all controls for debugging
            echo "Available controls:"
            ${pkgs.alsa-utils}/bin/amixer -c "$CARD_NUM" controls
          fi
        done
      '';
    };
  };

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
        ${pkgs.coreutils}/bin/sleep 3

        # Find all USB devices (including sub-devices like 3-7)
        for device_dir in /sys/bus/usb/devices/[0-9]*; do
          # Skip if not a directory or no authorized file
          if [ ! -d "$device_dir" ] || [ ! -f "$device_dir/authorized" ]; then
            continue
          fi
          
          # Check if this is a FiiO device
          is_fiio=0
          
          # Check by vendor/product ID (more reliable)
          if [ -f "$device_dir/idVendor" ] && [ -f "$device_dir/idProduct" ]; then
            vendor=$(cat "$device_dir/idVendor" 2>/dev/null)
            product=$(cat "$device_dir/idProduct" 2>/dev/null)
            if [ "$vendor" = "2972" ] && [ "$product" = "0047" ]; then
              is_fiio=1
            fi
          fi
          
          # Also check by manufacturer/product strings as fallback
          if [ "$is_fiio" -eq 0 ] && [ -f "$device_dir/manufacturer" ]; then
            if grep -qi "fiio" "$device_dir/manufacturer" 2>/dev/null; then
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
            
            echo "Resetting FiiO device..."
            echo 0 > "$device_dir/authorized"
            ${pkgs.coreutils}/bin/sleep 1
            echo 1 > "$device_dir/authorized"
            echo "FiiO device reset complete"
          fi
        done

        echo "USB audio reset service completed"
      '';
      RemainAfterExit = false;
    };
  };
}
