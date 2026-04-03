{ config, lib, ... }:
lib.mkIf config.enableZswap {
  # zswap: compressed swap cache with encrypted disk backing
  #
  # Data flow under memory pressure:
  #   1. Plaintext page in RAM
  #   2. zswap compresses the page (zstd) and stores it in RAM (zsmalloc pool, 50% of RAM)
  #   3. When the pool is full, LRU pages are evicted to the backing swap device
  #   4. dm-crypt encrypts the compressed page at the block layer (randomEncryption)
  #   5. Only encrypted+compressed data reaches the physical disk
  #
  # This replaces zram, which has no disk overflow path and triggers OOM under
  # extreme memory pressure.

  # Disable zram — zswap replaces it. Running both causes zswap to intercept
  # pages before they reach zram, duplicating work and wasting memory.
  zramSwap.enable = lib.mkForce false;

  boot.kernelParams = [
    "zswap.enabled=1" # Enable compressed swap cache
    "zswap.compressor=zstd" # Best compression ratio; CPU cost acceptable on 16+ core machines
    "zswap.zpool=zsmalloc" # Default allocator for kernel 6.18+; lowest fragmentation
    "zswap.max_pool_percent=50" # Security: keep half of RAM as compressed pool to minimize disk writes
    "zswap.shrinker_enabled=1" # Proactively shrink pool under memory pressure
  ];

  boot.kernel.sysctl = {
    # With zswap, values above 100 tell the kernel to prefer swapping compressed
    # pages over reclaiming file cache. 180 is the recommended zswap value.
    "vm.swappiness" = 180;

    # Disable watermark boosting — unnecessary with zswap's compressed pool
    "vm.watermark_boost_factor" = 0;

    # Higher scale factor reclaims memory earlier, reducing burst pressure
    "vm.watermark_scale_factor" = 125;

    # Disable readahead clustering — each zswap page is independently compressed
    "vm.page-cluster" = 0;
  };
}
