# mybash setup.sh (patched)

`setup.sh` installs [ChrisTitusTech/mybash](https://github.com/ChrisTitusTech/mybash)
("Beautiful Bash"). The upstream installer was **deleted** in commit
[`b537dd8` "Delete setup.sh"](https://github.com/ChrisTitusTech/mybash/commit/b537dd8),
and the upstream README now points at a third-party fork.

This script started as the genuine upstream installer recovered from the commit
just before deletion (`b537dd8^` / `95728c1`), then was **patched** to actually
work on Ubuntu 26.04 (Ptyxis terminal) and to stop clobbering your shell config.

## Usage

```bash
./setup.sh        # run as your NORMAL user — NOT with sudo
```

It clones a complete copy of mybash into `~/linuxtoolbox/mybash` and links from
there, so you can run the script from anywhere (no need to copy config files
next to it first). After it finishes, **fully quit your terminal — close all
windows — and reopen it** so the new font and shell config take effect.

## What it does

- Installs deps (bash-completion, bat, tree, multitail, fastfetch, neovim, etc.)
- Installs **JetBrainsMono Nerd Font**, Starship, fzf, zoxide
- Links `~/.config/starship.toml` and the fastfetch config to the clone
- **Merges** your bash instead of wiping it (see below)
- **Sets the terminal font** to the Nerd Font (Ptyxis + GNOME Terminal)

## How it differs from upstream

1. **Terminal font is configured** via `gsettings` for **Ptyxis** (Ubuntu 26.04's
   default terminal) and GNOME Terminal. Upstream installed a font but never
   selected it, so prompt/fastfetch icons showed as blank boxes — the whole
   reason "beautiful bash" looked broken.
2. **JetBrainsMono Nerd Font** instead of the cramped `Mono` Meslo variant, so
   icons render at a sensible width.
3. **Non-destructive bash merge.** Your existing `~/.bashrc` is backed up to
   `~/.bashrc.bak.<timestamp>`, then `~/.bashrc` becomes a small loader:

   ```sh
   [ -f ~/linuxtoolbox/mybash/.bashrc ] && . ~/linuxtoolbox/mybash/.bashrc
   [ -f ~/.bashrc_personal ] && . ~/.bashrc_personal
   ```

   Put your own settings in **`~/.bashrc_personal`** — it's sourced last, so it
   overrides mybash and survives re-runs and `git pull`s. The script seeds it
   with the ROCm vars from `../setup_rocm.sh` as a commented example.
4. **Refuses to run as root** and **removes dangling symlinks safely**, fixing
   the failure mode that left a broken `~/.bashrc` on the first attempt.

> ROCm env vars (`HSA_OVERRIDE_GFX_VERSION`, `PYTORCH_ROCM_ARCH`, …) belong in
> `~/.bashrc_personal`, not `~/.bashrc`. Don't also run step 5 of
> `../setup_rocm.sh`, or you'll get duplicate exports.

## Reference dotfiles

Snapshots of the live config `setup.sh` produces, for reference:

- `bashrc.loader.example` — the `~/.bashrc` loader (sources mybash + personal).
  Paths are absolute (`/home/joematrix/...`); adjust for another user/clone path.
- `bashrc_personal.example` — the seeded `~/.bashrc_personal`.
