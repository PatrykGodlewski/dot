# shellcheck shell=bash
# The projects folder: where your code lives (e.g. ~/Projects or ~/projects).
# One setting per machine, so scripts in your dotfiles don't hardcode it:
#
#   $DOT_ENV_FILE   ~/.config/dotfiles/env.sh, POSIX sh, never committed:
#                     export DOTS_PROJECT_ROOT='/home/you/Projects'
#
# Your shell sources it (e.g. from ~/.config/shell/env.sh), dot exports it to
# module hooks, and scripts read $DOTS_PROJECT_ROOT. Set it with `dot projects`,
# `dot setup` or `install.sh --projects <dir>`.

DOT_ENV_FILE="$DOT_CONFIG_DIR/env.sh"

# projects_saved -> the value in $DOT_ENV_FILE (empty when not set)
projects_saved() {
  [[ -f $DOT_ENV_FILE ]] || return 0
  # shellcheck disable=SC1090
  (unset DOTS_PROJECT_ROOT; . "$DOT_ENV_FILE" >/dev/null 2>&1; printf '%s' "${DOTS_PROJECT_ROOT:-}")
}

# projects_root -> the projects folder: saved setting, then $DOTS_PROJECT_ROOT,
# then an existing ~/Projects or ~/projects, then ~/projects
projects_root() {
  local d
  d=$(projects_saved)
  [[ -n $d ]] || d=${DOTS_PROJECT_ROOT:-}
  if [[ -z $d ]]; then
    if [[ -d $HOME/Projects ]]; then d=$HOME/Projects
    elif [[ -d $HOME/projects ]]; then d=$HOME/projects
    else d=$HOME/projects; fi
  fi
  printf '%s\n' "$d"
}

# projects_set <dir>: save the projects folder (creates it when missing)
projects_set() {
  local d
  d=$(realpath -m "${1/#\~/$HOME}")
  if [[ $DOT_DRY == 1 ]]; then
    info "would set DOTS_PROJECT_ROOT=$(pretty "$d") in $(pretty "$DOT_ENV_FILE")"
    return 0
  fi
  mkdir -p "$DOT_CONFIG_DIR"
  local tmp="$DOT_ENV_FILE.tmp" q=${d//\'/\'\\\'\'}
  if [[ -f $DOT_ENV_FILE ]]; then grep -v '^export DOTS_PROJECT_ROOT=' "$DOT_ENV_FILE" >"$tmp"
  else printf '# Machine-local settings written by dot (not in git). Sourced by your shell.\n' >"$tmp"; fi
  printf "export DOTS_PROJECT_ROOT='%s'\n" "$q" >>"$tmp"
  mv "$tmp" "$DOT_ENV_FILE"
  export DOTS_PROJECT_ROOT=$d
  [[ -d $d ]] || { mkdir -p "$d" && ok "created $(pretty "$d")"; }
  ok "projects folder: $(pretty "$d")  (DOTS_PROJECT_ROOT, in $(pretty "$DOT_ENV_FILE"))"
}
