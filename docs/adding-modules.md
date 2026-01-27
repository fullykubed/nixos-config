# Adding a New Module

1. Create module file in `modules/common/` or `modules/utility/`
2. Import in `configuration.nix`
3. Follow the standard module pattern:

```nix
{ config, pkgs, lib, ... }: {
  # Module configuration
}
```

## Module Locations

- `modules/common/` - Shared modules across all systems
- `modules/utility/` - Hardware-specific utilities (CPU/GPU configurations)
