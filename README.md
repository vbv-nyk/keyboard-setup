# keyboard-setup

Two system-wide keyboard behaviours for Linux, implemented with
[keyd](https://github.com/rvaiya/keyd) so they work in every application --
GTK, Qt, Electron, browsers, terminals, and neovim -- with no per-app setup.

| Keys | Does |
|---|---|
| `Ctrl+W` | Delete the previous word (instead of closing the tab/window) |
| `Shift+Escape` held, then `h` `j` `k` `l` | Left / Down / Up / Right |
| `Escape` alone | Plain, instant Escape -- unchanged |

Escape here means **the key you press as Escape**. If you swap Caps and Escape
(`caps:swapescape`), that is the physical CapsLock key, and the config must name
it `capslock` -- see [Key names](#key-names-keyd-sits-below-xkb).

## Install

```sh
git clone https://github.com/vbv-nyk/keyboard-setup
cd keyboard-setup
./install.sh
```

Or point any Claude Code session at this repo and say "set this up" -- see
[CLAUDE.md](CLAUDE.md).

## How it works

keyd sits below every application, rewriting events as they leave the kernel's
evdev layer. Press `Ctrl+W` in Firefox and the kernel reports
`LEFTCTRL down, W down`; keyd rewrites it to `LEFTCTRL down, BACKSPACE down`,
and Firefox never learns a `W` was involved. That invisibility is what makes
one config cover every toolkit.

### The terminal problem

That invisibility is also the danger. `Ctrl+Backspace` traditionally transmits
byte `0x08` (`^H`), which readline and neovim read as *delete one character*.
So a naive global remap silently downgrades word-delete to char-delete inside
the terminal, and destroys neovim's `Ctrl+W` window prefix.

Two independent guards fix that, and they are worth telling apart:

- **`snippets/alacritty.toml` round-trips the byte.** It binds
  `Ctrl+Backspace` to transmit `0x17` (`^W`) instead, so keyd turns W into
  Backspace and the terminal turns it back into a real `^W` on the wire. This
  fixes the **encoding**.
- **`config/keyd/app.conf` cancels the remap.** `keyd-application-mapper`
  restores a literal `Ctrl+W` whenever a terminal window has focus. This fixes
  the **keystroke**.

The first is load-bearing; the second is a bonus, because the mapper relies on
window-title detection and is unreliable under Hyprland. Either alone would
work, and running both is harmless.

### Key names: keyd sits below XKB

keyd reads raw evdev keycodes, before XKB ever touches them. So an XKB-level
swap -- `setxkbmap -option caps:swapescape`, Hyprland's `kb_options`, or a
`/etc/X11/xorg.conf.d` rule -- is **invisible to keyd**.

The practical consequence: if you have swapped Caps and Escape, the key you
press as Escape is physically CapsLock, and this config must bind `capslock`.
Binding `esc` would put the layer on the top-left key, which your swap has
turned into CapsLock.

The shipped config assumes the swap is in place and binds `capslock`. If you do
not swap, change that one line to `esc = layer(escl)`.

The ordering also explains why the tap still works: pressing the key alone is
not bound in keyd, so it passes through untouched and XKB then turns it into
Escape as usual.

### Why `Shift+Escape` and not bare `Escape`

The obvious design -- make Escape a tap/hold key, tap for Escape and hold for
the nav layer -- fails in practice. Any imperfect chord (releasing Escape a few
milliseconds before `h`) leaks a *real* Escape, and a stray Escape blurs text
inputs, closes dialogs and drops you out of insert mode. The tap action is
modal and destructive, which makes Escape the worst possible choice for a
tap/hold key.

Gating on Shift removes the failure mode entirely: Escape keeps a tap action of
**nothing at all**, has no timeout, and can never leak. It only becomes a layer
key while Shift is already held.

One trap, which the keyd manual is explicit about: keyd preserves
explicitly-held modifiers, so `[shift] esc = layer(nav)` with a plain layer
emits `Shift+Left` -- extending a selection instead of moving the cursor. The
config therefore uses a **composite layer** (`[shift+escl]`), which by design
ignores the modifiers of its constituents and emits unmodified arrows.

## Tradeoffs

- **`Shift+Escape` is a three-key chord.** It is comfortable when Caps and
  Escape are swapped (the layer key sits on the home row) and awkward when they
  are not, since you are then reaching for the top-left corner with Shift held.
- **`Shift+Escape` as a shortcut is consumed.** Few applications bind it, but if
  one you use does, it will no longer reach that application.
- **Terminals not covered by a snippet** fall back to `app.conf`, which is only
  as reliable as window-title detection. Add a snippet for your terminal if
  `Ctrl+W` starts deleting single characters.
- **keyd runs as root** and reads all keyboards. It is a keylogger-shaped
  daemon by construction; read `etc/keyd/default.conf` before installing.
- **A broken keyd config can lock you out of your keyboard.** `install.sh`
  runs `keyd check` before reloading, and keyd falls back to passthrough on a
  parse error, but keep a second input device around when experimenting.

## Layout

```
etc/keyd/default.conf     the global keymap (installed to /etc/keyd/)
config/keyd/app.conf      per-app overrides (installed to ~/.config/keyd/)
snippets/                 fragments appended to terminal / compositor configs
install.sh                idempotent installer, backs up everything it touches
CLAUDE.md                 instructions for Claude Code
```
