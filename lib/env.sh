# shellcheck shell=bash
# Machine settings for your shell, kept by dot (never committed):
#
#   $DOT_ENV_FILE   ~/.config/dotfiles/env.sh, POSIX sh, one line per setting:
#                     export KEY='value'
#
# Your shell sources it (e.g. from ~/.config/shell/env.sh), so scripts in your
# dotfiles read plain environment variables. Add a setting with env_set; see
# lib/projects.sh for an example (DOTS_PROJECT_ROOT).

DOT_ENV_FILE="$DOT_CONFIG_DIR/env.sh"

_env_valid_key() { [[ $1 =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || die "invalid setting name: $1"; }

# env_get KEY -> the saved value (empty when not set)
env_get() {
  _env_valid_key "$1"
  [[ -f $DOT_ENV_FILE ]] || return 0
  # a clean subshell, so the caller's environment can't leak into the answer
  # shellcheck disable=SC1090
  (unset "$1"; . "$DOT_ENV_FILE" >/dev/null 2>&1; printf '%s' "${!1:-}")
}

# env_set KEY VALUE: save (or replace) a setting and export it to this process
env_set() {
  _env_valid_key "$1"
  local key=$1 val=$2 tmp="$DOT_ENV_FILE.tmp"
  mkdir -p "$DOT_CONFIG_DIR"
  if [[ -f $DOT_ENV_FILE ]]; then
    grep -v "^export $key=" "$DOT_ENV_FILE" >"$tmp"
  else
    printf '# Machine settings written by dot (not in git). Sourced by your shell.\n' >"$tmp"
  fi
  # single-quoted for sh: ' becomes '\''
  printf "export %s='%s'\n" "$key" "${val//\'/\'\\\'\'}" >>"$tmp"
  mv "$tmp" "$DOT_ENV_FILE"
  export "$key=$val"
}
