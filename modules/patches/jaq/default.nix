# jaq 3.0.0-gamma - adds YAML/TOML/CBOR/XML format support (--from/--to flags)
# Required by PRD skill scripts which use `jaq --from yaml`
# Upstream: https://github.com/01mf02/jaq/releases/tag/v3.0.0-gamma
# Security audit: Radically Open Security (NLnet-funded Polyglot jaq project)
_: {
  nixpkgs.overlays = [
    (
      _final: prev:
      let
        newSrc = prev.fetchFromGitHub {
          owner = "01mf02";
          repo = "jaq";
          tag = "v3.0.0-gamma";
          hash = "sha256-2ltG/WnMxuNTqxQeH0JovrPwAnqXKAfAnZaOpFUIWm4=";
        };
      in
      {
        jaq = prev.jaq.overrideAttrs (_old: {
          version = "3.0.0-gamma";
          src = newSrc;
          cargoDeps = prev.rustPlatform.fetchCargoVendor {
            pname = "jaq";
            version = "3.0.0-gamma";
            src = newSrc;
            hash = "sha256-3gjGRDcZWd1Sm7ydmiFPx5Dp/AIgkHe5zgVcqkt2Zlg=";
          };
        });
      }
    )
  ];
}
