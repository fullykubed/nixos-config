# shellcheck shell=bash
# Remote metrics-collection snippet — no shebang, sourced via SSH heredoc.
# Outputs pipe-delimited:
#   builds|cpu%|mem_used_kb|mem_total_kb|disk_read_sectors|disk_write_sectors|
#   disk_total_kb|disk_used_kb|disk_pct|ssh_sessions|ts_status|queue_pending|
#   queue_done|idle_count|ccache_hits|ccache_misses|ccache_size_kb|
#   ccache_mount|ccache_sync|serve_count
#
# ccache_mount: 1 if /var/cache/ccache is a mountpoint, else 0.
# ccache_sync:  1 if ccache-r2-upload.timer is active, else 0.
#               Both default to 1 (no-op) when the relevant tool/unit is absent,
#               so the check never falsely flags a healthy builder that simply
#               does not have the unit.
#
# Disk sectors are cumulative counters; the dashboard computes rates from
# deltas between refreshes.
#
# Sync timer unit on the builder image: ccache-r2-upload.timer
# (defined in modules/utility/ccache-r2.nix, imported via images/builder/ccache.nix)
b=$(ps -eo user= 2>/dev/null | sort -u | grep -c '^nixbld' || true); b=${b:-0}
sv=$(pgrep -fc 'nix-store.*--serve' 2>/dev/null || true); sv=${sv:-0}
sc=$(command ss -Htn state established '( sport = :3098 )' 2>/dev/null | wc -l)
ss=$((sc > 1 ? sc - 1 : 0))
read _ u1 n1 s1 i1 w1 _ < /proc/stat
sleep 1
read _ u2 n2 s2 i2 w2 _ < /proc/stat
t1=$((u1+n1+s1+i1+w1)); t2=$((u2+n2+s2+i2+w2))
dt=$((t2-t1)); di=$((i2-i1))
if [ $dt -gt 0 ]; then cpu=$(((dt-di)*100/dt)); else cpu=0; fi
dr=0; dw=0
while read _ _ dn _ _ sr _ _ _ sw _; do
  case $dn in sda|vda|nvme0n1|xvda) dr=$sr; dw=$sw; break;; esac
done < /proc/diskstats
mt=0; ma=0
while read k v _; do
  case $k in MemTotal:) mt=$v;; MemAvailable:) ma=$v;; esac
done < /proc/meminfo
mu=$((mt-ma))
dline=$(df -k /nix/store | tail -1)
dst=$(echo "$dline" | tr -s ' ' | cut -d' ' -f2)
dsu=$(echo "$dline" | tr -s ' ' | cut -d' ' -f3)
dsp=$(echo "$dline" | tr -s ' ' | cut -d' ' -f5 | tr -d '%')
ts=$(tailscale status --json 2>/dev/null | jaq -r 'if .BackendState == "Running" then "up" else "down" end' 2>/dev/null || echo "unknown")
pq=$(bfs /var/lib/cache-upload-queue/pending -maxdepth 1 -type f 2>/dev/null | wc -l)
dq=$(bfs /var/lib/cache-upload-queue/done -maxdepth 1 -type f 2>/dev/null | wc -l)
ic=$(cat /var/lib/inactivity-monitor/idle-count 2>/dev/null || echo 0)
ch=0; cm_cc=0; csz=0
if command -v ccache >/dev/null 2>&1; then
  cstats=$(ccache -d /var/cache/ccache --print-stats 2>/dev/null) || cstats=""
  if [ -n "$cstats" ]; then
    dh=$(echo "$cstats" | awk -F'\t' '/^direct_cache_hit/{print $2}')
    ph=$(echo "$cstats" | awk -F'\t' '/^preprocessed_cache_hit/{print $2}')
    cm_cc=$(echo "$cstats" | awk -F'\t' '/^cache_miss/{print $2}')
    csz=$(echo "$cstats" | awk -F'\t' '/^cache_size_kibibyte/{print $2}')
    ch=$(( ${dh:-0} + ${ph:-0} ))
    cm_cc=${cm_cc:-0}
    csz=${csz:-0}
  fi
fi
# ccache mount + sync timer health (per-builder)
ccm=1
if command -v mountpoint >/dev/null 2>&1; then
  mountpoint -q /var/cache/ccache || ccm=0
fi
ccs=1
if command -v systemctl >/dev/null 2>&1 && systemctl list-unit-files ccache-r2-upload.timer >/dev/null 2>&1; then
  systemctl is-active --quiet ccache-r2-upload.timer || ccs=0
fi
printf '%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s\n' \
  "$b" "$cpu" "$mu" "$mt" "$dr" "$dw" "$dst" "$dsu" "$dsp" "$ss" "$ts" "$pq" "$dq" "$ic" \
  "$ch" "$cm_cc" "$csz" "$ccm" "$ccs" "$sv"
