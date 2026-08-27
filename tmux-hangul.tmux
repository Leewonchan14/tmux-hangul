#!/usr/bin/env bash

CURRENT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
COMMAND="$CURRENT_DIR/bin/tmux-hangul"
COMMAND_SHELL="$(printf '%q' "$COMMAND")"

set_default_option() {
  local option="$1"
  local value="$2"
  local current
  current="$(tmux show-option -gqv "$option" 2>/dev/null || true)"
  if [[ -z "$current" ]]; then
    tmux set-option -gq "$option" "$value"
  fi
}

set_default_option @hangul_prefix_layout dubeolsik
set_default_option @hangul_prefix_conflict skip
set_default_option @hangul_prefix_auto_sync on
set_default_option @hangul_prefix_sync_key H

SYNC_KEY="$(tmux show-option -gqv @hangul_prefix_sync_key 2>/dev/null || true)"
if [[ -n "$SYNC_KEY" ]]; then
  if ! tmux list-keys -T prefix "$SYNC_KEY" >/dev/null 2>&1; then
    tmux bind-key -T prefix "$SYNC_KEY" run-shell -b "$COMMAND_SHELL sync"
  fi
fi

AUTO_SYNC="$(tmux show-option -gqv @hangul_prefix_auto_sync 2>/dev/null || true)"
case "$AUTO_SYNC" in
  on|yes|1|true)
    tmux run-shell -b "$COMMAND_SHELL sync >/dev/null 2>&1"
    ;;
esac
