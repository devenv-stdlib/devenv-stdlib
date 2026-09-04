# Pure checks for home/warp-lib.nix. Needs <nixpkgs> only for lib.
let
  inherit ((import <nixpkgs> { })) lib;
  warp = import ../../home/warp-lib.nix { inherit lib; };

  must = name: cond: if cond then true else throw "warp-lib: ${name}";

  toml = warp.settingsToml "f12" "";
  tomlExtra = warp.settingsToml "ctrl-`" ''
    [appearance.text]
    font_size = 15.0
  '';
in
assert must "f12" (warp.toGnomeBinding "f12" == "F12");
assert must "ctrl-shift-f12" (warp.toGnomeBinding "ctrl-shift-f12" == "<Ctrl><Shift>F12");
assert must "ctrl-grave" (warp.toGnomeBinding "ctrl-`" == "<Ctrl>grave");
assert must "alt-enter" (warp.toGnomeBinding "alt-enter" == "<Alt>Return");
assert must "super-space" (warp.toGnomeBinding "super-space" == "<Super>space");
assert must "cmd-t" (warp.toGnomeBinding "cmd-t" == "<Super>t");
assert must "uppercase" (warp.toGnomeBinding "CTRL-SHIFT-F5" == "<Ctrl><Shift>F5");
assert must "empty" (!(builtins.tryEval (warp.toGnomeBinding "")).success);
assert must "honor_ps1" (lib.hasInfix "honor_ps1 = true" toml);
assert must "force_x11" (lib.hasInfix "force_x11 = false" toml);
assert must "quake" (lib.hasInfix "keybinding = \"f12\"" toml);
assert must "pin" (lib.hasInfix "active_pin_position = \"top\"" toml);
assert must "extra" (lib.hasInfix "font_size = 15.0" tomlExtra);
assert must "shortcut-path" (lib.hasSuffix "devenv-warp-quake/" warp.gnomeShortcutPath);
true
