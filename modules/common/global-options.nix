{
  config,
  pkgs,
  lib,
  ...
}:
{
  options.username =
    with lib;
    mkOption {
      type = types.str;
      description = "The primary user's username on the system.";
    };

  options.homeDir =
    with lib;
    mkOption {
      default = "/home/${config.username}";
      type = types.str;
      description = "The primary user's username on the system.";
    };
}
