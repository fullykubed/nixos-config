# Home Manager Usage

Packages and configuration should go through Home Manager whenever possible. Use `home.packages` for packages and `programs.*` for program configuration. Only use system-level options (`environment.systemPackages`, `services.*`, etc.) when the setting genuinely requires root or system-wide scope.

## Typical module

```nix
{ config, pkgs, ... }:
{
  home-manager.users.${config.username} = {
    # Install packages via Home Manager
    home.packages = [ pkgs.wl-clipboard ];

    # Shell aliases
    programs.zsh.shellAliases = {
      bn = "btop -f nixbld";
    };

    # Desktop entries
    xdg.desktopEntries.my-app = {
      name = "My App";
      exec = "my-app %U";
      type = "Application";
    };
  };
}
```

## Combining system-level and user-level config

When you need both in the same module:

```nix
{ config, pkgs, ... }:
{
  # System-level (only when necessary -- e.g. services, kernel modules, PAM)
  services.foo.enable = true;

  # User-level (preferred for packages and config)
  home-manager.users.${config.username} = {
    home.packages = [ pkgs.foo-client ];
  };
}
```
