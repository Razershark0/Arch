#!/bin/bash
# Run this from inside the cloned dotfiles repo, on a fresh Arch base install
# that already has: network, a user account in the wheel group, sudo installed.
set -e

echo "==> Installing official packages..."
sudo pacman -S --needed --noconfirm - < packages.txt

echo "==> Bootstrapping yay (AUR helper)..."
if ! command -v yay &> /dev/null; then
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    (cd /tmp/yay && makepkg -si --noconfirm)
fi

echo "==> Installing AUR packages..."
yay -S --needed --noconfirm - < aur-packages.txt

echo "==> Installing unimatrix (matrix rain effect, via pipx)..."
pipx ensurepath
pipx install "git+https://github.com/will8211/unimatrix.git" || true

echo "==> Symlinking config files..."
mkdir -p "$HOME/.config" "$HOME/.local/bin"
for dir in .config/*/; do
    name=$(basename "$dir")
    ln -sfn "$PWD/.config/$name" "$HOME/.config/$name"
done
for f in .local/bin/*; do
    ln -sf "$PWD/$f" "$HOME/.local/bin/$(basename "$f")"
done
chmod +x "$HOME"/.local/bin/* 2>/dev/null || true

echo "==> Enabling services..."
sudo systemctl enable --now NetworkManager
sudo systemctl enable --now ufw
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw --force enable
sudo systemctl enable --now tlp

echo "==> Setting lid-close to suspend..."
if ! grep -q "^HandleLidSwitch=suspend" /etc/systemd/logind.conf 2>/dev/null; then
    echo "HandleLidSwitch=suspend" | sudo tee -a /etc/systemd/logind.conf
    sudo systemctl restart systemd-logind
fi

echo "==> Setting Hyprland to launch on tty1 login (no display manager, no autologin)..."
if ! grep -q "exec Hyprland" "$HOME/.bash_profile" 2>/dev/null; then
    echo 'if [ -z "$WAYLAND_DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then exec Hyprland; fi' >> "$HOME/.bash_profile"
fi

echo "==> Done. Reboot, log in at the console prompt, Hyprland will start automatically."
