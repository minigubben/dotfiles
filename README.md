# Dotfiles

Personal Linux dotfiles for a Hyprland-based Wayland desktop. The repo uses GNU Stow packages for user configuration and includes a small package installer for Arch, Fedora, and Ubuntu-family systems.

## Contents

- `bash/` - Bash startup files, PATH setup, `fnm`, `pnpm`, Starship, ble.sh, and small shell helpers.
- `bin/` - User scripts installed into `~/.local/bin`, including `sgpt` and `installappimage`.
- `hypr/` - Hyprland Lua config, custom layouts, keybindings, autostart, portal setup, and Brave workspace helper.
- `swayidle/` - User systemd service for idle locking and DPMS.
- `swaylock/` - Screenshot blur lock command for `swaylock-effects`.
- `waybar/` - Waybar config, styling, and audio device picker script.
- `software/` - Common and distro-specific package manifests plus custom installers.
- `stow-all.sh` - Stows all top-level config packages into `$HOME`.
- `install-software.sh` - Installs the packages listed in `software/`.

## Supported Systems

`install-software.sh` detects and supports these distro families:

- Arch-like: `arch`, EndeavourOS, Manjaro, Garuda
- Fedora/RHEL-like: Fedora, RHEL, CentOS, Rocky, AlmaLinux
- Ubuntu/Debian-like: Ubuntu, Pop!_OS, Linux Mint, elementary, Zorin

The desktop configuration expects a Wayland/Hyprland setup with tools such as Waybar, PipeWire/WirePlumber, NetworkManager, swayidle, swaylock, grim, slurp, wl-clipboard, brightnessctl, and a Nerd Font.

## Install

Clone the repo, inspect the resolved package list, then install packages:

```sh
git clone <repo-url> ~/dotfiles
cd ~/dotfiles

./install-software.sh --list
./install-software.sh --dry-run
./install-software.sh
```

Useful installer options:

```sh
./install-software.sh --distro arch
./install-software.sh --distro fedora
./install-software.sh --distro ubuntu
./install-software.sh --no-aur
./install-software.sh --no-third-party
./install-software.sh --no-refresh
```

On Arch, AUR packages are installed with `yay` or `paru` when available. Brave is handled by `software/custom/brave.sh`; use `--no-third-party` to skip adding Brave repositories or AUR packages.

Manual follow-up items are printed at the end of the installer. The common package list currently includes `BlexMono Nerd Font` as a manual item.

## Apply Dotfiles

Preview Stow changes first:

```sh
./stow-all.sh --dry-run
```

Apply the dotfiles into your home directory:

```sh
./stow-all.sh
```

The script stows every top-level directory except `.git` and `software`. To stow into a different target:

```sh
./stow-all.sh --target /path/to/target
```

If Stow reports conflicts, move or back up the existing files first, then rerun the command.

## Optional Environment

`bin/.local/bin/sgpt` can read API settings from `.env` in this repo. Start from the sample:

```sh
cp .env.sample .env
```

Set `OPENCODE_ZEN_API_KEY` or `SGPT_API_KEY`. Optional overrides:

```sh
SGPT_MODEL=gpt-5.4-mini
SGPT_API_URL=https://opencode.ai/zen/v1/responses
```

## Hyprland Notes

The Hyprland config is Lua-based and includes:

- `SUPER+Q` terminal (`kitty`)
- `SUPER+E` file manager (`dolphin`)
- `SUPER+R` launcher (`hyprlauncher`)
- `SUPER+L` lock screen
- `Print` area screenshot to `~/Pictures/Screenshots` and clipboard
- `SUPER+T` cycle layouts: dwindle, master, scrolling, `lua:threecol`, `lua:threecolwide`
- `SUPER+1..0` switch workspaces
- `SUPER+SHIFT+1..0` move active window to workspace
- multimedia keys for volume, mic mute, brightness, and player control

Hyprland autostarts Waybar, Brave on workspace 1, a Brave workspace watcher, `nm-applet`, and restarts the relevant xdg-desktop-portal services.

## User Services

After stowing `swayidle/`, enable the idle service if desired:

```sh
systemctl --user enable --now swayidle.service
```

The service locks after 5 minutes, turns displays off after 10 minutes, and locks before sleep.

## Package Manifests

Package files are plain text with one item per line. Blank lines and comments are ignored.

Supported prefixes:

- `repo:<pkg>` - install from the distro package manager
- `aur:<pkg>` - install with `yay` or `paru` on Arch
- `manual:<name>` - print a manual follow-up item
- `<name>:<pkg>` - install through `software/custom/<name>.sh`

Unprefixed package names are treated as repository packages.
