# shellcheck shell=bash
# The projects folder: where your code lives (e.g. ~/projects), saved per
# machine as DOTS_PROJECT_ROOT (see lib/env.sh) so scripts in your dotfiles
# don't hardcode it. Set it with `dot projects`, `dot setup`, the menu or
# `install.sh --projects <dir>`.

PROJECTS_KEY=DOTS_PROJECT_ROOT

projects_saved() { env_get "$PROJECTS_KEY"; }

# projects_root -> the saved setting, then $DOTS_PROJECT_ROOT from the
# environment, then the first existing default folder, then ~/projects
projects_root() {
  local d
  d=$(projects_saved)
  [[ -n $d ]] || d=${!PROJECTS_KEY:-}
  if [[ -z $d ]]; then
    local c
    for c in "$HOME/projects" "$HOME/Projects"; do [[ -d $c ]] && { d=$c; break; }; done
  fi
  printf '%s\n' "${d:-$HOME/projects}"
}

# projects_set <dir>: create the folder when missing, then save it
projects_set() {
  local d
  d=$(realpath -m "${1/#\~/$HOME}")
  if [[ $DOT_DRY == 1 ]]; then
    info "would set $PROJECTS_KEY=$(pretty "$d") in $(pretty "$DOT_ENV_FILE")"
    return 0
  fi
  if [[ ! -d $d ]]; then
    mkdir -p "$d" || { err "cannot create $(pretty "$d")"; return 1; }
    ok "created $(pretty "$d")"
  fi
  env_set "$PROJECTS_KEY" "$d"
  ok "projects folder: $(pretty "$d")  ($PROJECTS_KEY, in $(pretty "$DOT_ENV_FILE"))"
}

# projects_ask: prompt with the current folder filled in; empty input keeps it.
# Returns 1 when the prompt was cancelled.
projects_ask() {
  local p
  p=$(ui_input "Projects folder" "$(pretty "$(projects_root)")") || return 1
  [[ -z $p ]] || projects_set "$p"
}
