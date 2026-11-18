# shellcheck shell=bash
# Config mode (copy vs link), dot clone, dot setup, install.sh --repo.

# a git repo with one module, usable as a clone URL
mk_remote_dotfiles() {
  local d=$1
  mkdir -p "$d/modules/a/home/.config/a"
  echo 'DESC=a' >"$d/modules/a/module.sh"
  echo v1 >"$d/modules/a/home/.config/a/cfg"
  git -C "$d" init -q -b main
  git -C "$d" add -A
  git -C "$d" -c user.email=t@t -c user.name=t commit -qm init
}

test_copy_mode_apply_status_and_remove() {
  mkmod a <<<'DESC=a; PKGS=(x)'
  mkhome a .config/a/cfg v1
  mkdir -p "$HOME/.config/dotfiles"; echo copy >"$HOME/.config/dotfiles/config-mode"
  dotx plan a; assert_ok
  assert_contains "$OUT" "copy      + ~/.config/a"
  dotx apply a --yes; assert_ok
  [[ -d $HOME/.config/a && ! -L $HOME/.config/a ]] || _fail "copy mode must copy, not link"
  assert_eq "a $HOME/.config/a" "$(cut -f1,2 --output-delimiter=' ' "$HOME/.local/state/dotfiles/copies")" "copy recorded"
  dotx apply a --yes; assert_contains "$OUT" "Everything is already applied"
  dotx status; assert_contains "$OUT" "ready"
  dotx remove a --yes; assert_ok
  assert_no_file "$HOME/.config/a"
  assert_eq v1 "$(cat "$HOME"/.local/state/dotfiles/backups/*/.config/a/cfg)"
}

test_link_mode_is_the_default() {
  mkmod a <<<'DESC=a'
  mkhome a .zshrc
  dotx apply a --yes; assert_ok
  assert_link "$HOME/.zshrc" "$R/modules/a/home/.zshrc"
}

test_clone_uses_repo_and_reuses_existing() {
  mk_remote_dotfiles "$T/remote"
  dotx clone "$T/remote" "$T/df"; assert_ok
  assert_file "$T/df/modules/a/module.sh"
  assert_line "$HOME/.config/dotfiles/repo" "$T/df"
  dotx clone "$T/remote" "$T/df"; assert_ok
  assert_contains "$OUT" "already a dotfiles repo"
  dotx clone "$T/remote"; assert_ok              # default dir: ~/<repo name>
  assert_file "$HOME/remote/modules/a/module.sh"
}

test_clone_rejects_non_dotfiles_repo() {
  mkdir -p "$T/plain"; echo x >"$T/plain/f"
  git -C "$T/plain" init -q -b main; git -C "$T/plain" add -A
  git -C "$T/plain" -c user.email=t@t -c user.name=t commit -qm init
  dotx clone "$T/plain" "$T/out"; assert_rc_fail
  assert_contains "$OUT" "not a dotfiles repo"
  assert_no_file "$HOME/.config/dotfiles/repo"
  mkdir -p "$T/busy"; echo x >"$T/busy/f"
  dotx clone "$T/plain" "$T/busy"; assert_rc_fail
}

test_setup_copy_apps_then_configs() {
  DOT_OMARCHY=0; export DOT_OMARCHY
  mkmod a <<<'DESC="app a"; PKGS=(x)'
  mkhome a .config/a/cfg
  mkmod b <<<'DESC="app b"; PKGS=(y)'
  mkhome b .zshrc
  # default projects · 1 copy · apps: tick a, accept, proceed · configs: tick the one left, accept, confirm
  doti $'\n1\n1\n\ny\n1\n\ny' setup; assert_ok
  assert_line "$HOME/.config/dotfiles/config-mode" copy
  assert_line "$FAKE_DB" "pacman x"
  assert_no_line "$FAKE_DB" "pacman y"           # b's app wasn't picked …
  [[ -f $HOME/.zshrc && ! -L $HOME/.zshrc ]] || _fail "… but its config was (as a copy)"
  [[ -d $HOME/.config/a && ! -L $HOME/.config/a ]] || _fail "a's config comes with the app, as a copy"
  assert_line "$SEL" a
  dotx apply --yes; assert_contains "$OUT" "Everything is already applied"
}

test_setup_steps_can_be_skipped() {
  DOT_OMARCHY=0; export DOT_OMARCHY
  mkmod a <<<'DESC=a; PKGS=(x)'
  mkhome a .zshrc
  doti $'\n2\n\n\n' setup; assert_ok             # default projects · link · no apps · no configs
  assert_line "$HOME/.config/dotfiles/config-mode" link
  assert_eq "" "$(cat "$FAKE_DB")"
  assert_no_file "$HOME/.zshrc"
  assert_contains "$OUT" "Done"
}

test_setup_sets_projects_folder() {
  DOT_OMARCHY=0; export DOT_OMARCHY
  mkmod a <<<'DESC=a'
  doti $'~/code\n2\n\n\n' setup; assert_ok
  assert_line "$HOME/.config/dotfiles/env.sh" "export DOTS_PROJECT_ROOT='$HOME/code'"
  [[ -d $HOME/code ]] || _fail "projects folder created"
}

test_projects_default_set_and_exported_to_hooks() {
  dotx projects; assert_ok
  assert_contains "$OUT" "$HOME/projects"
  assert_contains "$OUT" "not set yet"
  mkdir -p "$HOME/Projects"
  dotx projects; assert_contains "$OUT" "$HOME/Projects"   # existing folder wins over the default
  dotx projects "$T/my code"; assert_ok
  dotx projects; assert_contains "$OUT" "$T/my code"
  assert_contains "$OUT" "set in"
  ( unset DOTS_PROJECT_ROOT; . "$HOME/.config/dotfiles/env.sh"; [[ $DOTS_PROJECT_ROOT == "$T/my code" ]] ) ||
    _fail "env.sh must be sourceable sh"
  dotx projects "$T/other"; assert_ok
  assert_eq 1 "$(grep -c DOTS_PROJECT_ROOT "$HOME/.config/dotfiles/env.sh")" "replaced, not appended"
  mkmod a <<<'DESC=a
is_installed() { false; }
setup() { echo "$DOTS_PROJECT_ROOT" >"$HOME/seen"; }'
  dotx apply a --yes; assert_ok
  assert_eq "$T/other" "$(cat "$HOME/seen")" "hooks see DOTS_PROJECT_ROOT"
}

test_setup_needs_a_terminal() {
  dotx setup; assert_rc_fail
  assert_contains "$OUT" "interactive"
}

test_install_with_repo_clones_and_points_to_setup() {
  mk_remote_dotfiles "$T/remote"
  OUT=$(DOT_SOURCE=$REPO bash "$REPO/install.sh" --repo "$T/remote" --dir "$T/df" </dev/null 2>&1); RC=$?
  assert_ok
  assert_file "$HOME/.local/bin/dot"
  assert_file "$T/df/modules/a/module.sh"
  assert_line "$HOME/.config/dotfiles/repo" "$T/df"
  assert_contains "$OUT" "dot setup"
  OUT=$(DOT_SOURCE=$REPO bash "$REPO/install.sh" --projects "$T/pr" </dev/null 2>&1); RC=$?
  assert_ok
  assert_line "$HOME/.config/dotfiles/env.sh" "export DOTS_PROJECT_ROOT='$T/pr'"
  OUT=$(DOT_SOURCE=$REPO bash "$REPO/install.sh" --bogus 2>&1); RC=$?
  assert_rc_fail
}

test_menu_sets_projects_folder() {
  DOT_OMARCHY=0; export DOT_OMARCHY
  mkmod a <<<'DESC=a'
  doti '' menu
  local pick quit
  pick=$(sed -n 's/^ *\([0-9]*\)) projects .*/\1/p' <<<"$OUT")
  quit=$(sed -n 's/^ *\([0-9]*\)) quit.*/\1/p' <<<"$OUT")
  [[ -n $pick && -n $quit ]] || _fail "menu lists projects: $OUT"
  doti "$pick"$'\n~/code\n'"$quit" menu; assert_ok
  assert_line "$HOME/.config/dotfiles/env.sh" "export DOTS_PROJECT_ROOT='$HOME/code'"
}

test_menu_search_by_text() {
  DOT_OMARCHY=0; export DOT_OMARCHY
  mkmod a <<<'DESC=a'
  doti $'folder\n~/code\nquit' menu; assert_ok   # "folder" finds projects; "quit" by name
  assert_line "$HOME/.config/dotfiles/env.sh" "export DOTS_PROJECT_ROOT='$HOME/code'"
}

test_install_options_need_values() {
  OUT=$(DOT_SOURCE=$REPO bash "$REPO/install.sh" --projects 2>&1); RC=$?
  assert_rc_fail
  assert_contains "$OUT" "--projects needs a value"
}
