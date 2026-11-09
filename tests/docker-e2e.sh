#!/usr/bin/env bash
# End-to-end in a fresh container: install.sh -> dot init -> a small module with
# a real package and a config -> bootstrap -> apply -> verify -> remove.
# Uses the working tree (uncommitted changes included). Needs docker.
#   tests/docker-e2e.sh ubuntu:24.04
#   tests/docker-e2e.sh archlinux:latest
set -u
img=${1:-ubuntu:24.04}
repo=$(cd "$(dirname "$0")/.." && pwd)

inner='
set -u
export NO_COLOR=1 DOT_WSL=0
cd ~
DOT_SOURCE=/src bash /src/install.sh >/tmp/install.log 2>&1 || { tail -30 /tmp/install.log; exit 1; }
export PATH="$HOME/.local/bin:$PATH"
dot init ~/dotfiles >>/tmp/install.log 2>&1 || { tail -30 /tmp/install.log; exit 1; }
mkdir -p ~/dotfiles/modules/demo/home/.config/demo
printf "DESC=\"demo app\"\nPKGS=(tree)\n" >~/dotfiles/modules/demo/module.sh
echo "from repo" >~/dotfiles/modules/demo/home/.config/demo/demo.conf
echo demo >>~/dotfiles/presets/default
mkdir -p ~/.config/demo && echo existing >~/.config/demo/demo.conf
dot check >>/tmp/install.log 2>&1 || { tail -30 /tmp/install.log; exit 1; }
dot bootstrap </dev/null >>/tmp/install.log 2>&1 || { tail -30 /tmp/install.log; exit 1; }
command -v gum >/dev/null || { echo "FAIL: gum missing after bootstrap"; exit 1; }
dot apply @default --yes >/tmp/apply.log 2>&1 || { tail -40 /tmp/apply.log; exit 1; }
command -v tree >/dev/null || { echo "FAIL: package not installed"; exit 1; }
[ -L ~/.config/demo ] || { echo "FAIL: link"; exit 1; }
[ "$(cat ~/.local/state/dotfiles/backups/*/.config/demo/demo.conf)" = existing ] || { echo "FAIL: backup"; exit 1; }
dot apply --yes 2>&1 | grep -q "Everything is already applied" || { echo "FAIL: not idempotent"; exit 1; }
dot remove demo --yes >/dev/null 2>&1 && [ ! -e ~/.config/demo ] || { echo "FAIL: remove"; exit 1; }
echo E2E_OK
'

case $img in
  *arch*) prep='pacman -Sy --noconfirm --needed sudo git curl tar >/dev/null 2>&1' ;;
  *) prep='apt-get update -qq >/dev/null && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq sudo git curl ca-certificates >/dev/null 2>&1' ;;
esac

docker run --rm -v "$repo:/src:ro" "$img" bash -c "
$prep
useradd -m -s /bin/bash dev && echo 'dev ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/dev
su - dev -c '$(printf '%s' "$inner" | sed "s/'/'\\\\''/g")'
" 2>&1 | tail -20 | tee /dev/stderr | grep -q E2E_OK
