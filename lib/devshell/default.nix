# Development shell, formatter, and pre-commit checks
{
  nixpkgs,
  self,
  inputs,
  agenix-rekey,
}:
system:
let
  pkgs = import nixpkgs {
    inherit system;
    overlays = [
      agenix-rekey.overlays.default
    ];
  };
  hcloud-upload-image = pkgs.callPackage ../packages/hcloud-upload-image.nix { };
  nixfmt = pkgs.treefmt.withConfig {
    runtimeInputs = [ pkgs.nixfmt-rfc-style ];

    settings = {
      # Log level for files treefmt won't format
      on-unmatched = "info";

      # Configure nixfmt for .nix files
      formatter.nixfmt = {
        command = "nixfmt";
        includes = [ "*.nix" ];
      };
    };
  };
  checkBunVersions = pkgs.writeShellApplication {
    name = "check-bun-versions";
    runtimeInputs = [
      pkgs.jq
      pkgs.findutils
      pkgs.gawk
    ];
    text = builtins.readFile ./check-bun-versions.sh;
  };
  listMachines = pkgs.writeShellApplication {
    name = "list-machines";
    runtimeInputs = [ pkgs.jq ];
    text = builtins.readFile ./list-machines.sh;
  };
  flashInstaller = pkgs.writeShellApplication {
    name = "flash-installer";
    runtimeInputs = [
      pkgs.jq
      pkgs.util-linux
      pkgs.openssl
      pkgs.rage
      pkgs.pv
      pkgs.dosfstools
      listMachines
    ];
    text = builtins.readFile ./flash-installer.sh;
  };
  generateHostKey = pkgs.writeShellApplication {
    name = "generate-host-key";
    runtimeInputs = [
      pkgs.jq
      pkgs.rage
      pkgs.openssh
      pkgs.agenix-rekey
      listMachines
    ];
    text = builtins.readFile ./generate-host-key.sh;
  };
  ntScripts =
    builtins.map
      (
        name:
        pkgs.writeShellApplication {
          inherit name;
          text = builtins.readFile (./. + "/${name}.sh");
        }
      )
      [
        "nt-syntax"
        "nt-eval"
        "nt-dry"
        "nt-pkg"
        "nt-option"
        "nt-build"
        "nt-check"
        "nt-hosts"
      ];
in
{
  checks = {
    pre-commit-check = inputs.git-hooks.lib.${system}.run {
      src = self;
      hooks = {
        nixfmt-rfc-style.enable = true;
        statix.enable = true;
        deadnix.enable = true;
        gitleaks = {
          enable = true;
          name = "gitleaks";
          # Use protect mode to only scan staged changes, not full history
          entry = "${pkgs.gitleaks}/bin/gitleaks protect --staged -v --config ${../../gitleaks.toml}";
        };
        check-bun-versions = {
          enable = true;
          name = "check-bun-versions";
          entry = "${checkBunVersions}/bin/check-bun-versions";
          files = "package\\.json$";
          pass_filenames = false;
        };
      };
    };
  };

  formatter = nixfmt;
  devShell = pkgs.mkShell {
    packages = [
      nixfmt
      pkgs.agenix-rekey
      pkgs.age
      pkgs.gitleaks
      pkgs.hcloud
      hcloud-upload-image
      listMachines
      flashInstaller
      generateHostKey
    ]
    ++ ntScripts
    ++ self.checks.${system}.pre-commit-check.enabledPackages;

    inherit (self.checks.${system}.pre-commit-check) shellHook;
  };
}
