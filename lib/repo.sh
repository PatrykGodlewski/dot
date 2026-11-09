# shellcheck shell=bash
# Where things live. dot keeps two things apart:
#   DOT_HOME  the tool: lib/ cmd/ managers/ templates/
#             ~/.local/share/dot when installed, or the checkout dot runs from
#   DOT_ROOT  your dotfiles repo: modules/ presets/ sync.ignore
#             found by repo_find; empty when there is none (yet)

REPO_FILE="$DOT_CONFIG_DIR/repo"

is_dotfiles_repo() { [[ -n $1 && -d $1/modules ]]; }

# repo_find -> "path<TAB>how it was found" of the first match:
#   $DOTFILES_DIR, `dot repo <path>`, the checkout dot runs from, the current
#   directory, then ~/dotfiles ~/.dotfiles ~/Projects/dotfiles ~/projects/dotfiles
repo_find() {
  local saved='' d how
  [[ -f $REPO_FILE ]] && read -r saved <"$REPO_FILE"
  local -a cand=(
    "${DOTFILES_DIR:-}"$'\t'"\$DOTFILES_DIR"
    "$saved"$'\t'"set with 'dot repo'"
    "$DOT_HOME"$'\t'"the checkout dot runs from"
    "$PWD"$'\t'"current directory"
    "$HOME/dotfiles"$'\t'"default location"
    "$HOME/.dotfiles"$'\t'"default location"
    "$HOME/Projects/dotfiles"$'\t'"default location"
    "$HOME/projects/dotfiles"$'\t'"default location"
  )
  local c
  for c in "${cand[@]}"; do
    d=${c%%$'\t'*} how=${c#*$'\t'}
    is_dotfiles_repo "$d" && { printf '%s\t%s\n' "$(cd "$d" && pwd)" "$how"; return 0; }
  done
  return 1
}

repo_require() {
  [[ -n $DOT_ROOT ]] && return 0
  err "no dotfiles repo found (a directory with modules/)."
  printf '  Start a new one:    dot init            (creates ~/dotfiles)\n' >&2
  printf '  or use your clone:  dot repo /path/to/your/dotfiles\n' >&2
  exit 1
}

# repo_check -> one line per problem in the dotfiles repo (nothing = all good)
repo_check() {
  local d m f p fam
  for d in "$DOT_ROOT"/modules/*/; do
    m=$(basename "$d")
    [[ -f $d/module.sh ]] || { echo "modules/$m has no module.sh"; continue; }
    bash -n "$d/module.sh" 2>/dev/null || echo "modules/$m/module.sh has a syntax error"
  done
  # every module must load quietly, with a DESC and existing DEPENDS, on both families
  for fam in arch debian; do
    (
      OS_FAMILY=$fam OS_ID=$fam OS_TAGS=("$fam")
      for m in $(mod_all); do
        bash -n "$DOT_ROOT/modules/$m/module.sh" 2>/dev/null || continue
        out=$(mod_load "$m" 2>&1) || { echo "$m fails to load ($fam): $out"; continue; }
        [[ -z $out ]] || echo "$m prints while loading ($fam): $out"
        mod_load "$m" 2>/dev/null
        [[ -n $DESC ]] || echo "$m has no DESC"
        for d in "${DEPENDS[@]}"; do mod_exists "$d" || echo "$m depends on missing module $d"; done
      done
    )
  done | awk '!seen[$0]++'
  for f in "$DOT_ROOT"/presets/*; do
    [[ -f $f ]] || continue
    p=$(basename "$f")
    [[ $(head -n1 "$f") == '#'* ]] || echo "preset $p needs a '# description' first line"
    while read -r m; do
      m=${m%%#*} m=${m//[[:space:]]/}
      [[ -z $m ]] && continue
      if [[ $m == @* ]]; then
        [[ -f $DOT_ROOT/presets/${m#@} ]] || echo "preset $p includes missing preset ${m}"
      else
        mod_exists "$m" || echo "preset $p lists missing module $m"
      fi
    done <"$f"
  done
  for m in $(mod_all); do links_of "$m" | cut -f2 | sed "s|$| $m|"; done |
    awk '{ n[$1]++; mods[$1] = mods[$1] " " $2 } END { for (t in n) if (n[t] > 1) print "linked by more than one module:" mods[t] " → " t }' |
    sed "s|$HOME|~|"
  if ! mod_exists core; then
    echo "no core module: 'dot bootstrap' installs it (copy one from: dot init /tmp/x)"
  else
    ( mod_load core 2>/dev/null; [[ $REQUIRED == 1 ]] ) || echo "core must set REQUIRED=1"
  fi
}
