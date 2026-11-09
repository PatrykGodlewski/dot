# shellcheck shell=bash
# dot setup — guided first run on a machine:
#   1. copy or link configs here (saved for this machine)
#   2. apps to install (each module brings its configs)
#   3. more configs, without their apps
#   4. Omarchy profile (on Omarchy)
# Every step can be skipped by choosing nothing; each asks before changing anything.

cmd_setup() {
  ui_interactive || die "dot setup is interactive — without a terminal use: dot configs --copy|--link … / dot apply …"
  header "dot setup — $(pretty "$DOT_ROOT")"

  local mode
  mode=$(ui_choose_one "1/4  How should configs be put on this machine?" \
    "copy"$'\t'"real copies — the repo can change without affecting this machine" \
    "link"$'\t'"symlinks into the repo — edits land in the repo, git pull updates them") ||
    { info "Cancelled."; return 1; }
  config_mode_set "$mode"
  local -A done_word=([copy]=copied [link]=linked)
  ok "configs will be ${done_word[$mode]} on this machine"

  _setup_step "2/4  Apps — each comes with its configs (nothing chosen = skip)" \
    pick_and_apply "$(sel_get | tr '\n' ' ')"
  _setup_step "3/4  More configs, without their apps (nothing chosen = skip)" \
    cmd_configs "--$mode"
  if om_available && [[ -f $PROFILE_FILE ]]; then
    _setup_step "4/4  Omarchy profile (nothing chosen = skip)" omarchy_apply
  fi

  header "Done"
  info "later: dot (menu) · dot sync (record changes) · dot update (pull + refresh)"
}

# _setup_step "Title" command...: run one step; a failing step doesn't end setup
_setup_step() {
  local title=$1; shift
  header "$title"
  ( "$@" ) || true
}
