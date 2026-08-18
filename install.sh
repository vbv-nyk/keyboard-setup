#!/usr/bin/env bash
# Installs the keyboard setup described in README.md.
# Idempotent: safe to re-run. Every file it overwrites is backed up first.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"

say() { printf '\n==> %s\n' "$*"; }
warn() { printf '  !  %s\n' "$*" >&2; }

# --- 1. keyd -----------------------------------------------------------------
if ! command -v keyd >/dev/null 2>&1; then
  say "Installing keyd"
  if   command -v pacman  >/dev/null 2>&1; then sudo pacman -S --needed --noconfirm keyd
  elif command -v apt-get >/dev/null 2>&1; then sudo apt-get install -y keyd
  elif command -v dnf     >/dev/null 2>&1; then sudo dnf install -y keyd
  elif command -v zypper  >/dev/null 2>&1; then sudo zypper install -y keyd
  else
    warn "No known package manager. Build keyd from https://github.com/rvaiya/keyd and re-run."
    exit 1
  fi
else
  say "keyd already installed ($(keyd --version 2>&1 | head -1))"
fi

# --- 2. Global keymap --------------------------------------------------------
say "Installing /etc/keyd/default.conf"
sudo mkdir -p /etc/keyd
if [ -f /etc/keyd/default.conf ]; then
  sudo cp /etc/keyd/default.conf "/etc/keyd/default.conf.bak-$STAMP"
  echo "  backed up existing config to default.conf.bak-$STAMP"
fi
sudo cp "$REPO/etc/keyd/default.conf" /etc/keyd/default.conf
sudo keyd check

# --- 3. Per-application overrides -------------------------------------------
say "Installing ~/.config/keyd/app.conf"
mkdir -p "$HOME/.config/keyd"
[ -f "$HOME/.config/keyd/app.conf" ] && cp "$HOME/.config/keyd/app.conf" "$HOME/.config/keyd/app.conf.bak-$STAMP"
cp "$REPO/config/keyd/app.conf" "$HOME/.config/keyd/app.conf"

# --- 4. Terminal: translate Ctrl+Backspace back to 0x17 ----------------------
# This is the load-bearing half. Without it, word-delete inside the terminal
# silently degrades to single-character delete.
patch_file() {  # patch_file <target> <snippet> <grep-marker>
  local target="$1" snippet="$2" marker="$3"
  [ -f "$target" ] || { mkdir -p "$(dirname "$target")"; : > "$target"; }
  if grep -qF "$marker" "$target"; then
    echo "  already patched: $target"
  else
    cp "$target" "$target.bak-$STAMP"
    printf '\n' >> "$target"
    cat "$snippet" >> "$target"
    echo "  patched: $target"
  fi
}

say "Patching terminal configs (only those already present)"
[ -d "$HOME/.config/alacritty" ] && patch_file "$HOME/.config/alacritty/alacritty.toml" "$REPO/snippets/alacritty.toml" 'u0017'
[ -d "$HOME/.config/kitty" ]     && patch_file "$HOME/.config/kitty/kitty.conf"         "$REPO/snippets/kitty.conf"     'ctrl+backspace send_text'
[ -d "$HOME/.config/foot" ]      && patch_file "$HOME/.config/foot/foot.ini"            "$REPO/snippets/foot.ini"       'Control+BackSpace'
true

# --- 5. Hyprland autostart for the app mapper --------------------------------
HYPR="$HOME/.config/hypr/hyprland.conf"
if [ -f "$HYPR" ]; then
  say "Patching Hyprland autostart"
  patch_file "$HYPR" "$REPO/snippets/hyprland.conf" 'keyd-application-mapper'
fi

# --- 6. Start it -------------------------------------------------------------
say "Enabling and reloading keyd"
sudo systemctl enable --now keyd
sudo keyd reload
echo
echo "Done. Test it:"
echo "  Ctrl+W in a browser address bar   -> deletes the previous word"
echo "  Ctrl+W in a shell                 -> still deletes the previous word"
echo "  Shift+Escape held, then h/j/k/l   -> left/down/up/right"
echo "  Escape alone                      -> plain Escape, no delay"
