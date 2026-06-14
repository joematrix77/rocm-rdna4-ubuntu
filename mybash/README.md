# mybash setup.sh (archived)

`setup.sh` is the official installer for [ChrisTitusTech/mybash](https://github.com/ChrisTitusTech/mybash)
("Beautiful Bash"). It was **deleted** from the upstream repo in commit
[`b537dd8` "Delete setup.sh"](https://github.com/ChrisTitusTech/mybash/commit/b537dd8),
and the upstream README now points at a third-party fork instead.

This copy was recovered from the commit immediately **before** the deletion
(`b537dd8^`, i.e. `95728c1`) so it is the genuine upstream script, not a fork.

## Usage

```bash
git clone https://github.com/ChrisTitusTech/mybash ~/build/mybash
cp setup.sh ~/build/mybash/setup.sh   # restore the deleted installer
cd ~/build/mybash
./setup.sh                            # needs sudo; interactive
```

## What it does

- Installs deps (bash-completion, bat, tree, multitail, fastfetch, neovim, etc.)
- Installs MesloLGS Nerd Font, Starship, fzf, zoxide
- Backs up `~/.bashrc` to `~/.bashrc.bak`, then symlinks `~/.bashrc`,
  `~/.config/starship.toml`, and the fastfetch config to the repo files

> ⚠️ Because it replaces `~/.bashrc` with a symlink, keep custom exports
> (e.g. the ROCm vars from `../setup_rocm.sh`) in `~/.bashrc_personal` and
> source that file, rather than appending to `~/.bashrc` directly.
