# shellcheck shell=bash
# sysz — fzf-based systemctl interactive UI
# Drop-in replacement for upstream sysz-1.4.3 with two bug fixes:
#   1. No sudo/doas/pkexec. Read-only ops work via systemd-journal group;
#      state-changing ops rely on polkit for authentication.
#   2. User unit journals use `journalctl --user --user-unit=<name>` (canonical)
#      instead of stripping the --user flag (which returns nothing for user units).

shopt -s extglob

# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------

PROG="$(basename "$0")"
readonly PROG
SYSZ_VERSION="1.4.3"
SYSZ_HISTORY="${SYSZ_HISTORY:-${XDG_CACHE_HOME:-$HOME/.cache}/sysz/history}"

# Minimum required fzf version
MIN_FZF="0.27.1"

# ------------------------------------------------------------------------------
# Helper Functions: logging (all to stderr)
# ------------------------------------------------------------------------------

info()  { printf '%s\n' "$*" >&2; }
warn()  { printf 'warning: %s\n' "$*" >&2; }
error() { printf 'error: %s\n' "$*" >&2; exit 1; }

# ------------------------------------------------------------------------------
# Helper: systemctl dispatcher (NO sudo)
# ------------------------------------------------------------------------------

_sysz_systemctl() {
  local mgr="$1"
  shift
  if [[ $mgr == user ]]; then
    systemctl --user "$@"
  else
    systemctl "$@"
  fi
}

# ------------------------------------------------------------------------------
# Helper: journalctl dispatcher (fixes Bug 2)
# ------------------------------------------------------------------------------

_sysz_journal() {
  local mgr="$1" unit="$2"
  shift 2
  if [[ $mgr == user ]]; then
    journalctl --user --user-unit="$unit" "$@"
  else
    journalctl -u "$unit" "$@"
  fi
}

# ------------------------------------------------------------------------------
# Helper: batched unit property introspection (single systemctl call)
# ------------------------------------------------------------------------------

_sysz_unit_props() {
  local mgr="$1" unit="$2"
  _sysz_systemctl "$mgr" show \
    -p ActiveState -p LoadState -p UnitFileState -p CanReload \
    --value "$unit"
}

# ------------------------------------------------------------------------------
# Keybinding help text
# ------------------------------------------------------------------------------

_sysz_keys() {
  cat <<'EOF'
Keybindings:
  TAB           Toggle selection.
  ctrl-v        'cat' the unit in the preview window.
  ctrl-s        Select states to match. Selection is reset.
  ctrl-r        Run daemon-reload. Selection is reset.
  ctrl-p        History previous.
  ctrl-n        History next.
  ?             Show keybindings.
EOF
}

# ------------------------------------------------------------------------------
# Help text
# ------------------------------------------------------------------------------

_sysz_help() {
  cat >&2 <<EOF
A utility for using systemctl interactively via fzf.

Usage: $PROG [OPTS...] [CMD] [-- ARGS...]

Authentication: read-only operations never require a password (the user is in
the systemd-journal group). State-changing operations on system units invoke
plain systemctl and rely on the registered polkit agent for authentication.
No sudo, doas, or pkexec is used.

If only one unit is chosen, available commands will be presented
based on the state of the unit (e.g. "start" only shows if unit is inactive).

OPTS:
  -u, --user               Only show --user units
  --sys, --system          Only show --system units
  -s STATE, --state STATE  Only show units in STATE (repeatable)
  -V, --verbose            Print the systemctl command
  -v, --version            Print the version
  -h, --help               Print this message

  If no options are given, both system and user units are shown.

CMD:
  start                  systemctl start <unit>
  stop                   systemctl stop <unit>
  re, restart            systemctl restart <unit>
  s, stat, status        systemctl status <unit>
  ed, edit               systemctl edit <unit>
  reload                 systemctl reload <unit>
  en, enable             systemctl enable <unit>
  d, dis, disable        systemctl disable <unit>
  c, cat                 systemctl cat <unit>
  j, journal             journalctl for <unit>
  f, follow              journalctl --follow for <unit>

  If no command is given, one or more can be chosen interactively.

ARGS are passed to the systemctl/journalctl command for each selected unit.

$(_sysz_keys)

History:
  $PROG history is stored in $SYSZ_HISTORY
  This can be changed with the environment variable: SYSZ_HISTORY

Some units are colored based on state:
  green       active
  red         failed
  yellow      not-found

Examples:
  $PROG -u                      User units
  $PROG --sys -s active          Active system units
  $PROG --user --state failed   Failed user units

Examples with commands:
  $PROG start                  Start a unit
  $PROG --sys s                Get the status of system units
  $PROG --user edit            Edit user units
  $PROG s -- -n100             Show status with 100 log lines
  $PROG --sys -s active stop    Stop an active system unit
  $PROG -u --state failed re   Restart failed user units
EOF
}

# ------------------------------------------------------------------------------
# Unit listing helpers
# ------------------------------------------------------------------------------

_sysz_list() {
  # $1 = manager name ("user" or "system"), remaining = extra args (states etc.)
  local mgr="$1"
  shift
  local -a args=(
    --all
    --no-legend
    --full
    --plain
    --no-pager
    "$@"
  )
  (
    _sysz_systemctl "$mgr" list-units "${args[@]}"
    _sysz_systemctl "$mgr" list-unit-files "${args[@]}"
  ) | sort -u -t ' ' -k1,1 |
    while IFS= read -r line; do
      local unit
      unit="${line%% *}"
      if [[ $line == *" active "* ]]; then
        printf '\033[0;32m%s\033[0m\n' "$unit"  # green
      elif [[ $line == *" failed "* ]]; then
        printf '\033[0;31m%s\033[0m\n' "$unit"  # red
      elif [[ $line == *" not-found "* ]]; then
        printf '\033[1;33m%s\033[0m\n' "$unit"  # yellow
      else
        printf '%s\n' "$unit"
      fi
    done
}

_sysz_sort() {
  # Each iteration of the while loop computes a numeric sort key (_sk) for the
  # unit and immediately prints it.  The loop runs in a pipeline subshell but
  # _sk never needs to survive across iterations, so there is no cross-subshell
  # variable leak.
  while IFS= read -r str; do
    local mgr unit_colored unit _sk _type _unit_undashed
    mgr="${str%% *}"
    unit_colored="${str##* }"
    # Strip ANSI colour codes inline (no subshell). Same pattern as _strip_ansi.
    unit="${unit_colored//$'\e'[\[(]*([0-9;])[@-n]/}"

    if [[ $unit =~ \.service$ ]]; then
      _sk=0
      [[ $mgr == "[usr]" ]] && _sk=1
    elif [[ $unit =~ \.timer$ ]]; then
      _sk=2
      [[ $mgr == "[sys]" ]] && _sk=3
    elif [[ $unit =~ \.socket$ ]]; then
      _sk=4
      [[ $mgr == "[sys]" ]] && _sk=5
    elif [[ $mgr == "[usr]" ]]; then
      _sk=6
    else
      _sk=7
    fi
    _type="${unit##*.}"
    _unit_undashed="${unit//-/}"
    printf '%s\n' "${_sk}${_type}${_unit_undashed} ${mgr} ${unit_colored}"
  done | sort -bifu | cut -d' ' -f2-
}

_sysz_list_units() {
  local _mgr _tag
  for _mgr in "${MANAGERS[@]}"; do
    if [[ $_mgr == user ]]; then
      _tag="[usr]"
    else
      _tag="[sys]"
    fi
    _sysz_list "$_mgr" "${STATES[@]}" | sed -e "s/^/${_tag} /"
  done | _sysz_sort
}

# Resolve the manager string ("user" or "system") from a tagged picker line.
# Picker lines are prefixed with "[usr] " or "[sys] ".
_sysz_resolve_mgr() {
  case "${1%% *}" in
  '[usr]') printf 'user'   ;;
  '[sys]') printf 'system' ;;
  *) error "unknown manager tag in picker line: $1" ;;
  esac
}

# Extract the bare unit name from a tagged picker line (strip [tag] prefix and ANSI codes).
_sysz_resolve_unit() {
  local rest
  rest="${1#* }"
  # Strip ANSI colour codes to get the raw unit name.
  printf '%s' "${rest//$'\e'[\[(]*([0-9;])[@-n]/}"
}

# Strip ANSI colour codes from a string.
_strip_ansi() {
  printf '%s' "${1//$'\e'[\[(]*([0-9;])[@-n]/}"
}

# ------------------------------------------------------------------------------
# Extra-feature helper: classify a unit as "user" or "system"
# Uses systemctl --user status first; falls back to system.
# ------------------------------------------------------------------------------

_sysz_classify() {
  local unit="$1"
  if systemctl --user status -- "$unit" &>/dev/null; then
    printf 'user'
  else
    printf 'system'
  fi
}

# ------------------------------------------------------------------------------
# Extra-feature helper: generic fzf picker + command dispatch.
# Reads tagged "[sys]/[usr] <unit>" rows from stdin; lets user pick one;
# then runs the interactive command picker and dispatches the result.
# Usage: printf '%s\n' "${rows}" | _sysz_picker "Prompt label"
# ------------------------------------------------------------------------------

_sysz_picker() {
  local label="${1:-Units}"
  local -a picked=()
  readarray -t picked < <(
    fzf \
      --ansi \
      --multi \
      --no-sort \
      --prompt="${label}: " \
      --bind "ctrl-v:preview('${BASH_SOURCE[0]}' _fzf_cat {})" \
      --preview="'${BASH_SOURCE[0]}' _fzf_preview {}" \
      --preview-window=70%
  )

  if [[ ${#picked[@]} -eq 0 ]]; then
    exit 1
  fi

  # Build unit-command picker (mirrors main script command-selection block).
  local _multi=false
  local _active_state="" _load_state="" _unit_file_state="" _can_reload=""
  local _preview_cmd=""

  if [[ ${#picked[@]} -gt 1 ]]; then
    _preview_cmd="printf '%s\n' $(printf '%q ' "${picked[@]}")"
    _multi=true
  else
    local _u0="${picked[0]}"
    local _m0 _b0
    _m0="$(_sysz_resolve_mgr "$_u0")"
    _b0="$(_sysz_resolve_unit "$_u0")"
    local _props
    _props="$(_sysz_unit_props "$_m0" "$_b0")"
    _active_state="$(printf '%s\n' "$_props" | sed -n '1p')"
    _load_state="$(printf '%s\n' "$_props" | sed -n '2p')"
    _unit_file_state="$(printf '%s\n' "$_props" | sed -n '3p')"
    _can_reload="$(printf '%s\n' "$_props" | sed -n '4p')"
    _preview_cmd="'${BASH_SOURCE[0]}' _fzf_preview $(printf '%q' "$_u0")"
  fi

  local _cmds_file
  _cmds_file="$(mktemp)"
  {
    printf '%s\n' "status"
    if [[ $_multi == true || $_active_state == active ]]; then
      printf '\033[0;31m%s\033[0m\n' "restart"
    fi
    if [[ $_multi == true || $_active_state != active ]]; then
      printf '\033[0;32m%s\033[0m\n' "start"
    fi
    if [[ $_multi == true || $_active_state == active ]]; then
      printf '\033[0;31m%s\033[0m\n' "stop"
    fi
    if [[ $_multi == true || $_unit_file_state != enabled ]]; then
      printf '\033[0;32m%s\033[0m\n' "enable"
      printf '\033[0;32m%s\033[0m\n' "enable --now"
    fi
    if [[ $_multi == true || $_unit_file_state == enabled ]]; then
      printf '\033[0;31m%s\033[0m\n' "disable"
      printf '\033[0;31m%s\033[0m\n' "disable --now"
    fi
    printf '%s\n' "journal"
    printf '%s\n' "follow"
    if [[ $_multi == true || $_can_reload == yes ]]; then
      printf '\033[0;37m%s\033[0m\n' "reload"
    fi
    if [[ $_multi == true || ( $_unit_file_state != masked && $_load_state != masked ) ]]; then
      printf '\033[0;31m%s\033[0m\n' "mask"
    fi
    if [[ $_multi == true || $_unit_file_state == masked || $_load_state == masked ]]; then
      printf '\033[0;32m%s\033[0m\n' "unmask"
    fi
    printf '%s\n' "cat"
    printf '%s\n' "edit"
    printf '%s\n' "show"
  } >> "$_cmds_file"

  local -a _cmds=()
  readarray -t _cmds < <(
    fzf \
      --multi \
      --ansi \
      --no-info \
      --prompt="Commands: " \
      --preview="$_preview_cmd" \
      --preview-window=80% \
      < "$_cmds_file"
  )
  rm -f "$_cmds_file"

  if [[ ${#_cmds[@]} -eq 0 ]]; then
    exit 1
  fi

  # Dispatch each (unit, command) pair.
  local _pick _raw_cmd _stripped _plain_cmd _extra _pick_mgr _pick_unit _code
  for _pick in "${picked[@]}"; do
    _pick_mgr="$(_sysz_resolve_mgr "$_pick")"
    _pick_unit="$(_sysz_resolve_unit "$_pick")"
    for _raw_cmd in "${_cmds[@]}"; do
      _stripped="$(_strip_ansi "$_raw_cmd")"
      _plain_cmd="${_stripped%% *}"
      _extra=""
      if [[ "$_stripped" == *" "* ]]; then
        _extra="${_stripped#* }"
      fi
      _code=0
      case "$_plain_cmd" in
      journal)
        _sysz_journal "$_pick_mgr" "$_pick_unit" -xe
        ;;
      follow)
        _sysz_journal "$_pick_mgr" "$_pick_unit" -xef
        ;;
      status)
        SYSTEMD_COLORS=1 _sysz_systemctl "$_pick_mgr" status --no-pager -- "$_pick_unit"
        ;;
      cat | show)
        _sysz_systemctl "$_pick_mgr" "$_plain_cmd" -- "$_pick_unit" || exit $?
        ;;
      enable | disable)
        # shellcheck disable=SC2086
        _sysz_systemctl "$_pick_mgr" $_plain_cmd ${_extra} -- "$_pick_unit" || _code=$?
        SYSTEMD_COLORS=1 _sysz_systemctl "$_pick_mgr" status --no-pager -- "$_pick_unit" || true
        if [[ ${#picked[@]} -eq 1 ]]; then
          exit $_code
        fi
        ;;
      *)
        # shellcheck disable=SC2086
        _sysz_systemctl "$_pick_mgr" $_plain_cmd -- "$_pick_unit" || _code=$?
        SYSTEMD_COLORS=1 _sysz_systemctl "$_pick_mgr" status --no-pager -- "$_pick_unit" || true
        if [[ ${#picked[@]} -eq 1 ]]; then
          exit $_code
        fi
        ;;
      esac
    done
  done
}

# ------------------------------------------------------------------------------
# Extra feature: --failed
# Shows failed system + user units in a single fzf picker.
# ------------------------------------------------------------------------------

_sysz_failed() {
  local rows
  rows=$(
    systemctl list-units --state=failed --all --no-legend \
      | awk '{ printf "[sys] %s\n", $0 }'
    systemctl --user list-units --state=failed --all --no-legend \
      | awk '{ printf "[usr] %s\n", $0 }'
  )
  if [[ -z $rows ]]; then
    printf 'no failed units\n'
    return 0
  fi
  printf '%s\n' "$rows" | _sysz_picker "failed units"
}

# ------------------------------------------------------------------------------
# Extra feature: --drops <unit>
# Colorized systemd-delta output for a unit, paged through ${PAGER:-less -R}.
# ------------------------------------------------------------------------------

_sysz_drops() {
  local unit="$1"
  if [[ -z $unit ]]; then
    error "--drops requires a unit name"
  fi
  # Detect whether unit is a user unit by trying systemctl --user status.
  # If it succeeds, pass --user to systemd-delta.
  local -a delta_args=()
  if systemctl --user status -- "$unit" &>/dev/null; then
    delta_args=(--user)
  fi
  systemd-delta "${delta_args[@]}" "$unit" | awk '
    /^\[MASKED\]/     { printf "\033[31m%s\033[0m\n", $0; next }
    /^\[OVERRIDDEN\]/ { printf "\033[33m%s\033[0m\n", $0; next }
    /^\[EXTENDED\]/   { printf "\033[32m%s\033[0m\n", $0; next }
    /^\[REDIRECTED\]/ { printf "\033[36m%s\033[0m\n", $0; next }
    /^\[EQUIVALENT\]/ { printf "\033[2m%s\033[0m\n", $0; next }
    /^\[UNCHANGED\]/  { printf "\033[2m%s\033[0m\n", $0; next }
    { print }
  ' | ${PAGER:-less -R}
}

# ------------------------------------------------------------------------------
# Extra feature: --timers
# Unified system + user timer view fed into fzf with status preview.
# ------------------------------------------------------------------------------

_sysz_timers() {
  local rows
  rows=$(
    systemctl list-timers --all --no-legend --no-pager \
      | awk '{ printf "[sys] %s\n", $0 }'
    systemctl --user list-timers --all --no-legend --no-pager \
      | awk '{ printf "[usr] %s\n", $0 }'
  )
  if [[ -z $rows ]]; then
    printf 'no timers found\n'
    return 0
  fi

  # Feed the timer rows into fzf; extract the timer unit name from the UNIT
  # column (column 5 in list-timers output, column 6 after our [tag] prefix).
  # On pick, resolve manager and dispatch to command picker.
  local _picked_row
  _picked_row=$(
    printf '%s\n' "$rows" |
      fzf \
        --ansi \
        --no-sort \
        --prompt="Timers: " \
        --preview="
          _tag=\$(printf '%s' {} | awk '{print \$1}')
          _unit=\$(printf '%s' {} | awk '{print \$6}')
          if [[ \$_tag == '[sys]' ]]; then
            SYSTEMD_COLORS=1 systemctl status --no-pager -- \"\$_unit\"
          else
            SYSTEMD_COLORS=1 systemctl --user status --no-pager -- \"\$_unit\"
          fi
        " \
        --preview-window=70%
  )

  if [[ -z $_picked_row ]]; then
    exit 1
  fi

  # Extract tag and unit name; reconstruct a picker-compatible tagged line.
  local _tag _timer_unit
  _tag="$(printf '%s' "$_picked_row" | awk '{print $1}')"
  _timer_unit="$(printf '%s' "$_picked_row" | awk '{print $6}')"

  # Build a tagged line compatible with _sysz_picker's expected format.
  printf '%s %s\n' "$_tag" "$_timer_unit" | _sysz_picker "timer"
}

# ------------------------------------------------------------------------------
# Extra feature: --follow <unit>...
# Multi-unit log follow using Pattern A (PID array + trap cleanup).
# System units batched into one journalctl process; user units into another.
# ------------------------------------------------------------------------------

_sysz_follow_multi() {
  if [[ $# -eq 0 ]]; then
    error "--follow requires at least one unit name"
  fi

  local -a sys_units=() usr_units=()
  local unit mgr

  for unit in "$@"; do
    mgr="$(_sysz_classify "$unit")"
    if [[ $mgr == user ]]; then
      usr_units+=("$unit")
    else
      sys_units+=("$unit")
    fi
  done

  declare -a PIDS=()
  # shellcheck disable=SC2329
  cleanup() {
    local pid
    for pid in "${PIDS[@]}"; do
      kill -0 "$pid" 2>/dev/null && kill "$pid" 2>/dev/null
    done
    wait 2>/dev/null || true
  }
  trap cleanup EXIT INT TERM

  if [[ ${#sys_units[@]} -gt 0 ]]; then
    local -a sys_args=()
    for unit in "${sys_units[@]}"; do sys_args+=(-u "$unit"); done
    journalctl --follow "${sys_args[@]}" &
    PIDS+=("$!")
  fi

  if [[ ${#usr_units[@]} -gt 0 ]]; then
    local -a usr_args=()
    for unit in "${usr_units[@]}"; do usr_args+=(--user-unit="$unit"); done
    journalctl --user --follow "${usr_args[@]}" &
    PIDS+=("$!")
  fi

  wait
}

# ------------------------------------------------------------------------------
# fzf preview helpers (called as sub-commands of the same script)
# ------------------------------------------------------------------------------

_fzf_cat() {
  local mgr unit
  mgr="$(_sysz_resolve_mgr "$1")"
  unit="$(_sysz_resolve_unit "$1")"
  SYSTEMD_COLORS=1 _sysz_systemctl "$mgr" cat -- "$unit"
}

_fzf_preview() {
  local mgr unit
  mgr="$(_sysz_resolve_mgr "$1")"
  unit="$(_sysz_resolve_unit "$1")"
  if [[ $unit == *@.* ]]; then
    SYSTEMD_COLORS=1 _sysz_systemctl "$mgr" cat -- "$unit"
  else
    SYSTEMD_COLORS=1 _sysz_systemctl "$mgr" status --no-pager -- "$unit"
  fi
}

# ------------------------------------------------------------------------------
# Interactive picker helpers
# ------------------------------------------------------------------------------

_sysz_daemon_reload() {
  local -a opts=()
  local _m
  for _m in "${MANAGERS[@]}"; do
    if [[ $_m == user ]]; then
      opts+=('[usr] daemon-reload')
    else
      opts+=('[sys] daemon-reload')
    fi
  done

  local -a reloads=()
  readarray -t reloads < <(
    printf '%s\n' "${opts[@]}" |
      fzf \
        --multi \
        --no-info \
        --prompt="Reload: "
  )

  local reload
  for reload in "${reloads[@]}"; do
    case "$reload" in
    '[usr] daemon-reload')
      if [[ $VERBOSE == true ]]; then info '> systemctl --user daemon-reload'; fi
      _sysz_systemctl user daemon-reload >&2
      ;;
    '[sys] daemon-reload')
      if [[ $VERBOSE == true ]]; then info '> systemctl daemon-reload'; fi
      _sysz_systemctl system daemon-reload >&2
      ;;
    esac
  done
}

_sysz_states() {
  local -a picked_states=()
  readarray -t picked_states < <(
    systemctl --state=help |
      grep -v ':' |
      grep -v 'ing' |
      sort -u |
      grep -v '^$' |
      fzf \
        --multi \
        --prompt="States: "
  )

  if [[ ${#picked_states[@]} -gt 0 ]]; then
    STATES=()
    local s
    for s in "${picked_states[@]}"; do
      STATES+=("--state=${s}")
    done
  fi
}

# ------------------------------------------------------------------------------
# Version check
# ------------------------------------------------------------------------------

_sysz_check_fzf_version() {
  local fzf_ver
  fzf_ver="$(fzf --version | cut -d' ' -f1)"
  if [[ "$(printf '%s\n' "$MIN_FZF" "$fzf_ver" | sort -V | head -n1)" != "$MIN_FZF" ]]; then
    error "fzf >= $MIN_FZF required (got $fzf_ver). See https://github.com/junegunn/fzf#upgrading-fzf"
  fi
}

# ------------------------------------------------------------------------------
# Argument parsing
# ------------------------------------------------------------------------------

# Default: root has no user units; regular user sees both.
if [[ $EUID -eq 0 ]]; then
  MANAGERS=(system)
else
  MANAGERS=(user system)
fi

declare -a STATES=()
VERBOSE=false
CMD=""
declare -a ARGS=()

# Check for internal sub-command dispatch first (called from fzf bindings).
# These must be handled before the regular option loop.
if [[ "${1:-}" == "_fzf_preview" ]]; then
  shift
  _fzf_preview "$@"
  exit 0
fi
if [[ "${1:-}" == "_fzf_cat" ]]; then
  shift
  _fzf_cat "$@"
  exit 0
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
  -u | --user)
    MANAGERS=(user)
    shift
    ;;
  --sys | --system)
    MANAGERS=(system)
    shift
    ;;
  -s | --state)
    STATES+=("--state=$2")
    shift 2
    ;;
  --state=*)
    STATES+=("$1")
    shift
    ;;
  -v | --version)
    printf '%s %s\n' "$PROG" "$SYSZ_VERSION"
    exit 0
    ;;
  -V | --verbose)
    VERBOSE=true
    shift
    ;;
  -h | --help)
    _sysz_help
    exit 0
    ;;
  h | help)
    _sysz_help
    exit 0
    ;;
  # Short command aliases
  re)
    CMD=restart
    shift
    ;;
  s | stat | status)
    CMD=status
    shift
    ;;
  ed | edit)
    CMD=edit
    shift
    ;;
  en | enable)
    CMD=enable
    shift
    ;;
  d | dis | disable)
    CMD=disable
    shift
    ;;
  j | journal)
    CMD=journal
    shift
    ;;
  f | follow)
    CMD=follow
    shift
    ;;
  c | 'cat')
    CMD='cat'
    shift
    ;;
  --failed)
    _sysz_failed
    exit 0
    ;;
  --drops)
    shift
    _sysz_drops "${1:-}"
    exit 0
    ;;
  --timers)
    _sysz_timers
    exit 0
    ;;
  --follow)
    shift
    _sysz_follow_multi "$@"
    exit 0
    ;;
  --)
    shift
    ARGS=("$@")
    break
    ;;
  -*)
    error "unknown option: $1"
    ;;
  *)
    CMD="$1"
    shift
    ;;
  esac
done

# ------------------------------------------------------------------------------
# Validate states
# ------------------------------------------------------------------------------

for _state_arg in "${STATES[@]}"; do
  _state_val="${_state_arg##*=}"
  if [[ -n $_state_val ]] && ! systemctl --state=help | grep -q "^${_state_val}$"; then
    error "invalid state: $_state_val"
  fi
done

# ------------------------------------------------------------------------------
# Ensure history directory exists
# ------------------------------------------------------------------------------

mkdir -p "$(dirname "$SYSZ_HISTORY")"
touch "$SYSZ_HISTORY"

# ------------------------------------------------------------------------------
# fzf version check
# ------------------------------------------------------------------------------

_sysz_check_fzf_version

# ------------------------------------------------------------------------------
# Unit selection loop
# ------------------------------------------------------------------------------

declare -a UNITS=()
KEY=""

while true; do
  UNITS=()
  KEY=""

  declare -a _picks=()
  # SC2016: single-quoted variables are intentional in fzf --bind/--preview strings
  readarray -t _picks < <(
    _sysz_list_units |
      fzf \
        --multi \
        --ansi \
        --no-sort \
        --expect=ctrl-r,ctrl-s \
        --history="$SYSZ_HISTORY" \
        --prompt="Units: " \
        --header='? for keybindings' \
        --bind "?:preview(printf '%s\n' 'Keybindings:' '  TAB           Toggle selection.' '  ctrl-v        cat the unit in the preview window.' '  ctrl-s        Select states to match. Selection is reset.' '  ctrl-r        Run daemon-reload. Selection is reset.' '  ctrl-p        History previous.' '  ctrl-n        History next.' '  ?             Show keybindings.')" \
        --bind "ctrl-v:preview('${BASH_SOURCE[0]}' _fzf_cat {})" \
        --preview="'${BASH_SOURCE[0]}' _fzf_preview {}" \
        --preview-window=70%
  )

  KEY="${_picks[0]:-}"
  if [[ $VERBOSE == true ]]; then info "KEY: $KEY"; fi
  UNITS=("${_picks[@]:1}")

  case "$KEY" in
  ctrl-r)
    _sysz_daemon_reload
    continue
    ;;
  ctrl-s)
    _sysz_states
    continue
    ;;
  esac

  if [[ ${#UNITS[@]} -eq 0 ]]; then
    exit 1
  fi

  break
done

if [[ $VERBOSE == true ]]; then
  printf 'UNIT: %s\n' "${UNITS[@]}" >&2
fi

# ------------------------------------------------------------------------------
# Command selection
# ------------------------------------------------------------------------------

declare -a CMDS=()

if [[ -n $CMD ]]; then
  CMDS=("$CMD")
else

  MULTI=false
  ACTIVE_STATE=""
  LOAD_STATE=""
  UNIT_FILE_STATE=""
  CAN_RELOAD=""
  PREVIEW_CMD=""

  if [[ ${#UNITS[@]} -gt 1 ]]; then
    PREVIEW_CMD="printf '%s\n' $(printf '%q ' "${UNITS[@]}")"
    MULTI=true
  else
    _unit0="${UNITS[0]}"

    # Template unit: prompt for instance parameter
    if [[ $_unit0 == *@.* ]]; then
      _param=""
      read -r -p "$_unit0 requires a parameter: " _param || true
      if [[ -z $_param ]]; then
        error "$_unit0 requires a parameter"
      fi
      _unit0="${_unit0/@/@${_param}}"
      UNITS[0]="$_unit0"
    fi

    _mgr0="$(_sysz_resolve_mgr "$_unit0")"
    _bare_unit0="$(_sysz_resolve_unit "$_unit0")"

    # Batch introspection: single systemctl show call (fixes upstream's 4× calls)
    _props="$(_sysz_unit_props "$_mgr0" "$_bare_unit0")"
    ACTIVE_STATE="$(printf '%s\n' "$_props" | sed -n '1p')"
    LOAD_STATE="$(printf '%s\n' "$_props" | sed -n '2p')"
    UNIT_FILE_STATE="$(printf '%s\n' "$_props" | sed -n '3p')"
    CAN_RELOAD="$(printf '%s\n' "$_props" | sed -n '4p')"

    PREVIEW_CMD="'${BASH_SOURCE[0]}' _fzf_preview $(printf '%q' "$_unit0")"
  fi

  # Build the candidate command list into a temp file so fzf can read from it
  # while readarray reads fzf's output — both in the main shell via process
  # substitution, avoiding any subshell assignment for CMDS.
  _cmds_file="$(mktemp)"
  {
    # status always available
    printf '%s\n' "status"
    # restart (shown when active or multi)
    if [[ $MULTI == true || $ACTIVE_STATE == active ]]; then
      printf '\033[0;31m%s\033[0m\n' "restart"
    fi
    # start (shown when not active or multi)
    if [[ $MULTI == true || $ACTIVE_STATE != active ]]; then
      printf '\033[0;32m%s\033[0m\n' "start"
    fi
    # stop (shown when active or multi)
    if [[ $MULTI == true || $ACTIVE_STATE == active ]]; then
      printf '\033[0;31m%s\033[0m\n' "stop"
    fi
    # enable (shown when not enabled or multi)
    if [[ $MULTI == true || $UNIT_FILE_STATE != enabled ]]; then
      printf '\033[0;32m%s\033[0m\n' "enable"
      printf '\033[0;32m%s\033[0m\n' "enable --now"
    fi
    # disable (shown when enabled or multi)
    if [[ $MULTI == true || $UNIT_FILE_STATE == enabled ]]; then
      printf '\033[0;31m%s\033[0m\n' "disable"
      printf '\033[0;31m%s\033[0m\n' "disable --now"
    fi
    # journal / follow always available
    printf '%s\n' "journal"
    printf '%s\n' "follow"
    # reload (shown when CanReload=yes or multi)
    if [[ $MULTI == true || $CAN_RELOAD == yes ]]; then
      printf '\033[0;37m%s\033[0m\n' "reload"
    fi
    # mask / unmask
    if [[ $MULTI == true || ( $UNIT_FILE_STATE != masked && $LOAD_STATE != masked ) ]]; then
      printf '\033[0;31m%s\033[0m\n' "mask"
    fi
    if [[ $MULTI == true || $UNIT_FILE_STATE == masked || $LOAD_STATE == masked ]]; then
      printf '\033[0;32m%s\033[0m\n' "unmask"
    fi
    # cat / edit / show
    printf '%s\n' "cat"
    printf '%s\n' "edit"
    printf '%s\n' "show"
  } >> "$_cmds_file"

  # readarray in main shell; fzf reads from the temp file inside the procsub
  readarray -t CMDS < <(
    fzf \
      --multi \
      --ansi \
      --no-info \
      --prompt="Commands: " \
      --preview="$PREVIEW_CMD" \
      --preview-window=80% \
      < "$_cmds_file"
  )
  rm -f "$_cmds_file"
fi

if [[ ${#CMDS[@]} -eq 0 ]]; then
  exit 1
fi

# ------------------------------------------------------------------------------
# Command dispatch
# ------------------------------------------------------------------------------

for PICK in "${UNITS[@]}"; do

  PICK_MGR="$(_sysz_resolve_mgr "$PICK")"
  PICK_UNIT="$(_sysz_resolve_unit "$PICK")"

  for RAW_CMD in "${CMDS[@]}"; do
    # Commands from the picker may carry ANSI colour codes; strip them.
    STRIPPED_RAW="$(_strip_ansi "$RAW_CMD")"
    PLAIN_CMD="${STRIPPED_RAW%% *}"
    # If entry has embedded extra args (e.g. "enable --now"), extract them.
    EXTRA_FROM_CMD=""
    if [[ "$STRIPPED_RAW" == *" "* ]]; then
      EXTRA_FROM_CMD="${STRIPPED_RAW#* }"
    fi

    if [[ $VERBOSE == true ]]; then
      info "> dispatch: mgr=$PICK_MGR unit=$PICK_UNIT cmd=$PLAIN_CMD${EXTRA_FROM_CMD:+ extra=$EXTRA_FROM_CMD}"
    fi

    _code=0
    case "$PLAIN_CMD" in
    journal)
      _sysz_journal "$PICK_MGR" "$PICK_UNIT" -xe "${ARGS[@]}"
      ;;
    follow)
      _sysz_journal "$PICK_MGR" "$PICK_UNIT" -xef "${ARGS[@]}"
      ;;
    status)
      SYSTEMD_COLORS=1 _sysz_systemctl "$PICK_MGR" status --no-pager "${ARGS[@]}" -- "$PICK_UNIT"
      ;;
    cat | show)
      _sysz_systemctl "$PICK_MGR" "$PLAIN_CMD" "${ARGS[@]}" -- "$PICK_UNIT" || exit $?
      ;;
    enable | disable)
      # shellcheck disable=SC2086
      _sysz_systemctl "$PICK_MGR" $PLAIN_CMD ${EXTRA_FROM_CMD} "${ARGS[@]}" -- "$PICK_UNIT" || _code=$?
      SYSTEMD_COLORS=1 _sysz_systemctl "$PICK_MGR" status --no-pager -- "$PICK_UNIT" || true
      if [[ ${#UNITS[@]} -eq 1 ]]; then
        exit $_code
      fi
      ;;
    *)
      # shellcheck disable=SC2086
      _sysz_systemctl "$PICK_MGR" $PLAIN_CMD "${ARGS[@]}" -- "$PICK_UNIT" || _code=$?
      SYSTEMD_COLORS=1 _sysz_systemctl "$PICK_MGR" status --no-pager -- "$PICK_UNIT" || true
      if [[ ${#UNITS[@]} -eq 1 ]]; then
        exit $_code
      fi
      ;;
    esac
  done
done
