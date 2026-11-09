# shellcheck shell=bash
# Your dotfiles repo: repo (show / set), init (start one), check (validate).

# dot repo [path]: show which dotfiles repo is used, or remember one
cmd_repo() {
  local path=${1:-} found
  if [[ -z $path ]]; then
    found=$(repo_find) || { repo_require; return 1; }
    printf '%s\n' "${found%%$'\t'*}"
    info "${found#*$'\t'}"
    return 0
  fi
  path=$(realpath -m "${path/#\~/$HOME}")
  is_dotfiles_repo "$path" || die "$(pretty "$path") is not a dotfiles repo (no modules/ inside) — create one with: dot init $(pretty "$path")"
  _repo_remember "$path"
}

_repo_remember() {
  [[ $DOT_DRY == 1 ]] && { info "would remember $(pretty "$1")"; return 0; }
  mkdir -p "$DOT_CONFIG_DIR"
  printf '%s\n' "$1" >"$REPO_FILE"
  ok "dot now uses $(pretty "$1")"
}

# dot init [dir]: start a new dotfiles repo (default ~/dotfiles) and use it
cmd_init() {
  local dir=${1:-$HOME/dotfiles}
  dir=$(realpath -m "${dir/#\~/$HOME}")
  if [[ -e $dir ]] && [[ -n $(ls -A "$dir" 2>/dev/null) ]]; then
    die "$(pretty "$dir") already exists and isn't empty — use it with: dot repo $(pretty "$dir")"
  fi
  header "New dotfiles repo: $(pretty "$dir")"
  run mkdir -p "$dir" || return 1
  [[ $DOT_DRY == 1 ]] && return 0
  cp -R "$DOT_HOME/templates/repo/." "$dir/"
  ok "modules/core (base tools), presets/default, sync.ignore, README.md"
  if om_available; then
    mkdir -p "$dir/modules/omarchy"
    cp "$DOT_HOME/templates/omarchy/module.sh" "$dir/modules/omarchy/module.sh"
    { cat "$DOT_HOME/templates/omarchy/profile.head"; echo; om_state; } >"$dir/modules/omarchy/profile"
    ok "modules/omarchy/profile with this machine's defaults, theme and font"
  fi
  if has git; then git -C "$dir" init -q -b main && ok "git repository initialized"; fi
  _repo_remember "$dir"
  printf '\nNext:\n'
  printf '  dot new <app>                 add a module (packages + configs)\n'
  printf '  dot adopt ~/.config/<app>     move an existing config into a module\n'
  printf '  dot sync                      capture what you installed / changed on this machine\n'
}

# dot check: validate the dotfiles repo
cmd_check() {
  header "Checking $(pretty "$DOT_ROOT")"
  local problems
  problems=$(repo_check)
  if [[ -z $problems ]]; then
    ok "$(mod_all | wc -l) modules and $(preset_all | wc -l) presets look good"
    return 0
  fi
  while IFS= read -r l; do err "$l"; done <<<"$problems"
  return 1
}
