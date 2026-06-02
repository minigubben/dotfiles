#!/bin/sh
set -eu

workspace_id=1
brave_command=${BRAVE_COMMAND:-brave}
launch_stamp="${XDG_RUNTIME_DIR:-/tmp}/hypr-keep-brave-workspace1.last"
lock_dir="${XDG_RUNTIME_DIR:-/tmp}/hypr-keep-brave-workspace1.lock"

if ! mkdir "$lock_dir" 2>/dev/null; then
  lock_pid=$(cat "$lock_dir/pid" 2>/dev/null || true)

  if [ -n "$lock_pid" ] && kill -0 "$lock_pid" 2>/dev/null; then
    exit 0
  fi

  rm -rf "$lock_dir"
  mkdir "$lock_dir" 2>/dev/null || exit 0
fi

printf '%s\n' "$$" > "$lock_dir/pid"
trap 'rm -rf "$lock_dir"' EXIT INT TERM

active_workspace_id() {
  hyprctl activeworkspace 2>/dev/null | awk 'tolower($0) ~ /^workspace id / { print $3; exit }'
}

brave_on_workspace_1() {
  hyprctl clients 2>/dev/null | awk -v workspace_id="$workspace_id" '
    function check_client() {
      if (workspace == workspace_id && class ~ /^(brave|brave-browser|Brave-browser)$/) {
        found = 1
      }
    }

    /^Window / {
      check_client()
      workspace = ""
      class = ""
    }

    /^[[:space:]]*workspace:/ { workspace = $2 }
    /^[[:space:]]*class:/ { class = $2 }

    END {
      check_client()
      exit found ? 0 : 1
    }
  '
}

recently_launched() {
  [ -r "$launch_stamp" ] || return 1

  now=$(date +%s)
  last=$(cat "$launch_stamp" 2>/dev/null || printf 0)
  [ "$((now - last))" -lt 3 ]
}

ensure_brave_on_workspace_1() {
  [ "$(active_workspace_id)" = "$workspace_id" ] || return 0
  brave_on_workspace_1 && return 0
  recently_launched && return 0

  date +%s > "$launch_stamp"
  hyprctl dispatch "hl.dsp.exec_cmd(\"[workspace $workspace_id silent] $brave_command --new-window\")" >/dev/null 2>&1 || true
}

event_socket="${XDG_RUNTIME_DIR:-}/hypr/${HYPRLAND_INSTANCE_SIGNATURE:-}/.socket2.sock"

(sleep 5; ensure_brave_on_workspace_1) &

while true; do
  if [ ! -S "$event_socket" ]; then
    sleep 1
    continue
  fi

  nc -U "$event_socket" 2>/dev/null | while IFS= read -r event; do
    case "$event" in
      activeworkspace*|workspace*|closewindow*)
        ensure_brave_on_workspace_1
        ;;
    esac
  done

  sleep 1
done
