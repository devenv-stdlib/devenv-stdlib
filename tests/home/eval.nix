# Pure checks for home/terminal-lib.nix. Needs <nixpkgs> only for lib.
# Import lib alone — `import <nixpkgs> { }` evaluates the whole package set and
# can hang for many minutes on flake:nixpkgs (CI looks stuck, then cancelled).
let
  lib = import <nixpkgs/lib>;
  term = import ../../home/terminal-lib.nix { inherit lib; };

  must = name: cond: if cond then true else throw "terminal-lib: ${name}";

  toml = term.warpSettingsToml {
    keybinding = "f12";
    heightPercent = 30;
    extra = "";
  };
  tomlExtra = term.warpSettingsToml {
    keybinding = "ctrl-`";
    heightPercent = 40;
    extra = ''
      [appearance.text]
      font_size = 15.0
    '';
  };

  desktop = term.mkDesktopEntry {
    name = "Alacritty (Zellij)";
    comment = "test";
    exec = "alacritty -e zellij";
    icon = "/icon.svg";
    wmClass = "dev.devenv.AlacrittyZellij";
  };
  quakeDesktop = term.mkDesktopEntry {
    name = "Alacritty (Quake)";
    comment = "test";
    exec = "alacritty -o window.decorations=None -e zellij";
    icon = "/icon.svg";
    wmClass = "dev.devenv.AlacrittyZellijQuake";
    noDisplay = true;
  };
in
assert must "f12" (term.toGnomeBinding "f12" == "F12");
assert must "ctrl-shift-f12" (term.toGnomeBinding "ctrl-shift-f12" == "<Ctrl><Shift>F12");
assert must "ctrl-grave" (term.toGnomeBinding "ctrl-`" == "<Ctrl>grave");
assert must "alt-enter" (term.toGnomeBinding "alt-enter" == "<Alt>Return");
assert must "super-space" (term.toGnomeBinding "super-space" == "<Super>space");
assert must "cmd-t" (term.toGnomeBinding "cmd-t" == "<Super>t");
assert must "uppercase" (term.toGnomeBinding "CTRL-SHIFT-F5" == "<Ctrl><Shift>F5");
assert must "empty" (!(builtins.tryEval (term.toGnomeBinding "")).success);
assert must "honor_ps1" (lib.hasInfix "honor_ps1 = true" toml);
assert must "force_x11" (lib.hasInfix "force_x11 = false" toml);
assert must "quake" (lib.hasInfix "keybinding = \"f12\"" toml);
assert must "height" (lib.hasInfix "height = 30" toml);
assert must "extra" (lib.hasInfix "font_size = 15.0" tomlExtra);
assert must "shortcut-path" (lib.hasSuffix "devenv-warp-quake/" term.warpShortcutPath);
assert must "alacritty-id" (term.desktopIds.alacritty == "dev.devenv.AlacrittyZellij.desktop");
assert must "alacritty-quake-id" (
  term.desktopIds.alacrittyQuake == "dev.devenv.AlacrittyZellijQuake.desktop"
);
assert must "desktop-exec" (lib.hasInfix "alacritty -e zellij" desktop);
assert must "quake-nodisplay" (lib.hasInfix "NoDisplay=true" quakeDesktop);
assert must "quake-uuid" (term.quakeExtensionUuid == "quake-terminal@diegodario88.github.io");
true
