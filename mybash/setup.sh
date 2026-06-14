#!/bin/sh -e

# ChrisTitusTech mybash installer — patched for Ubuntu 26.04 / Ptyxis.
#
# Differences from the upstream (deleted) setup.sh:
#   1. Configures the TERMINAL to actually use a Nerd Font (Ptyxis + GNOME
#      Terminal) via gsettings. Upstream installed a font but never selected
#      it, so prompt/fastfetch icons rendered as blank boxes.
#   2. Installs JetBrainsMono Nerd Font (renders icons cleanly, unlike the
#      cramped "Mono" Meslo variant).
#   3. Non-destructive bash merge: backs up your existing ~/.bashrc and turns
#      ~/.bashrc into a loader that sources mybash THEN ~/.bashrc_personal,
#      so your own settings (e.g. ROCm exports) survive.
#   4. Always links config from the complete clone and removes dangling
#      symlinks safely (the bug that left a broken ~/.bashrc on first try).
#
# Run as your NORMAL user (NOT with sudo) — it calls sudo only where needed,
# and the terminal font step must run in your own desktop session.

# Define color codes using tput for better compatibility
RC=$(tput sgr0)
RED=$(tput setaf 1)
YELLOW=$(tput setaf 3)
GREEN=$(tput setaf 2)

LINUXTOOLBOXDIR="$HOME/linuxtoolbox"
MYBASHDIR="$LINUXTOOLBOXDIR/mybash"   # the complete clone we link from
NERD_FONT="JetBrainsMono Nerd Font"   # family name fontconfig reports
NERD_FONT_SIZE="12"
PACKAGER=""
SUDO_CMD=""
SUGROUP=""

# Helper functions
print_colored() {
    printf "${1}%s${RC}\n" "$2"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Remove an existing file OR (even dangling) symlink, then create a fresh link.
safe_link() {
    src="$1"
    dst="$2"
    if [ ! -e "$src" ]; then
        print_colored "$RED" "Source missing, cannot link: $src"
        return 1
    fi
    if [ -e "$dst" ] || [ -L "$dst" ]; then
        rm -f "$dst"
    fi
    ln -svf "$src" "$dst"
}

# Refuse to run as root — gsettings + the bashrc merge must target the real user.
check_not_root() {
    if [ "$(id -u)" -eq 0 ]; then
        print_colored "$RED" "Do NOT run this with sudo. Run it as your normal user."
        exit 1
    fi
}

setup_directories() {
    if [ ! -d "$LINUXTOOLBOXDIR" ]; then
        print_colored "$YELLOW" "Creating linuxtoolbox directory: $LINUXTOOLBOXDIR"
        mkdir -p "$LINUXTOOLBOXDIR"
    fi

    if [ -d "$MYBASHDIR" ]; then
        print_colored "$YELLOW" "Updating existing mybash clone in $MYBASHDIR"
        git -C "$MYBASHDIR" pull --ff-only || print_colored "$YELLOW" "Could not fast-forward; using existing copy"
    else
        print_colored "$YELLOW" "Cloning mybash into: $MYBASHDIR"
        if ! git clone https://github.com/ChrisTitusTech/mybash "$MYBASHDIR"; then
            print_colored "$RED" "Failed to clone mybash repository"
            exit 1
        fi
    fi
    print_colored "$GREEN" "mybash clone ready: $MYBASHDIR"
}

check_environment() {
    REQUIREMENTS='curl groups sudo unzip'
    for req in $REQUIREMENTS; do
        if ! command_exists "$req"; then
            print_colored "$RED" "To run me, you need: $REQUIREMENTS"
            exit 1
        fi
    done

    PACKAGEMANAGER='nala apt dnf yum pacman zypper emerge xbps-install nix-env'
    for pgm in $PACKAGEMANAGER; do
        if command_exists "$pgm"; then
            PACKAGER="$pgm"
            printf "Using %s\n" "$pgm"
            break
        fi
    done
    if [ -z "$PACKAGER" ]; then
        print_colored "$RED" "Can't find a supported package manager"
        exit 1
    fi

    if command_exists sudo; then
        SUDO_CMD="sudo"
    elif command_exists doas && [ -f "/etc/doas.conf" ]; then
        SUDO_CMD="doas"
    else
        SUDO_CMD="su -c"
    fi
    printf "Using %s as privilege escalation software\n" "$SUDO_CMD"

    SUPERUSERGROUP='wheel sudo root'
    for sug in $SUPERUSERGROUP; do
        if groups | grep -q "$sug"; then
            SUGROUP="$sug"
            break
        fi
    done
    if ! groups | grep -q "$SUGROUP"; then
        print_colored "$RED" "You need to be a member of the sudo group to run me!"
        exit 1
    fi
}

install_dependencies() {
    DEPENDENCIES='bash bash-completion tar bat tree multitail fastfetch wget unzip fontconfig trash-cli'
    if ! command_exists nvim; then
        DEPENDENCIES="${DEPENDENCIES} neovim"
    fi

    print_colored "$YELLOW" "Installing dependencies..."
    case "$PACKAGER" in
        pacman)
            ${SUDO_CMD} ${PACKAGER} --noconfirm -S ${DEPENDENCIES}
            ;;
        nala | apt)
            ${SUDO_CMD} ${PACKAGER} install -y ${DEPENDENCIES}
            ;;
        dnf)
            ${SUDO_CMD} ${PACKAGER} install -y ${DEPENDENCIES}
            ;;
        zypper)
            ${SUDO_CMD} ${PACKAGER} install -n ${DEPENDENCIES}
            ;;
        *)
            ${SUDO_CMD} ${PACKAGER} install -yq ${DEPENDENCIES}
            ;;
    esac
}

install_nerd_font() {
    if fc-list | grep -qi "$NERD_FONT"; then
        printf "%s already installed\n" "$NERD_FONT"
        return
    fi
    print_colored "$YELLOW" "Installing $NERD_FONT..."
    FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
    FONT_DIR="$HOME/.local/share/fonts/$NERD_FONT"
    TEMP_DIR=$(mktemp -d)
    if curl -fsSL "$FONT_URL" -o "$TEMP_DIR/font.zip"; then
        mkdir -p "$FONT_DIR"
        unzip -oq "$TEMP_DIR/font.zip" -d "$TEMP_DIR/unzipped"
        # Prefer the standard (non-Mono, non-Propo) variant for well-sized icons
        cp "$TEMP_DIR"/unzipped/JetBrainsMonoNerdFont-*.ttf "$FONT_DIR"/ 2>/dev/null \
            || cp "$TEMP_DIR"/unzipped/*.ttf "$FONT_DIR"/
        fc-cache -f >/dev/null 2>&1
        print_colored "$GREEN" "$NERD_FONT installed"
    else
        print_colored "$RED" "Failed to download $NERD_FONT"
    fi
    rm -rf "$TEMP_DIR"
}

install_starship_and_fzf() {
    if ! command_exists starship; then
        if ! curl -sS https://starship.rs/install.sh | sh; then
            print_colored "$RED" "Something went wrong during starship install!"
            exit 1
        fi
    else
        printf "Starship already installed\n"
    fi

    if ! command_exists fzf; then
        if [ -d "$HOME/.fzf" ]; then
            print_colored "$YELLOW" "FZF directory already exists. Skipping."
        else
            git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
            ~/.fzf/install --all
        fi
    else
        printf "Fzf already installed\n"
    fi
}

install_zoxide() {
    if ! command_exists zoxide; then
        if ! curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh; then
            print_colored "$RED" "Something went wrong during zoxide install!"
            exit 1
        fi
    else
        printf "Zoxide already installed\n"
    fi
}

# Link starship/fastfetch config and merge ~/.bashrc non-destructively.
link_config() {
    mkdir -p "$HOME/.config" "$HOME/.config/fastfetch"
    safe_link "$MYBASHDIR/starship.toml" "$HOME/.config/starship.toml"
    safe_link "$MYBASHDIR/config.jsonc" "$HOME/.config/fastfetch/config.jsonc"

    BRC="$HOME/.bashrc"
    PERSONAL="$HOME/.bashrc_personal"
    MARKER="# >>> mybash loader (managed by setup.sh) >>>"

    # Back up an existing real ~/.bashrc the first time only.
    if [ -e "$BRC" ] && ! grep -qF "$MARKER" "$BRC" 2>/dev/null; then
        BACKUP="$BRC.bak.$(date +%Y%m%d%H%M%S)"
        cp -aL "$BRC" "$BACKUP" 2>/dev/null || cp -a "$BRC" "$BACKUP"
        print_colored "$YELLOW" "Backed up existing ~/.bashrc to $BACKUP"
    fi

    # Seed a personal file for the user's own settings (sourced last == wins).
    if [ ! -f "$PERSONAL" ]; then
        cat > "$PERSONAL" <<'PEOF'
# ~/.bashrc_personal — your custom shell settings live here.
# Sourced AFTER the mybash config, so anything here overrides it.
#
# Example (ROCm on AMD RDNA4 / gfx1201):
#   export ROCM_PATH=/usr
#   export HSA_OVERRIDE_GFX_VERSION=12.0.0
#   export PYTORCH_ROCM_ARCH=gfx1201
#   export PATH="$PATH:$HOME/.local/bin"
PEOF
        print_colored "$GREEN" "Created ~/.bashrc_personal for your custom settings"
    fi

    # ~/.bashrc becomes a small loader: mybash first, then your overrides.
    cat > "$BRC" <<EOF
$MARKER
# Managed by mybash setup.sh — keep custom config in ~/.bashrc_personal instead.
[ -f "$MYBASHDIR/.bashrc" ] && . "$MYBASHDIR/.bashrc"
[ -f "$HOME/.bashrc_personal" ] && . "$HOME/.bashrc_personal"
# <<< mybash loader <<<
EOF
    print_colored "$GREEN" "~/.bashrc now loads mybash + ~/.bashrc_personal"

    # Ensure login shells pick it up too.
    if [ ! -f "$HOME/.bash_profile" ]; then
        echo '[ -f ~/.bashrc ] && . ~/.bashrc' > "$HOME/.bash_profile"
    fi
}

# THE fix that was missing upstream: make the terminal actually use the font.
configure_terminal_font() {
    if ! command_exists gsettings; then
        print_colored "$YELLOW" "gsettings not found; set your terminal font to '$NERD_FONT' manually."
        return
    fi
    SCHEMAS=$(gsettings list-schemas 2>/dev/null || true)
    DONE=0

    # Ptyxis (Ubuntu 26.04+ default terminal)
    if echo "$SCHEMAS" | grep -q '^org.gnome.Ptyxis$'; then
        gsettings set org.gnome.Ptyxis use-system-font false
        gsettings set org.gnome.Ptyxis font-name "$NERD_FONT $NERD_FONT_SIZE"
        print_colored "$GREEN" "Set Ptyxis font to '$NERD_FONT $NERD_FONT_SIZE'"
        DONE=1
    fi

    # GNOME Terminal (older Ubuntu / GNOME)
    if echo "$SCHEMAS" | grep -q '^org.gnome.Terminal.ProfilesList$'; then
        PROFILE=$(gsettings get org.gnome.Terminal.ProfilesList default 2>/dev/null | tr -d "'")
        if [ -n "$PROFILE" ]; then
            BASE="org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$PROFILE/"
            gsettings set "$BASE" use-system-font false
            gsettings set "$BASE" font "$NERD_FONT $NERD_FONT_SIZE"
            print_colored "$GREEN" "Set GNOME Terminal font to '$NERD_FONT $NERD_FONT_SIZE'"
            DONE=1
        fi
    fi

    if [ "$DONE" -eq 0 ]; then
        print_colored "$YELLOW" "No supported terminal schema found; set the font to '$NERD_FONT' manually."
    fi
}

# Main execution
check_not_root
setup_directories
check_environment
install_dependencies
install_nerd_font
install_starship_and_fzf
install_zoxide
link_config
configure_terminal_font

print_colored "$GREEN" "Done! FULLY QUIT your terminal (close all windows) and reopen it"
print_colored "$GREEN" "so the new font and shell config take effect."
