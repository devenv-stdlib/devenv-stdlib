{
  lib,
  term,
  ...
}:
{
  testGnomeBindingF12 = {
    expr = term.toGnomeBinding "f12";
    expected = "F12";
  };

  testGnomeBindingCtrlShiftF12 = {
    expr = term.toGnomeBinding "ctrl-shift-f12";
    expected = "<Ctrl><Shift>F12";
  };

  testGnomeBindingCtrlGrave = {
    expr = term.toGnomeBinding "ctrl-`";
    expected = "<Ctrl>grave";
  };

  testGnomeBindingAltEnter = {
    expr = term.toGnomeBinding "alt-enter";
    expected = "<Alt>Return";
  };

  testGnomeBindingSuperSpace = {
    expr = term.toGnomeBinding "super-space";
    expected = "<Super>space";
  };

  testGnomeBindingCmdT = {
    expr = term.toGnomeBinding "cmd-t";
    expected = "<Super>t";
  };

  testGnomeBindingUppercase = {
    expr = term.toGnomeBinding "CTRL-SHIFT-F5";
    expected = "<Ctrl><Shift>F5";
  };

  testGnomeBindingEmptyFails = {
    expr = (builtins.tryEval (term.toGnomeBinding "")).success;
    expected = false;
  };

  testWarpTomlHonorPs1 = {
    expr = lib.hasInfix "honor_ps1 = true" (
      term.warpSettingsToml {
        keybinding = "f12";
        heightPercent = 30;
        extra = "";
      }
    );
    expected = true;
  };

  testWarpTomlForceX11 = {
    expr = lib.hasInfix "force_x11 = false" (
      term.warpSettingsToml {
        keybinding = "f12";
        heightPercent = 30;
        extra = "";
      }
    );
    expected = true;
  };

  testWarpTomlKeybinding = {
    expr = lib.hasInfix "keybinding = \"f12\"" (
      term.warpSettingsToml {
        keybinding = "f12";
        heightPercent = 30;
        extra = "";
      }
    );
    expected = true;
  };

  testWarpTomlHeight = {
    expr = lib.hasInfix "height = 30" (
      term.warpSettingsToml {
        keybinding = "f12";
        heightPercent = 30;
        extra = "";
      }
    );
    expected = true;
  };

  testWarpTomlExtra = {
    expr = lib.hasInfix "font_size = 15.0" (
      term.warpSettingsToml {
        keybinding = "ctrl-`";
        heightPercent = 40;
        extra = ''
          [appearance.text]
          font_size = 15.0
        '';
      }
    );
    expected = true;
  };

  testWarpShortcutPath = {
    expr = lib.hasSuffix "devenv-warp-quake/" term.warpShortcutPath;
    expected = true;
  };

  testDesktopIds = {
    expr = term.desktopIds;
    expected = {
      alacritty = "dev.devenv.AlacrittyZellij.desktop";
      alacrittyQuake = "dev.devenv.AlacrittyZellijQuake.desktop";
      warp = "dev.warp.Warp.desktop";
    };
  };

  testDesktopExec = {
    expr = lib.hasInfix "alacritty -e zellij" (
      term.mkDesktopEntry {
        name = "Alacritty (Zellij)";
        comment = "test";
        exec = "alacritty -e zellij";
        icon = "/icon.svg";
        wmClass = "dev.devenv.AlacrittyZellij";
      }
    );
    expected = true;
  };

  testQuakeNoDisplay = {
    expr = lib.hasInfix "NoDisplay=true" (
      term.mkDesktopEntry {
        name = "Alacritty (Quake)";
        comment = "test";
        exec = "alacritty -o window.decorations=None -e zellij";
        icon = "/icon.svg";
        wmClass = "dev.devenv.AlacrittyZellijQuake";
        noDisplay = true;
      }
    );
    expected = true;
  };

  testQuakeExtensionUuid = {
    expr = term.quakeExtensionUuid;
    expected = "quake-terminal@diegodario88.github.io";
  };
}
