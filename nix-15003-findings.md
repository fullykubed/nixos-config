# Findings: Nix Issue #15003 — `contentAddressedByDefault` Breaks NixOS System Builds

> Testing on Nix 2.33.3, nixpkgs 25.11.

## Summary

The `contentAddressedByDefault` crash is caused by **CA placeholder paths with subpath suffixes** (e.g. `<placeholder>/lib`) inside `exportReferencesGraph` entries in `closure-info.drv`. Bare CA placeholders work fine. The initrd builder is the call site that surfaced for us, but the pattern can occur anywhere a subpath string flows into `closureInfo` rootPaths. A nixpkgs overlay on `makeInitrd` can work around the initrd case without patching Nix itself.

## Reproduction

```bash
nix build --dry-run --impure --option substituters "" \
  --extra-experimental-features ca-derivations --expr '
  let
    flake = builtins.getFlake (toString ./.);
    patched = flake.nixosConfigurations.<host>.extendModules {
      modules = [{ nixpkgs.config.contentAddressedByDefault = true; }];
    };
  in patched.config.system.build.toplevel
'
# Error:
#   … while parsing derivation '/nix/store/...-closure-info.drv'
#   error: path '/0z1qhjshz88n4yif.../lib' is not in the Nix store
```

## Root Cause

### The crash path

1. `make-initrd.nix` creates a `closureInfo` with `rootPaths = objects`, where `objects` comes from the initrd `contents` list
2. `stage-1.nix` populates that list with **subpath string interpolations**:
   ```nix
   { object = "${modulesClosure}/lib"; symlink = "/lib"; }
   { object = "${pkgs.kmod-blacklist-ubuntu}/modprobe.conf"; symlink = "/etc/modprobe.d/ubuntu.conf"; }
   ```
3. These strings become `rootPaths` for `closureInfo`, which passes them through `unsafeDiscardStringContext` into `exportReferencesGraph`
4. When **any transitive dependency** is content-addressed, the entire dependency chain gets deferred output paths (Nix can't compute an input-addressed hash when an input has an unknown CA placeholder path)
5. `"${modulesClosure}/lib"` resolves to `"<ca-placeholder>/lib"` — a placeholder hash with `/lib` appended
6. The Nix daemon fails parsing `closure-info.drv` because `<ca-placeholder>/lib` is neither a valid store path nor a recognized placeholder format

### CA placeholder propagation cascade

Making a **single** package CA doesn't just affect that package. All downstream input-addressed derivations also get deferred output paths, because Nix can't compute their hashes when an input has an unknown path. This cascade continues until it reaches a derivation whose subpath string is passed to `closureInfo`.

### Why some packages crash and others don't

Testing 944 packages individually (each made CA via `overrideAttrs { __contentAddressed = true; }`):

- **FAIL**: Packages in the transitive closure of initrd content items that use subpath references (e.g. `acl` → `coreutils` → `stage-1-init.sh` → initrd). The cascade causes `${modulesClosure}/lib` to become unparseable.
- **PASS**: Packages outside the initrd subpath dependency chain. e.g. `dbus` affects `stage-1-init.sh` (a bare path — no subpath suffix), so its placeholder is fine.

### Proof: examining `closure-info.drv`

**CA-acl (FAIL)** — all 6 initrd entries became placeholders, 2 with subpaths:
```
PLACEHOLDER:         /1mckrpravga6w88li8c6pgwmgjdsi3lq3rz9q6pxh6x3gmjnc25q
PLACEHOLDER+SUBPATH: /0z1qhjshz88n4yifbnvklkdyrj5bwb1q7s0n69lkv5gw2kryzwhp/lib       ← CRASH
PLACEHOLDER+SUBPATH: /1szi39jb73z9d1bagy4kbwfw2zvqsl61wnv4vk2synbh2m9ly2ak/modprobe.conf ← CRASH
```

**CA-dbus (PASS)** — only `stage-1-init.sh` became a placeholder (bare, no subpath):
```
PLACEHOLDER: /1dl62an0dganb3pbaigq0y6z7dz383gapbdjmlcyr58dp6xclkwd
ok:          /nix/store/.../lib
ok:          /nix/store/.../modprobe.conf
```

Confirmed across 8 packages total (acl, glibc, ncurses, curl = FAIL; dbus, chromium, cups, coreutils-full = PASS).

## Workaround: `makeInitrd` overlay

`make-initrd.nix` already has a `suffix` mechanism that keeps subpaths out of `closureInfo`:

```nix
objects  = map (x: x.object) contents;            # → feeds closureInfo
suffices = map (x: if x ? suffix then x.suffix else "none") contents;  # → shell only
# make-initrd.sh: ln -s $object$suffix root/$symlink
```

An overlay on `makeInitrd` can auto-split subpath entries before they reach `closureInfo`:

```nix
makeInitrd = args:
  let
    fixEntry = entry:
      if entry ? suffix then entry
      else let
        str = toString entry.object;
        # Match normal store paths (/nix/store/<32-hash>-<name>/...)
        # and CA placeholders (/<52-hash>/...)
        matched = builtins.match
          "(/nix/store/[a-z0-9]{32}-[^/]+|/[a-z0-9]{52})(/.+)" str;
      in
      if matched == null then entry
      else let
        baseLen = builtins.stringLength (builtins.elemAt matched 0);
        len = builtins.stringLength str;
      in entry // {
        # builtins.substring preserves string context; builtins.match does not
        object = builtins.substring 0 baseLen str;
        suffix = builtins.substring baseLen (len - baseLen) str;
      };
  in prev.makeInitrd (args // {
    contents = map fixEntry (args.contents or []);
  });
```

This transforms `{ object = "${modulesClosure}/lib"; }` into `{ object = modulesClosure; suffix = "/lib"; }`, so `closureInfo` receives bare store paths (or bare CA placeholders, which the daemon handles fine). Verified: `--dry-run` evaluation of a full NixOS system succeeds with this overlay active.

## Vulnerable `closureInfo` call sites in nixpkgs

The initrd was the crash that surfaced for us, but the underlying pattern — subpath strings flowing into `closureInfo` rootPaths — can occur at any call site that accepts caller-provided content lists. There are ~23 `closureInfo` call sites in nixpkgs. The ones that accept external content lists and are therefore vulnerable:

| Call site | rootPaths source | Subpaths today? |
|---|---|---|
| `make-initrd.nix` | `map (x: x.object) contents` from callers like `stage-1.nix` | **Yes** — `"${modulesClosure}/lib"`, `"${kmod-blacklist-ubuntu}/modprobe.conf"` |
| `make-iso9660-image.nix` | `map (x: x.object) storeContents` from `iso-image.nix` et al. | No (full derivations currently) |
| `make-system-tarball.nix` | `map (x: x.object) storeContents` from `lxc-container.nix` et al. | No |
| `make-squashfs.nix` | `storeContents` from callers | No |
| `docker/default.nix` | `contentsList` from callers | No |
| `make-disk-image.nix` | `basePaths ++ additionalPaths'` | No |
| `make-ext4-fs.nix` | `storePaths` parameter | No |
| `make-btrfs-fs.nix` | `storePaths` parameter | No |
| `image/repart.nix` | `partitionConfig.storePaths` | No |
| `systemd-confinement.nix` | service dependency paths | No |
| `portable-service/default.nix` | `[ rootFsScaffold ] ++ contents` | No |

The remaining call sites pass hardcoded derivation references (e.g. `config.system.build.toplevel`) and are not vulnerable.

Any of the "No" sites could become vulnerable if a future nixpkgs change introduces subpath strings into their content lists. The `makeInitrd` overlay workaround above only covers `make-initrd.nix`; a proper fix in Nix itself or a systematic upstream patch to all call sites would be more robust.

## Other possible fixes

1. **Patch `stage-1.nix` upstream** — restructure subpath entries to use the existing `suffix` field directly (aligned with roberth's suggestion to not discard string context or filter subpaths out)
2. **Fix in Nix** — the `.drv` parser should handle CA placeholder paths with subpath suffixes in `exportReferencesGraph` entries. roberth points to #11954 as the long-term solution

## Note: Determinate Nix has a separate bug

With substituters **enabled**, a different crash occurs: `Assertion '!prev' failed in Callback<T>::operator()` during `.doi` realisation 404 handling. This is a race condition in the download callback specific to Determinate Nix. All root cause analysis was done with `--option substituters ""` to bypass it.

## Environment

- Nix: 2.33.3 (Determinate Nix 3.16.3)
- nixpkgs: 25.11.20260304
- x86_64-linux
