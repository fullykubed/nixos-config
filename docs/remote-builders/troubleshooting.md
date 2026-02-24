# Troubleshooting

## Builder won't start

1. Check the API token is present:
   ```bash
   cat /run/agenix/hetzner-api-token
   ```
2. Verify a builder snapshot exists with the correct label:
   ```bash
   hcloud image list --type snapshot -l type=builder
   ```
3. Check the SSH public key file:
   ```bash
   cat secrets/builder-ssh-key.pub
   ```

## Build fails to connect

1. Check if the builder server exists:
   ```bash
   builders list
   ```
2. Attempt a manual SSH connection to see the ProxyCommand output:
   ```bash
   ssh -v builder-1
   ```
   The ProxyCommand logs provisioning progress to stderr, which appears in verbose SSH output.
3. Check that SSH connects on port 3098 (builders run SSH on a non-standard port):
   ```bash
   nc -z <builder-ip> 3098
   ```

## Builder not auto-destroying

1. SSH into the builder to inspect the monitor:
   ```bash
   ssh builder-1
   ```
2. Check the timer status:
   ```bash
   systemctl status inactivity-monitor.timer
   ```
3. View monitor logs:
   ```bash
   journalctl -u inactivity-monitor
   ```
4. Confirm the Hetzner token was injected via cloud-init:
   ```bash
   cat /run/hcloud-token
   ```

## Stale builder preventing new provisioning

If a builder from a previous session was not cleaned up:

```bash
builders destroy builder-1   # or big-builder-1
```

The ProxyCommand will re-provision the builder on the next SSH connection.

## Big-parallel builder not using all cores

1. SSH into the big builder and check the override conf was written:
   ```bash
   ssh big-builder-1
   cat /etc/nix/builder-override.conf
   ```
   Should contain `max-jobs = 1` and `cores = 0`.
2. Verify nix-daemon was restarted after cloud-init:
   ```bash
   journalctl -u cloud-init
   ```

## Cache uploads stuck

1. Check the upload service:
   ```bash
   systemctl status cache-upload.service
   journalctl -u cache-upload.service -n 50
   ```
2. If the service hit a start limit (should not happen with current config):
   ```bash
   sudo systemctl reset-failed cache-upload.service
   ```
3. Check the tunnel is up:
   ```bash
   curl -s http://127.0.0.1:9751/
   systemctl status cache-tunnel.service
   ```

## Cache tunnel not connecting

1. Verify a cache server exists:
   ```bash
   cache status
   ```
2. Run full diagnostics:
   ```bash
   cache check
   ```
3. Check tunnel logs:
   ```bash
   journalctl -u cache-tunnel.service -n 50
   ```

## Substituter not finding cached paths

1. Check the CDN is reachable:
   ```bash
   curl -I https://nixos-cache.panfactumcf.com/nix-cache-info
   ```
2. Verify the signing key is trusted:
   ```bash
   nix show-config | grep trusted-public-keys
   ```
