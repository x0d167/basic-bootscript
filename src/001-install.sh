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

# ---------- AUR Helpers -----------------------------------------------------

announce "Checking for existing AUR helper..."

# Check if yay or paru is installed
if command -v yay &>/dev/null; then
    AUR="yay"
    log "Found existing AUR helper: yay"
elif command -v paru &>/dev/null; then
    AUR="paru"
    log "Found existing AUR helper: paru"
else
    announce "No AUR helper found. Choose one to install:"
    echo "1. Install paru"
    echo "2. Install yay"
    read -rp "Enter your choice (1/2): " choice

    case $choice in
        1)
            announce "Installing paru..."
            sudo pacman -S --noconfirm --needed rustup 2>&1 | tee -a "$LOG_FILE"
            git clone https://aur.archlinux.org/paru.git 2>&1 | tee -a "$LOG_FILE"
            cd paru
            makepkg -si --noconfirm --needed 2>&1 | tee -a "$LOG_FILE"
            paru --gendb 2>&1 | tee -a "$LOG_FILE"
            cd ..
            rm -rf paru
            AUR="paru"
            log "paru installed and initialized"
            ;;
        2)
            announce "Installing yay..."
            git clone https://aur.archlinux.org/yay.git 2>&1 | tee -a "$LOG_FILE"
            cd yay
            makepkg -si --noconfirm --needed 2>&1 | tee -a "$LOG_FILE"
            yay -Y --devel --save 2>&1 | tee -a "$LOG_FILE"
            yay -Y --gendb 2>&1 | tee -a "$LOG_FILE"
            cd ..
            rm -rf yay
            AUR="yay"
            log "yay installed and initialized"
            ;;
        *)
            echo "[!] Invalid choice. Exiting." | tee -a "$LOG_FILE"
            exit 1
            ;;
    esac
fi

announce "Selected AUR helper: $AUR"
log "AUR helper confirmed: $AUR"

# ---------- Install Packages -----------------------------------------------------
announce "Installing required packages for Hyprland"

if ! xargs -a "$PKG_LIST" $AUR -S --needed --noconfirm 2>&1 | tee -a "$LOG_FILE"; then
    echo "[!] Package installation failed." | tee -a "$LOG_FILE"
    exit 1
fi

log "All packages installed successfully."

# ---------- Enable Services -------------------------------------------------------
announce "Enabling Network and Security Services"

SYSTEM_SERVICES=(
  NetworkManager
  sshd
  firewalld
  fail2ban
  sddm
)

for svc in "${SYSTEM_SERVICES[@]}"; do
  sudo systemctl enable --now "$svc" 2>&1 | tee -a "$LOG_FILE"
done
log "Network and security services enabled"

announce "Enabling essential user services"

USER_SERVICES=(
  hyprpolkitagent
  swaync
  hypridle
)

for service in "${USER_SERVICES[@]}"; do
  systemctl --user enable --now "${service}.service" 2>&1 | tee -a "$LOG_FILE"
done

log "User services enabled"

announce "Verifying enabled system and user services"

# System services you expect to be running
SYSTEM_SERVICES=(
  NetworkManager
  sshd
  firewalld
  fail2ban
)

# User services you expect to be running
USER_SERVICES=(
  hyprpolkitagent
  swaync
  hypridle
)

log "Checking system services..."
for service in "${SYSTEM_SERVICES[@]}"; do
  if systemctl is-active --quiet "$service"; then
    log "[OK] $service is active"
  else
    log "[!] $service is NOT active"
  fi
done

log "Checking user services..."
for service in "${USER_SERVICES[@]}"; do
  if systemctl --user is-active --quiet "${service}.service"; then
    log "[OK] $service (user) is active"
  else
    log "[!] $service (user) is NOT active"
  fi
done
