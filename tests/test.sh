#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN="$ROOT_DIR/bin/tmux-hangul"
REAL_TMUX="$(command -v tmux)"
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/tmux-hangul-test.XXXXXX")"
SOCKET="tmux-hangul-test-$$"
STATE_DIR="$TEST_DIR/state"
WRAPPER_DIR="$TEST_DIR/bin"

cleanup() {
  "$REAL_TMUX" -L "$SOCKET" kill-server >/dev/null 2>&1 || true
  rm -rf "$TEST_DIR"
}
trap cleanup EXIT

mkdir -p "$WRAPPER_DIR" "$STATE_DIR"
cat > "$WRAPPER_DIR/tmux" <<EOF
#!/bin/sh
exec "$REAL_TMUX" -L "$SOCKET" "\$@"
EOF
chmod +x "$WRAPPER_DIR/tmux"
export PATH="$WRAPPER_DIR:$PATH"
export TMUX_HANGUL_STATE_DIR="$STATE_DIR"

tmux() {
  "$REAL_TMUX" -L "$SOCKET" "$@"
}

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local message="${3:-expected output to contain $needle}"
  [[ "$haystack" == *"$needle"* ]] || fail "$message\noutput: $haystack"
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  local message="${3:-expected output not to contain $needle}"
  [[ "$haystack" != *"$needle"* ]] || fail "$message\noutput: $haystack"
}

assert_key_exists() {
  local key="$1"
  tmux list-keys -T prefix "$key" >/dev/null 2>&1 || fail "expected binding for $key"
}

assert_key_missing() {
  local key="$1"
  if tmux list-keys -T prefix "$key" >/dev/null 2>&1; then
    fail "expected no binding for $key"
  fi
}

list_key() {
  tmux list-keys -T prefix "$1" 2>/dev/null || true
}

"$REAL_TMUX" -L "$SOCKET" -f /dev/null new-session -d -s test

tmux bind-key -T prefix q display-message 'quoted "q"'
tmux bind-key -r -T prefix r resize-pane -L 5
tmux bind-key -T prefix c if-shell -F '#{pane_in_mode}' '{ display-message "yes" }' '{ display-message "no" }'

DRY_RUN="$($PLUGIN sync --dry-run)"
assert_contains "$DRY_RUN" '+ add q -> ㅂ' 'dry-run should plan a q mapping'
assert_contains "$DRY_RUN" '+ add r -> ㄱ' 'dry-run should plan a repeat mapping'
assert_key_missing ㅂ
assert_key_missing ㄱ

SYNC_OUTPUT="$($PLUGIN sync)"
assert_contains "$SYNC_OUTPUT" 'added=' 'sync should report its summary'

ENGLISH_N="$(list_key n)"
HANGUL_U="$(list_key ㅜ)"
assert_contains "$ENGLISH_N" 'next-window' 'English binding must remain'
assert_contains "$HANGUL_U" 'next-window' 'Hangul binding should mirror English binding'

REPEAT_G="$(list_key ㄱ)"
assert_contains "$REPEAT_G" '-r' 'repeat flag must be preserved'
assert_contains "$REPEAT_G" 'resize-pane -L 5' 'repeat command must be preserved'

BRACED_C="$(list_key ㅊ)"
assert_contains "$BRACED_C" 'if-shell' 'compound command name must be preserved'
assert_contains "$BRACED_C" 'display-message \"yes\"' 'quoted compound command must be preserved'
assert_contains "$BRACED_C" 'display-message \"no\"' 'both compound command branches must be preserved'

# A user-owned Hangul binding wins over the generated mapping.
tmux bind-key -T prefix ㅜ display-message user-owned
tmux bind-key -T prefix n next-window
$PLUGIN sync >/dev/null
CONFLICTING_U="$(list_key ㅜ)"
assert_contains "$CONFLICTING_U" 'user-owned' 'existing Hangul binding must be preserved'
assert_not_contains "$CONFLICTING_U" 'next-window' 'conflicting mapping must be skipped'

# Releasing the conflict lets the plugin create the mapping again.
tmux unbind-key -T prefix ㅜ
$PLUGIN sync >/dev/null
assert_contains "$(list_key ㅜ)" 'next-window' 'mapping should be recreated after conflict removal'

# A changed source command updates only the generated counterpart.
tmux bind-key -T prefix n previous-window
$PLUGIN sync >/dev/null
assert_contains "$(list_key n)" 'previous-window' 'source binding should be changed'
assert_contains "$(list_key ㅜ)" 'previous-window' 'generated binding should follow source changes'

# Removing the source binding removes the generated binding, but not unrelated keys.
tmux unbind-key -T prefix n
$PLUGIN sync >/dev/null
assert_key_missing n
assert_key_missing ㅜ
assert_key_exists p

# The explicit error policy reports a conflict without overwriting the user binding.
tmux bind-key -T prefix n next-window
tmux bind-key -T prefix ㅜ display-message protected
tmux set-option -g @hangul_prefix_conflict error
if $PLUGIN sync >/dev/null 2>&1; then
  fail 'error conflict policy should return non-zero'
fi
assert_contains "$(list_key ㅜ)" 'protected' 'error policy must preserve the conflicting binding'
tmux set-option -g @hangul_prefix_conflict skip

# clear removes only bindings still owned by the plugin.
tmux unbind-key -T prefix ㅜ
$PLUGIN sync >/dev/null
assert_key_exists ㅜ
$PLUGIN clear >/dev/null
assert_key_missing ㅜ
assert_key_exists n
assert_key_exists p
# clear must not remove a generated key after the user has taken ownership.
tmux unbind-key -T prefix ㅜ
$PLUGIN sync >/dev/null
tmux bind-key -T prefix ㅜ display-message user-owned-after-sync
$PLUGIN clear >/dev/null 2>&1
assert_contains "$(list_key ㅜ)" 'user-owned-after-sync' 'clear must preserve user-owned overrides'
tmux unbind-key -T prefix ㅜ


# The TPM entrypoint installs a conflict-safe manual sync key and auto-syncs when enabled.
tmux set-option -g @hangul_prefix_auto_sync off
tmux unbind-key -q -T prefix H
"$ROOT_DIR/tmux-hangul.tmux"
assert_contains "$(list_key H)" 'run-shell' 'entrypoint should install the manual sync binding'

tmux set-option -g @hangul_prefix_auto_sync on
"$ROOT_DIR/tmux-hangul.tmux"
for ((attempt = 0; attempt < 80; attempt++)); do
  if tmux list-keys -T prefix ㅜ >/dev/null 2>&1 && [[ -f "$STATE_DIR/m" ]]; then
    break
  fi
  sleep 0.05
done
assert_contains "$(list_key ㅜ)" 'next-window' 'entrypoint auto-sync should create Hangul bindings'
[[ -f "$STATE_DIR/m" ]] || fail 'entrypoint auto-sync should finish all mappings'

printf 'PASS: tmux-hangul behavior\n'
