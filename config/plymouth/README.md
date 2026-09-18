# Boot / disk-unlock screen

`serpantinum/` is a Plymouth theme that looks like the shell's lock screen: the
dimmed wallpaper, a "Welcome <user>" box, and a passphrase field that shows one
dot per typed character. It is what asks for the LUKS passphrase at boot.

- `serpantinum.script` has an `@USER@` placeholder; `install.sh` fills in the
  username when it installs the theme.
- `background.png` is the wallpaper stretched to 1366x768 and darkened 75%
  (the same darkening as the lock screen); the script scales it to the real
  screen. `box.png`, `field.png` and `dot.png` are the box, input field and dot.
- The font is Iosevka Nerd Font, which is why the fonts in `config/fonts` are
  installed system-wide: the initramfs build runs as root and copies it in.

`install.sh` also hides the GRUB menu (Esc during the 1 second wait brings it
back), makes the boot quiet, and adds a rescue GRUB entry that boots the
original initramfs (`/boot/initramfs-linux-backup.img`) with no splash, in case
the new one ever misbehaves.

To preview without rebooting, switch to a spare console (Ctrl+Alt+F2) and run
as root, with the desktop's DISPLAY variables removed so Plymouth finds the GPU
itself:

    plymouthd --mode=boot --tty=tty2 --kernel-command-line="quiet splash"
    plymouth show-splash
    plymouth ask-for-password --prompt=test
    plymouth quit
