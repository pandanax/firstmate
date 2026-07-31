#!/usr/bin/env bash
# Behavior tests for the project-owned delivery, autonomy, and merge-authority registry contract.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

TMP_ROOT=$(fm_test_tmproot fm-project-mode)
HOME_DIR="$TMP_ROOT/home"
mkdir -p "$HOME_DIR/data"

cat > "$HOME_DIR/data/projects.md" <<'EOF'
- legacy - legacy defaults (added 2026-08-01)
- manual [direct-PR merge:manual] - explicit manual (added 2026-08-01)
- automatic [no-mistakes +yolo merge:auto] - automatic PR (added 2026-08-01)
- reordered [merge:auto direct-PR +yolo] - order-independent properties (added 2026-08-01)
- local-auto [local-only merge:auto] - invalid auto combination (added 2026-08-01)
- bad-merge [direct-PR merge:sometimes] - invalid merge value (added 2026-08-01)
EOF

assert_mode() {
  local project=$1 expected=$2 actual
  actual=$(FM_HOME="$HOME_DIR" "$ROOT/bin/fm-project-mode.sh" "$project" 2>/dev/null)
  [ "$actual" = "$expected" ] || fail "$project resolved to '$actual', expected '$expected'"
}

assert_mode legacy "no-mistakes off manual"
assert_mode manual "direct-PR off manual"
assert_mode automatic "no-mistakes on auto"
assert_mode reordered "direct-PR on auto"
assert_mode local-auto "local-only off manual"
assert_mode bad-merge "direct-PR off manual"
assert_mode absent "no-mistakes off manual"
pass "fm-project-mode resolves project-owned merge authority with safe defaults"

actual=$(PANDAMATE_PROJECT_SLUG=manual PANDAMATE_MERGE_MODE=auto \
  FM_HOME="$HOME_DIR" "$ROOT/bin/fm-project-mode.sh" manual 2>/dev/null)
[ "$actual" = "direct-PR off auto" ] \
  || fail "matching Pandamate override resolved to '$actual', expected 'direct-PR off auto'"

actual=$(PANDAMATE_PROJECT_SLUG=automatic PANDAMATE_MERGE_MODE=invalid \
  FM_HOME="$HOME_DIR" "$ROOT/bin/fm-project-mode.sh" automatic 2>/dev/null)
[ "$actual" = "no-mistakes on manual" ] \
  || fail "invalid matching Pandamate override did not fail closed: '$actual'"

actual=$(PANDAMATE_PROJECT_SLUG=another-project PANDAMATE_MERGE_MODE=manual \
  FM_HOME="$HOME_DIR" "$ROOT/bin/fm-project-mode.sh" automatic 2>/dev/null)
[ "$actual" = "no-mistakes on auto" ] \
  || fail "nonmatching Pandamate slug changed automatic: '$actual'"

actual=$(PANDAMATE_PROJECT_SLUG=unregistered PANDAMATE_MERGE_MODE=auto \
  FM_HOME="$HOME_DIR" "$ROOT/bin/fm-project-mode.sh" unregistered 2>/dev/null)
[ "$actual" = "no-mistakes off auto" ] \
  || fail "matching Pandamate launch did not apply to the safe unregistered defaults: '$actual'"
pass "fm-project-mode scopes Pandamate merge authority to the matching launched project"
