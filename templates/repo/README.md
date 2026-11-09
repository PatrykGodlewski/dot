# dotfiles

My configs and apps, managed by [dot](https://github.com/PatrykGodlewski/dot).

```bash
curl -fsSL https://raw.githubusercontent.com/PatrykGodlewski/dot/main/install.sh | bash
git clone <this repo> ~/dotfiles
dot configs      # copy / link the configs you want
dot              # everything else
```

- `modules/<name>/module.sh` — what to install; `modules/<name>/home/` — files that mirror `$HOME`
- `presets/` — lists of modules (`@other` includes another preset)
- `modules/omarchy/profile` — Omarchy commands (only on Omarchy)
- `sync.ignore` — what `dot sync` should never propose

New module: `dot new <name>`, or capture an existing config: `dot adopt ~/.config/<app>`.
Check the repo: `dot check`.
