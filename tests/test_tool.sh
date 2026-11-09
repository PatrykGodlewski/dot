# shellcheck shell=bash
# Integrity of the tool itself (no dotfiles involved).

test_tool_all_scripts_parse() {
  local f bad=''
  for f in "$REPO"/dot "$REPO"/install.sh "$REPO"/lib/*.sh "$REPO"/cmd/*.sh "$REPO"/managers/*.sh \
    "$REPO"/templates/module.sh "$REPO"/templates/omarchy/module.sh "$REPO"/templates/repo/modules/*/module.sh; do
    bash -n "$f" 2>/dev/null || bad+=" $f"
  done
  assert_eq "" "$bad" "syntax errors in:"
}

test_tool_managers_implement_interface() {
  local f fn
  for f in "$REPO"/managers/*.sh; do
    (
      source "$f"
      [[ -n ${M_VAR:-} ]] || _fail "$(basename "$f"): M_VAR missing"
      [[ -n ${M_DESC:-} ]] || _fail "$(basename "$f"): M_DESC missing"
      for fn in m_available m_ensure m_has m_install m_remove; do
        [[ $(type -t $fn) == function ]] || _fail "$(basename "$f"): $fn missing"
      done
    ) || exit 1
  done
}

test_tool_install_sh_wrapped_in_main() {
  # protects against running a half-downloaded script via curl | bash
  assert_eq 'main "$@"' "$(grep -v '^\s*$' "$REPO/install.sh" | tail -n1)"
}

test_tool_template_has_placeholders() {
  local t p; t=$(cat "$REPO/templates/module.sh")
  for p in __NAME__ __DESC__ __PKGS__ __PACMAN__ __APT__; do assert_contains "$t" "$p"; done
}

test_tool_repo_template_core_is_required() {
  ( source "$REPO/templates/repo/modules/core/module.sh"; [[ ${REQUIRED:-0} == 1 ]] ) || _fail "core must be REQUIRED=1"
}

test_tool_contains_no_personal_dotfiles() {
  local d
  for d in modules presets; do assert_no_file "$REPO/$d"; done
}
