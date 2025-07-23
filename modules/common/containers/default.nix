{ config, pkgs, ... }:
{
  virtualisation = {

    podman = {
      enable = true;
      extraPackages = with pkgs; [ zfs ];
      defaultNetwork.settings.dns_enabled = true;
      dockerCompat = false;
      autoPrune = {
        enable = true;
        flags = [ "--all" ];
        dates = "weekly";
      };
    };

    containers = {
      storage = {
        settings = {
          storage = {
            driver = "overlay";
          };
        };
      };
      containersConf = {
        settings = {
          containers = {
            pids_limit = 65536;
            default_ulimits = [ "nofile=65536:65536" ];
          };
          network = {
            network_backend = "netavark";
          };
          engine = {
            helper_binaries_dir = [ "${pkgs.podman}/libexec/podman" ];
          };
        };
      };
    };
  };

  # Podman user service is broken by default
  systemd.user.services.podman.enable = false;

  environment.systemPackages = with pkgs; [
    slirp4netns # Required for rootless networking
    podman # Container management
    podman-compose # docker-compose alternative
  ];

  # See https://rootlesscontaine.rs/getting-started/common/cgroup2/#enabling-cpu-cpuset-and-io-delegation
  systemd.packages = [
    (pkgs.runCommand "delegate.conf"
      {
        preferLocalBuild = true;
        allowSubstitutes = false;
      }
      ''
        mkdir -p $out/etc/systemd/system/user@.service.d/
        echo -e "[Service]\nDelegate=cpu cpuset io memory pids" > $out/etc/systemd/system/user@.service.d/delegate.conf
      ''
    )
  ];

  # User ns setup - required for rootless
  users.users.${config.username} = {
    subUidRanges = [
      {
        count = 65543;
        startUid = 100001;
      }
    ];
    subGidRanges = [
      {
        count = 65543;
        startGid = 100001;
      }
    ];
  };

  home-manager.users.${config.username} = {
    xdg.configFile = {
      # TODO: Not sure why we are mounting the containers in the home directory
      "containers/storage.conf" = {
        source = ./storage.conf;
      };
    };
  };

}
