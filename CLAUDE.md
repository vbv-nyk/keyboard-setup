# Instructions for Claude

The user wants this keyboard setup installed on the machine you are running on.
Read this whole file before touching anything.

## What you are installing

1. `Ctrl+W` deletes the previous word everywhere, instead of closing the
   tab/window -- and **still** deletes a word (not a character) inside
   terminals, tmux and neovim.
2. `Shift+Escape` held turns `hjkl` into arrow keys. `Escape` pressed alone
   stays a plain, instant Escape.

**Check the Caps/Escape swap before you install.** Grep the user's config for
`caps:swapescape` (Hyprland `kb_options`, `setxkbmap`, `/etc/X11/xorg.conf.d`).
keyd reads raw evdev keycodes below XKB and does not see that swap, so:

- swap present  -> the layer key must be named `capslock` (the shipped default)
- no swap       -> change it to `esc = layer(escl)`

Get this wrong and the layer lands on the wrong physical key, which the user
will report as "Shift+Escape does nothing".

## Do this

Run `./install.sh` from the repo root. It is idempotent and backs up every file
it overwrites with a `.bak-<timestamp>` suffix. Prefer it over hand-editing.

If the user wants to review before anything changes, show them
`etc/keyd/default.conf` first -- keyd runs as root and reads every keyboard, so
a user is entitled to read the keymap before installing it.

## Things that will bite you

- **Never skip the terminal snippet.** keyd rewrites `Ctrl+W` into
  `Ctrl+Backspace` system-wide. Terminals transmit `Ctrl+Backspace` as `0x08`
  (`^H`), which readline and neovim treat as *delete one character*. Without
  the matching terminal binding that sends `0x17` (`^W`) instead, word-delete
  silently degrades to char-delete and the user will report it as "Ctrl+W is
  broken in the terminal". `install.sh` handles this for alacritty, kitty and
  foot; for any other terminal, write the equivalent binding and add a snippet.
- **Always run `sudo keyd check` before `sudo keyd reload`.** A malformed
  keymap is the one failure mode here that can leave a machine hard to use.
- **Do not turn Escape into a tap/hold key.** It was tried and reverted. A
  tap/hold Escape leaks a real Escape on any imperfect chord, which blurs text
  fields and exits insert mode. This is why the layer is gated behind Shift.
- **Keep the nav layer composite.** `[shift+escl]` is deliberate. A plain layer
  would emit `Shift+Left` (extend selection) because keyd preserves
  explicitly-held modifiers. Do not "simplify" it to `[shift] esc = layer(nav)`.
- **Never name keys by what they produce.** keyd names the physical key. Any
  XKB-level remap (`caps:swapescape`, custom layouts, `xmodmap`) happens after
  keyd and is invisible to it.
- **keyd needs a real system.** It talks to `/dev/input` and systemd, so it will
  not work in a container or over plain SSH into a headless box without a seat.

## Verify, then report

Ask the user to confirm each of these -- you cannot test keystrokes yourself:

- `Ctrl+W` in a browser address bar deletes the previous word
- `Ctrl+W` in a shell prompt still deletes the previous word, not one character
- `Ctrl+W` in neovim normal mode still starts a window command
- `Shift+Escape` held, then `h`, moves the cursor left without selecting text
  (pressing whichever physical key their layout makes Escape)
- `Escape` alone exits insert mode instantly, with no delay

If the arrows select text instead of moving, the layer lost its composite form.
If terminal `Ctrl+W` deletes one character, the terminal snippet did not apply.

## Adapting

Different terminal: add a snippet under `snippets/` and a `patch_file` line in
`install.sh`. Different compositor: the only compositor-specific piece is
autostarting `keyd-application-mapper`, which is optional -- the terminal
snippet is what actually carries the behaviour.
