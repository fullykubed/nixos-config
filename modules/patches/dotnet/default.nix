_: {
  nixpkgs.overlays = [
    (_final: prev: {
      # Dotnet VMR: Fix 2026 FileVersion overflow in azure-activedirectory-identitymodel-extensions
      # Bug: Original formula (year-2019)*10000+MMdd produces 70101+ in 2026, exceeding UInt16 max (65535)
      # Error: CS7035 "The specified version string '7.1.2.70120' does not conform to the recommended format"
      # Fix: Apply upstream patch from https://github.com/dotnet/dotnet/pull/4043
      # New formula: 61232 + (year-2019)*416 + month*32 + day stays within bounds through 2029
      dotnetCorePackages = prev.dotnetCorePackages.overrideScope (
        _dotnetFinal: dotnetPrev: {
          vmr_8_0 = dotnetPrev.vmr_8_0.overrideAttrs (old: {
            patches = (old.patches or [ ]) ++ [
              ./dotnet-2026-fileversion-fix.patch
            ];
          });
          vmr_9_0 = dotnetPrev.vmr_9_0.overrideAttrs (old: {
            patches = (old.patches or [ ]) ++ [
              ./dotnet-2026-fileversion-fix.patch
            ];
          });
        }
      );
    })
  ];
}
