# Deployment

The `un.sh` script (located in `modules/common/scripts/scripts/`) handles deployment:

1. Copies configuration to `/etc/nixos`
2. Runs `nixos-rebuild switch` with appropriate flags
3. Automatically uses the current hostname for the flake target

## Script Options

```bash
# Quick rebuild and switch
./modules/common/scripts/scripts/un.sh

# Rebuild boot configuration only
./modules/common/scripts/scripts/un.sh --boot

# Update flake inputs and rebuild
./modules/common/scripts/scripts/un.sh --update

# Build without network access
./modules/common/scripts/scripts/un.sh --offline
```
