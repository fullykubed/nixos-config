# Working with Packages

## Unstable channel

`lib/nixpkgs-unstable.nix` exposes `nixpkgs-unstable` as a module argument. Use it to pull bleeding-edge packages without changing the stable channel.

```nix
{ config, nixpkgs-unstable, ... }:
{
  home-manager.users.${config.username} = {
    home.packages = [
      nixpkgs-unstable.some-package
    ];
  };
}
```

## External packages

Packages outside of nixpkgs and nixpkgs-unstable are fine, but their versions and hashes should be defined as options and set centrally in `lib/versions.nix`. This keeps version bumps to a single file.

### Define version options in your module

```nix
{ config, pkgs, lib, ... }:
{
  options.versions = {
    myTool = lib.mkOption {
      type = lib.types.str;
      description = "Version of my-tool";
    };
    myToolSrcHash = lib.mkOption {
      type = lib.types.str;
      description = "Source hash for my-tool";
    };
  };

  config = let
    inherit (config) versions;
  in {
    home-manager.users.${config.username}.home.packages = [
      (pkgs.buildGoModule {
        pname = "my-tool";
        version = versions.myTool;
        src = pkgs.fetchFromGitHub {
          owner = "example";
          repo = "my-tool";
          rev = "v${versions.myTool}";
          hash = versions.myToolSrcHash;
        };
      })
    ];
  };
}
```

### Set values in lib/versions.nix

```nix
{
  # my-tool (modules/common/my-module)
  myTool = "1.2.3";
  myToolSrcHash = "sha256-...";
}
```

### Getting hashes

Prefetch upfront:

```bash
# Prefetch a GitHub repo
nix-prefetch-url --unpack https://github.com/example/my-tool/archive/v1.2.3.tar.gz

# Prefetch with nix flake prefetch (SRI hash)
nix flake prefetch github:example/my-tool/v1.2.3
```

Alternatively, set the hash to an empty string (`""`) and build. Nix will fail with a hash mismatch error that includes the correct hash — copy it back into `lib/versions.nix`. This works for `src` hashes, `cargoHash`, `vendorHash`, and any other fixed-output derivation hash.
