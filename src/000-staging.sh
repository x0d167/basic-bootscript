#!/usr/bin/env bash

set -euo pipefail
trap 'echo "[!] Aborted by user"; exit 1' INT TERM

if [[ -z "${LOG_FILE:-}" ]]; then
    echo "[!] LOG_FILE is not set. Please run via main.sh."
    exit 1
fi

# ---------- Helpers --------------------------------------------------------

confirm() {
  read -r -p "${1:-Are you sure? [y/N]} " ans
  [[ "$ans" =~ ^([yY][eE][sS]|[yY])$ ]]
}

announce() {
  local msg="$1"
  printf "\n\e[1;34m==> %s\e[0m\n" "$msg"
  [[ -n "${LOG_FILE:-}" ]] && printf "==> %s\n" "$msg" >> "$LOG_FILE"
}

log() {
  local msg="$1"
  printf "%s\n" "$msg"
  [[ -n "${LOG_FILE:-}" ]] && printf "%s\n" "$msg" >> "$LOG_FILE"
}

# ---------- 1. Staging ------------------------------------------------------

announce "Begin initial staging for bootstrap"

# First update the arch keyring and add reflector
sudo pacman -Sy --noconfirm archlinux-keyring reflector 2>&1 | tee -a "$LOG_FILE"
log "Archlinux-keyring and reflector updated and added"

# Regenerate a ranked list that suits me
sudo reflector --country 'United States' --age 12 --sort rate \
    --protocol https --save /etc/pacman.d/mirrorlist
log "Mirrorlist regenerated"

# Perform big sync to test regeneration
sudo pacman -Syyu --noconfirm 2>&1 | tee -a "$LOG_FILE"
log "Pacman syncing complete"

# ---------- 2. Initial packages ----------------------------------------------
announce "Installing bootstrap packages: base-devel git, curl, wget, vi, vim, rustup, xdg-user-dirs"
if ! sudo pacman -S --noconfirm --needed base-devel git curl wget vi vim rustup xdg-user-dirs 2>&1 | tee -a "$LOG_FILE"; then
    echo "[!] Package installation failed." | tee -a "$LOG_FILE"
    exit 1
fi

# ---------- 3. Set up user dirs ----------------------------------------------
announce "Configuring XDG user directories"

# 1. Make the various default directories if not already created

for dir in "$HOME"/{dev,sync,.cache} "$HOME"/.local/{bin,share,state}; do
    [[ ! -d "$dir" ]] && mkdir -p "$dir" && log "Created directory: $dir"
done

# 2. Write your preferred layout
cat > "$HOME/.config/user-dirs.dirs" <<EOF
XDG_DESKTOP_DIR="\$HOME/archive/desktop"
XDG_DOWNLOAD_DIR="\$HOME/tmp/downloads"
XDG_TEMPLATES_DIR="\$HOME/archive/templates/"
XDG_PUBLICSHARE_DIR="\$HOME/tmp/public/"
XDG_DOCUMENTS_DIR="\$HOME/docs"
XDG_MUSIC_DIR="\$HOME/media/music"
XDG_PICTURES_DIR="\$HOME/media/pictures"
XDG_VIDEOS_DIR="\$HOME/media/videos"
EOF

# 3. Generate any missing dirs
xdg-user-dirs-update 2>&1 | tee -a "$LOG_FILE"

# 4. Log it
log "XDG user dirs configured and created."

# ---------- 4. Minimal Bootstrap Bashrc --------------------------------------

# 1. Write a clean, dedicated bootstrap config
cat <<'EOF' > "$HOME/.bashrc.bootstrap"
# XDG Base Dirs
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"

# XDG User Dirs
export XDG_DESKTOP_DIR="$HOME/archive/desktop"
export XDG_DOWNLOAD_DIR="$HOME/tmp/downloads"
export XDG_DOCUMENTS_DIR="$HOME/docs"
export XDG_MUSIC_DIR="$HOME/media/music"
export XDG_PICTURES_DIR="$HOME/media/pictures"
export XDG_VIDEOS_DIR="$HOME/media/videos"

# Tool-specific env vars
export GNUPGHOME="$XDG_DATA_HOME/gnupg"
export CARGO_HOME="$XDG_DATA_HOME/cargo"
export GOPATH="$XDG_DATA_HOME/go"
export GOBIN="$GOPATH/bin"
export GOMODCACHE="$XDG_CACHE_HOME/go/mod"
export NPM_CONFIG_USERCONFIG="$XDG_CONFIG_HOME/npm/npmrc"
export FFMPEG_DATADIR="$XDG_CONFIG_HOME/ffmpeg"
export RUFF_CACHE_DIR=$XDG_CACHE_HOME/ruff
export RUSTUP_HOME="$XDG_DATA_HOME"/rustup
export MANPAGER='nvim +Man!'

# Minimal PATH
export PATH="$HOME/.local/bin:$PATH"
EOF

# 2. Ensure .bashrc sources it (only once)
if ! grep -Fxq "source \$HOME/.bashrc.bootstrap" "$HOME/.bashrc"; then
    echo 'source $HOME/.bashrc.bootstrap' >> "$HOME/.bashrc"
    log "Appended bootstrap source to .bashrc"
fi

# 3. Source it now so later script steps use the new environment
source "$HOME/.bashrc.bootstrap"
log "Loaded bootstrap environment variables"

log "--- Staging complete ---"
