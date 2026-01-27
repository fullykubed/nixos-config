# Commands

## System Rebuild

```bash
# Quick rebuild and switch (uses current hostname, with --fast)
./modules/common/scripts/scripts/un.sh

# Rebuild boot configuration only
./modules/common/scripts/scripts/un.sh --boot
# or
./modules/common/scripts/scripts/un.sh -b

# Update flake inputs and rebuild
./modules/common/scripts/scripts/un.sh --update
# or
./modules/common/scripts/scripts/un.sh -u

# Build without network access (offline mode)
./modules/common/scripts/scripts/un.sh --offline
# or
./modules/common/scripts/scripts/un.sh -o

# Manual rebuild for specific systems
sudo nixos-rebuild switch --fast --flake /etc/nixos#fullykubed-tower
sudo nixos-rebuild switch --fast --flake /etc/nixos#fullykubed-mini-pc
```
