# Boot / disk-unlock screen

`passphrase/` is a tiny Plymouth theme (script module) that asks for the LUKS
passphrase at boot: a black screen, the question "Passphrase?" (it scrambles in from
random characters, about a second) and, under it, a blinking white block cursor (a full
character cell, like a terminal's). Every typed character shows as `*`; the stars and
cursor stay centred, growing outward from the middle. No box or other decoration.
Nothing else is drawn, before or after the prompt.

- The font is JetBrains Mono Bold, set with `Font=`/`MonospaceFont=` in `passphrase.plymouth`
  (the initramfs only carries the fonts named there; without them Plymouth bundles the
  thin system default, FreeMono).
- `passphrase.script` draws everything; `white.png` is one white pixel that the
  script scales into the block cursor.
- `install.sh` installs the theme, hides the GRUB menu (Esc during the 1 second
  wait brings it back), makes the boot quiet, loads the Intel GPU driver early
  and forces full backlight at the prompt, and adds a rescue GRUB entry that
  boots the original initramfs (`/boot/initramfs-linux-backup.img`) with no
  splash, in case the new one ever misbehaves.
- Theme edits only take effect after `sudo plymouth-set-default-theme -R passphrase`
  (that rebuilds the initramfs).
