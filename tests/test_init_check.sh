# shellcheck shell=bash
# dot init (start a dotfiles repo) and dot check (validate one).

# run the tool from a checkout that is NOT a dotfiles repo (like the real tool repo)
tool_only() {
  rm -rf "$R/modules" "$R/presets"
  mkdir -p "$T/work"
}
doto() { OUT=$(cd "$T/work" && "$R/dot" "$@" </dev/null 2>&1); RC=$?; }

test_init_creates_repo_and_uses_it() {
  tool_only
  DOT_OMARCHY=0; export DOT_OMARCHY
  doto status; assert_rc_fail "no repo yet"
  assert_contains "$OUT" "dot init"
  doto init; assert_ok
  local d=$HOME/dotfiles
  assert_file "$d/modules/core/module.sh"
  assert_file "$d/presets/default"
  assert_file "$d/sync.ignore"
  assert_file "$d/README.md"
  assert_no_file "$d/modules/omarchy"
  assert_line "$HOME/.config/dotfiles/repo" "$d"
  [[ -d $d/.git ]] || _fail "git repo expected"
  doto check; assert_ok
  assert_contains "$OUT" "look good"
}

test_init_refuses_non_empty_dir() {
  tool_only
  mkdir -p "$T/full"; echo x >"$T/full/file"
  doto init "$T/full"; assert_rc_fail
  assert_contains "$OUT" "isn't empty"
  assert_no_file "$HOME/.config/dotfiles/repo"
}

test_init_on_omarchy_records_current_setup() {
  tool_only
  om_setup
  rm -rf "$R/modules"   # om_setup creates a fixture module; this test wants none
  doto init "$T/mine"; assert_ok
  assert_file "$T/mine/modules/omarchy/module.sh"
  assert_line "$T/mine/modules/omarchy/profile" "default browser chromium"
  assert_line "$T/mine/modules/omarchy/profile" 'theme set "Tokyo Night"'
  assert_eq "" "$(om_log)" "init must not change the system"
}

test_check_reports_problems() {
  mkmod core <<<'DESC=core; REQUIRED=1'
  mkmod ok <<<'DESC=fine'
  mkmod nodesc <<<'PKGS=(x)'
  mkmod baddep <<<'DESC=x; DEPENDS=(ghost)'
  mkmod broken <<<'DESC=x; if then'
  mkmod noisy <<<'DESC=x; echo hello'
  mkhome ok .zshrc
  mkhome noisy .zshrc
  mkdir -p "$R/modules/empty"
  mkpreset good '# fine' ok
  printf 'ok\n' >"$R/presets/nohead"
  mkpreset badref '# x' ok ghost @nope
  dotx check; assert_rc_fail
  assert_contains "$OUT" "modules/empty has no module.sh"
  assert_contains "$OUT" "modules/broken/module.sh has a syntax error"
  assert_contains "$OUT" "nodesc has no DESC"
  assert_contains "$OUT" "baddep depends on missing module ghost"
  assert_contains "$OUT" "noisy prints while loading"
  assert_contains "$OUT" "preset nohead needs a '# description' first line"
  assert_contains "$OUT" "preset badref lists missing module ghost"
  assert_contains "$OUT" "preset badref includes missing preset @nope"
  assert_contains "$OUT" "linked by more than one module: noisy ok → ~/.zshrc"
  assert_not_contains "$OUT" "core must"
}

test_check_wants_required_core() {
  mkmod core <<<'DESC=core'
  dotx check; assert_rc_fail
  assert_contains "$OUT" "core must set REQUIRED=1"
}

test_sync_builtin_ignores_apply_without_repo_file() {
  om_setup
  printf 'git\nobsidian\npinta\nnvidia-utils\nhtop\n' >"$T/om/pkgs"
  printf 'nvidia-utils\nhtop\n' >"$T/om/explicit"
  rm -f "$R/sync.ignore"
  dotx sync --omarchy --yes; assert_ok
  assert_line "$R/modules/omarchy/profile" "pkg add htop"
  assert_no_line "$R/modules/omarchy/profile" "pkg add nvidia-utils"
}
