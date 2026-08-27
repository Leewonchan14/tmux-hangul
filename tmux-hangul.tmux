#!/usr/bin/env bash

# TPM executes this file when the plugin is loaded.
# BASH_SOURCE is used instead of the current working directory because tmux
# may load a plugin from any directory.
CURRENT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
COMMAND="$CURRENT_DIR/bin/tmux-hangul"

# tmux run-shell receives a shell command string. Quote the executable path so
# the plugin still works when its installation path contains spaces.
COMMAND_SHELL="$(printf '%q' "$COMMAND")"

# Set a user option only when it has no value yet. Existing user configuration
# must take precedence over plugin defaults.
set_default_option() {
  local option="$1"
  local value="$2"
  local current
  current="$(tmux show-option -gqv "$option" 2>/dev/null || true)"
  if [[ -z "$current" ]]; then
    tmux set-option -gq "$option" "$value"
  fi
}

# Keyboard layout used by bin/tmux-hangul.
set_default_option @hangul_prefix_layout dubeolsik
# Conflict policy for an already-used Hangul key. "skip" is the safe default.
set_default_option @hangul_prefix_conflict skip
# Run the initial synchronization automatically when the plugin loads.
set_default_option @hangul_prefix_auto_sync on
# Optional prefix key for manually triggering synchronization.
set_default_option @hangul_prefix_sync_key H

# Install the manual sync binding only when the configured key is unused.
# This prevents the plugin from overwriting a user's existing prefix binding.
SYNC_KEY="$(tmux show-option -gqv @hangul_prefix_sync_key 2>/dev/null || true)"
if [[ -n "$SYNC_KEY" ]]; then
  if ! tmux list-keys -T prefix "$SYNC_KEY" >/dev/null 2>&1; then
    tmux bind-key -T prefix "$SYNC_KEY" run-shell -b "$COMMAND_SHELL sync"
  fi
fi

# Start synchronization in the background so loading the plugin does not
# block tmux configuration processing. Hide the summary from the status line;
# conflicts are still reported by an explicit/manual sync.
AUTO_SYNC="$(tmux show-option -gqv @hangul_prefix_auto_sync 2>/dev/null || true)"
case "$AUTO_SYNC" in
  on|yes|1|true)
    tmux run-shell -b "$COMMAND_SHELL sync >/dev/null 2>&1"
    ;;
esac
