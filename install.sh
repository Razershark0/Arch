#!/bin/bash
# Rebuilds this exact desktop -- Hyprland + Serpantinum (the custom Quickshell
# shell in serpantinum/) -- on a fresh Arch install.
#
# Run this from inside the cloned repo, on a fresh Arch base install that
# already has: network, a user account in the wheel group, sudo installed.
set -e

echo "==> Installing official packages..."
sudo pacman -S --needed --noconfirm - < packages.txt

echo "==> Bootstrapping yay (AUR helper)..."
if ! command -v yay &> /dev/null; then
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    (cd /tmp/yay && makepkg -si --noconfirm)
fi

echo "==> Installing AUR packages..."
# yay opens /dev/tty directly even with --noconfirm, which fails under a
# non-interactive/piped invocation (e.g. a CI runner or an agent's shell) --
# script(1) allocates a real pty so it has one to open.
script -qec "yay -S --needed --noconfirm - < aur-packages.txt" /dev/null

echo "==> Deploying Serpantinum (the custom Quickshell desktop shell)..."
mkdir -p "$HOME/.local/share"
rm -rf "$HOME/.local/share/serpantinum"
cp -r serpantinum "$HOME/.local/share/serpantinum"
chmod +x "$HOME/.local/share/serpantinum/bin/"* \
         "$HOME/.local/share/serpantinum/src/scripts/"*.sh \
         "$HOME/.local/share/serpantinum/src/scripts/system/"*.sh 2>/dev/null || true
sudo ln -sf "$HOME/.local/share/serpantinum/bin/serpantinum" /usr/local/bin/serpantinum
sudo ln -sf "$HOME/.local/share/serpantinum/bin/serpantinumd" /usr/local/bin/serpantinumd

echo "==> Deploying Hyprland + Alacritty config..."
mkdir -p "$HOME/.config"
rm -rf "$HOME/.config/hypr" "$HOME/.config/alacritty"
cp -r config/hypr "$HOME/.config/hypr"
cp -r config/alacritty "$HOME/.config/alacritty"
sed -i "s|/home/[^/]*/|$HOME/|g" "$HOME/.config/hypr/hyprpaper.conf"

echo "==> Deploying the reference wallpaper..."
mkdir -p "$HOME/Pictures/wallpapers"
cp config/wallpaper/mimikyu.jpg "$HOME/Pictures/wallpapers/mimikyu.jpg"

echo "==> Deploying Serpantinum's reference settings (theme, bar layout, idle"
echo "    schedule: lock w/ matrix background at 5 min, suspend at 10 min)..."
mkdir -p "$HOME/.config/serpantinum"
sed "s|/home/[^/]*/|$HOME/|g" config/serpantinum/settings.json > "$HOME/.config/serpantinum/settings.json"

echo "==> Enabling nerd-font icon glyph fallback (keeps ttf-jetbrains-mono small"
echo "    instead of needing the full nerd-font variant for icon glyphs)..."
sudo ln -sf /usr/share/fontconfig/conf.avail/10-nerd-font-symbols.conf /etc/fonts/conf.d/
fc-cache -f

echo "==> Enabling services..."
sudo systemctl enable --now NetworkManager
sudo systemctl enable --now ufw
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw --force enable
sudo systemctl enable --now tlp

echo "==> Capping battery charge at 80% (start recharging at 75%) to slow"
echo "    wear -- this ThinkPad's battery was already down to 72% of its"
echo "    design capacity at only 32 cycles from always charging to 100%..."
sudo sed -i -E "s/^#?START_CHARGE_THRESH_BAT1=.*/START_CHARGE_THRESH_BAT1=75/" /etc/tlp.conf
sudo sed -i -E "s/^#?STOP_CHARGE_THRESH_BAT1=.*/STOP_CHARGE_THRESH_BAT1=80/" /etc/tlp.conf
sudo tlp start >/dev/null

systemctl --user enable --now hyprpolkitagent

echo "==> Setting lid-close to suspend..."
if ! grep -q "^HandleLidSwitch=suspend" /etc/systemd/logind.conf 2>/dev/null; then
    echo "HandleLidSwitch=suspend" | sudo tee -a /etc/systemd/logind.conf
    sudo systemctl restart systemd-logind
fi

echo "==> Setting timezone + enabling NTP sync..."
sudo timedatectl set-timezone America/New_York
sudo timedatectl set-ntp true

echo "==> Shell prompt: username only, no host/path..."
if ! grep -q "^PS1='\\\\u\\\\\$ '" "$HOME/.bashrc" 2>/dev/null; then
    sed -i "s/^PS1=.*/PS1='\\\\u\\\\\$ '/" "$HOME/.bashrc"
fi

echo "==> Renaming Alacritty's launcher entry to 'Terminal' (user-level override)..."
mkdir -p "$HOME/.local/share/applications"
sed 's/^Name=Alacritty$/Name=Terminal/' /usr/share/applications/Alacritty.desktop > "$HOME/.local/share/applications/Alacritty.desktop"

echo "==> Hiding Calibre's bundled LRF viewer from the app launcher..."
sudo rm -f /usr/share/applications/calibre-lrfviewer.desktop

echo "==> Hiding hwloc's lstopo (pulled in as a dependency, not something we"
echo "    use) from the app launcher (user-level override, hwloc itself stays"
echo "    installed -- easyeffects/opencv depend on it)..."
mkdir -p "$HOME/.local/share/applications"
cat > "$HOME/.local/share/applications/lstopo.desktop" << 'DESKTOPEOF'
[Desktop Entry]
Name=Hardware Locality lstopo
NoDisplay=true
Type=Application
DESKTOPEOF

echo "==> Setting Hyprland to launch on tty1 login (no display manager)..."
if ! grep -q "start-hyprland" "$HOME/.bash_profile" 2>/dev/null; then
    echo 'if [ -z "$WAYLAND_DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then exec start-hyprland; fi' >> "$HOME/.bash_profile"
fi

echo ""
echo "==> Done. Drop a wallpaper image at the path set in"
echo "    ~/.config/hypr/hyprpaper.conf (edit that path if you want a different"
echo "    image/location), then reboot and log in at the console --"
echo "    Hyprland + Serpantinum will start automatically."
echo ""
echo "    Keybinds:  mod+D launcher, mod+C clipboard, mod+L lock (shows the"
echo "    matrix rain background), mod+R reload the shell."
