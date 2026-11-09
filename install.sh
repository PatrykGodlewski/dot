#!/usr/bin/env bash
# Install the `dot` tool — nothing else (no clone, no packages, no configs):
#
#   curl -fsSL https://raw.githubusercontent.com/PatrykGodlewski/dot/main/install.sh | bash
#
#   ~/.local/bin/dot          the command
#   ~/.local/share/dot/       its files (lib/ cmd/ managers/ templates/)
#
# Your dotfiles are separate: `dot init` starts a new repo, or clone yours
# (dot finds ~/dotfiles and a few other places itself, or run `dot repo <path>`).
# Running this again updates the tool (same as `dot self-update`).
#
# Also set up your dotfiles in the same go (clones them, then runs `dot setup`):
#   curl -fsSL .../install.sh | bash -s -- --repo <git-url> [--dir <path>]
#
# Env: DOT_REF=<branch|tag> (default main)
#      DOT_SOURCE=<dir|tar.gz> install from a local copy instead of GitHub
#      DOT_NO_SETUP=1          with --repo: clone only, don't start `dot setup`
#
# Everything is inside main() so a partially downloaded script never runs.

main() {
  set -euo pipefail
  local ref=${DOT_REF:-main} src=${DOT_SOURCE:-}
  local url="https://github.com/PatrykGodlewski/dot/archive/refs/heads/$ref.tar.gz"
  local bin="$HOME/.local/bin" share="${XDG_DATA_HOME:-$HOME/.local/share}/dot"
  local tmp part repo='' dir=''
  fail() { printf 'error: %s\n' "$*" >&2; exit 1; }
  while (($#)); do
    case $1 in
      --repo) repo=${2:-}; shift ;;
      --dir) dir=${2:-}; shift ;;
      *) fail "unknown option: $1 (use: --repo <git-url> [--dir <path>])" ;;
    esac
    shift
  done

  tmp=$(mktemp -d)
  # shellcheck disable=SC2064 # expand now: the trap runs after main's locals are gone
  trap "rm -rf '$tmp'" EXIT
  if [[ -z $src ]]; then
    command -v curl >/dev/null || fail "curl is needed"
    command -v tar >/dev/null || fail "tar is needed"
    curl -fsSL "$url" | tar -xz -C "$tmp" --strip-components=1 || fail "download failed: $url"
    src=$tmp
  elif [[ -f $src ]]; then
    tar -xzf "$src" -C "$tmp" --strip-components=1 || fail "cannot unpack $src"
    src=$tmp
  fi
  [[ -f $src/dot && -d $src/lib && -d $src/cmd ]] || fail "$src does not contain the dot tool"

  # replace the tool files in one step, so a failed copy leaves the old install
  rm -rf "$share.new"
  mkdir -p "$share.new" "$bin"
  for part in lib cmd managers templates; do cp -R "$src/$part" "$share.new/"; done
  rm -rf "$share"
  mv "$share.new" "$share"
  rm -f "$bin/dot" # may be a symlink from an older install
  cp "$src/dot" "$bin/dot"
  chmod 755 "$bin/dot"
  echo "✓ installed dot → ~/.local/bin/dot"

  # ~/.local/bin first in PATH for new shells (graphviz ships /usr/bin/dot)
  local rc marker='# dotfiles: ~/.local/bin first'
  for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    [[ -f $rc && ! -L $rc ]] || continue # a symlinked rc comes from the repo, which handles PATH
    grep -qF "$marker" "$rc" && continue
    printf '\n%s (so `dot` is not shadowed by e.g. graphviz)\ncase ":$PATH:" in ":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac\n' \
      "$marker" >>"$rc"
    echo "✓ ~/.local/bin added to the front of PATH in ${rc/#$HOME/\~}"
  done

  local stale=0
  [[ $(command -v dot 2>/dev/null) == "$bin/dot" ]] || stale=1

  if [[ -n $repo ]]; then # dotfiles too: the tool does the cloning and the setup
    "$bin/dot" clone "$repo" ${dir:+"$dir"} </dev/null || exit 1
    if [[ -z ${DOT_NO_SETUP:-} ]] && { : </dev/tty; } 2>/dev/null; then
      ((stale)) && echo "(afterwards open a new terminal so plain \`dot\` finds it)"
      exec "$bin/dot" setup </dev/tty
    fi
    echo "→ next: $bin/dot setup"
    return 0
  fi

  if ((stale)); then
    echo "→ open a new terminal (or run: exec \$SHELL -l), then: dot"
  else
    echo "→ next: dot"
  fi
}

main "$@"
